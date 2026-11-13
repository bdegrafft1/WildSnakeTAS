-- BizHawk Lua
-- 12x26 First-Snake Grid Visualizer
--
-- Phase 1:
--   ONLY display first-snake tiles that we have actually
--   observed.
--
-- DISPLAY:
--   Black = everything else
--   Green = confirmed first-snake tile
--
-- CONSOLE:
--   Logs confirmed snake tile positions only when they change.
--
-- Confirmed tile structure:
--
--   Each actual tile appears to be:
--
--       [tile ID] [attribute]
--
--   Empty:
--
--       01 08
--
-- Confirmed first-snake IDs so far:
--
--   23
--   25
--   28
--   2A
--   2D
--
-- IMPORTANT:
--
-- The previous diagnostic grouped four bytes together.
-- Those were actually TWO adjacent 2-byte tiles.
--
-- So:
--
--   28 08 25 08
--
-- means:
--
--   tile 28
--   tile 25
--
-- NOT one four-byte cell.

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- TILEMAP GEOMETRY
-- ============================================================

-- Actual tiles are two bytes.
local CELL_SIZE = 2

-- Vertical separation observed while falling.
local ROW_STRIDE = 0x80


-- ============================================================
-- MEMORY ANCHOR
--
-- From the diagnostic:
--
-- R22 contained:
--
--   C02 = 28 08 25 08
--   C03 = 2A 08 01 08
--
-- Because the old diagnostic's "C" was 4 bytes wide:
--
-- old C02 corresponds to actual tile columns 4 and 5.
-- old C03 corresponds to actual tile columns 6 and 7.
--
-- However, the playfield itself is 12 columns wide.
--
-- Rather than reuse the incorrect old column numbering,
-- use the observed row buffer directly.
-- ============================================================

-- R22, old C00:
--
-- 00 00 F4 08
--
-- F4 is the left border, so the first playable tile follows it.
--
-- The first playable tile for row 22 therefore begins after
-- the F4 08 pair.
local ROW22_BASE = 0x0F9E


-- Calculate other rows from the confirmed 0x80 spacing.
local GRID_BASE =
    ROW22_BASE -
    (22 * ROW_STRIDE)


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
-- EXPECTED ATTRIBUTE
-- ============================================================

local TILE_ATTRIBUTE = 0x08


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
-- MEMORY HELPERS
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function cellAddress(row, column)

    return
        GRID_BASE +
        row * ROW_STRIDE +
        column * CELL_SIZE

end


local function readCell(row, column)

    local address =
        cellAddress(
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

local function isSnakeTile(tile, attribute)

    if attribute ~= TILE_ATTRIBUTE then
        return false
    end


    return SNAKE_TILES[tile] == true

end


-- ============================================================
-- FIND SNAKE CELLS
-- ============================================================

local function findSnakeCells()

    local matches = {}


    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local tile, attribute, address =
                readCell(
                    row,
                    column
                )


            if isSnakeTile(tile, attribute) then

                matches[#matches + 1] = {

                    row = row,

                    column = column,

                    tile = tile,

                    address = address

                }

            end

        end

    end


    return matches

end


-- ============================================================
-- MATCH SIGNATURE
-- ============================================================

local function buildSignature(matches)

    local result = ""


    for i = 1, #matches do

        local match =
            matches[i]


        result =
            result ..
            string.format(
                "%02d,%02d,%02X|",
                match.row,
                match.column,
                match.tile
            )

    end


    return result

end


-- ============================================================
-- CONSOLE LOG
-- ============================================================

local function logMatches(matches)

    local signature =
        buildSignature(
            matches
        )


    if signature == previousSignature then
        return
    end


    previousSignature =
        signature


    console.log(
        string.format(
            "Snake cells: %d",
            #matches
        )
    )


    for i = 1, #matches do

        local match =
            matches[i]


        console.log(
            string.format(
                "  row=%02d col=%02d addr=0x%04X tile=%02X",
                match.row,
                match.column,
                match.address,
                match.tile
            )
        )

    end


    console.log(
        "--------------------------------"
    )

end


-- ============================================================
-- STARTUP LOG
-- ============================================================

console.clear()

console.log(
    "First-snake visualizer"
)

console.log(
    "Confirmed IDs: 23 25 28 2A 2D"
)

console.log(
    "Empty tile: 01 08"
)

console.log(
    string.format(
        "Grid base candidate: 0x%04X",
        GRID_BASE
    )
)

console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- READ SNAKE
    -- ========================================================

    local matches =
        findSnakeCells()


    logMatches(
        matches
    )


    -- ========================================================
    -- DISPLAY POSITION
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
    -- BLACK GRID
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
    -- GREEN SNAKE CELLS
    -- ========================================================

    for i = 1, #matches do

        local match =
            matches[i]


        local x =
            gridX +
            match.column * CELL_PIXELS


        local y =
            gridY +
            match.row * CELL_PIXELS


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
