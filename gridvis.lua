-- BizHawk Lua
-- 12x26 Snake Grid Visualizer
--
-- CURRENT GOAL:
-- Prove the bottom-row alignment using the snake sequence
-- that we have actually found in live WRAM.
--
-- Confirmed live WRAM:
--
--   0x10E8 = 2D  head
--   0x10EA = 25  body
--   0x10EC = 25  body
--   0x10EE = 25  body
--   0x10F0 = 25  body
--   0x10F2 = 23  tail
--
-- The snake visually occupies:
--
--   row 25
--   columns 6,7,8,9,10,11
--
-- Therefore the bottom row begins:
--
--   0x10E8 - (6 * 2)
--   = 0x10DC
--
-- IMPORTANT:
-- We are NOT assuming a row stride yet.
-- Only the confirmed bottom row is reading actual WRAM.

local DOMAIN = "WRAM"


-- ============================================================
-- GRID SIZE
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_SIZE = 2


-- ============================================================
-- CONFIRMED MEMORY
-- ============================================================

local BOTTOM_ROW_BASE = 0x10DC

local SNAKE_TILES = {

    [0x2D] = true, -- head

    [0x25] = true, -- body

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
    + 30


-- ============================================================
-- ADD SPACE TO RIGHT SIDE
-- ============================================================

client.SetGameExtraPadding(
    0,
    0,
    PANEL_WIDTH,
    0
)


-- ============================================================
-- HELPERS
-- ============================================================

local function isSnakeTile(tile)

    return SNAKE_TILES[tile] == true

end


local function readBottomCell(column)

    local address =
        BOTTOM_ROW_BASE
        + column * CELL_SIZE

    local tile =
        memory.read_u8(
            address,
            DOMAIN
        )

    return tile, address

end


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    local panelX =
        client.bufferwidth()

    local panelY = 0

    local gridX =
        panelX + PANEL_MARGIN

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
    -- DRAW EMPTY 12x26 GRID
    -- ========================================================

    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local x =
                gridX
                + column * CELL_PIXELS

            local y =
                gridY
                + row * CELL_PIXELS

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
    -- DRAW CONFIRMED BOTTOM ROW
    --
    -- This explicitly reads:
    --
    -- column 0  = 10DC
    -- column 1  = 10DE
    -- column 2  = 10E0
    -- column 3  = 10E2
    -- column 4  = 10E4
    -- column 5  = 10E6
    -- column 6  = 10E8
    -- column 7  = 10EA
    -- column 8  = 10EC
    -- column 9  = 10EE
    -- column 10 = 10F0
    -- column 11 = 10F2
    -- ========================================================

    local bottomRow =
        GRID_HEIGHT - 1

    local debugValues = ""


    for column = 0, GRID_WIDTH - 1 do

        local tile, address =
            readBottomCell(column)


        local x =
            gridX
            + column * CELL_PIXELS


        local y =
            gridY
            + bottomRow * CELL_PIXELS


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
            0xFFFFFFFF,
            fillColor
        )


        debugValues =
            debugValues
            .. string.format(
                "%02X ",
                tile
            )

    end


    -- ========================================================
    -- EXPECTED:
    --
    -- ?? ?? ?? ?? ?? ?? 2D 25 25 25 25 23
    --
    -- ========================================================

    local debugY =
        gridY
        + GRID_HEIGHT * CELL_PIXELS
        + 4


    gui.pixelText(
        panelX + 1,
        debugY,
        debugValues,
        0xFFFFFFFF,
        0xFF000000
    )


    -- ========================================================
    -- DIRECTLY READ CONFIRMED SEQUENCE
    --
    -- This gives us a second independent check.
    -- ========================================================

    local verify = ""

    for address = 0x10E8, 0x10F2, 2 do

        local value =
            memory.read_u8(
                address,
                DOMAIN
            )

        verify =
            verify
            .. string.format(
                "%02X ",
                value
            )

    end


    gui.pixelText(
        panelX + 1,
        debugY + 9,
        "SEQ: " .. verify,
        0xFF00FF40,
        0xFF000000
    )


    -- ========================================================
    -- ADDRESS INFO
    -- ========================================================

    gui.pixelText(
        panelX + 1,
        debugY + 18,
        "ROW: 10DC-10F2",
        0xFFAAAAAA,
        0xFF000000
    )


    emu.frameadvance()

end
