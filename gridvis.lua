-- BizHawk Lua
-- Raw Snake Memory Visualizer
--
-- PURPOSE:
--
-- Stop guessing the game's logical grid mapping.
--
-- Scan the raw memory range directly.
-- Any byte matching a known snake sprite ID is GREEN.
-- Everything else is BLACK.
--
-- Raw memory is displayed as 32 two-byte entries per row,
-- matching the apparent 0x40-byte row structure.
--
-- DISPLAY:
--   Black = not a known snake value
--   Green = known/candidate snake value
--
-- DEBUG:
--   Console only, only when matches change.

local DOMAIN = "WRAM"


-- ============================================================
-- MEMORY RANGE
-- ============================================================

local START_ADDR = 0x0A80
local END_ADDR   = 0x110E


-- ============================================================
-- RAW TILEMAP GEOMETRY
--
-- 0x40 bytes per memory row
-- 2 bytes per tile
--
-- = 32 entries per raw memory row
-- ============================================================

local BYTES_PER_TILE = 2
local BYTES_PER_ROW  = 0x40
local RAW_WIDTH      = 32

local RAW_HEIGHT =
    math.ceil(
        (END_ADDR - START_ADDR + 1)
        / BYTES_PER_ROW
    )


-- ============================================================
-- KNOWN / CANDIDATE SNAKE IDS
--
-- Include the values we have observed so far.
-- ============================================================

local SNAKE_TILES = {

    [0x22] = true,

    [0x23] = true,

    [0x24] = true,

    [0x25] = true,

    [0x26] = true,

    [0x27] = true,

    [0x28] = true,

    [0x29] = true,

    [0x2A] = true,

    [0x2B] = true,

    [0x2C] = true,

    [0x2D] = true,

    [0x2E] = true

}


-- ============================================================
-- DISPLAY
-- ============================================================

local CELL_PIXELS = 5
local PANEL_MARGIN = 6

local PANEL_WIDTH =
    RAW_WIDTH * CELL_PIXELS +
    PANEL_MARGIN * 2

local PANEL_HEIGHT =
    RAW_HEIGHT * CELL_PIXELS +
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

local previousSignature = ""


-- ============================================================
-- MEMORY
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function isSnakeValue(value)

    return SNAKE_TILES[value] == true

end


-- ============================================================
-- SCAN RAW MEMORY
-- ============================================================

local function scanSnakeValues()

    local matches = {}


    -- Read the first byte of every two-byte entry.
    for address = START_ADDR, END_ADDR, BYTES_PER_TILE do

        local value =
            readByte(address)


        if isSnakeValue(value) then

            local offset =
                address - START_ADDR


            local rawRow =
                math.floor(
                    offset / BYTES_PER_ROW
                )


            local withinRow =
                offset % BYTES_PER_ROW


            local rawColumn =
                math.floor(
                    withinRow / BYTES_PER_TILE
                )


            matches[#matches + 1] = {

                address = address,

                value = value,

                row = rawRow,

                column = rawColumn

            }

        end

    end


    return matches

end


-- ============================================================
-- CONSOLE
-- ============================================================

local function logMatches(matches)

    local parts = {}


    for i = 1, #matches do

        local match =
            matches[i]


        parts[#parts + 1] =
            string.format(
                "%04X:%02X",
                match.address,
                match.value
            )

    end


    local signature =
        table.concat(
            parts,
            "|"
        )


    if signature == previousSignature then
        return
    end


    previousSignature =
        signature


    console.log(
        string.format(
            "Known values found: %d",
            #matches
        )
    )


    for i = 1, #matches do

        local match =
            matches[i]


        console.log(
            string.format(
                "  0x%04X = %02X -> raw row=%02d col=%02d",
                match.address,
                match.value,
                match.row,
                match.column
            )
        )

    end


    console.log(
        "--------------------------------"
    )

end


-- ============================================================
-- STARTUP
-- ============================================================

console.clear()


console.log(
    "Raw snake memory visualizer"
)


console.log(
    string.format(
        "Range: 0x%04X - 0x%04X",
        START_ADDR,
        END_ADDR
    )
)


console.log(
    "Raw geometry: 32 tiles x 0x40-byte rows"
)


console.log(
    "Candidate IDs: 22-2E"
)


console.log(
    "No attribute filtering"
)


console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- SCAN
    -- ========================================================

    local matches =
        scanSnakeValues()


    logMatches(
        matches
    )


    -- ========================================================
    -- PANEL
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
    -- EMPTY RAW GRID
    -- ========================================================

    for row = 0, RAW_HEIGHT - 1 do

        for column = 0, RAW_WIDTH - 1 do

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
    -- KNOWN VALUES
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


    emu.frameadvance()

end
