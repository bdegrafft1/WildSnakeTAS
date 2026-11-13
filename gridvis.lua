-- BizHawk Lua
-- Simple 12x26 Snake Tile Visualizer
--
-- No snake shape detection.
-- No head detection.
-- No relative address calculations.
--
-- Simply:
--
--   1. Read the tilemap
--   2. Look at each tile ID
--   3. Known snake ID = GREEN
--   4. Anything else = BLACK
--
-- Known snake IDs from observed WRAM:
--
--   23
--   24
--   25
--   27
--   28
--   2A
--   2D
--   2E

local DOMAIN = "WRAM"


-- ============================================================
-- GRID SIZE
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26


-- ============================================================
-- MEMORY LAYOUT
-- ============================================================

-- Tilemap rows are 0x40 bytes apart.
local ROW_STRIDE = 0x40

-- Each tile is:
--
--   byte 0 = tile ID
--   byte 1 = attribute
--
local TILE_SIZE = 2


-- ============================================================
-- TILEMAP START
--
-- Start of the first underlying tilemap row.
-- ============================================================

local TILEMAP_BASE = 0x0A80


-- ============================================================
-- PLAYFIELD OFFSET
--
-- Number of 2-byte tiles to skip at the beginning of each
-- underlying tilemap row.
--
-- This is intentionally isolated so we can adjust alignment
-- without changing anything else.
-- ============================================================

local PLAYFIELD_X_OFFSET = 1


-- ============================================================
-- KNOWN SNAKE TILE IDS
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

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


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
-- MEMORY HELPER
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


-- ============================================================
-- GET TILE ADDRESS
--
-- This is intentionally simple:
--
-- row base
-- +
-- horizontal playable-field offset
-- +
-- column
--
-- ============================================================

local function getTileAddress(row, column)

    local rowAddress =
        TILEMAP_BASE +
        row * ROW_STRIDE


    local tileIndex =
        PLAYFIELD_X_OFFSET +
        column


    return
        rowAddress +
        tileIndex * TILE_SIZE

end


-- ============================================================
-- READ TILE
-- ============================================================

local function readTile(row, column)

    local address =
        getTileAddress(
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
-- IS KNOWN SNAKE
-- ============================================================

local function isSnake(tile)

    return SNAKE_TILES[tile] == true

end


-- ============================================================
-- CONSOLE
-- ============================================================

console.clear()

console.log(
    "Simple snake tile visualizer"
)

console.log(
    string.format(
        "Tilemap base: 0x%04X",
        TILEMAP_BASE
    )
)

console.log(
    string.format(
        "Row stride: 0x%02X",
        ROW_STRIDE
    )
)

console.log(
    string.format(
        "Playfield X offset: %d tiles",
        PLAYFIELD_X_OFFSET
    )
)

console.log(
    "Known IDs: 23 24 25 27 28 2A 2D 2E"
)

console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- PANEL POSITION
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
                readTile(
                    row,
                    column
                )


            local color =
                0xFF000000


            -- ------------------------------------------------
            -- Don't care about shape.
            --
            -- If the tile ID is one we've seen in this snake,
            -- mark the cell green.
            -- ------------------------------------------------

            if isSnake(tile) then

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
