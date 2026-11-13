-- BizHawk Lua
-- 12x26 First-Snake Visualizer
--
-- Confirmed memory geometry:
--
--   Horizontal grid step = 0x02
--   Vertical grid step   = 0x40
--
-- Tile format:
--
--   [tile ID] [attribute]
--
-- Empty:
--
--   01 08
--
-- First-snake IDs identified so far:
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
--   Black = empty / unknown
--   Green = known first-snake tile
--
-- DEBUG:
--
--   Console only.
--   Logs snake cells only when the detected layout changes.

local DOMAIN = "WRAM"


-- ============================================================
-- GRID SIZE
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
-- Current candidate based on the raw tilemap structure.
--
-- This represents:
--
--   row 0
--   column 0
--
-- of the 12x26 logical visualization.
--
-- Keep this isolated because if the entire snake is shifted
-- uniformly, this is the only value we should need to adjust.
-- ============================================================

local GRID_BASE = 0x0A82


-- ============================================================
-- TILE FORMAT
-- ============================================================

local TILE_ATTRIBUTE = 0x08
local EMPTY_TILE     = 0x01


-- ============================================================
-- FIRST-SNAKE TILE IDS
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
-- PANEL SIZE
-- ============================================================

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS +
    PANEL_MARGIN * 2


local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS +
    PANEL_MARGIN * 2


-- Add empty space to the right of the game.
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


-- ============================================================
-- ADDRESS FOR GRID CELL
--
-- address =
--
--   base
--   + row * 0x40
--   + column * 0x02
-- ============================================================

local function getCellAddress(row, column)

    return
        GRID_BASE +
        row * ROW_STRIDE +
        column * COLUMN_STRIDE

end


-- ============================================================
-- READ GRID CELL
-- ============================================================

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
-- SNAKE CLASSIFICATION
-- ============================================================

local function isSnakeTile(tile, attribute)

    if attribute ~= TILE_ATTRIBUTE then
        return false
    end


    if SNAKE_TILES[tile] ~= true then
        return false
    end


    return true

end


-- ============================================================
-- FIND ALL FIRST-SNAKE CELLS
-- ======================================================
