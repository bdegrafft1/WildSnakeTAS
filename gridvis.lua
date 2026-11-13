-- BizHawk Lua
-- First Snake Visualizer / Unknown Sprite Finder
--
-- CONFIRMED FOR CURRENT FRAME:
--
--   0x0FA0 = 28 08
--   0x0FA2 = 25 08
--   0x0FA4 = 2A 08
--
-- These are three pieces of the visible bent snake.
--
-- DISPLAY:
--
--   Black  = empty / background
--   Green  = confirmed snake sprite
--   Yellow = unknown non-empty tile with attribute 08
--
-- CONSOLE:
--
--   Logs unknown candidate tiles near the snake.
--
-- Current confirmed first-snake IDs:
--
--   23
--   25
--   28
--   2A
--   2D

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- MEMORY STRUCTURE
-- ============================================================

local CELL_SIZE  = 2
local ROW_STRIDE = 0x80


-- ============================================================
-- CURRENT GRID BASE
--
-- Keep this unchanged for this diagnostic.
-- ============================================================

local GRID_BASE = 0x049E


-- ============================================================
-- TILE FORMAT
-- ============================================================

local EMPTY_TILE = 0x01
local TILE_ATTRIBUTE = 0x08


-- ============================================================
-- CONFIRMED FIRST-SNAKE IDS
-- ============================================================

local SNAKE_TILES = {

    [0x23] = true,

    [0x25] = true,

    [0x28] = true,

    [0x2A] = true,

    [0x2D] = true

}


-- ============================================================
-- IGNORE KNOWN BOARD GRAPHICS
--
-- These are structural/background pieces we've already seen
-- in the dump and do not want highlighted as candidates.
-- ============================================================

local IGNORE_TILES = {

    [0x01] = true,

    [0xF4] = true,

    [0xF5] = true,

    [0xF6] = true,

    [0xF7] = true,

    [0xFC] = true,

    [0xFD] = true,

    [0xFE] = true,

    [0xFF] = true

}


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

local previousUnknownSignature = ""


-- ============================================================
-- MEMORY
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function getCellAddress(row, column)

    return
        GRID_BASE +
        row * ROW_STRIDE +
        column * CELL_SIZE

end


local function readCell(row, column)

    local address =
        getCellAddress(
            row,
            column
        )


    local tile =
        readByte(address)


    local attribute =
        readByte(address + 1)


    return tile, attribute, address

end


-- ============================================================
-- CLASSIFICATION
-- ============================================================

local function isConfirmedSnake(tile, attribute)

    return
        attribute == TILE_ATTRIBUTE and
        SNAKE_TILES[tile] == true

end


local function isUnknownCandidate(tile, attribute)

    if attribute ~= TILE_ATTRIBUTE then
        return false
    end


    if SNAKE_TILES[tile] then
        return false
    end


    if IGNORE_TILES[tile] then
        return false
    end


    return true

end


-- ============================================================
-- BUILD UNKNOWN LIST
-- ============================================================

local function findUnknownCandidates()

    local candidates = {}


    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local tile, attribute, address =
                readCell(
                    row,
                    column
                )


            if isUnknownCandidate(tile, attribute) then

                candidates[#candidates + 1] = {

                    row = row,

                    column = column,

                    tile = tile,

                    address = address

                }

            end

        end

    end


    return candidates

end


-- ============================================================
-- LOG UNKNOWN CANDIDATES
-- ============================================================

local function logUnknownCandidates(candidates)

    local parts = {}


    for i = 1, #candidates do

        local candidate =
            candidates[i]


        parts[#parts + 1] =
            string.format(
                "%04X:%02X",
                candidate.address,
                candidate.tile
            )

    end


    local signature =
        table.concat(
            parts,
            "|"
        )


    if signature == previousUnknownSignature then
        return
    end


    previousUnknownSignature =
        signature


    console.log(
        string.format(
            "Unknown candidates: %d",
            #candidates
        )
    )


    for i = 1, #candidates do

        local candidate =
            candidates[i]


        console.log(
            string.format(
                "  row=%02d col=%02d addr=0x%04X tile=%02X",
                candidate.row,
                candidate.column,
                candidate.address,
                candidate.tile
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
    "First-snake unknown sprite finder"
)

console.log(
    "Green = confirmed snake"
)

console.log(
    "Yellow = unknown XX 08 candidate"
)

console.log(
    "Confirmed IDs: 23 25 28 2A 2D"
)

console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- FIND UNKNOWN CANDIDATES
    -- ========================================================

    local unknownCandidates =
        findUnknownCandidates()


    logUnknownCandidates(
        unknownCandidates
    )


    -- ========================================================
    -- VISUALIZATION
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
    -- DRAW CELLS
    -- ========================================================

    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local tile, attribute, address =
                readCell(
                    row,
                    column
                )


            local color =
                0xFF000000


            -- Confirmed snake
            if isConfirmedSnake(
                tile,
                attribute
            ) then

                color =
                    0xFF00FF40


            -- Unknown candidate
            elseif isUnknownCandidate(
                tile,
                attribute
            ) then

                color =
                    0xFFFFFF00

            end


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
                color
            )

        end

    end


    emu.frameadvance()

end
