-- BizHawk Lua
-- Snake memory diagnostic
--
-- Goal:
-- Find the actual memory locations being used for the snake.
--
-- Black = everything else
-- Green = known snake sprite values
--
-- Known snake values:
--   2D = head facing right
--   25 = horizontal body
--   23 = tail

local DOMAIN = "WRAM"

-- ============================================================
-- MEMORY RANGE
-- ============================================================

local START_ADDR = 0x000A80
local END_ADDR   = 0x00110E

local CELL_SIZE = 2


-- ============================================================
-- RAW MEMORY GRID
-- ============================================================

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
-- DISPLAY SETTINGS
-- ============================================================

local CELL_PIXELS = 7
local PANEL_MARGIN = 6

local PANEL_WIDTH =
    DISPLAY_WIDTH * CELL_PIXELS
    + PANEL_MARGIN * 2

local PANEL_HEIGHT =
    DISPLAY_HEIGHT * CELL_PIXELS
    + 80


-- ============================================================
-- KNOWN SNAKE TILES
-- ============================================================

local SNAKE_TILES = {
    [0x2D] = true,
    [0x25] = true,
    [0x23] = true
}


-- ============================================================
-- BORDER / EXTRA SPACE
-- ============================================================

client.SetGameExtraPadding(
    0,
    0,
    PANEL_WIDTH,
    0
)


-- ============================================================
-- FUNCTIONS
-- ============================================================

local function isSnakeTile(value)

    return SNAKE_TILES[value] == true
end


-- ============================================================
-- MAIN
-- ============================================================

while true do

    local panelX =
        client.bufferwidth()

    local panelY = 0


    -- ========================================================
    -- PANEL BACKGROUND
    -- ========================================================

    gui.drawRectangle(
        panelX,
        panelY,
        PANEL_WIDTH - 1,
        client.bufferheight(),
        0xFF404040,
        0xFF101010
    )


    -- ========================================================
    -- SCAN FOR MATCHES FIRST
    -- ========================================================

    local matches = {}

    for index = 0, ENTRY_COUNT - 1 do

        local address =
            START_ADDR
            + index * CELL_SIZE

        local value =
            memory.read_u8(
                address,
                DOMAIN
            )

        if isSnakeTile(value) then

            matches[#matches + 1] = {
                address = address,
                value = value,
                index = index
            }

        end

    end


    -- ========================================================
    -- HEADER
    -- ========================================================

    gui.pixelText(
        panelX + PANEL_MARGIN,
        2,
        string.format(
            "Snake matches: %d",
            #matches
        ),
        0xFFFFFFFF,
        0xFF101010
    )


    -- ========================================================
    -- PRINT MATCHED ADDRESSES
    --
    -- This is intentionally at the TOP now.
    -- ========================================================

    local textX =
        panelX + PANEL_MARGIN

    local textY = 12

    local line = ""

    for i = 1, #matches do

        local match =
            matches[i]

        line =
            line ..
            string.format(
                "%04X=%02X ",
                match.address,
                match.value
            )

        -- Four entries per line
        if i % 4 == 0 then

            gui.pixelText(
                textX,
                textY,
                line,
                0xFFFFFFFF,
                0xFF101010
            )

            textY =
                textY + 9

            line = ""

        end

    end


    -- Output remaining entries
    if line ~= "" then

        gui.pixelText(
            textX,
            textY,
            line,
            0xFFFFFFFF,
            0xFF101010
        )

        textY =
            textY + 9
    end


    -- ========================================================
    -- RAW MEMORY GRID
    -- ========================================================

    local gridX =
        panelX + PANEL_MARGIN

    local gridY =
        textY + 5


    for index = 0, ENTRY_COUNT - 1 do

        local address =
            START_ADDR
            + index * CELL_SIZE


        local value =
            memory.read_u8(
                address,
                DOMAIN
            )


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


        if isSnakeTile(value) then

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
    -- FIND CONSECUTIVE SNAKE SEQUENCES
    --
    -- We're specifically interested in:
    --
    -- 2D 25 25 25 25 23
    --
    -- with each tile 2 bytes apart.
    -- ========================================================

    local sequenceAddress = nil

    for address = START_ADDR, END_ADDR - 10, 2 do

        local v1 = memory.read_u8(address, DOMAIN)
        local v2 = memory.read_u8(address + 2, DOMAIN)
        local v3 = memory.read_u8(address + 4, DOMAIN)
        local v4 = memory.read_u8(address + 6, DOMAIN)
        local v5 = memory.read_u8(address + 8, DOMAIN)
        local v6 = memory.read_u8(address + 10, DOMAIN)


        if
            v1 == 0x2D and
            v2 == 0x25 and
            v3 == 0x25 and
            v4 == 0x25 and
            v5 == 0x25 and
            v6 == 0x23
        then

            sequenceAddress = address
            break

        end

    end


    -- ========================================================
    -- DISPLAY EXACT SEQUENCE RESULT
    -- ========================================================

    if sequenceAddress ~= nil then

        gui.pixelText(
            panelX + PANEL_MARGIN,
            client.bufferheight() - 20,
            string.format(
                "SNAKE FOUND @ %04X",
                sequenceAddress
            ),
            0xFF00FF40,
            0xFF000000
        )

    else

        gui.pixelText(
            panelX + PANEL_MARGIN,
            client.bufferheight() - 20,
            "Snake sequence not found",
            0xFFFF4040,
            0xFF000000
        )

    end


    emu.frameadvance()

end
