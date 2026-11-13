-- BizHawk Lua
-- 12x26 First-Snake Visualizer
--
-- Black = empty
-- Green = detected first snake
--
-- MEMORY GEOMETRY:
--
--   horizontal = +0x02
--   vertical   = +0x40
--
-- IMPORTANT:
--
-- Previous version normalized the snake's X position:
--
--   outputColumn = rawColumn - minColumn
--
-- That made every snake appear against the left edge.
--
-- This version preserves the REAL raw memory column and
-- subtracts one fixed playfield offset.
--
-- Debug -> console only.

local DOMAIN = "WRAM"


-- ============================================================
-- OUTPUT GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 5
local PANEL_MARGIN = 4


-- ============================================================
-- RAW MEMORY
-- ============================================================

local SEARCH_START = 0x0A80
local SEARCH_END   = 0x110E

local HORIZONTAL_STEP = 0x02
local VERTICAL_STEP   = 0x40


-- ============================================================
-- PLAYFIELD CALIBRATION
--
-- A raw memory row is 32 tiles wide.
--
-- The actual game board uses 12 of those columns.
--
-- This value means:
--
--   raw column 16 -> game column 0
--   raw column 17 -> game column 1
--   ...
--   raw column 27 -> game column 11
--
-- If the entire snake appears:
--
--   1 cell too far LEFT:
--       decrease this by 1
--
--   1 cell too far RIGHT:
--       increase this by 1
--
-- ============================================================

local PLAYFIELD_RAW_COLUMN = 16


-- ============================================================
-- VERTICAL CALIBRATION
--
-- SEARCH_START is currently treated as raw row zero.
--
-- Keep this adjustable independently from X.
-- ============================================================

local PLAYFIELD_RAW_ROW = 0


-- ============================================================
-- FIRST-SNAKE CANDIDATE IDS
-- ============================================================

local SNAKE_TILES = {}

for value = 0x22, 0x2E do
    SNAKE_TILES[value] = true
end


-- ============================================================
-- FILTERING
--
-- Ignore isolated coincidental values.
-- ============================================================

local MIN_CLUSTER_SIZE = 2


-- ============================================================
-- DISPLAY SIZE
-- ============================================================

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS +
    PANEL_MARGIN * 2

local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS +
    PANEL_MARGIN * 2


client.SetGameExtraPadding(
    0,
    0,
    PANEL_WIDTH,
    0
)


-- ============================================================
-- STATE
-- ============================================================

local previousSignature = ""


-- ============================================================
-- MEMORY HELPER
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


-- ============================================================
-- RAW COORDINATES
--
-- Convert an address directly into the 32-column raw tilemap.
-- ============================================================

local function rawCoordinates(address)

    local offset =
        address - SEARCH_START


    local rawRow =
        math.floor(
            offset / VERTICAL_STEP
        )


    local byteColumn =
        offset % VERTICAL_STEP


    local rawColumn =
        math.floor(
            byteColumn / HORIZONTAL_STEP
        )


    return rawRow, rawColumn

end


-- ============================================================
-- RAW -> GAME GRID
--
-- Preserve the actual X/Y position.
-- ============================================================

local function gameCoordinates(address)

    local rawRow, rawColumn =
        rawCoordinates(
            address
        )


    local gameColumn =
        rawColumn -
        PLAYFIELD_RAW_COLUMN


    local gameRow =
        rawRow -
        PLAYFIELD_RAW_ROW


    return gameRow, gameColumn

end


-- ============================================================
-- SCAN CANDIDATES
-- ============================================================

