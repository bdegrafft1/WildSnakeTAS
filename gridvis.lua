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
    GRID_WIDTH
