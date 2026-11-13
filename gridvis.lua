-- BizHawk Lua
-- 12x26 Multi-Color Snake Visualizer
--
-- Grid geometry:
--   horizontal = 0x02 bytes
--   vertical   = 0x40 bytes
--
-- Current sprite families:
--
--   CYAN
--     attr 0C
--     tiles 54-5E
--
--   YELLOW
--     attr 08
--     tiles 33-3D
--
--   ORANGE
--     attr 08
--     tiles 44-50
--
--   BLUE
--     attr 08
--     tiles 12-32
--
-- Display:
--   black  = empty
--   cyan   = cyan snake
--   yellow = yellow snake
--   orange = orange snake
--   blue   = blue snake
--
-- Debug goes to console only.

local DOMAIN = "WRAM"


-- ============================================================
-- GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 5
local MARGIN = 4


-- ============================================================
-- MEMORY
-- ============================================================

local SEARCH_START = 0x0A80
local SEARCH_END   = 0x110E

local X_STEP = 0x02
local Y_STEP = 0x40


-- ============================================================
-- GRID CALIBRATION
-- ============================================================

local RAW_X_ORIGIN = 16
local RAW_Y_ORIGIN = 0


-- ============================================================
-- COLORS
-- ============================================================

local COLOR_BLUE   = 0xFF2080FF
local COLOR_CYAN   = 0xFF00FFFF
local COLOR_YELLOW = 0xFFFFFF00
local COLOR_ORANGE = 0xFFFF8000


-- ============================================================
-- MINIMUM CONNECTED COMPONENT SIZE
--
-- Single matching bytes are ignored.
-- ============================================================

local MIN_COMPONENT_SIZE = 2


-- ============================================================
-- TILE CLASSIFICATION
-- ============================================================

local function classifyTile(tile, attribute)

    -- Cyan family
    if
        attribute == 0x0C and
        tile >= 0x54 and
        tile <= 0x5E
    then
        return "cyan", COLOR_CYAN
    end


    -- Other currently identified snakes use attr 08.
    if attribute ~= 0x08 then
        return nil, nil
    end


    -- Yellow family
    if
        tile >= 0x33 and
        tile <= 0x3D
    then
        return "yellow", COLOR_YELLOW
    end


    -- Orange family
    if
        tile >= 0x44 and
        tile <= 0x50
    then
        return "orange", COLOR_ORANGE
    end


    -- Blue family
    if
        tile >= 0x12 and
        tile <= 0x32
    then
        return "blue", COLOR_BLUE
    end


    return nil, nil
end


-- ============================================================
-- PANEL
-- ============================================================

local PANEL_WIDTH =
    GRID_WIDTH * CELL_PIXELS +
    MARGIN * 2

local PANEL_HEIGHT =
    GRID_HEIGHT * CELL_PIXELS +
    MARGIN * 2


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
-- MEMORY HELPERS
-- ============================================================

local function readByte(address)

    return memory.read_u8(
        address,
        DOMAIN
    )

end


local function readTile(address)

    local tile =
        readByte(address)

    local attribute =
        readByte(address + 1)

    return tile, attribute
end


-- ============================================================
-- COORDINATES
-- ============================================================

local function rawCoordinates(address)

    local offset =
        address - SEARCH_START


    local rawRow =
        math.floor(
            offset / Y_STEP
        )


    local rawColumn =
        math.floor(
            (offset % Y_STEP) / X_STEP
        )


    return rawRow, rawColumn
end


local function gridCoordinates(address)

    local rawRow, rawColumn =
        rawCoordinates(address)


    return
        rawRow - RAW_Y_ORIGIN,
        rawColumn - RAW_X_ORIGIN
end


-- ============================================================
-- SCAN CANDIDATES
-- ============================================================

local function scanCandidates()

    local cells = {}


    for address = SEARCH_START, SEARCH_END - 1, 2 do

        local tile, attribute =
            readTile(address)


        local family, color =
            classifyTile(
                tile,
                attribute
            )


        if family ~= nil then

            local row, column =
                gridCoordinates(address)


            if
                row >= 0 and
                row < GRID_HEIGHT and
                column >= 0 and
                column < GRID_WIDTH
            then

                cells[#cells + 1] = {

                    address = address,

                    tile = tile,

                    attribute = attribute,

                    family = family,

                    color = color,

                    row = row,

                    column = column

                }

            end
        end
    end


    return cells
end


-- ============================================================
-- BUILD LOOKUP
--
-- Separate lookup tables per color family.
-- ============================================================

