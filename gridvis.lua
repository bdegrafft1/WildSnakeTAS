-- BizHawk Lua
-- 12x26 Snake Grid Visualizer
--
-- CURRENT MAPPING FROM OBSERVATIONS:
--
--   Y + 1 grid cell = +0x80
--   X + 1 grid cell = +0x04
--
-- Examples:
--
--   0x0CA8 -> 0x0D28 = +0x80
--       down 1
--
--   0x0C24 -> 0x0CA8 = +0x84
--       down 1 + right 1
--
-- CONFIRMED HORIZONTAL SNAKE SIGNATURE:
--
--   2D ?? 25 ?? 25 ?? 25 ?? 25 ?? 23
--
-- DISPLAY:
--   Black = empty
--   Green = detected snake
--
-- DEBUG:
--   Console only

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- MEMORY MAPPING
-- ============================================================

local ROW_STRIDE = 0x80

local COLUMN_STRIDE = 0x04


-- ============================================================
-- SEARCH RANGE
-- ============================================================

local START_ADDR = 0x0A00
local END_ADDR   = 0x1150


-- ============================================================
-- REFERENCE POSITION
--
-- We observed:
--
--   0x0C24
--
-- at the position shown in the first screenshot.
--
-- From the rendered grid / game image, use this as our
-- temporary coordinate anchor.
--
-- The vertical position was already calculated as row 15.
--
-- Visually, the snake head is approximately column 3.
--
-- If X is off by exactly one square, only REFERENCE_COLUMN
-- needs changing.
-- ============================================================

local REFERENCE_ADDRESS = 0x0C24

local REFERENCE_ROW = 15

local REFERENCE_COLUMN = 3


-- ============================================================
-- SNAKE SHAPE
-- ============================================================

local SNAKE_LENGTH = 6


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


-- ============================================================
-- FIND HORIZONTAL SNAKE
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
-- CONVERT ADDRESS DELTA -> GRID MOVEMENT
--
-- delta = rows * 0x80 + columns * 0x04
--
-- We use the closest row component, then whatever remains
-- becomes horizontal movement.
-- ============================================================

local function addressToGrid(address)

    local delta =
        address - REFERENCE_ADDRESS


    -- Determine vertical movement.
    local rowDelta

    if delta >= 0 then

        rowDelta =
            math.floor(
                delta / ROW_STRIDE
            )

    else

        rowDelta =
            math.ceil(
                delta / ROW_STRIDE
            )

    end


    -- Remove vertical portion.
    local remainder =
        delta
        - rowDelta * ROW_STRIDE


    -- Remaining bytes represent horizontal movement.
    local columnDelta =
        remainder / COLUMN_STRIDE


    local row =
        REFERENCE_ROW
        + rowDelta


    local column =
        REFERENCE_COLUMN
        + columnDelta


    return row, column

end


-- ============================================================
-- CONSOLE LOGGING
-- ============================================================

local function logHead(address)

    if address == nil then
        return
    end


    if address == lastHead then
        return
    end


    local row, column =
        addressToGrid(address)


    if lastHead == nil then

        console.log(
            string.format(
                "HEAD 0x%04X -> grid (%d,%d)",
                address,
                column,
                row
            )
        )

    else

        local delta =
            address - lastHead


        console.log(
            string.format(
                "HEAD 0x%04X -> 0x%04X | delta %+d / 0x%X -> grid (%d,%d)",
                lastHead,
                address,
                delta,
                math.abs(delta),
                column,
                row
            )
        )

    end


    lastHead =
        address

end


-- ============================================================
-- INITIAL CONSOLE
-- ============================================================

console.clear()

console.log("Snake grid visualizer")
console.log("--------------------------------")

console.log(
    "Y stride: 0x80"
)

console.log(
    "X stride: 0x04"
)

console.log(
    string.format(
        "Reference: 0x%04X -> (%d,%d)",
        REFERENCE_ADDRESS,
        REFERENCE_COLUMN,
        REFERENCE_ROW
    )
)

console.log("--------------------------------")


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- DETECT
    -- ========================================================

    local headAddress =
        findHorizontalSnake()


    if headAddress ~= nil then

        logHead(
            headAddress
        )

    end


    -- ========================================================
    -- PANEL
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
    -- EMPTY GRID
    -- ========================================================

    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

           
