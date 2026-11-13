-- BizHawk Lua
-- 12x26 Snake Grid Visualizer
--
-- Phase 1:
--   Black = empty / unknown
--   Green = known snake sprite
--
-- CONFIRMED:
--
-- Bottom row:
--
--   column 0  = 0x10DC
--   column 6  = 0x10E8 = 2D
--   column 7  = 0x10EA = 25
--   column 8  = 0x10EC = 25
--   column 9  = 0x10EE = 25
--   column 10 = 0x10F0 = 25
--   column 11 = 0x10F2 = 23
--
-- This version does NOT assume a fixed vertical row stride.
--
-- Instead, it searches backwards from the confirmed bottom
-- row for candidate board rows.

local DOMAIN = "WRAM"

-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_SIZE = 2


-- ============================================================
-- CONFIRMED BOTTOM ROW
-- ============================================================

local BOTTOM_ROW_BASE = 0x10DC


-- ============================================================
-- KNOWN SNAKE TILE VALUES
-- ============================================================

local SNAKE_TILES = {

    [0x2D] = true, -- right-facing head

    [0x25] = true, -- horizontal body

    [0x23] = true  -- tail

}


-- ============================================================
-- EMPTY / NORMAL BOARD TILE
--
-- The raw dump repeatedly shows:
--
--     01 08
--
-- for empty board locations.
--
-- So 01 is treated as an empty playable tile.
-- ============================================================

local EMPTY_TILE = 0x01


-- ============================================================
-- DISPLAY
-- ============================================================

local CELL_PIXELS = 8
local PANEL_MARGIN = 8

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS
    + PANEL_MARGIN * 2

local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS
    + PANEL_MARGIN * 2
    + 22


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


local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


-- ============================================================
-- ROW DETECTION
--
-- A board row should contain 12 consecutive 2-byte entries.
--
-- Empty playable locations usually look like:
--
--   01 08
--
-- Snake locations look like:
--
--   XX 08
--
-- So the strongest structural marker is currently the
-- attribute byte 08.
--
-- This function gives a candidate row a score based on
-- how many of its 12 cells have attribute == 08.
-- ============================================================

local function rowScore(baseAddress)

    local score = 0

    for column = 0, GRID_WIDTH - 1 do

        local address =
            baseAddress
            + column * CELL_SIZE

        local attribute =
            readByte(address + 1)

        if attribute == 0x08 then

            score =
                score + 1

        end

    end

    return score

end


-- ============================================================
-- FIND PREVIOUS ROW
--
-- Search backwards from the current row.
--
-- From the supplied memory dump, rows appear to have other
-- structures between them, so we search rather than assume
-- 0x40.
--
-- A perfect candidate has 12/12 attribute bytes == 08.
-- ============================================================

local function findPreviousRow(currentBase)

    -- Avoid accidentally finding the current row shifted by
    -- only one or two cells.
    local searchStart =
        currentBase - 0x18

    -- Search up to 0x100 bytes backwards.
    local searchEnd =
        currentBase - 0x100

    local bestAddress = nil
    local bestScore = -1

    -- Keep addresses even because cells are 2-byte entries.
    if searchStart % 2 ~= 0 then

        searchStart =
            searchStart - 1

    end


    for candidate = searchStart, searchEnd, -2 do

        local score =
            rowScore(candidate)

        if score > bestScore then

            bestScore =
                score

            bestAddress =
                candidate

        end


        -- 12/12 is good enough.
        if score == GRID_WIDTH then

            return candidate, score

        end

    end


    return bestAddress, bestScore

end


-- ============================================================
-- BUILD ROW TABLE
--
-- rowBases[26] = confirmed bottom
-- then search backwards to rowBases[1].
-- ============================================================

local function buildRowTable()

    local rows = {}
    local scores = {}

    rows[GRID_HEIGHT] =
        BOTTOM_ROW_BASE

    scores[GRID_HEIGHT] =
        rowScore(BOTTOM_ROW_BASE)


    for row = GRID_HEIGHT - 1, 1, -1 do

        local previousAddress, score =
            findPreviousRow(
                rows[row + 1]
            )

        rows[row] =
            previousAddress

        scores[row] =
            score

    end


    return rows, scores

end


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    local rowBases, rowScores =
        buildRowTable()


    local panelX =
        client.bufferwidth()

    local gridX =
        panelX + PANEL_MARGIN

    local gridY =
        8


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
    -- DRAW 12x26 GRID
    -- ========================================================

    for row = 0, GRID_HEIGHT - 1 do

        local rowBase =
            rowBases[row + 1]


        for column = 0, GRID_WIDTH - 1 do

            local address =
                rowBase
                + column * CELL_SIZE


            local tile =
                readByte(address)


            local x =
                gridX
                + column * CELL_PIXELS


            local y =
                gridY
                + row * CELL_PIXELS


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
                0xFF303030,
                fillColor
            )

        end

    end


    -- ========================================================
    -- DEBUG
    --
    -- Show detected top and bottom row addresses.
    -- ========================================================

    local debugY =
        gridY
        + GRID_HEIGHT * CELL_PIXELS
        + 3


    gui.pixelText(
        panelX + 1,
        debugY,
        string.format(
            "TOP:%04X BOT:%04X",
            rowBases[1],
            rowBases[GRID_HEIGHT]
        ),
        0xFFFFFFFF,
        0xFF000000
    )


    -- ========================================================
    -- BOTTOM ROW VERIFY
    -- ========================================================

    local verify = ""

    for column = 0, GRID_WIDTH - 1 do

        local address =
            BOTTOM_ROW_BASE
            + column * CELL_SIZE

        local value =
            readByte(address)

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
        verify,
        0xFF00FF40,
        0xFF000000
    )


    emu.frameadvance()

end