local function scanCandidates()

    local candidates = {}

    local lookup = {}


    for address = SEARCH_START, SEARCH_END, 2 do

        local value =
            readByte(address)


        if SNAKE_TILES[value] then

            local candidate = {

                address = address,

                value = value

            }


            candidates[#candidates + 1] =
                candidate


            lookup[address] =
                candidate

        end

    end


    return candidates, lookup

end


-- ============================================================
-- BUILD CONNECTED CLUSTERS
--
-- Connected if:
--
--   +/- 0x02 horizontally
--   +/- 0x40 vertically
-- ============================================================

local function buildClusters(candidates, lookup)

    local clusters = {}

    local visited = {}


    for i = 1, #candidates do

        local start =
            candidates[i]


        if not visited[start.address] then

            local cluster = {}

            local queue = {
                start.address
            }

            local queueIndex = 1


            visited[start.address] =
                true


            while queueIndex <= #queue do

                local address =
                    queue[queueIndex]


                queueIndex =
                    queueIndex + 1


                local entry =
                    lookup[address]


                if entry ~= nil then

                    cluster[#cluster + 1] =
                        entry


                    local neighbours = {

                        address - HORIZONTAL_STEP,
                        address + HORIZONTAL_STEP,

                        address - VERTICAL_STEP,
                        address + VERTICAL_STEP

                    }


                    for n = 1, #neighbours do

                        local neighbour =
                            neighbours[n]


                        if
                            lookup[neighbour] ~= nil and
                            not visited[neighbour]
                        then

                            visited[neighbour] =
                                true


                            queue[#queue + 1] =
                                neighbour

                        end

                    end

                end

            end


            if #cluster >= MIN_CLUSTER_SIZE then

                clusters[#clusters + 1] =
                    cluster

            end

        end

    end


    return clusters

end


-- ============================================================
-- CHOOSE BEST CLUSTER
--
-- For phase 1, use the largest connected cluster.
-- ============================================================

local function chooseSnake(clusters)

    local best = nil


    for i = 1, #clusters do

        local cluster =
            clusters[i]


        if
            best == nil or
            #cluster > #best
        then

            best =
                cluster

        end

    end


    return best

end


-- ============================================================
-- MAP CLUSTER INTO REAL 12x26 GRID
-- ============================================================

local function mapSnake(cluster)

    local output = {}


    if cluster == nil then
        return output
    end


    for i = 1, #cluster do

        local entry =
            cluster[i]


        local row, column =
            gameCoordinates(
                entry.address
            )


        if
            column >= 0 and
            column < GRID_WIDTH and
            row >= 0 and
            row < GRID_HEIGHT
        then

            output[#output + 1] = {

                address = entry.address,

                value = entry.value,

                row = row,

                column = column

            }

        end

    end


    return output

end


-- ============================================================
-- CONSOLE DEBUG
-- ============================================================

local function logSnake(cluster)

    local parts = {}


    if cluster ~= nil then

        for i = 1, #cluster do

            local entry =
                cluster[i]


            parts[#parts + 1] =
                string.format(
                    "%04X:%02X",
                    entry.address,
                    entry.value
                )

        end

    end


    local signature =
        table.concat(
            parts,
            "|"
        )


    if signature == previousSignature then
        return
    end


    previousSignature =
        signature


    if cluster == nil then

        console.log(
            "Snake cluster: none"
        )

        return

    end


    console.log(
        string.format(
            "Snake cluster: %d cells",
            #cluster
        )
    )


    for i = 1, #cluster do

        local entry =
            cluster[i]


        local rawRow, rawColumn =
            rawCoordinates(
                entry.address
            )


        local gameRow, gameColumn =
            gameCoordinates(
                entry.address
            )


        console.log(
            string.format(
                "  0x%04X=%02X raw=(%d,%d) game=(%d,%d)",
                entry.address,
                entry.value,
                rawColumn,
                rawRow,
                gameColumn,
                gameRow
            )
        )

    end


    console.log(
        "--------------------------------"
    )

end


-- ============================================================
-- STARTUP
-- ============================================================

console.clear()


console.log(
    "12x26 snake visualizer"
)


console.log(
    string.format(
        "Playfield raw X origin: %d",
        PLAYFIELD_RAW_COLUMN
    )
)


console.log(
    string.format(
        "Playfield raw Y origin: %d",
        PLAYFIELD_RAW_ROW
    )
)


console.log(
    "X step = 0x02"
)


console.log(
    "Y step = 0x40"
)


console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- DETECT SNAKE
    -- ========================================================

    local candidates, lookup =
        scanCandidates()


    local clusters =
        buildClusters(
            candidates,
            lookup
        )


    local cluster =
        chooseSnake(
            clusters
        )


    logSnake(
        cluster
    )


    local snake =
        mapSnake(
            cluster
        )


    -- ========================================================
    -- PANEL POSITION
    -- ========================================================

    local panelX =
        client.bufferwidth()


    local gridX =
        panelX +
        PANEL_MARGIN


    local gridY =
        PANEL_MARGIN


    -- ========================================================
    -- BACKGROUND
    -- ========================================================

    gui.drawRectangle(
        panelX,
        0,
        PANEL_WIDTH - 1,
        PANEL_HEIGHT,
        0xFF202020,
        0xFF101010
    )


    -- ========================================================
    -- EXACTLY 12 x 26 GRID
    -- ========================================================

    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local x =
                gridX +
                column * CELL_PIXELS


            local y =
                gridY +
                row * CELL_PIXELS


            gui.drawRectangle(
                x,
                y,
                CELL_PIXELS - 1,
                CELL_PIXELS - 1,
                0xFF404040,
                0xFF000000
            )

        end

    end


    -- ========================================================
    -- DRAW SNAKE
    -- ========================================================

    for i = 1, #snake do

        local cell =
            snake[i]


        local x =
            gridX +
            cell.column * CELL_PIXELS


        local y =
            gridY +
            cell.row * CELL_PIXELS


        gui.drawRectangle(
            x,
            y,
            CELL_PIXELS - 1,
            CELL_PIXELS - 1,
            0xFFFFFFFF,
            0xFF00FF40
        )

    end


    emu.frameadvance()

end
