-- BizHawk Lua
-- 12x26 Snake Grid Visualizer
--
-- DISPLAY:
--   Black = empty
--   Green = detected horizontal snake
--
-- CONSOLE:
--   Head address
--   Address delta
--   Calculated row/column
--
-- CURRENT OBSERVATIONS:
--
-- Normal downward movement:
--   +0x80
--
-- Example:
--   0x0CA8 -> 0x0D28 = +0x80
--   0x0D28 -> 0x0DA8 = +0x80
--
-- Observed combined movement:
--   0x0C24 -> 0x0CA8 = +0x84
--
-- Working hypothesis:
--   Y step = 0x80
--   X step = 0x04

local DOMAIN = "WRAM"


-- ============================================================
-- GRID SETTINGS
-- ============================================================

local GRID_WIDTH = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- MEMORY MAPPING
-- ============================================================

local ROW_STRIDE = 0x80
local COLUMN_STRIDE = 0x04

local START_ADDR = 0x0A00
local END_ADDR = 0x1150


-- ============================================================
-- REFERENCE POSITION
--
-- 0x0C24 was observed during the falling sequence.
--
-- Current provisional mapping:
--   0x0C24 = row 15, column 3
--
-- We can adjust REFERENCE_COLUMN later without changing
-- the underlying X/Y stride logic.
-- ============================================================

local REFERENCE_ADDRESS = 0x0C24
local REFERENCE_ROW = 15
local REFERENCE_COLUMN = 3


-- ============================================================
-- SNAKE
-- ============================================================

local SNAKE_LENGTH = 6


-- ============================================================
-- PANEL
-- ============================================================

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
-- STATE
-- ============================================================

local lastHead = nil


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
-- FIND HORIZONTAL SNAKE
--
-- Searches for:
--
--   2D ?? 25 ?? 25 ?? 25 ?? 25 ?? 23
--
-- ============================================================

local function findHorizontalSnake()

    for address = START_ADDR, END_ADDR - 10, 2 do

        if
            readByte(address) == 0x2D and
            readByte(address + 2) == 0x25 and
            readByte(address + 4) == 0x25 and
            readByte(address + 6) == 0x25 and
            readByte(address + 8) == 0x25 and
            readByte(address + 10) == 0x23
        then

            return address

        end

    end

    return nil

end


-- ============================================================
-- ADDRESS -> GRID
-- ============================================================

local function addressToGrid(address)

    local delta =
        address - REFERENCE_ADDRESS


    -- --------------------------------------------------------
    -- Estimate vertical movement.
    --
    -- Using floor here handles positive falling addresses.
    -- --------------------------------------------------------

    local rowDelta

    if delta >= 0 then

        rowDelta =
            math.floor(delta / ROW_STRIDE)

    else

        rowDelta =
            math.ceil(delta / ROW_STRIDE)

    end


    -- --------------------------------------------------------
    -- Remove vertical portion.
    -- --------------------------------------------------------

    local horizontalBytes =
        delta -
        rowDelta * ROW_STRIDE


    -- --------------------------------------------------------
    -- Remaining bytes represent horizontal movement.
    -- --------------------------------------------------------

    local columnDelta =
        horizontalBytes / COLUMN_STRIDE


    local row =
        REFERENCE_ROW +
        rowDelta


    local column =
        REFERENCE_COLUMN +
        columnDelta


    return row, column

end


-- ============================================================
-- CONSOLE LOGGING
--
-- Only logs when address changes.
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
                "HEAD 0x%04X -> row=%d col=%d",
                address,
                row,
                column
            )
        )

    else

        local delta =
            address - lastHead


        console.log(
            string.format(
                "HEAD 0x%04X -> 0x%04X | delta %+d / 0x%X | row=%d col=%d",
                lastHead,
                address,
                delta,
                math.abs(delta),
                row,
                column
            )
        )

    end


    lastHead = address

end


-- ============================================================
-- INITIAL CONSOLE
-- ============================================================

console.clear()

console.log("Snake grid visualizer")
console.log("--------------------------------")

console.log(
    string.format(
        "Y stride: 0x%X",
        ROW_STRIDE
    )
)

console.log(
    string.format(
        "X stride: 0x%X",
        COLUMN_STRIDE
    )
)

console.log(
    string.format(
        "Reference: 0x%04X = row %d col %d",
        REFERENCE_ADDRESS,
        REFERENCE_ROW,
        REFERENCE_COLUMN
    )
)

console.log("--------------------------------")


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- FIND SNAKE
    -- ========================================================

    local headAddress =
        findHorizontalSnake()


    -- ========================================================
    -- LOG ONLY WHEN SOMETHING CHANGES
    -- ========================================================

    if headAddress ~= nil then

        logHead(
            headAddress
        )

    end


    -- ========================================================
    -- PANEL COORDINATES
    -- ========================================================

    local panelX =
        client.bufferwidth()

    local gridX =
        panelX +
        PANEL_MARGIN

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
    -- DRAW EMPTY GRID
    -- ========================================================

    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

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
                0xFF000000
            )

        end

    end


    -- ========================================================
    -- DRAW DETECTED SNAKE
    -- ========================================================

    if headAddress ~= nil then

        local snakeRow, snakeColumn =
            addressToGrid(
                headAddress
            )


        -- Only draw if our calculated coordinates are sensible.
        if
            snakeRow >= 0 and
            snakeRow < GRID_HEIGHT and
            snakeColumn >= 0 and
            snakeColumn < GRID_WIDTH
        then

            for segment = 0, SNAKE_LENGTH - 1 do

                local column =
                    snakeColumn +
                    segment


                if
                    column >= 0 and
                    column < GRID_WIDTH
                then

                    local x =
                        gridX +
                        column * CELL_PIXELS

                    local y =
                        gridY +
                        snakeRow * CELL_PIXELS


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

        end

    end


    -- ========================================================
    -- NEXT FRAME
    -- ========================================================

    emu.frameadvance()

end
