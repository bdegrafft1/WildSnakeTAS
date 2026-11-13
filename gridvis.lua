-- BizHawk Lua
-- Snake memory diagnostic
--
-- Purpose:
--   Scan the known WRAM range and identify where the
--   known snake tile values actually occur.
--
-- Known snake values:
--   2D = right-facing head
--   25 = horizontal body
--   23 = tail
--
-- Visualization:
--   Black = everything else
--   Green = known snake tile
--
-- Additionally prints the addresses of every match.

local DOMAIN = "WRAM"

-- ============================================================
-- MEMORY RANGE
-- ============================================================

local START_ADDR = 0x000A80
local END_ADDR   = 0x00110E

local CELL_SIZE = 2


-- ============================================================
-- RAW MEMORY DISPLAY
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
-- VISUAL SETTINGS
-- ============================================================

local CELL_PIXELS = 5
local PANEL_MARGIN = 4

local PANEL_WIDTH =
    DISPLAY_WIDTH * CELL_PIXELS
    + PANEL_MARGIN * 2

local PANEL_HEIGHT =
    DISPLAY_HEIGHT * CELL_PIXELS
    + PANEL_MARGIN * 2


-- ============================================================
-- KNOWN SNAKE TILE VALUES
-- ============================================================

local SNAKE_TILES = {

    [0x2D] = true, -- head
    [0x25] = true, -- body
    [0x23] = true  -- tail

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
-- HELPERS
-- ============================================================

local function isSnakeTile(value)

    return SNAKE_TILES[value] == true

end


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    local panelX =
        client.bufferwidth()

    local gridX =
        panelX + PANEL_MARGIN

    local gridY =
        18


    -- ========================================================
    -- BACKGROUND
    -- ========================================================

    gui.drawRectangle(
        panelX,
        0,
        PANEL_WIDTH - 1,
        client.bufferheight(),
        0xFF404040,
        0xFF101010
    )


    gui.pixelText(
        panelX + PANEL_MARGIN,
        2,
        "RAW WRAM",
        0xFFFFFFFF,
        0xFF101010
    )


    -- ========================================================
    -- MATCH LIST
    -- ========================================================

    local matches = {}


    -- ========================================================
    -- SCAN MEMORY
    -- ========================================================

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


            -- Save matched address/value
            matches[#matches + 1] = {
                address = address,
                value = value
            }

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
    -- DISPLAY MATCHED ADDRESSES
    -- ========================================================

    local textX =
        panelX + 1

    local textY =
        gridY
        + DISPLAY_HEIGHT * CELL_PIXELS
        + 4


    gui.pixelText(
        textX,
        textY,
        "MATCHES:",
        0xFFFFFFFF,
        0xFF000000
    )


    textY =
        textY + 9


    -- Break the output across several lines so it fits.
    local line = ""
    local itemsOnLine = 0


    for i = 1, #matches do

        local entry =
            matches[i]


        local item =
            string.format(
                "%04X=%02X ",
                entry.address,
                entry.value
            )


        line =
            line .. item


        itemsOnLine =
            itemsOnLine + 1


        if itemsOnLine >= 3 then

            gui.pixelText(
                textX,
                textY,
                line,
                0xFFFFFFFF,
                0xFF000000
            )


            textY =
                textY + 9


            line = ""
            itemsOnLine = 0

        end

    end


    -- Print remaining items
    if line ~= "" then

        gui.pixelText(
            textX,
            textY,
            line,
            0xFFFFFFFF,
            0xFF000000
        )

    end


    -- ========================================================
    -- MATCH COUNT
    -- ========================================================

    gui.pixelText(
        textX,
        textY + 12,
        string.format(
            "Count: %d",
            #matches
        ),
        0xFFFFFFFF,
        0xFF000000
    )


    emu.frameadvance()

end
