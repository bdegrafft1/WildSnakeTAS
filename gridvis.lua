-- BizHawk Lua
-- 12x26 First-Snake Visualizer
--
-- Confirmed memory geometry:
--
--   Horizontal tile step = 0x02
--   Vertical tile step   = 0x40
--
-- Confirmed / strongly identified snake #1 tile IDs:
--
--   23
--   24
--   25
--   27
--   28
--   2A
--   2D
--   2E
--
-- DISPLAY:
--
--   Black = empty / everything else
--   Green = snake #1
--
-- CONSOLE:
--
--   Only logs snake layout when it changes.

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
local ROW_STRIDE    = 0x40


-- ============================================================
-- GRID BASE
--
-- We know from the current frame:
--
--   row? col? = 0x0FA0
--
-- The previous diagnostics were offset because they used
-- 0x80 as the row stride.
--
-- From the original dump, playable rows repeat on 0x40
-- boundaries.
--
-- Start of first playable interior row:
--
--   0x0A82
--
-- We'll use this directly and validate against the six-tile
-- shape.
-- ============================================================

local GRID_BASE = 0x0A82


-- ============================================================
-- TILE FORMAT
-- ============================================================

local TILE_ATTRIBUTE = 0x08


-- ============================================================
-- FIRST SNAKE TILE IDS
-- ============================================================

local SNAKE_TILES = {

    [0x23] = true,

    [0x24] = true,

    [0x25] = true,

    [0x27] = true,

    [0x28] = true,

    [0x2A] = true,

    [0x2D] = true,

    [0x2E] = true

}


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
-- CLASSIFICATION
-- ============================================================

local function isSnakeTile(tile, attribute)

    return
        attribute == TILE_ATTRIBUTE and
        SNAKE_TILES[tile] == true

end


-- ============================================================
-- FIND SNAKE
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


            if isSnakeTile(
                tile,
                attribute
            ) then

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
-- SIGNATURE
-- ============================================================

local function buildSignature(matches)

    local parts = {}


    for i = 1, #matches do

        local match =
            matches[i]


        parts[#parts + 1] =
            string.format(
                "%02d:%02d:%02X",
                match.row,
                match.column,
                match.tile
            )

    end


    return table.concat(
        parts,
        "|"
    )

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
-- STARTUP
-- ============================================================

console.clear()


console.log(
    "First-snake visualizer"
)


console.log(
    "Horizontal stride = 0x02"
)


console.log(
    "Vertical stride = 0x40"
)


console.log(
    "Snake IDs = 23 24 25 27 28 2A 2D 2E"
)


console.log(
    string.format(
        "Grid base = 0x%04X",
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
    -- DETECT SNAKE
    -- ========================================================

    local matches =
        findSnakeCells()


    logMatches(
        matches
    )


    -- ========================================================
    -- PANEL
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
    -- DRAW GRID
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


            if isSnakeTile(
                tile,
                attribute
            ) then

                color =
                    0xFF00FF40

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
