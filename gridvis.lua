-- BizHawk Lua
-- 12x26 Multi-Color Snake Visualizer
--
-- Memory structure discovered so far:
--
--   [tile ID] [attribute / palette]
--
-- Likely palettes from the supplied same-frame dump:
--
--   XX 08 = blue/orange snake
--   XX 0C = cyan snake
--   XX 19 = yellow snake
--
-- Empty board cell:
--
--   01 08
--
-- Memory geometry:
--
--   horizontal neighbor = +/- 0x02
--   vertical neighbor   = +/- 0x40
--
-- DISPLAY:
--
--   Black  = empty
--   Blue   = attribute 08
--   Cyan   = attribute 0C
--   Yellow = attribute 19
--
-- Isolated candidate values are ignored.
-- All connected snake clusters are drawn.
-- Debug output goes to the Lua console only.

local DOMAIN = "WRAM"


-- ============================================================
-- OUTPUT GRID
-- ============================================================

local GRID_WIDTH  = 12
local GRID_HEIGHT = 26

local CELL_PIXELS = 5
local MARGIN = 4


-- ============================================================
-- MEMORY RANGE
-- ============================================================

local SEARCH_START = 0x0A80
local SEARCH_END   = 0x110E

local X_STEP = 0x02
local Y_STEP = 0x40


-- ============================================================
-- PLAYFIELD CALIBRATION
--
-- Keep the value that looked better in the last test.
--
-- Raw column 16 becomes output column 0.
--
-- Smaller value moves output right.
-- Larger value moves output left.
-- ============================================================

local RAW_X_ORIGIN = 16

local RAW_Y_ORIGIN = 0


-- ============================================================
-- PALETTE / ATTRIBUTE COLORS
--
-- ARGB format:
--
--   0xAA RR GG BB
-- ============================================================

local ATTRIBUTE_COLORS = {

    -- Blue snake.
    [0x08] = 0xFF2080FF,

    -- Cyan snake.
    [0x0C] = 0xFF00FFFF,

    -- Yellow snake.
    [0x19] = 0xFFFFFF00

}


-- ============================================================
-- EMPTY / STRUCTURAL TILE IDS
--
-- These values are known board, border, or empty graphics.
-- They must not become snake cells merely because an attribute
-- happens to match.
-- ============================================================

