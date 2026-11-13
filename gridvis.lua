-- BizHawk Lua
-- 12x26 Snake Grid Diagnostic
--
-- Goal:
--   Identify ALL sprite/tile values used by the first snake.
--
-- Current evidence:
--
--   Vertical grid step   = 0x80
--   Horizontal grid step = 0x04
--
-- Known first-snake values:
--
--   0x25 = known body
--   0x2D = known head/orientation
--   0x23 = known tail/orientation
--
-- DISPLAY:
--   Black = unknown / empty
--   Green = currently known snake value
--
-- CONSOLE:
--   Dumps logical grid cells whose values are not obvious
--   empty/background values.
--
-- No debug text is drawn over the game/grid.

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- MEMORY GEOMETRY
-- ============================================================

local ROW_STRIDE = 0x80
local COLUMN_STRIDE = 0x04


-- ============================================================
-- REFERENCE
--
-- Observed:
--
--   0x0C24 -> row 15, column 3
--
-- Therefore:
--
--   address(row,col)
--
--     = REFERENCE_ADDRESS
--       + (row - REFERENCE_ROW) * 0x80
--       + (col - REFERENCE_COLUMN) * 0x04
-- ============================================================

local REFERENCE_ADDRESS = 0x0C24
local REFERENCE_ROW = 15
local REFERENCE_COLUMN = 3


-- ============================================================
-- KNOWN FIRST-SNAKE VALUES
-- ============================================================

local SNAKE_TILES = {

    [0x23] = true,

    [0x25] = true,

    [0x2D] = true

}


-- ============================================================
-- DISPLAY SIZE
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

local previousSignature = nil


-- ============================================================
-- MEMORY HELPERS
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function getCellAddress(row, column)

    return
        REFERENCE_ADDRESS
        + (row - REFERENCE_ROW) * ROW_STRIDE
        + (column - REFERENCE_COLUMN) * COLUMN_STRIDE

end


local function isKnownSnake(value)

    return SNAKE_TILES[value] == true

end


-- ============================================================
-- READ LOGICAL CELL
--
-- We currently don't know the exact structure of each logical
-- cell, so read four bytes.
--
-- This is important because COLUMN_STRIDE = 4.
-- ============================================================

local function readCell(row, column)

    local address =
        getCellAddress(
            row,
            column
        )


    local b0 =
        readByte(address)

    local b1 =
        readByte(address + 1)

    local b2 =
        readByte(address + 2)

    local b3 =
        readByte(address + 3)


    return {
        address = address,

        b0 = b0,
        b1 = b1,
        b2 = b2,
        b3 = b3
    }

end


-- ============================================================
-- CREATE CURRENT MEMORY SIGNATURE
--
-- Used only to prevent console spam.
-- ============================================================

local function buildSignature()

    local parts = {}


    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local cell =
                readCell(
                    row,
                    column
                )


            parts[#parts + 1] =
                string.format(
                    "%02X%02X%02X%02X",
                    cell.b0,
                    cell.b1,
                    cell.b2,
                    cell.b3
                )

        end

    end


    return table.concat(
        parts,
        ":"
    )

end


-- ============================================================
-- CONSOLE SNAPSHOT
-- ============================================================

local function logGridSnapshot()

    console.log(
        "============== GRID CHANGE =============="
    )


    for row = 0, GRID_HEIGHT - 1 do

        local foundSomething = false

        local line =
            string.format(
                "R%02d: ",
                row
            )


        for column = 0, GRID_WIDTH - 1 do

            local cell =
                readCell(
                    row,
                    column
                )


            -- -----------------------------------------------
            -- For now treat an all-zero cell as uninteresting.
            --
            -- Everything else gets represented in the row.
            -- -----------------------------------------------

            if
                cell.b0 ~= 0 or
                cell.b1 ~= 0 or
                cell.b2 ~= 0 or
                cell.b3 ~= 0
            then

                foundSomething = true


                line =
                    line ..
                    string.format(
                        "C%02d=%02X%02X%02X%02X ",
                        column,
                        cell.b0,
                        cell.b1,
                        cell.b2,
                        cell.b3
                    )

            end

        end


        if foundSomething then

            console.log(
                line
            )

        end

    end


    console.log(
        "========================================="
    )

end


-- ============================================================
-- INITIAL CONSOLE
-- ============================================================

console.clear()

console.log(
    "First-snake grid diagnostic"
)

console.log(
    "Y stride = 0x80"
)

console.log(
    "X stride = 0x04"
)

console.log(
    "Known snake IDs = 23, 25, 2D"
)

console.log(
    "Waiting for logical grid changes..."
)

console.log(
    "========================================="
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- CHECK FOR MEMORY CHANGES
    -- ========================================================

    local signature =
        buildSignature()


    if signature ~= previousSignature then

        logGridSnapshot()

        previousSignature =
            signature

    end


    -- ========================================================
    -- VISUALIZATION
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
    -- DRAW GRID
    -- ========================================================

    for row = 0, GRID_HEIGHT - 1 do

        for column = 0, GRID_WIDTH - 1 do

            local cell =
                readCell(
                    row,
                    column
                )


            local fillColor =
                0xFF000000


            -- For the moment, check all four bytes for one
            -- of the confirmed first-snake IDs.
            if
                isKnownSnake(cell.b0) or
                isKnownSnake(cell.b1) or
                isKnownSnake(cell.b2) or
                isKnownSnake(cell.b3)
            then

                fillColor =
                    0xFF00FF40

            end


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
                fillColor
            )

        end

    end


    emu.frameadvance()

end
