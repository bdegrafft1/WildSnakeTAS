-- BizHawk Lua
-- 12x26 Snake Visualizer
--
-- Strategy:
--
--   1. Scan raw WRAM for known snake tile IDs.
--   2. Group candidates by adjacency in memory:
--
--        horizontal = +/- 0x02
--        vertical   = +/- 0x40
--
--   3. Reject isolated/random matches.
--   4. Select the largest connected cluster.
--   5. Draw that cluster on a clean 12x26 grid.
--
-- This avoids relying on a questionable global GRID_BASE.
--
-- DISPLAY:
--   Black = empty
--   Green = connected snake tiles
--
-- CONSOLE:
--   Debug only when the detected snake changes.

local DOMAIN = "WRAM"


-- ============================================================
-- OUTPUT GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- RAW MEMORY
-- ============================================================

local SEARCH_START = 0x0A80
local SEARCH_END   = 0x110E

local HORIZONTAL_STEP = 0x02
local VERTICAL_STEP   = 0x40


-- ============================================================
-- SNAKE TILE IDS
--
-- Candidate first-snake sprite family.
-- ============================================================

local SNAKE_TILES = {

    [0x22] = true,
    [0x23] = true,
    [0x24] = true,
    [0x25] = true,
    [0x26] = true,
    [0x27] = true,
    [0x28] = true,
    [0x29] = true,
    [0x2A] = true,
    [0x2B] = true,
    [0x2C] = true,
    [0x2D] = true,
    [0x2E] = true

}


-- ============================================================
-- FILTERING
--
-- Minimum number of connected tiles required before a group
-- is considered a snake.
--
-- Your snake currently has six visible pieces, but using 2
-- allows partial visibility / animation without disappearing.
--
-- Isolated random pixels will be rejected.
-- ============================================================

local MIN_CLUSTER_SIZE = 2


-- ============================================================
-- PANEL
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
-- MEMORY
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function isSnakeValue(value)

    return SNAKE_TILES[value] == true

end


-- ============================================================
-- SCAN CANDIDATES
--
-- Return every two-byte-aligned address containing one of the
-- known/candidate snake tile IDs.
-- ============================================================

