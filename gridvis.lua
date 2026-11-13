-- BizHawk Lua
-- First Snake Local Memory Diagnostic
--
-- Known current snake section:
--
--   0x0FA0 = 28 08
--   0x0FA2 = 25 08
--   0x0FA4 = 2A 08
--
-- The visible snake has additional vertical segments.
--
-- Goal:
--   Find those segments WITHOUT making another grid-layout
--   assumption.
--
-- DISPLAY:
--   Existing 12x26 visualization
--   Green = confirmed snake IDs
--   Black = everything else
--
-- CONSOLE:
--   Dumps interesting XX 08 pairs in the local memory region.
--
-- Confirmed IDs:
--   23 25 28 2A 2D

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 8
local PANEL_MARGIN = 8


-- ============================================================
-- CURRENT VISUALIZATION MAPPING
-- ============================================================

local GRID_BASE = 0x049E

local CELL_SIZE  = 2
local ROW_STRIDE = 0x80


-- ============================================================
-- LOCAL MEMORY SEARCH
--
-- This deliberately ignores the assumed grid mapping.
-- ============================================================

local SEARCH_START = 0x0E80
local SEARCH_END   = 0x0FFF


-- ============================================================
-- TILE DATA
-- ============================================================

local TILE_ATTRIBUTE = 0x08


local SNAKE_TILES = {

    [0x23] = true,

    [0x25] = true,

    [0x28] = true,

    [0x2A] = true,

    [0x2D] = true

}


-- Board/background tiles we already recognize.
local IGNORE_TILES = {

    [0x00] = true,

    [0x01] = true,

    [0xF4] = true,

    [0xF5] = true,

    [0xF6] = true,

    [0xF7] = true,

    [0xFC] = true,

    [0xFD] = true,

    [0xFE] = true,

    [0xFF] = true

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


local function getGridAddress(row, column)

    return
        GRID_BASE +
        row * ROW_STRIDE +
        column * CELL_SIZE

end


-- ============================================================
-- LOCAL MEMORY SCAN
--
-- Scan every two bytes for:
--
--     XX 08
--
-- Ignore known empty/border values.
-- ============================================================

local function scanLocalMemory()

    local results = {}


    for address = SEARCH_START, SEARCH_END, 2 do

        local tile =
            readByte(address)


        local attribute =
            readByte(address + 1)


        if
            attribute == TILE_ATTRIBUTE and
            not IGNORE_TILES[tile]
        then

            results[#results + 1] = {

                address = address,

                tile = tile,

                confirmed =
                    SNAKE_TILES[tile] == true

            }

        end

    end


    return results

end


-- ============================================================
-- SIGNATURE
-- ============================================================

local function buildSignature(results)

    local parts = {}


    for i = 1, #results do

        local result =
            results[i]


        parts[#parts + 1] =
            string.format(
                "%04X:%02X",
                result.address,
                result.tile
            )

    end


    return table.concat(
        parts,
        "|"
    )

end


-- ============================================================
-- CONSOLE
-- ============================================================

local function logResults(results)

    local signature =
        buildSignature(
            results
        )


    if signature == previousSignature then
        return
    end


    previousSignature =
        signature


    console.log(
        "========== LOCAL MEMORY =========="
    )


    console.log(
        string.format(
            "Interesting XX 08 pairs: %d",
            #results
        )
    )


    for i = 1, #results do

        local result =
            results[i]


        local marker = "?"


        if result.confirmed then

            marker = "*"

        end


        console.log(
            string.format(
                "%s 0x%04X = %02X 08",
                marker,
                result.address,
                result.tile
            )
        )

    end


    console.log(
        "* = confirmed snake ID"
    )


    console.log(
        "? = unknown candidate"
    )


    console.log(
        "=================================="
    )

end


-- ============================================================
-- STARTUP
-- ============================================================

console.clear()

console.log(
    "First-snake local memory diagnostic"
)

console.log(
    "Scanning 0x0E80-0x0FFF"
)

console.log(
    "Known horizontal section:"
)

console.log(
    "0x0FA0=28, 0x0FA2=25, 0x0FA4=2A"
)

console.log(
    "----------------------------------"
)


-- ============================================================
-- MAIN
-- ============================================================

while true do

    -- ========================================================
    -- RAW LOCAL SCAN
    -- ========================================================

    local results =
        scanLocalMemory()


    logResults(
        results
    )


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


    -- Background
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

            local address =
                getGridAddress(
                    row,
                    column
                )


            local tile =
                readByte(address)


            local attribute =
                readByte(address + 1)


            local color =
                0xFF000000


            if
                attribute == TILE_ATTRIBUTE and
                SNAKE_TILES[tile]
            then

                color =
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
                color
            )

        end

    end


    emu.frameadvance()

end
