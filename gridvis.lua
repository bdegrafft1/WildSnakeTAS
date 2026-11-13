-- BizHawk Lua
-- 12x26 Multi-Color Snake Visualizer
--
-- Current memory model:
--
--   [tile ID] [attribute]
--
-- Grid geometry:
--
--   horizontal = +0x02
--   vertical   = +0x40
--
-- Color classification based on the mature same-frame dump:
--
--   Cyan:
--       attribute 0C
--       tile family 54-5E
--
--   Yellow:
--       attribute 08
--       tile family 33-3D
--
--   Orange:
--       attribute 08
--       tile family 44-50
--
--   Blue:
--       attribute 08
--       tile family 12-32
--
-- Isolated cells are removed WITHIN each color family.
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

local COLOR_BLUE =
    0xFF2080FF

local COLOR_CYAN =
    0xFF00FFFF

local COLOR_YELLOW =
    0xFFFFFF00

local COLOR_ORANGE =
    0xFFFF8000


-- ============================================================
-- CLASSIFICATION
--
-- Returns:
--
--   name
--   color
--
-- or nil if the pair isn't currently recognized as snake data.
-- ============================================================

local function classifyTile(tile, attribute)

    -- --------------------------------------------------------
    -- CYAN
    -- --------------------------------------------------------

    if
        attribute == 0x0C and
        tile >= 0x54 and
        tile <= 0x5E
    then

        return "cyan", COLOR_CYAN

    end


    -- Remaining observed families use attribute 08.
    if attribute ~= 0x08 then
        return nil, nil
    end


    -- --------------------------------------------------------
    -- YELLOW
    --
    -- Strong sequence at the bottom:
    --
    -- 3D 35 35 35 35 35 35 33
    -- --------------------------------------------------------

    if
        tile >= 0x33 and
        tile <= 0x3D
    then

        return "yellow", COLOR_YELLOW

    end


    -- --------------------------------------------------------
    -- ORANGE
    --
    -- Repeated mature-board values:
    --
    -- 44 45 46 47 4A 50
    -- --------------------------------------------------------

    if
        tile >= 0x44 and
        tile <= 0x50
    then

        return "orange", COLOR_ORANGE

    end


    -- --------------------------------------------------------
    -- BLUE
    --
    -- Remaining observed first-snake / blue-family values.
    --
    -- Examples:
    --
    -- 12 16 1B 23 25 26 27 28 29 2E 30 32
    -- --------------------------------------------------------

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
-- MEMORY
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


    local row =
        math.floor(
            offset / Y_STEP
        )


    local column =
        math.floor(
            (offset % Y_STEP) / X_STEP
        )


    return row, column

end


local function gridCoordinates(address)

    local rawRow, rawColumn =
        rawCoordinates(address)


    return
        rawRow - RAW_Y_ORIGIN,
        rawColumn - RAW_X_ORIGIN

end


-- ============================================================
-- SCAN
-- ============================================================

local function scanCells()

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
                gridCoordinates(
                    address
                )


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
-- FILTER ISOLATED CELLS
--
-- Important:
--
-- Connectivity is checked ONLY against cells of the same
-- color family.
--
-- Therefore touching blue/yellow/orange snakes don't merge.
-- ============================================================

local function filterConnected(cells)

    local lookup = {}


    for i = 1, #cells do

        local cell =
            cells[i]


        local key =
            cell.family ..
            ":" ..
            string.format(
                "%04X",
                cell.address
            )


        lookup[key] =
            true

    end


    local output = {}


    for i = 1, #cells do

        local cell =
            cells[i]


        local neighbours = {

            cell.address - X_STEP,
            cell.address + X_STEP,

            cell.address - Y_STEP,
            cell.address + Y_STEP

        }


        local connected =
            false


        for n = 1, #neighbours do

            local key =
                cell.family ..
                ":" ..
                string.format(
                    "%04X",
                    neighbours[n]
                )


            if lookup[key] then

                connected =
                    true

                break

            end

        end


        if connected then

            output[#output + 1] =
                cell

        end

    end


    return output

end


-- ============================================================
-- CONSOLE
-- ============================================================

local function logCells(cells)

    local pieces = {}


    for i = 1, #cells do

        local cell =
            cells[i]


        pieces[#pieces + 1] =
            string.format(
                "%s:%04X:%02X",
                cell.family,
                cell.address,
                cell.tile
            )

    end


    table.sort(
        pieces
    )


    local signature =
        table.concat(
            pieces,
            "|"
        )


    if signature == previousSignature then
        return
    end


    previousSignature =
        signature


    local counts = {

        blue = 0,

        cyan = 0,

        yellow = 0,

        orange = 0

    }


    for i = 1, #cells do

        local family =
            cells[i].family


        counts[family] =
            counts[family] + 1

    end


    console.log(
        string.format(
            "blue=%d cyan=%d yellow=%d orange=%d",
            counts.blue,
            counts.cyan,
            counts.yellow,
            counts.orange
        )
    )


    for i = 1, #cells do

        local cell =
            cells[i]


        console.log(
            string.format(
                "%-6s row=%02d col=%02d addr=0x%04X tile=%02X attr=%02X",
                cell.family,
                cell.row,
                cell.column,
                cell.address,
                cell.tile,
                cell.attribute
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
    "12x26 multi-color snake visualizer"
)


console.log(
    "cyan   = attr 0C, tiles 54-5E"
)


console.log(
    "yellow = attr 08, tiles 33-3D"
)


console.log(
    "orange = attr 08, tiles 44-50"
)


console.log(
    "blue   = attr 08, tiles 12-32"
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
    -- READ GRID
    -- ========================================================

    local scanned =
        scanCells()


    local cells =
        filterConnected(
            scanned
        )


    logCells(
        cells
    )


    -- ========================================================
    -- PANEL
    -- ========================================================

    local panelX =
        client.bufferwidth()


    local gridX =
        panelX +
        MARGIN


    local gridY =
        MARGIN


    -- ========================================================
    -- BACKGROUND
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
    -- BLACK 12x26 GRID
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
    -- COLORED SNAKE CELLS
    -- ========================================================

    for i = 1, #cells do

        local cell =
            cells[i]


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
            cell.color
        )

    end


    emu.frameadvance()

end
