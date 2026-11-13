-- BizHawk Lua
-- 12x26 First Snake Visualizer
--
-- Output is EXACTLY:
--
--   12 columns
--   26 rows
--
-- Black = empty
-- Green = detected snake
--
-- Memory detection:
--
--   snake candidate IDs = 0x22 through 0x2E
--   horizontal adjacency = 0x02
--   vertical adjacency   = 0x40
--
-- Isolated candidate bytes are ignored.
--
-- Debug goes to console only.

local DOMAIN = "WRAM"


-- ============================================================
-- OUTPUT GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

-- Smaller cells so the output visually matches the game grid.
local CELL_PIXELS = 5

local PANEL_MARGIN = 4


-- ============================================================
-- MEMORY
-- ============================================================

local SEARCH_START = 0x0A80
local SEARCH_END   = 0x110E

local HORIZONTAL_STEP = 0x02
local VERTICAL_STEP   = 0x40


-- ============================================================
-- SNAKE IDS
-- ============================================================

local SNAKE_TILES = {}

for value = 0x22, 0x2E do
    SNAKE_TILES[value] = true
end


-- ============================================================
-- FILTER
--
-- A random matching byte by itself is ignored.
-- ============================================================

local MIN_CLUSTER_SIZE = 2


-- ============================================================
-- PANEL SIZE
--
-- 12 * 5 = 60 pixels wide
-- 26 * 5 = 130 pixels tall
-- ============================================================

local GRID_PIXEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS

local GRID_PIXEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS

local PANEL_WIDTH =
    GRID_PIXEL_WIDTH +
    PANEL_MARGIN * 2

local PANEL_HEIGHT =
    GRID_PIXEL_HEIGHT +
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
-- SCAN MEMORY
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
-- CHOOSE LARGEST CLUSTER
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
-- RAW ADDRESS -> RAW MEMORY X/Y
--
-- Each raw memory row:
--
--   0x40 bytes
--
-- Each logical tile:
--
--   2 bytes
--
-- Therefore each raw row contains 32 positions.
-- ============================================================

local function rawCoordinates(address)

    local offset =
        address - SEARCH_START


    local row =
        math.floor(
            offset / VERTICAL_STEP
        )


    local byteColumn =
        offset % VERTICAL_STEP


    local column =
        math.floor(
            byteColumn / HORIZONTAL_STEP
        )


    return row, column

end


-- ============================================================
-- MAP SNAKE TO 12x26
--
-- We don't yet know the exact playfield X origin inside the
-- 32-wide raw tilemap.
--
-- Instead of displaying all 32 columns, determine the snake's
-- bounding box and preserve its shape in the 12-wide output.
--
-- Vertical position follows raw memory row.
-- ============================================================

local function mapSnake(cluster)

    local output = {}


    if cluster == nil then
        return output
    end


    local raw = {}

    local minColumn = nil


    for i = 1, #cluster do

        local entry =
            cluster[i]


        local row, column =
            rawCoordinates(
                entry.address
            )


        raw[#raw + 1] = {

            address = entry.address,

            value = entry.value,

            row = row,

            column = column

        }


        if
            minColumn == nil or
            column < minColumn
        then

            minColumn =
                column

        end

    end


    -- --------------------------------------------------------
    -- X placement
    --
    -- Temporarily place the snake starting at its relative
    -- position within the 12-column board.
    --
    -- Using column 0 as the snake bounding-box origin means
    -- the output can NEVER exceed 12 columns.
    -- --------------------------------------------------------

    for i = 1, #raw do

        local entry =
            raw[i]


        local outputColumn =
            entry.column -
            minColumn


        local outputRow =
            entry.row


        if
            outputColumn >= 0 and
            outputColumn < GRID_WIDTH and
            outputRow >= 0 and
            outputRow < GRID_HEIGHT
        then

            output[#output + 1] = {

                address = entry.address,

                value = entry.value,

                row = outputRow,

                column = outputColumn

            }

        end

    end


    return output

end


-- ============================================================
-- CONSOLE
-- ============================================================

local function logSnake(cluster)

    local signatureParts = {}


    if cluster ~= nil then

        for i = 1, #cluster do

            local entry =
                cluster[i]


            signatureParts[#signatureParts + 1] =
                string.format(
                    "%04X:%02X",
                    entry.address,
                    entry.value
                )

        end

    end


    local signature =
        table.concat(
            signatureParts,
            "|"
        )


    if signature == previousSignature then
        return
    end


    previousSignature =
        signature


    if cluster == nil then

        console.log(
            "Snake: none"
        )

        return

    end


    console.log(
        string.format(
            "Snake: %d cells",
            #cluster
        )
    )


    for i = 1, #cluster do

        local entry =
            cluster[i]


        local row, column =
            rawCoordinates(
                entry.address
            )


        console.log(
            string.format(
                "  0x%04X = %02X raw=(%d,%d)",
                entry.address,
                entry.value,
                column,
                row
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
    "Output width: 12"
)


console.log(
    "Output height: 26"
)


console.log(
    string.format(
        "Pixel size: %dx%d",
        GRID_PIXEL_WIDTH,
        GRID_PIXEL_HEIGHT
    )
)


console.log(
    "Candidate IDs: 22-2E"
)


console.log(
    "Isolated matches ignored"
)


console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- DETECT
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
    -- PANEL BACKGROUND
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
    -- EXACTLY 12 x 26 CELLS
    -- ========================================================

    for row = 0, 25 do

        for column = 0, 11 do

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
    -- GREEN SNAKE
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
