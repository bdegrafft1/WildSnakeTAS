-- WildSnake SNES TAS Research Logger
-- Intended for BizHawk Lua console.
--
-- Fill in the addresses in CONFIG.addresses after finding them.
-- Address types:
--   "u8"  = unsigned 8-bit
--   "s8"  = signed 8-bit
--   "u16" = unsigned 16-bit little endian
--   "s16" = signed 16-bit little endian
--
-- Start with LOG_ONLY_CHANGES = false while investigating.
-- Once addresses are understood, true produces much smaller logs.

local CONFIG = {
    OUTPUT_FILE = "wildsnake_tas_log.csv",

    -- Usually "WRAM" for SNES work RAM.
    -- Check BizHawk's Hex Editor / Memory Domains.
    MEMORY_DOMAIN = "WRAM",

    LOG_ONLY_CHANGES = false,

    -- Add/remove anything useful.
    addresses = {
        -- Example placeholders. REPLACE THESE.
        snake_color = { addr = 0x0000, type = "u8"  },
        snake_x     = { addr = 0x0001, type = "u8"  },
        snake_y     = { addr = 0x0002, type = "u8"  },

        -- Add these when discovered:
        -- next_color  = { addr = 0x1234, type = "u8"  },
        -- rng         = { addr = 0x1235, type = "u16" },
        -- challenge   = { addr = 0x1237, type = "u8"  },
        -- snake_count = { addr = 0x1238, type = "u8"  },
        -- timer       = { addr = 0x1239, type = "u16" },
        -- game_state  = { addr = 0x123B, type = "u8"  },
    }
}

memory.usememorydomain(CONFIG.MEMORY_DOMAIN)

------------------------------------------------------------
-- Memory utilities
------------------------------------------------------------

local function read_value(info)
    if info.type == "u8" then
        return memory.read_u8(info.addr)

    elseif info.type == "s8" then
        return memory.read_s8(info.addr)

    elseif info.type == "u16" then
        return memory.read_u16_le(info.addr)

    elseif info.type == "s16" then
        return memory.read_s16_le(info.addr)

    else
        error("Unknown memory type: " .. tostring(info.type))
    end
end

------------------------------------------------------------
-- Input
------------------------------------------------------------

local function get_input_string()
    local p = joypad.get(1)
    local pressed = {}

    -- SNES buttons
    local buttons = {
        "Up",
        "Down",
        "Left",
        "Right",
        "A",
        "B",
        "X",
        "Y",
        "L",
        "R",
        "Start",
        "Select"
    }

    for _, button in ipairs(buttons) do
        if p[button] then
            table.insert(pressed, button)
        end
    end

    if #pressed == 0 then
        return "-"
    end

    return table.concat(pressed, "+")
end

------------------------------------------------------------
-- CSV
------------------------------------------------------------

local file = io.open(CONFIG.OUTPUT_FILE, "w")

if not file then
    error("Unable to open " .. CONFIG.OUTPUT_FILE)
end

-- Determine stable column order.

local address_names = {}

for name, _ in pairs(CONFIG.addresses) do
    table.insert(address_names, name)
end

table.sort(address_names)

-- Header

file:write("frame,input")

for _, name in ipairs(address_names) do
    file:write("," .. name)
end

file:write(",marker\n")
file:flush()

------------------------------------------------------------
-- State
------------------------------------------------------------

local previous = {}
local marker = ""

------------------------------------------------------------
-- Snapshot memory
------------------------------------------------------------

local function snapshot()
    local values = {}

    for _, name in ipairs(address_names) do
        values[name] = read_value(CONFIG.addresses[name])
    end

    return values
end

------------------------------------------------------------
-- Detect changes
------------------------------------------------------------

local function values_changed(current)
    for _, name in ipairs(address_names) do
        if previous[name] ~= current[name] then
            return true
        end
    end

    return false
end

------------------------------------------------------------
-- CSV-safe string
------------------------------------------------------------

local function csv_escape(s)
    if s == nil then
        return ""
    end

    s = tostring(s)

    if string.find(s, '[,"\n]') then
        s = '"' .. string.gsub(s, '"', '""') .. '"'
    end

    return s
end

------------------------------------------------------------
-- Write row
------------------------------------------------------------

local function write_row(frame, input, values)
    file:write(tostring(frame))
    file:write("," .. csv_escape(input))

    for _, name in ipairs(address_names) do
        file:write("," .. tostring(values[name]))
    end

    file:write("," .. csv_escape(marker))
    file:write("\n")

    file:flush()

    marker = ""
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------

local function draw_gui(frame, input, values)

    local x = 4
    local y = 4
    local line = 14

    gui.text(x, y, "WildSnake TAS Logger")
    y = y + line

    gui.text(x, y, "Frame: " .. tostring(frame))
    y = y + line

    gui.text(x, y, "Input: " .. tostring(input))
    y = y + line

    for _, name in ipairs(address_names) do
        local info = CONFIG.addresses[name]
        local value = values[name]

        local text = string.format(
            "%-12s $%06X = %d ($%X)",
            name,
            info.addr,
            value,
            value
        )

        gui.text(x, y, text)
        y = y + line
    end

    if marker ~= "" then
        y = y + 4
        gui.text(x, y, "MARK: " .. marker, "yellow")
    end
end

------------------------------------------------------------
-- Marker hotkey
------------------------------------------------------------

-- Change this if desired.
-- Pressing M marks the next logged row.
local old_keyboard = {}

local function check_marker()
    local keyboard = input.get()

    if keyboard["M"] and not old_keyboard["M"] then
        marker = "MANUAL_MARK"
    end

    old_keyboard = keyboard
end

------------------------------------------------------------
-- Main
------------------------------------------------------------

while true do

    local frame = emu.framecount()
    local controller = get_input_string()
    local current = snapshot()

    check_marker()

    local changed = values_changed(current)

    if not CONFIG.LOG_ONLY_CHANGES or changed or marker ~= "" then
        write_row(frame, controller, current)
    end

    draw_gui(frame, controller, current)

    -- Copy current state
    for name, value in pairs(current) do
        previous[name] = value
    end

    emu.frameadvance()
end
