-- BizHawk Lua
-- 12x26 Snake Grid Visualizer
--
-- Phase 1:
--   Detect individual known snake sprite values
--   instead of requiring one exact horizontal snake.
--
-- DISPLAY:
--   Black = empty / unknown
--   Green = known snake tile
--
-- CONSOLE:
--   Debug information only
--
-- Observed memory geometry:
--
--   Down 1 row  = +0x80
--   Right 1 col = +0x04   (current hypothesis)
--
-- Known sprite values:
--
--   2D = known head/orientation sprite
--   25 = known body sprite
--   23 = known tail sprite

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- MEMORY
-- ============================================================

local START_ADDR = 0x0A00
local END_ADDR   = 0x1150

local ROW_STRIDE    = 0x80
local COLUMN_STRIDE = 0x04


-- ============================================================
-- REFERENCE
--
-- Current provisional anchor:
--
--   address 0x0C24
--   row 15
--   column 3
--
-- ============================================================

local REFERENCE_ADDRESS = 0x0C24
local REFERENCE_ROW = 15
local REFERENCE_COLUMN = 3


-- ============================================================
-- KNOWN SNAKE SPRITES
-- ============================================================

local SNAKE_TILES = {

    [0x2D] = true,

    [0x25] = true,

    [0x23] = true

}


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

local previousMatches = ""


-- ============================================================
-- MEMORY
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function isSnakeTile(value)

    return SNAKE_TILES[value] == true

end


-- ============================================================
-- ADDRESS -> GRID
-- ============================================================

local function addressToGrid(address)

    local delta =
        address - REFERENCE_ADDRESS


    -- Find nearest logical row.
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


    local remainder =
        delta -
        rowDelta * ROW_STRIDE


    -- Must fall exactly on our hypothesised
    -- 4-byte column boundaries.
    if remainder % COLUMN_STRIDE ~= 0 then

        return nil, nil

    end


    local columnDelta =
        remainder / COLUMN_STRIDE


    local row =
        REFERENCE_ROW +
        rowDelta


    local column =
        REFERENCE_COLUMN +
        columnDelta


    -- Reject anything outside our 12x26 board.
    if
        row < 0 or
        row >= GRID_HEIGHT or
        column < 0 or
        column >= GRID_WIDTH
    then

        return nil, nil

    end


    return row, column

end


-- ============================================================
-- SCAN KNOWN SPRITE VALUES
-- ============================================================

local function findSnakeTiles()

    local matches = {}


    -- Scan every byte for now.
    --
    -- This is intentional. We don't yet know whether all
    -- orientation sprites always occupy even addresses.
    for address = START_ADDR, END_ADDR do

        local value =
            readByte(address)


        if isSnakeTile(value) then

            local row, column =
                addressToGrid(address)


            if row ~= nil and column ~= nil then

                matches[#matches + 1] = {

                    address = address,

                    value = value,

                    row = row,

                    column = column

                }

            end

        end

    end


    return matches

end


-- ============================================================
-- LOG ONLY WHEN MATCH SET CHANGES
-- ============================================================

local function logMatches(matches)

    local signature = ""


    for i = 1, #matches do

        local match =
            matches[i]


        signature =
            signature ..
            string.format(
                "%04X:%02X:%d:%d|",
                match.address,
                match.value,
                match.column,
                match.row
            )

    end


    if signature == previousMatches then

        return

    end


    previousMatches =
        signature


    console.log(
        string.format(
            "Known snake tiles: %d",
            #matches
        )
    )


    for i = 1, #matches do

        local match =
            matches[i]


        console.log(
            string.format(
                "  0x%04X = %02X -> col=%d row=%d",
                match.address,
                match.value,
                match.column,
                match.row
            )
        )

    end


    console.log("--------------------------------")

end


-- ============================================================
-- INITIAL CONSOLE
-- ============================================================

console.clear()

console.log("Snake tile visualizer")
console.log("--------------------------------")
console.log("Y stride hypothesis: 0x80")
console.log("X stride hypothesis: 0x04")
console.log("Scanning individual known sprite values")
console.log("--------------------------------")


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- SCAN MEMORY
    -- ========================================================

    local matches =
        findSnakeTiles()


    logMatches(
        matches
    )


    -- ========================================================
    -- VISUALIZATION POSITION
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
    -- EMPTY GRID
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
    -- DRAW ALL KNOWN SNAKE TILES
    -- ========================================================

    for i = 1, #matches do

        local match =
            matches[i]


        local x =
            gridX +
            match.column * CELL_PIXELS


        local y =
            gridY +
            match.row * CELL_PIXELS


        gui.drawRectangle(
            x,
            y,
            CELL_PIXELS - 1,
            CELL_PIXELS - 1,
            0xFFFFFFFF,
            0xFF00FF40
        )

    end


    -- ========================================================
    -- NEXT FRAME
    -- ========================================================

    emu.frameadvance()

end
