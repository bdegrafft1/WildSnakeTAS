-- BizHawk Lua
-- First-Snake Relative-Mapping Visualizer
--
-- IMPORTANT:
-- This version DOES NOT use GRID_BASE.
--
-- Instead, it scans WRAM directly for known snake tiles and
-- converts their addresses into relative X/Y positions using
-- the geometry established from the current frame.
--
-- CONFIRMED CURRENT FRAME:
--
--   0x0F60 = 2E
--
--   0x0FA0 = 28
--   0x0FA2 = 25
--   0x0FA4 = 2A
--
--   0x0FE2 = 24
--   0x0FE4 = 27
--
-- MEMORY GEOMETRY:
--
--   +0x02 = one cell right
--   +0x40 = one cell down
--
-- DISPLAY:
--
--   Black = empty
--   Green = known first-snake tile
--
-- DEBUG:
--
--   Console only.

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

local COLUMN_STRIDE = 0x02
local ROW_STRIDE    = 0x40


-- ============================================================
-- MEMORY SEARCH RANGE
-- ============================================================

local SEARCH_START = 0x0A00
local SEARCH_END   = 0x1150


-- ============================================================
-- REFERENCE TILE
--
-- This is a known snake tile in the current frame.
--
-- From the screenshot, we'll temporarily place this around
-- column 2, row 22.
--
-- The IMPORTANT part is relative shape, not absolute placement.
-- ============================================================

local REFERENCE_ADDRESS = 0x0FA0

local REFERENCE_COLUMN = 2
local REFERENCE_ROW    = 22


-- ============================================================
-- TILE FORMAT
-- ============================================================

local TILE_ATTRIBUTE = 0x08


-- ============================================================
-- KNOWN FIRST-SNAKE IDS
-- ============================================================

local SNAKE_TILES = {

    [0x23] = true,

    [0x24] = true,

    [0x25] = true,

    [0x27] = true,

    [0x28] = true,

    [0x2A] = true,

    [0x2D] = true,

    [0x2E] = true

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


-- ============================================================
-- ADDRESS -> RELATIVE GRID POSITION
--
-- This intentionally works relative to 0x0FA0.
--
-- Examples:
--
-- 0x0F60:
--
--   delta = -0x40
--   row   = reference row - 1
--
-- 0x0FA2:
--
--   delta = +2
--   col   = reference col + 1
--
-- 0x0FE2:
--
--   delta = +0x42
--         = +0x40 + 0x02
--
--   row + 1
--   col + 1
-- ============================================================

local function addressToGrid(address)

    local delta =
        address - REFERENCE_ADDRESS


    -- Estimate row difference.
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


    -- Remove the vertical component.
    local horizontalDelta =
        delta -
        rowDelta * ROW_STRIDE


    -- Must align to a 2-byte tile.
    if horizontalDelta % COLUMN_STRIDE ~= 0 then

        return nil, nil

    end


    local columnDelta =
        horizontalDelta / COLUMN_STRIDE


    local row =
        REFERENCE_ROW +
        rowDelta


    local column =
        REFERENCE_COLUMN +
        columnDelta


    -- Keep only things that land inside the visualization.
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
-- FIND KNOWN SNAKE TILES
-- ============================================================

local function findSnakeTiles()

    local matches = {}


    -- Scan on even addresses because observed tile records
    -- are two-byte aligned.
    for address = SEARCH_START, SEARCH_END, 2 do

        local tile =
            readByte(address)


        local attribute =
            readByte(address + 1)


        if
            attribute == TILE_ATTRIBUTE and
            SNAKE_TILES[tile] == true
        then

            local row, column =
                addressToGrid(address)


            if row ~= nil and column ~= nil then

                matches[#matches + 1] = {

                    address = address,

                    tile = tile,

                    row = row,

                    column = column

                }

            end

        end

    end


    return matches

end


-- ============================================================
-- SIGNATURE
-- ============================================================

local function buildSignature(matches)

    local parts = {}


    for i = 1, #matches do

        local match =
            matches[i]


        parts[#parts + 1] =
            string.format(
                "%04X:%02X",
                match.address,
                match.tile
            )

    end


    return table.concat(
        parts,
        "|"
    )

end


-- ============================================================
-- CONSOLE DEBUG
-- ============================================================

local function logMatches(matches)

    local signature =
        buildSignature(
            matches
        )


    if signature == previousSignature then

        return

    end


    previousSignature =
        signature


    console.log(
        string.format(
            "Snake cells: %d",
            #matches
        )
    )


    for i = 1, #matches do

        local match =
            matches[i]


        console.log(
            string.format(
                "  0x%04X = %02X -> row=%02d col=%02d",
                match.address,
                match.tile,
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
    "First-snake relative mapper"
)


console.log(
    "No GRID_BASE used"
)


console.log(
    "Horizontal = +0x02"
)


console.log(
    "Vertical = +0x40"
)


console.log(
    string.format(
        "Reference 0x%04X -> row %d col %d",
        REFERENCE_ADDRESS,
        REFERENCE_ROW,
        REFERENCE_COLUMN
    )
)


console.log(
    "--------------------------------"
)


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
    -- DRAW KNOWN SNAKE TILES
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
