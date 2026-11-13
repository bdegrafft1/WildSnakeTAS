-- Debug the final row
local debug = ""

for column = 0, GRID_WIDTH - 1 do
    local tile, attribute, address =
        readCell(GRID_HEIGHT - 1, column)

    debug = debug .. string.format(
        "%02X ",
        tile
    )
end

gui.pixelText(
    panelX + PANEL_MARGIN,
    gridY + GRID_HEIGHT * CELL_PIXELS + 2,
    debug,
    0xFFFFFFFF,
    0xFF000000
)
