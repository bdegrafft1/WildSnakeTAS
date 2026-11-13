-- BizHawk Lua
-- Snake object / sprite memory diagnostic
--
-- DISPLAY:
--   12x26 grid only
--
-- CONSOLE:
--   Logs detected snake state whenever the detected head
--   address changes.
--
-- OBSERVED:
--
-- Falling one row changes the detected address by 0x04:
--
--   10E0
--   10E4
--   10E8
--
-- This strongly suggests we're looking at sprite/object data,
-- not a normal 12x26 tilemap.
--
-- This version dumps surrounding memory whenever the snake
-- position changes so we can identify the actual fields.

local DOMAIN = "WRAM"


-- ============================================================
-- SEARCH RANGE
-- ============================================================

local START_ADDR = 0x0A00
local END_ADDR   = 0x1150


-- ============================================================
-- GRID DISPLAY
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8

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
-- KNOWN VALUES
-- ============================================================

local SNAKE_TILES = {

    [0x2D] = true,
    [0x25] = true,
    [0x23] = true

}


-- ============================================================
-- STATE
-- ============================================================

local lastHead = nil

local observationNumber = 0


-- ============================================================
-- MEMORY
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
-- FIND HORIZONTAL SNAKE SIGNATURE
--
-- Existing signature:
--
-- 2D ?? 25 ?? 25 ?? 25 ?? 25 ?? 23
--
-- We're intentionally checking only every second byte.
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
-- FORMAT MEMORY BLOCK
-- ============================================================

local function memoryBlock(startAddress, count)

    local result = ""

    for i = 0, count - 1 do

        result =
            result ..
            string.format(
                "%02X ",
                readByte(startAddress + i)
            )

    end

    return result

end


-- ============================================================
-- LOG OBSERVATION
-- ============================================================

local function logObservation(address)

    if address == nil then
        return
    end


    if address == lastHead then
        return
    end


    observationNumber =
        observationNumber + 1


    console.log(
        string.format(
            "=== OBSERVATION %d ===",
            observationNumber
        )
    )


    console.log(
        string.format(
            "Detected address: 0x%04X",
            address
        )
    )


    if lastHead ~= nil then

        local delta =
            address - lastHead


        console.log(
            string.format(
                "Previous:         0x%04X",
                lastHead
            )
        )


        console.log(
            string.format(
                "Delta:            %+d / 0x%X",
                delta,
                math.abs(delta)
            )
        )

    end


    -- ========================================================
    -- Dump 16 bytes before and 32 bytes after.
    --
    -- This is more useful than just looking at the bytes
    -- matching 2D/25/23.
    -- ========================================================

    local dumpStart =
        address - 16


    console.log(
        string.format(
            "Memory 0x%04X-0x%04X:",
            dumpStart,
            dumpStart + 47
        )
    )


    -- Three lines of 16 bytes.
    for offset = 0, 32, 16 do

        local lineAddress =
            dumpStart + offset


        console.log(
            string.format(
                "%04X: %s",
                lineAddress,
                memoryBlock(
                    lineAddress,
                    16
                )
            )
        )

    end


    console.log("")


    -- ========================================================
    -- Also show the 16-bit words around the detection.
    -- ========================================================

    console.log("16-bit pairs:")


    local pairText = ""


    for offset = -8, 16, 2 do

        local pairAddress =
            address + offset

        local low =
            readByte(pairAddress)

        local high =
            readByte(pairAddress + 1)


        pairText =
            pairText ..
            string.format(
                "%04X=%02X%02X ",
                pairAddress,
                low,
                high
            )

    end


    console.log(pairText)

    console.log("--------------------------------")


    lastHead =
        address

end


-- ============================================================
-- INITIAL CONSOLE
-- ============================================================

console.clear()

console.log("Snake object mapping diagnostic")
console.log("")

console.log(
    "Observed vertical address movement: 0x10E0 -> 0x10E4 -> 0x10E8"
)

console.log(
    "Observed vertical delta: +0x04"
)

console.log("")

console.log(
    "Waiting for snake position changes..."
)

console.log("--------------------------------")


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- FIND / LOG
    -- ========================================================

    local currentHead =
        findHorizontalSnake()


    if currentHead ~= nil then

        logObservation(
            currentHead
        )

    end


    -- ========================================================
    -- VISUALIZATION
    --
    -- Grid only. Debugging remains in console.
    -- ========================================================

    local panelX =
        client.bufferwidth()

    local gridX =
        panelX + PANEL_MARGIN

    local gridY =
        PANEL_MARGIN


    -- Background
    gui.drawRectangle(
        panelX,
        0,
        PANEL_WIDTH - 1,
        PANEL_HEIGHT,
        0xFF404040,
        0xFF101010
    )


    -- Empty grid
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


    emu.frameadvance()

end
