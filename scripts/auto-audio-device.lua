local mp = require "mp"
local msg = require "mp.msg"
local options = require "mp.options"

local config = {
    enabled = true,
    mappings = "",
    fallback_device = "",
    restore_device = "auto",
}

options.read_options(config, "auto_audio_device")

local auto_change = config.enabled

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function parse_mappings(value)
    local parsed = {}

    for entry in (value .. ";;"):gmatch("(.-);;") do
        entry = trim(entry)
        if entry ~= "" then
            local separator_start, separator_end = entry:find("=>", 1, true)
            if not separator_start then
                msg.warn("Ignoring invalid audio-device mapping (expected DISPLAY=>DEVICE): " .. entry)
            else
                local display = trim(entry:sub(1, separator_start - 1))
                local device = trim(entry:sub(separator_end + 1))
                if display == "" or device == "" then
                    msg.warn("Ignoring incomplete audio-device mapping: " .. entry)
                else
                    if parsed[display] then
                        msg.warn("Duplicate mapping for display '" .. display .. "'; using the last value")
                    end
                    parsed[display] = device
                end
            end
        end
    end

    return parsed
end


local device_map = parse_mappings(config.mappings)

local function configured_device(value)
    if type(value) ~= "string" then
        return nil
    end

    value = trim(value)
    if value == "" then
        return nil
    end

    return value
end

local function apply_audio_device(device)
    device = configured_device(device)
    if not device then
        return
    end

    local current_device = mp.get_property("audio-device", "auto")
    if device ~= current_device then
        msg.info("Audio device: " .. device)
        mp.osd_message("Audio device: " .. device)
        mp.set_property("audio-device", device)
    end
end

local function set_audio_device(observed_displays)
    if not auto_change then
        return
    end

    local displays = observed_displays
    if displays == nil then
        displays = mp.get_property_native("display-names")
    end

    -- An empty list is MPV's normal initial value before the VO is ready.
    if type(displays) ~= "table" or type(displays[1]) ~= "string" or displays[1] == "" then
        return
    end

    local display = displays[1]
    msg.verbose("Display: " .. display)

    -- Unmatched displays intentionally leave the current device untouched unless
    -- the user explicitly configures a fallback device.
    apply_audio_device(device_map[display] or config.fallback_device)
end

mp.observe_property("display-names", "native", function(_, value)
    set_audio_device(value)
end)

mp.add_key_binding("", "set-audio-device", function()
    set_audio_device(nil)
end)

mp.add_key_binding("", "toggle-switching", function()
    auto_change = not auto_change

    if auto_change then
        set_audio_device(nil)
    else
        apply_audio_device(config.restore_device)
    end

    mp.osd_message("Audio device switching: " .. (auto_change and "enabled" or "disabled"))
end)