local IGNORED_TILES = {

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
-- ATTRIBUTE-SPECIFIC TILE RANGES
--
-- The supplied dump shows different tile-ID families for
-- different palettes.
--
-- 08:
--   includes values such as 02, 05, 06, 09, 0F, 12, 16,
--   1B, 22-50, etc.
--
-- 0C:
--   includes 54, 55, 56, 57, 59, 5B, 5E.
--
-- 19:
--   includes the yellow snake sprite family.
--
-- Broad ranges are used, but connected-cluster filtering and
-- playfield clipping remove isolated unrelated values.
-- ============================================================

local function isCandidateTile(tile, attribute)

    if ATTRIBUTE_COLORS[attribute] == nil then
        return false
    end


    if IGNORED_TILES[tile] then
        return false
    end


    -- Cyan family observed in the dump.
    if attribute == 0x0C then

        return
            tile >= 0x50 and
            tile <= 0x5F

    end


    -- Yellow family observed with attribute 19.
    if attribute == 0x19 then

        return
            tile >= 0x10 and
            tile <= 0x5F

    end


    -- Blue/orange family.
    if attribute == 0x08 then

        return
            tile >= 0x02 and
            tile <= 0x5F

    end


    return false

end


-- ============================================================
-- CLUSTER FILTERING
--
-- Ignore single coincidental matches.
--
-- A minimum of two connected tiles allows short visible
-- sections while eliminating the stuck isolated pixels.
-- ============================================================

local MIN_CLUSTER_SIZE = 2


-- ============================================================
-- PANEL SIZE
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
-- ADDRESS COORDINATES
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


    local gridRow =
        rawRow -
        RAW_Y_ORIGIN


    local gridColumn =
        rawColumn -
        RAW_X_ORIGIN


    return gridRow, gridColumn

end


-- ============================================================
-- SCAN CANDIDATE CELLS
--
-- lookup is indexed by:
--
--   attribute -> address -> candidate
--
-- Keeping palettes separate prevents adjacent snakes of
-- different colors from merging into one cluster.
-- ============================================================

local function scanCandidates()

    local candidatesByAttribute = {}

    local lookupByAttribute = {}


    for attribute, color in pairs(ATTRIBUTE_COLORS) do

        candidatesByAttribute[attribute] = {}
        lookupByAttribute[attribute] = {}

    end


    for address = SEARCH_START, SEARCH_END - 1, 2 do

        local tile, attribute =
            readTile(address)


        if isCandidateTile(tile, attribute) then

            local row, column =
                gridCoordinates(address)


            -- Only retain values inside the visible 12x26
            -- playfield. This removes unrelated data elsewhere
            -- in the underlying 32-wide memory row.
            if
                row >= 0 and
                row < GRID_HEIGHT and
                column >= 0 and
                column < GRID_WIDTH
            then

                local entry = {

                    address = address,

                    tile = tile,

                    attribute = attribute,

                    row = row,

                    column = column

                }


                local candidates =
                    candidatesByAttribute[attribute]


                local lookup =
                    lookupByAttribute[attribute]


                candidates[#candidates + 1] =
                    entry


                lookup[address] =
                    entry

            end

        end

    end


    return
        candidatesByAttribute,
        lookupByAttribute

end


-- ============================================================
-- BUILD CLUSTERS FOR ONE COLOR
-- ============================================================

local function buildClusters(candidates, lookup)

    local clusters = {}

    local visited = {}


    for i = 1, #candidates do

        local start =
            candidates[i]


        if not visited[start.address] then

            local cluster = {}

            local queue = {
                start.address
            }

            local queueIndex = 1


            visited[start.address] =
                true


            while queueIndex <= #queue do

                local address =
                    queue[queueIndex]


                queueIndex =
                    queueIndex + 1


                local entry =
                    lookup[address]


                if entry ~= nil then

                    cluster[#cluster + 1] =
                        entry


                    local neighbors = {

                        address - X_STEP,
                        address + X_STEP,

                        address - Y_STEP,
                        address + Y_STEP

                    }


                    for n = 1, #neighbors do

                        local neighbor =
                            neighbors[n]


                        if
                            lookup[neighbor] ~= nil and
                            not visited[neighbor]
                        then

                            visited[neighbor] =
                                true


                            queue[#queue + 1] =
                                neighbor

                        end

                    end

                end

            end


            if #cluster >= MIN_CLUSTER_SIZE then

                clusters[#clusters + 1] =
                    cluster

            end

        end

    end


    return clusters

end


-- ============================================================
-- FIND ALL COLORED SNAKES
-- ============================================================

local function findAllClusters()

    local candidatesByAttribute,
          lookupByAttribute =
        scanCandidates()


    local allClusters = {}


    for attribute, color in pairs(ATTRIBUTE_COLORS) do

        local candidates =
            candidatesByAttribute[attribute]


        local lookup =
            lookupByAttribute[attribute]


        local clusters =
            buildClusters(
                candidates,
                lookup
            )


        for i = 1, #clusters do

            allClusters[#allClusters + 1] = {

                attribute = attribute,

                color = color,

                cells = clusters[i]

            }

        end

    end


    return allClusters

end


-- ============================================================
-- CONSOLE LOGGING
-- ============================================================

local function logClusters(clusters)

    local parts = {}


    for i = 1, #clusters do

        local cluster =
            clusters[i]


        for c = 1, #cluster.cells do

            local cell =
                cluster.cells[c]


            parts[#parts + 1] =
                string.format(
                    "%02X:%04X:%02X",
                    cluster.attribute,
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
            "Colored clusters: %d",
            #clusters
        )
    )


    for i = 1, #clusters do

        local cluster =
            clusters[i]


        console.log(
            string.format(
                "Cluster %d: attr=%02X cells=%d",
                i,
                cluster.attribute,
                #cluster.cells
            )
        )


        for c = 1, #cluster.cells do

            local cell =
                cluster.cells[c]


            console.log(
                string.format(
                    "  row=%02d col=%02d addr=0x%04X tile=%02X",
                    cell.row,
                    cell.column,
                    cell.address,
                    cell.tile
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
    string.format(
        "Raw X origin: %d",
        RAW_X_ORIGIN
    )
)


console.log(
    "08 = blue"
)


console.log(
    "0C = cyan"
)


console.log(
    "19 = yellow"
)


console.log(
    "Isolated matches ignored"
)


console.log(
    "--------------------------------"
)


-- ============================================================
-- MAIN LOOP
-- ============================================================

while true do

    -- ========================================================
    -- DETECT ALL COLORED CLUSTERS
    -- ========================================================

    local clusters =
        findAllClusters()


    logClusters(
        clusters
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
    -- 12x26 BLACK GRID
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
    -- DRAW ALL COLORED CLUSTERS
    -- ========================================================

    for i = 1, #clusters do

        local cluster =
            clusters[i]


        for c = 1, #cluster.cells do

            local cell =
                cluster.cells[c]


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
                cluster.color
            )

        end

    end


    emu.frameadvance()

end
