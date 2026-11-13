-- BizHawk Lua
-- 12x26 Snake Grid Visualizer
--
-- Phase 1
--
-- Black = empty / unknown
-- Green = known snake sprite
--
-- Confirmed from live memory:
--
--   10E8 = 2D   head
--   10EA = 25   body
--   10EC = 25   body
--   10EE = 25   body
--   10F0 = 25   body
--   10F2 = 23   tail
--
-- The visible snake occupies the final 6 cells
-- of the bottom row.

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_SIZE  = 2
local ROW_STRIDE = 0x40


-- ============================================================
-- MEMORY MAPPING
-- ============================================================

-- Confirmed snake head.
local SNAKE_HEAD_ADDRESS = 0x10E8

-- Snake visually begins at column 6.
local SNAKE_HEAD_COLUMN = 6

-- Calculate the beginning of the bottom row.
local LAST_ROW_BASE =
    SNAKE_HEAD_ADDRESS
    - (SNAKE_HEAD_COLUMN * CELL_SIZE)

-- Calculate the beginning of row zero.
local GRID_BASE =
    LAST_ROW_BASE
    - ((GRID_HEIGHT - 1) * ROW_STRIDE)


-- ============================================================
-- KNOWN SNAKE TILES
-- ============================================================

local SNAKE_TILES = {

    [0x2D] = true, -- right-facing head

    [0x25] = true, -- horizontal body

    [0x23] = true  -- tail
}


-- ============================================================
-- VISUAL SETTINGS
-- ============================================================

local CELL_PIXELS = 8
local PANEL_MARGIN = 8

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS
    + PANEL_MARGIN * 2

local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS
    + PANEL_MARGIN * 2
    + 18


-- ============================================================
-- EXTRA SCREEN SPACE
-- ============================================================

client.SetGameExtraPadding(
    0,
    0,
    PANEL_WIDTH,
    0
)


-- ============================================================
-- MEMORY FUNCTIONS
-- ============================================================

local function getCellAddress(row, column)

    return GRID_BASE
        + row * ROW_STRIDE
        + column * CELL_SIZE

end


local function readCell(row, column)

    local address =
        getCellAddress(
            row,
            column
        )

    local tile =
        memory.read_u8(
            address,
            DOMAIN
        )

    local attribute =
        memory.read_u8(
            address + 1,
            DOMAIN
        )

    return tile, attribute, address

end


local function isSnakeTile(tile)

    return SNAKE_TILES[tile] == true

end


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- Your working right-side panel location.
    local panelX =
        client.bufferwidth()

    local panelY =
        PANEL_MARGIN - 16


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
    -- GRID TITLE
    -- ========================================================

    gui.pixelText(
        panelX + PANEL_MARGIN,
        panelY,
        "Snake grid 12x26",
        0xFFFFFFFF,
        0xFF101010
    )


    local gridX =
        panelX + PANEL_MARGIN

    local gridY =
        panelY + 14


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


            local x =
                gridX
                + column * CELL_PIXELS


            local y =
                gridY
                + row * CELL_PIXELS


            local fillColor =
                0xFF000000


            if isSnakeTile(tile) then

                fillColor =
                    0xFF00C840

            end


            gui.drawRectangle(
                x,
                y,
                CELL_PIXELS - 1,
                CELL_PIXELS - 1,
                0xFF303030,
                fillColor
            )

        end

    end


    -- ========================================================
    -- DEBUG: LAST ROW
    -- ========================================================

    local debug = ""

    for column = 0, GRID_WIDTH - 1 do

        local tile, attribute, address =
            readCell(
                GRID_HEIGHT - 1,
                column
            )


        debug =
            debug
            .. string.format(
                "%02X ",
                tile
            )

    end


    gui.pixelText(
        panelX + 1,
        gridY
            + GRID_HEIGHT * CELL_PIXELS
            + 3,
        debug,
        0xFFFFFFFF,
        0xFF000000
    )


    -- ========================================================
    -- DEBUG: BASE ADDRESSES
    -- ========================================================

    gui.pixelText(
        panelX + 1,
        gridY
            + GRID_HEIGHT * CELL_PIXELS
            + 12,
        string.format(
            "BASE:%04X LAST:%04X",
            GRID_BASE,
            LAST_ROW_BASE
        ),
        0xFFAAAAAA,
        0xFF000000
    )


    emu.frameadvance()

end
