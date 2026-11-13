-- BizHawk Lua
-- 12x26 tilemap visualizer
--
-- Phase 1:
--   Black = empty/unknown
--   Green = known snake tile
--
-- Tilemap format:
--   32 cells per underlying tilemap row
--   2 bytes per cell
--   therefore 0x40 bytes per row

local DOMAIN = "WRAM"

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local ROW_STRIDE = 0x40
local CELL_SIZE  = 2

-- 0xA80 appears to be the row immediately before the playable grid.
-- First playable row begins at 0xAC0.
-- The left border is at 0xAC0, so the first interior cell is 0xAC2.
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

-- Add drawing space to the right side of the emulator.
client.SetGameExtraPadding(0, 0, PANEL_WIDTH, 0)

local function getCellAddress(row, column)
    return GRID_BASE
        + row * ROW_STRIDE
        + column * CELL_SIZE
end

local function readCell(row, column)
    local address = getCellAddress(row, column)

    local tile = memory.read_u8(address, DOMAIN)
    local attribute = memory.read_u8(address + 1, DOMAIN)

    return tile, attribute, address
end

local function isSnakeTile(tile)
    return SNAKE_TILES[tile] == true
end

while true do
    -- Right-side padding begins PANEL_WIDTH pixels before the
    -- complete buffer's right edge.
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

    local gridX = panelX + PANEL_MARGIN
    local gridY = panelY + 14

    for row = 0, GRID_HEIGHT - 1 do
        for column = 0, GRID_WIDTH - 1 do
            local tile, attribute, address =
                readCell(row, column)

            local x = gridX + column * CELL_PIXELS
            local y = gridY + row * CELL_PIXELS

            local fillColor

            if isSnakeTile(tile) then
                fillColor = 0xFF00C840
            else
                -- Empty cells and currently unknown sprite IDs
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

    emu.frameadvance()
end