local function scanCandidates()

    local candidates = {}

    local lookup = {}


    for address = SEARCH_START, SEARCH_END, 2 do

        local value =
            readByte(address)


        if isSnakeValue(value) then

            local entry = {

                address = address,

                value = value

            }


            candidates[#candidates + 1] =
                entry


            lookup[address] =
                entry

        end

    end


    return candidates, lookup

end


-- ============================================================
-- FIND CONNECTED CLUSTERS
--
-- Two candidate tiles are adjacent when their addresses differ
-- by:
--
--   0x02 horizontally
--   0x40 vertically
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

            visited[start.address] =
                true


            local queueIndex = 1


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
-- CHOOSE SNAKE
--
-- For phase 1 there is only one snake of interest.
--
-- Choose the largest connected candidate cluster.
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
-- MEMORY ADDRESS -> RAW COORDINATE
--
-- This coordinate system is relative to the detected cluster,
-- not to the game's absolute playfield.
--
-- Since:
--
--   x step = 0x02
--   y step = 0x40
--
-- we can derive the shape directly.
-- ============================================================

local function calculateClusterCoordinates(cluster)

    if cluster == nil then
        return {}
    end


    -- Find the smallest address row represented by the cluster.
    local minRowBase = nil

    local rawCells = {}


    for i = 1, #cluster do

        local entry =
            cluster[i]


        local relative =
            entry.address - SEARCH_START


        local row =
            math.floor(
                relative / VERTICAL_STEP
            )


        local byteInRow =
            relative % VERTICAL_STEP


        local column =
            math.floor(
                byteInRow / HORIZONTAL_STEP
            )


        rawCells[#rawCells + 1] = {

            address = entry.address,

            value = entry.value,

            rawRow = row,

            rawColumn = column

        }


        if
            minRowBase == nil or
            row < minRowBase
        then

            minRowBase = row

        end

    end


    return rawCells

end


-- ============================================================
-- NORMALIZE CLUSTER
--
-- Convert raw memory coordinates into coordinates suitable for
-- the clean 12x26 visualization.
--
-- Keep the shape intact.
--
-- For now:
--   horizontally center the detected snake
--   preserve its raw vertical position as much as possible
-- ============================================================

local function normalizeSnake(rawCells)

    if #rawCells == 0 then
        return {}
    end


    local minColumn = nil
    local maxColumn = nil

    local minRow = nil
    local maxRow = nil


    for i = 1, #rawCells do

        local cell =
            rawCells[i]


        if
            minColumn == nil or
            cell.rawColumn < minColumn
        then

            minColumn =
                cell.rawColumn

        end


        if
            maxColumn == nil or
            cell.rawColumn > maxColumn
        then

            maxColumn =
                cell.rawColumn

        end


        if
            minRow == nil or
            cell.rawRow < minRow
        then

            minRow =
                cell.rawRow

        end


        if
            maxRow == nil or
            cell.rawRow > maxRow
        then

            maxRow =
                cell.rawRow

        end

    end


    local snakeWidth =
        maxColumn - minColumn + 1


    -- Center horizontally for the moment.
    local outputStartColumn =
        math.floor(
            (GRID_WIDTH - snakeWidth) / 2
        )


    -- Preserve vertical movement relative to the searched
    -- memory region.
    local outputStartRow =
        minRow


    -- Keep it in bounds.
    if outputStartRow < 0 then
        outputStartRow = 0
    end


    if outputStartRow >= GRID_HEIGHT then

        outputStartRow =
            GRID_HEIGHT - 1

    end


    local result = {}


    for i = 1, #rawCells do

        local cell =
            rawCells[i]


        local column =
            outputStartColumn +
            (cell.rawColumn - minColumn)


        local row =
            outputStartRow +
            (cell.rawRow - minRow)


        if
            column >= 0 and
            column < GRID_WIDTH and
            row >= 0 and
            row < GRID_HEIGHT
        then

            result[#result + 1] = {

                address = cell.address,

                value = cell.value,

                row = row,

                column = column

            }

        end

    end


    return result

end


-- ============================================================
-- CONSOLE LOGGING
-- ============================================================

local function logSnake(snake)

    local parts = {}


    if snake ~= nil then

        for i = 1, #snake do

            local cell =
                snake[i]


            parts[#parts + 1] =
                string.format(
                    "%04X:%02X",
                    cell.address,
                    cell.value
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


    if snake == nil then

        console.log(
            "Snake cluster: none"
        )

        return

    end


    console.log(
        string.format(
            "Snake cluster: %d tiles",
            #snake
        )
    )


    for i = 1, #snake do

        local cell =
            snake[i]


        console.log(
            string.format(
                "  0x%04X = %02X",
                cell.address,
                cell.value
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
    "Connected snake visualizer"
)


console.log(
    "Raw horizontal adjacency: 0x02"
)


console.log(
    "Raw vertical adjacency: 0x40"
)


console.log(
    "Isolated candidate values are ignored"
)


console.log(
    string.format(
        "Minimum cluster: %d",
        MIN_CLUSTER_SIZE
    )
)


console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN
-- ============================================================

while true do

    -- ========================================================
    -- DETECT CONNECTED SNAKE
    -- ========================================================

    local candidates, lookup =
        scanCandidates()


    local clusters =
        buildClusters(
            candidates,
            lookup
        )


    local snake =
        chooseSnake(
            clusters
        )


    logSnake(
        snake
    )


    local rawCells =
        calculateClusterCoordinates(
            snake
        )


    local displayCells =
        normalizeSnake(
            rawCells
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
        0xFF404040,
        0xFF101010
    )


    -- ========================================================
    -- CLEAN 12x26 GRID
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
                0xFF303030,
                0xFF000000
            )

        end

    end


    -- ========================================================
    -- DETECTED CONNECTED SNAKE
    -- ========================================================

    for i = 1, #displayCells do

        local cell =
            displayCells[i]


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
