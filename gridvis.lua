-- BizHawk Lua
-- Snake memory diagnostic
--
-- Phase 1:
--   Black = empty / unknown
--   Green = known snake sprite value
--
-- Known values:
--   2D = right-facing head
--   25 = horizontal body
--   23 = tail
--
-- This diagnostic intentionally does NOT assume
-- that the game board has a 0x40 row stride.
--
-- Instead, it displays the raw memory range as
-- consecutive 2-byte tile entries so we can determine
-- the actual relationship between memory and the board.

local DOMAIN = "WRAM"

-- ============================================================
-- MEMORY RANGE
-- ============================================================

local START_ADDR = 0x000A80
local END_ADDR   = 0x00110E

-- From the dump, entries appear to commonly be:
--
--   tile byte
--   attribute byte
--
-- Example:
--
--   2D 08
--   25 08
--   25 08
--   23 ...
--
local CELL_SIZE = 2


-- ============================================================
-- DIAGNOSTIC GRID
-- ============================================================

-- Display 32 memory entries per row.
--
-- NOTE:
-- This is NOT claiming that the game board is 32 wide.
-- This is only a raw visualization of memory.
local DISPLAY_WIDTH = 32

local ENTRY_COUNT =
    math.floor(
        (END_ADDR - START_ADDR) / CELL_SIZE
    ) + 1

local DISPLAY_HEIGHT =
    math.ceil(
        ENTRY_COUNT / DISPLAY_WIDTH
    )


-- ============================================================
-- VISUALIZATION
-- ============================================================

local CELL_PIXELS = 5
local PANEL_MARGIN = 4

local PANEL_WIDTH =
    DISPLAY_WIDTH * CELL_PIXELS
    + PANEL_MARGIN * 2

local PANEL_HEIGHT =
    DISPLAY_HEIGHT * CELL_PIXELS
    + PANEL_MARGIN * 2
    + 20


-- ============================================================
-- KNOWN SNAKE VALUES
-- ============================================================

local SNAKE_TILES = {

    -- Right-facing head
    [0x2D] = true,

    -- Horizontal body
    [0x25] = true,

    -- Tail
    [0x23] = true
}


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
-- HELPER FUNCTIONS
-- ============================================================

local function isSnakeTile(tile)

    return SNAKE_TILES[tile] == true
end


local function readTile(address)

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

    return tile, attribute
end


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- Keep the positioning method from your working script.
    local panelX = client.bufferwidth()

    local gridX =
        panelX + PANEL_MARGIN

    local gridY =
        PANEL_MARGIN + 10


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
    -- TITLE
    -- ========================================================

    gui.pixelText(
        panelX + PANEL_MARGIN,
        1,
        "Raw WRAM",
        0xFFFFFFFF,
        0xFF101010
    )


    -- ========================================================
    -- RAW MEMORY VISUALIZATION
    -- ========================================================

    for index = 0, ENTRY_COUNT - 1 do

        local address =
            START_ADDR
            + index * CELL_SIZE

        local tile, attribute =
            readTile(address)

        local column =
            index % DISPLAY_WIDTH

        local row =
            math.floor(
                index / DISPLAY_WIDTH
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
                0xFF00FF40

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


    -- ========================================================
    -- DEBUG 0x1100 REGION
    --
    -- Read addresses:
    --
    -- 1100
    -- 1102
    -- 1104
    -- 1106
    -- 1108
    -- 110A
    -- 110C
    -- 110E
    -- 1110
    -- 1112
    -- 1114
    -- 1116
    -- 1118
    --
    -- If the raw dump and Lua address space match, we expect
    -- something resembling:
    --
    -- F4 01 01 01 01 01 01 2D 25 25 25 25 23
    --
    -- ========================================================

    local debug = ""

    for address = 0x1100, 0x1118, 2 do

        local value =
            memory.read_u8(
                address,
                DOMAIN
            )

        debug =
            debug
            .. string.format(
                "%02X ",
                value
            )
    end


    -- Put debug values at bottom of the visible panel.
    gui.pixelText(
        panelX + 1,
        client.bufferheight() - 10,
        debug,
        0xFFFFFFFF,
        0xFF000000
    )


    emu.frameadvance()
end