local function buildLookup(cells)

    local lookup = {}


    for i = 1, #cells do

        local cell =
            cells[i]


        if lookup[cell.family] == nil then
            lookup[cell.family] = {}
        end


        lookup[cell.family][cell.address] =
            cell
    end


    return lookup
end


-- ============================================================
-- CONNECTED COMPONENT FOR ONE CELL
-- ============================================================

local function getComponent(startCell, familyLookup, visited)

    local component = {}

    local queue = {
        startCell.address
    }

    local queueIndex = 1


    visited[startCell.address] =
        true


    while queueIndex <= #queue do

        local address =
            queue[queueIndex]

        queueIndex =
            queueIndex + 1


        local cell =
            familyLookup[address]


        if cell ~= nil then

            component[#component + 1] =
                cell


            local neighbours = {

                address - X_STEP,
                address + X_STEP,

                address - Y_STEP,
                address + Y_STEP

            }


            for n = 1, #neighbours do

                local neighbour =
                    neighbours[n]


                if
                    familyLookup[neighbour] ~= nil and
                    not visited[neighbour]
                then

                    visited[neighbour] =
                        true


                    queue[#queue + 1] =
                        neighbour
                end
            end
        end
    end


    return component
end


-- ============================================================
-- FILTER INTO VALID CONNECTED SNAKES
-- ============================================================

local function findComponents(cells)

    local lookup =
        buildLookup(cells)


    local components = {}


    for family, familyLookup in pairs(lookup) do

        local visited = {}


        for address, cell in pairs(familyLookup) do

            if not visited[address] then

                local component =
                    getComponent(
                        cell,
                        familyLookup,
                        visited
                    )


                if #component >= MIN_COMPONENT_SIZE then

                    components[#components + 1] = {

                        family = family,

                        color = cell.color,

                        cells = component

                    }

                end
            end
        end
    end


    return components
end


-- ============================================================
-- CONSOLE
-- ============================================================

local function logComponents(components)

    local parts = {}


    for i = 1, #components do

        local component =
            components[i]


        for c = 1, #component.cells do

            local cell =
                component.cells[c]


            parts[#parts + 1] =
                string.format(
                    "%s:%04X:%02X",
                    component.family,
                    cell.address,
                    cell.tile
                )
        end
    end


    table.sort(parts)


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
            "Components: %d",
            #components
        )
    )


    for i = 1, #components do

        local component =
            components[i]


        console.log(
            string.format(
                "%s snake: %d cells",
                component.family,
                #component.cells
            )
        )


        for c = 1, #component.cells do

            local cell =
                component.cells[c]


            console.log(
                string.format(
                    "  row=%02d col=%02d addr=0x%04X tile=%02X attr=%02X",
                    cell.row,
                    cell.column,
                    cell.address,
                    cell.tile,
                    cell.attribute
                )
            )
        end
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
    "12x26 multi-color snake visualizer"
)


console.log(
    "cyan   : 54-5E / attr 0C"
)


console.log(
    "yellow : 33-3D / attr 08"
)


console.log(
    "orange : 44-50 / attr 08"
)


console.log(
    "blue   : 12-32 / attr 08"
)


console.log(
    string.format(
        "Raw X origin: %d",
        RAW_X_ORIGIN
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
    -- DETECT
    -- ========================================================

    local candidates =
        scanCandidates()


    local components =
        findComponents(
            candidates
        )


    logComponents(
        components
    )


    -- ========================================================
    -- PANEL POSITION
    -- ========================================================

    local panelX =
        client.bufferwidth()


    local gridX =
        panelX +
        MARGIN


    local gridY =
        MARGIN


    -- ========================================================
    -- PANEL BACKGROUND
    -- ========================================================

    gui.drawRectangle(
        panelX,
        0,
        PANEL_WIDTH - 1,
        PANEL_HEIGHT - 1,
        0xFF202020,
        0xFF101010
    )


    -- ========================================================
    -- EMPTY 12x26 GRID
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
                0xFF404040,
                0xFF000000
            )

        end
    end


    -- ========================================================
    -- DRAW EVERY VALID COMPONENT
    -- ========================================================

    for i = 1, #components do

        local component =
            components[i]


        for c = 1, #component.cells do

            local cell =
                component.cells[c]


            local x =
                gridX +
                cell.column * CELL_PIXELS


            local y =
                gridY +
                cell.row * CELL_PIXELS


            gui.drawRectangle(
                x,
                y,
                CELL_PIXELS - 1,
                CELL_PIXELS - 1,
                0xFFFFFFFF,
                component.color
            )

        end
    end


    emu.frameadvance()
end
