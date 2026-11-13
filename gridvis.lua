-- BizHawk Lua
-- 12x26 snake grid visualizer
--
-- Phase 1:
--   Black = empty / unknown
--   Green = known snake sprite tile
--
-- Grid is 12 wide x 26 high.

local DOMAIN = "WRAM"

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_SIZE = 2

-- ============================================================
-- MEMORY MAPPING
-- ============================================================

-- We know the snake head on the LAST ROW appears around 0x110E.
--
-- Start with 0x40. If diagnostic output doesn't line up,
-- ROW_STRIDE is the value we'll adjust.
local ROW_STRIDE = 0x40

-- Calculate backwards from the known last row rather than
-- guessing where the first row begins.
--
-- 0x110E appears to be column 6 of the final row.
local LAST_ROW_HEAD = 0x110E
local HEAD_COLUMN   = 6

local LAST_ROW_BASE =
    LAST_ROW_HEAD - (HEAD_COLUMN * CELL_SIZE)

local GRID_BASE =
    LAST_ROW_BASE - ((GRID_HEIGHT - 1) * ROW_STRIDE)

-- ============================================================
-- DISPLAY
-- ============================================================

local CELL_PIXELS = 8
local PANEL_MARGIN = 8

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS +
    PANEL_MARGIN * 2

local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS +
    PANEL_MARGIN * 2 +
    18

-- ============================================================
-- KNOWN SNAKE SPRITES
-- ============================================================

local SNAKE_TILES = {
    [0x2D] = true, -- head facing right
    [0x25] = true, -- horizontal body
    [0x23] = true  -- tail
}

client.SetGameExtraPadding(0, 0, PANEL_WIDTH, 0)

-- ============================================================
-- MEMORY
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

    local panelX = client.bufferwidth()
    local panelY = PANEL_MARGIN - 16

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
        string.format(
            "Grid %04X -> %04X",
            GRID_BASE,
            LAST_ROW_BASE
        ),
        0xFFFFFFFF,
        0xFF101010
    )

    local gridX = panelX + PANEL_MARGIN
    local gridY = panelY + 14

    for row = 0, GRID_HEIGHT - 1 do
        for column = 0, GRID_WIDTH - 1 do

            local tile, attribute, address =
                readCell(row, column)

            local x =
                gridX + column * CELL_PIXELS

            local y =
                gridY + row * CELL_PIXELS

            local fillColor = 0xFF000000

            if isSnakeTile(tile) then
                fillColor = 0xFF00C840
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
