-- BizHawk Lua
-- Sprite/grid memory visualizer

local BASE = 0x000A80

local GRID_W = 26
local GRID_H = 12

-- Based on the memory dump:
-- adjust these two values to shift/align the grid.
local ROW_STRIDE = 0x50
local COL_STRIDE = 2

-- Which byte inside each cell contains the sprite character.
local VALUE_OFFSET = 0

local DOMAIN = "WRAM"

-- Screen placement
local SCREEN_X = 8
local SCREEN_Y = 145

local CELL_W = 9
local CELL_H = 9


local function readCell(row, col)
    local addr =
        BASE +
        row * ROW_STRIDE +
        col * COL_STRIDE +
        VALUE_OFFSET

    return memory.read_u8(addr, DOMAIN), addr
end


local function cellColor(value)

    -- '.' / blank = black
    --
    -- I'm treating zero as empty as well because the dump
    -- contains large amounts of 00 padding.
    if value == 0x00 or value == string.byte(".") then
        return 0xD0000000
    end

    -- '&' body
    if value == string.byte("&") then
        return 0xFF00CC44
    end

    -- '+' tail
    if value == string.byte("+") then
        return 0xFFFFFF00
    end

    -- Anything else = some kind of snake/sprite data
    return 0xFFFF3030
end


while true do

    for row = 0, GRID_H - 1 do
        for col = 0, GRID_W - 1 do

            local value, addr = readCell(row, col)

            local x = SCREEN_X + col * CELL_W
            local y = SCREEN_Y + row * CELL_H

            gui.drawRectangle(
                x,
                y,
                CELL_W - 1,
                CELL_H - 1,
                0xFF303030,
                cellColor(value)
            )

            -- Show the actual character/value for occupied cells
            if value ~= 0 and value ~= string.byte(".") then

                local display

                if value >= 0x20 and value <= 0x7E then
                    display = string.char(value)
                else
                    display = string.format("%X", value)
                end

                gui.pixelText(
                    x + 1,
                    y + 1,
                    display,
                    0xFFFFFFFF,
                    0x00000000
                )
            end

        end
    end

    gui.text(
        SCREEN_X,
        SCREEN_Y - 14,
        string.format(
            "Grid %dx%d  base:%06X stride:%02X",
            GRID_W,
            GRID_H,
            BASE,
            ROW_STRIDE
        ),
        "white",
        "black"
    )

    emu.frameadvance()
end
