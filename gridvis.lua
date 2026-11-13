-- BizHawk Lua
-- 12x26 Snake Grid + Console Debugging
--
-- DISPLAY:
--   Black = empty / unknown
--   Green = known snake sprite
--
-- CONSOLE:
--   Current snake head address
--   Delta from previous position
--   Delta from confirmed bottom position
--
-- Confirmed horizontal snake at bottom:
--
--   10E8 = 2D   head
--   10EA = 25   body
--   10EC = 25   body
--   10EE = 25   body
--   10F0 = 25   body
--   10F2 = 23   tail

local DOMAIN = "WRAM"


-- ============================================================
-- MEMORY SEARCH RANGE
-- ============================================================

local START_ADDR = 0x0A00
local END_ADDR   = 0x1150

local CELL_SIZE = 2


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- CONFIRMED BOTTOM POSITION
-- ============================================================

local BOTTOM_ROW_BASE = 0x10DC
local CONFIRMED_BOTTOM_HEAD = 0x10E8


-- ============================================================
-- KNOWN SNAKE VALUES
-- ============================================================

local SNAKE_TILES = {

    [0x2D] = true, -- right-facing head

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

local observedAddresses = {}

local observedLookup = {}


-- ============================================================
-- HELPERS
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
-- Search for:
--
-- 2D 25 25 25 25 23
--
-- Each tile is two bytes apart.
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
-- LOG POSITION
-- ============================================================

local function logPosition(address)

    if address == nil then
        return
    end


    -- Only log when the head actually moves.
    if address == lastHead then
        return
    end


    local deltaPrevious = nil

    if lastHead ~= nil then

        deltaPrevious =
            address - lastHead

    end


    local deltaBottom =
        address - CONFIRMED_BOTTOM_HEAD


    -- ========================================================
    -- NEW UNIQUE POSITION
    -- ========================================================

    if not observedLookup[address] then

        observedLookup[address] = true

        observedAddresses[
            #observedAddresses + 1
        ] = address

    end


    -- ========================================================
    -- CONSOLE OUTPUT
    -- ========================================================

    console.log(
        string.format(
            "Snake head: 0x%04X",
            address
        )
    )


    if deltaPrevious ~= nil then

        console.log(
            string.format(
                "  previous: 0x%04X",
                lastHead
            )
        )

        console.log(
            string.format(
                "  delta previous: %+d / 0x%X",
                deltaPrevious,
                math.abs(deltaPrevious)
            )
        )

    end


    console.log(
        string.format(
            "  delta bottom: %+d",
            deltaBottom
        )
    )


    console.log(
        string.format(
            "  unique position #%d",
            #observedAddresses
        )
    )


    console.log("--------------------------------")


    lastHead =
        address

end


-- ============================================================
-- INITIAL CONSOLE INFO
-- ============================================================

console.clear()

console.log("Snake grid diagnostic started")
console.log("")

console.log(
    string.format(
        "Confirmed bottom head: 0x%04X",
        CONFIRMED_BOTTOM_HEAD
    )
)

console.log(
    string.format(
        "Confirmed bottom row: 0x%04X",
        BOTTOM_ROW_BASE
    )
)

console.log("Waiting for horizontal snake...")
console.log("--------------------------------")


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- FIND CURRENT SNAKE
    -- ========================================================

    local currentHead =
        findHorizontalSnake()


    if currentHead ~= nil then

        logPosition(
            currentHead
        )

    end


    -- ========================================================
    -- PANEL POSITION
    -- ========================================================

    local panelX =
        client.bufferwidth()

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
    -- DRAW BLANK 12x26 GRID
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
    -- For now this is the only row for which we have a
    -- confirmed memory mapping.
    -- ========================================================

    local bottomRow =
        GRID_HEIGHT - 1


    for column = 0, GRID_WIDTH - 1 do

        local address =
            BOTTOM_ROW_BASE
            + column * CELL_SIZE


        local value =
            readByte(address)


        local color =
            0xFF000000


        if isSnake(value) then

            color =
                0xFF00FF40

        end


        local x =
            gridX
            + column * CELL_PIXELS


        local y =
            gridY
            + bottomRow * CELL_PIXELS


        gui.drawRectangle(
            x,
            y,
            CELL_PIXELS - 1,
            CELL_PIXELS - 1,
            0xFF303030,
            color
        )

    end


    emu.frameadvance()

end
