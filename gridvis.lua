-- BizHawk Lua
-- 12x26 Snake Grid Visualizer
--
-- Phase 1
--
-- DISPLAY ONLY:
--   Black = empty
--   Green = known snake
--
-- Debug information goes to the Lua console.
--
-- CONFIRMED FROM FALL TEST:
--
--   Vertical movement = +0x80 per grid row
--
-- Example:
--
--   0D24
--   0DA4
--   0E24
--   0EA4
--   0F24
--   0FA4
--   1024
--   10A4
--
-- The landed state appears to use a different representation,
-- so we map the falling playfield independently.

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- MEMORY STRUCTURE
-- ============================================================

-- Confirmed from the falling test.
local ROW_STRIDE = 0x80

-- Tile/sprite values are separated by 2 bytes horizontally
-- within the observed horizontal snake.
local COLUMN_STRIDE = 2


-- ============================================================
-- SEARCH RANGE
-- ============================================================

local START_ADDR = 0x0A00
local END_ADDR   = 0x1150


-- ============================================================
-- KNOWN SNAKE VALUES
-- ============================================================

local SNAKE_TILES = {

    [0x2D] = true, -- horizontal head

    [0x25] = true, -- horizontal body

    [0x23] = true  -- tail

}


-- ============================================================
-- PANEL
-- ============================================================

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS
    + PANEL_MARGIN * 2

local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS
    + PANEL_MARGIN * 2


client.SetGameExtraPadding(
    0,
    0,
    PANEL_WIDTH,
    0
)


-- ============================================================
-- STATE
-- ============================================================

local lastHead = nil


-- ============================================================
-- MEMORY HELPERS
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function isSnake(value)

    return SNAKE_TILES[value] == true

end


-- ============================================================
-- FIND HORIZONTAL SNAKE
--
-- Detect:
--
--   2D 25 25 25 25 23
--
-- at two-byte intervals.
-- ============================================================

local function findHorizontalSnake()

    for address = START_ADDR, END_ADDR - 10, 2 do

        if
            readByte(address)      == 0x2D and
            readByte(address + 2)  == 0x25 and
            readByte(address + 4)  == 0x25 and
            readByte(address + 6)  == 0x25 and
            readByte(address + 8)  == 0x25 and
            readByte(address + 10) == 0x23
        then

            return address

        end

    end

    return nil

end


-- ============================================================
-- LOG MOVEMENT
-- ============================================================

local function logHead(address)

    if address == nil then
        return
    end


    if address == lastHead then
        return
    end


    if lastHead == nil then

        console.log(
            string.format(
                "Head detected: 0x%04X",
                address
            )
        )

    else

        local delta =
            address - lastHead


        console.log(
            string.format(
                "Head: 0x%04X -> 0x%04X | delta %+d / 0x%X",
                lastHead,
                address,
                delta,
                math.abs(delta)
            )
        )

    end


    lastHead =
        address

end


-- ============================================================
-- INITIAL CONSOLE OUTPUT
-- ============================================================

console.clear()

console.log("Snake grid visualizer")
console.log("--------------------------------")
console.log("Confirmed vertical stride: 0x80")
console.log("Observed horizontal spacing: 0x02")
console.log("--------------------------------")


-- ============================================================
-- MAIN
-- ============================================================

while true do

    -- ========================================================
    -- DETECT CURRENT HORIZONTAL SNAKE
    -- ========================================================

    local headAddress =
        findHorizontalSnake()


    if headAddress ~= nil then

        logHead(
            headAddress
        )

    end


    -- ========================================================
    -- SCREEN POSITION
    -- ========================================================

    local panelX =
        client.bufferwidth()

    local gridX =
        panelX + PANEL_MARGIN

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
    -- DRAW EMPTY GRID
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
    -- DRAW CURRENT SNAKE
    --
    -- For this phase we KNOW:
    --
    --   * shape is six cells wide
    --   * memory advances 2 bytes per snake segment
    --   * vertical falling movement advances 0x80
    --
    -- We do NOT yet know the absolute horizontal origin.
    --
    -- So derive the row from the observed address progression
    -- and temporarily draw the six-cell snake centered.
    -- ========================================================

    if headAddress ~= nil then

        -- 0x10A4 is the latest confirmed normal falling row
        -- before the landing representation changes.
        --
        -- Treat that as row 24 temporarily.
        local REFERENCE_ADDRESS =
            0x10A4

        local REFERENCE_ROW =
            24


        local addressDifference =
            headAddress
            - REFERENCE_ADDRESS


        local rowOffset =
            math.floor(
                addressDifference
                / ROW_STRIDE
            )


        local snakeRow =
            REFERENCE_ROW
            + rowOffset


        -- Clamp so malformed/landing states do not draw
        -- outside the visualization.
        if snakeRow < 0 then
            snakeRow = 0
        end

        if snakeRow >= GRID_HEIGHT then
            snakeRow =
                GRID_HEIGHT - 1
        end


        -- We still need to determine the absolute X origin.
        --
        -- For now use column 3, roughly matching the
        -- horizontal position shown in your falling screenshot.
        local snakeColumn = 3


        -- ====================================================
        -- DRAW SIX SEGMENTS
        -- ====================================================

        for segment = 0, 5 do

            local column =
                snakeColumn
                + segment


            if
                column >= 0 and
                column < GRID_WIDTH
            then

                local x =
                    gridX
                    + column * CELL_PIXELS


                local y =
                    gridY
                    + snakeRow * CELL_PIXELS


                gui.drawRectangle(
                    x,
                    y,
                    CELL_PIXELS - 1,
                    CELL_PIXELS - 1,
                    0xFFFFFFFF,
                    0xFF00FF40
                )

            end

        end


        -- Console only.
        console.log(
            string.format(
                "Mapped head 0x%04X -> row %d",
                headAddress,
                snakeRow
            )
        )

    end


    emu.frameadvance()

end
