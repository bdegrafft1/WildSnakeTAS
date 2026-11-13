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
                   
