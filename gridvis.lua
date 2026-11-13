-- BizHawk Lua
-- 12x26 First-Snake Grid Visualizer
--
-- DISPLAY:
--   Black = empty / background / unknown
--   Green = likely first-snake tile
--
-- CONSOLE:
--   Logs changes to detected snake tiles only
--
-- Confirmed memory structure:
--
--   One tile = 2 bytes:
--
--       byte 0 = tile / sprite ID
--       byte 1 = attribute
--
--   Horizontal stride = 0x02
--   Vertical stride   = 0x80
--
-- Examples from captured bent snake:
--
--   28 08
--   25 08
--   24 08
--
-- Previously captured horizontal snake:
--
--   2D 08
--   25 08
--   25 08
--   25 08
--   25 08
--   23 08

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- MEMORY GEOMETRY
-- ============================================================

local COLUMN_STRIDE = 0x02
local ROW_STRIDE    = 0x80

-- Derived from the captured tilemap:
--
-- Diagnostic row 12 had its first interior tile at 0x0A9C.
--
-- Therefore:
--
--   row 0  = 0x049C
--   row 12 = 0x0A9C
--   row 22 = 0x0F9C
--
-- Some upper rows may belong to another tilemap buffer.
-- For now, invalid/unrecognized data remains black.
local GRID_BASE = 0x049C


-- ============================================================
-- TILE DEFINITIONS
-- ============================================================

local EMPTY_TILE = 0x01

local EXPECTED_ATTRIBUTE = 0x08


-- Confirmed first-snake values.
local CONFIRMED_SNAKE_TILES = {
    [0x23] = true,
    [0x24] = true,
    [0x25] = true,
    [0x28] = true,
    [0x2D] = true
}


-- For this first-snake diagnostic, values 0x20 through 0x3F
-- with attribute 0x08 are treated as likely snake graphics.
--
-- This should include straight, bent, head and tail variants.
local SNAKE_TILE_MIN = 0x20
local SNAKE_TILE_MAX = 0x3F


-- ============================================================
-- DISPLAY
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

local previousSignature = nil


-- ============================================================
-- MEMORY HELPERS
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
        column * COLUMN_STRIDE

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
-- FIRST-SNAKE CLASSIFICATION
-- ============================================================

local function isFirstSnakeTile(tile, attribute)

    -- Require the tilemap attribute observed on the snake.
    if attribute ~= EXPECTED_ATTRIBUTE then
        return false
    end


    -- Explicitly confirmed values.
    if CONFIRMED_SNAKE_TILES[tile] then
        return true
    end


    -- Likely related sprite variants.
    if
        tile >= SNAKE_TILE_MIN and
        tile <= SNAKE_TILE_MAX
    then

        return true

    end


    return false

end


-- ============================================================
-- FIND CURRENT SNAKE TILES
-- ============================================================

local function findSnakeTiles()

    local matches = {}


    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local tile, attribute, address =
                readCell(
                    row,
                    column
                )


            if isFirstSnakeTile(tile, attribute) then

                matches[#matches + 1] = {
                    row = row,
                    column = column,
                    address = address,
                    tile = tile,
                    attribute = attribute
                }

            end

        end

    end


    return matches

end


-- ============================================================
-- BUILD MATCH SIGNATURE
--
-- Prevents console output every frame.
-- ============================================================

local function buildMatchSignature(matches)

    local parts = {}


    for i = 1, #matches do

        local match =
            matches[i]


        parts[#parts + 1] =
            string.format(
                "%04X:%02X",
                match.address,
                match.tile
            )

    end


    return table.concat(
        parts,
        "|"
    )

end


-- ============================================================
-- CONSOLE LOGGING
-- ============================================================

local function logMatches(matches)

    local signature =
        buildMatchSignature(
            matches
        )


    if signature == previousSignature then
        return
    end


    previousSignature =
        signature


    console.log(
        string.format(
            "Snake tiles detected: %d",
            #matches
        )
    )


    for i = 1, #matches do

        local match =
            matches[i]


        local confirmation = "candidate"


        if CONFIRMED_SNAKE_TILES[match.tile] then

            confirmation = "confirmed"

        end


        console.log(
            string.format(
                "  row=%02d col=%02d addr=0x%04X tile=%02X attr=%02X %s",
                match.row,
                match.column,
                match.address,
                match.tile,
                match.attribute,
                confirmation
            )
        )

    end


    console.log("--------------------------------")

end


-- ============================================================
-- INITIAL CONSOLE
-- ============================================================

console.clear()

console.log("First-snake tile visualizer")
console.log("--------------------------------")

console.log(
    string.format(
        "Grid base: 0x%04X",
        GRID_BASE
    )
)

console.log(
    string.format(
        "Vertical stride: 0x%02X",
        ROW_STRIDE
    )
)

console.log(
    string.format(
        "Horizontal stride: 0x%02X",
        COLUMN_STRIDE
    )
)

console.log(
    "Confirmed IDs: 23 24 25 28 2D"
)

console.log(
    "Candidate IDs: 20-3F with attribute 08"
)

console.log("--------------------------------")


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- READ CURRENT GRID
    -- ========================================================

    local matches =
        findSnakeTiles()


    logMatches(
        matches
    )


    -- ========================================================
    -- VISUALIZATION POSITION
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
        0xFF404040,
        0xFF101010
    )


    -- ========================================================
    -- DRAW BLACK GRID
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
    -- DRAW DETECTED FIRST-SNAKE TILES
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
