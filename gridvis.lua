-- BizHawk Lua
-- 12x26 tilemap visualizer
--
-- Phase 1:
--   Black = empty / unknown
--   Green = known snake tile
--
-- Tilemap format currently being tested:
--   32 cells per underlying tilemap row
--   2 bytes per cell
--   0x40 bytes per row

local DOMAIN = "WRAM"

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local ROW_STRIDE = 0x40
local CELL_SIZE  = 2

-- Current candidate for top-left playable cell.
local GRID_BASE = 0x000AC2

-- Visualization settings
local CELL_PIXELS = 8
local PANEL_MARGIN = 8

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS +
    PANEL_MARGIN * 2

local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS +
    PANEL_MARGIN * 2 +
    18

-- Known snake tile IDs from the final row:
-- 2D = right-facing head
-- 25 = horizontal body
-- 23 = tail
local SNAKE_TILES = {
    [0x2D] = true,
    [0x25] = true,
    [0x23] = true
}

-- Add drawing space to the right side.
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

    local address = getCellAddress(row, column)

    local tile =
        memory.read_u8(address, DOMAIN)

    local attribute =
        memory.read_u8(address + 1, DOMAIN)

    return tile, attribute, address
end


local function isSnakeTile(tile)

    return SNAKE_TILES[tile] == true
end


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- Based on your current working panel position.
    local panelX = client.bufferwidth()
    local panelY = PANEL_MARGIN - 16

    -- Panel background
    gui.drawRectangle(
        panelX,
        0,
        PANEL_WIDTH - 1,
        PANEL_HEIGHT,
        0xFF404040,
        0xFF101010
    )

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
                readCell(row, column)

            local x =
                gridX + column * CELL_PIXELS

            local y =
                gridY + row * CELL_PIXELS

            local fillColor

            if isSnakeTile(tile) then

                -- Known snake sprite
                fillColor = 0xFF00C840

            else

                -- Empty or currently unknown tile
                fillColor = 0xFF000000

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
    -- DEBUG: FINAL ROW
    --
    -- We want to see whether our address mapping produces:
    --
    -- 01 01 01 01 01 01 2D 25 25 25 25 23
    --
    -- for the snake position shown in your screenshot.
    -- ========================================================

    local debug = ""

    for column = 0, GRID_WIDTH - 1 do

        local tile, attribute, address =
            readCell(GRID_HEIGHT - 1, column)

        debug =
            debug ..
            string.format("%02X ", tile)
    end

    gui.pixelText(
        panelX + 1,
        gridY + GRID_HEIGHT * CELL_PIXELS + 3,
        debug,
        0xFFFFFFFF,
        0xFF000000
    )


    -- ========================================================
    -- DEBUG: ADDRESSES
    -- ========================================================

    local firstAddress =
        getCellAddress(
            GRID_HEIGHT - 1,
            0
        )

    local lastAddress =
        getCellAddress(
            GRID_HEIGHT - 1,
            GRID_WIDTH - 1
        )

    gui.pixelText(
        panelX + 1,
        gridY + GRID_HEIGHT * CELL_PIXELS + 12,
        string.format(
            "%06X-%06X",
            firstAddress,
            lastAddress
        ),
        0xFFAAAAAA,
        0xFF000000
    )


    emu.frameadvance()
end
