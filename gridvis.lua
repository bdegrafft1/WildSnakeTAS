-- BizHawk Lua
-- Visualize a 26x12 grid mapped approximately between
-- WRAM addresses 0x000A80 and 0x00110E.

local START_ADDR = 0x000A80
local END_ADDR   = 0x00110E

local GRID_W = 26
local GRID_H = 12
local CELL_COUNT = GRID_W * GRID_H

-- Screen position / size
local START_X = 4
local START_Y = 4
local CELL_W = 9
local CELL_H = 9

-- Change if your BizHawk core uses a different domain name.
local DOMAIN = "WRAM"

-- Approximate address spacing across the supplied range.
local ADDRESS_RANGE = END_ADDR - START_ADDR

local function addressForCell(index)
    -- index = 0 .. 311
    local t = index / (CELL_COUNT - 1)
    return math.floor(START_ADDR + ADDRESS_RANGE * t + 0.5)
end

local function getColor(value)
    -- Adjust these meanings once the actual values are known.
    if value == 0 then
        return 0x40000000       -- transparent black
    elseif value == 1 then
        return 0xFF00FF00       -- green
    elseif value == 2 then
        return 0xFFFFFF00       -- yellow
    elseif value == 3 then
        return 0xFFFF8000       -- orange
    else
        return 0xFFFF0000       -- red
    end
end

while true do
    for row = 0, GRID_H - 1 do
        for col = 0, GRID_W - 1 do

            local index = row * GRID_W + col
            local addr = addressForCell(index)

            local value = memory.read_u8(addr, DOMAIN)

            local x = START_X + col * CELL_W
            local y = START_Y + row * CELL_H

            gui.drawRectangle(
                x,
                y,
                CELL_W - 1,
                CELL_H - 1,
                0xFF404040,
                getColor(value)
            )

            -- Optional: show non-zero values
            if value ~= 0 then
                gui.pixelText(
                    x + 2,
                    y + 1,
                    tostring(value),
                    0xFFFFFFFF,
                    0x00000000
                )
            end
        end
    end

    -- Diagnostic information
    gui.text(
        START_X,
        START_Y + GRID_H * CELL_H + 3,
        string.format(
            "Grid %dx%d  %06X-%06X",
            GRID_W,
            GRID_H,
            START_ADDR,
            END_ADDR
        )
    )

    emu.frameadvance()
end
