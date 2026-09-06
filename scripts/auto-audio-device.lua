local mp = require "mp"
local msg = require "mp.msg"
local options = require "mp.options"
local utils = require "mp.utils"

local config = {
    enabled = true,
    mappings = "",
    fallback_device = "",
    restore_device = "auto",
    log_display_name = true,
}

options.read_options(config, "auto_audio_device")

local auto_change = config.enabled

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function read_binary_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end

    local data = file:read("*a")
    file:close()
    return data
end

local function decode_edid_name(edid)
    if type(edid) ~= "string" or #edid < 128 then
        return nil
    end

    local expected_header = "\0\255\255\255\255\255\255\0"
    if edid:sub(1, 8) ~= expected_header then
        return nil
    end

    -- EDID base blocks contain four 18-byte descriptors starting at byte 54.
    -- A descriptor tagged 0xfc contains the display product name.
    for descriptor = 0, 3 do
        local start = 55 + (descriptor * 18)
        if edid:byte(start) == 0 and edid:byte(start + 1) == 0
            and edid:byte(start + 2) == 0 and edid:byte(start + 3) == 0xfc then
            local name = edid:sub(start + 5, start + 17)
                :gsub("%z", "")
                :gsub("[\r\n]", "")
                :gsub("[%c]", "")
            name = trim(name)
            if name ~= "" then
                return name
            end
        end
    end

    -- Some displays omit the product-name descriptor. Fall back to the EDID
    -- manufacturer code and numeric product code in that case.
    local manufacturer_word = (edid:byte(9) * 256) + edid:byte(10)
    local manufacturer = string.char(
        math.floor(manufacturer_word / 1024) % 32 + 64,
        math.floor(manufacturer_word / 32) % 32 + 64,
        manufacturer_word % 32 + 64
    )
    if manufacturer:match("^[A-Z][A-Z][A-Z]$") then
        local product_code = edid:byte(11) + (edid:byte(12) * 256)
        return string.format("%s %04X", manufacturer, product_code)
    end

    return nil
end

local display_name_cache = {}

local function linux_display_name(connector)
    if display_name_cache[connector] ~= nil then
        return display_name_cache[connector] or nil
    end

    local entries = utils.readdir("/sys/class/drm", "all")
    if type(entries) ~= "table" then
        display_name_cache[connector] = false
        return nil
    end

    table.sort(entries)
    local suffix = "-" .. connector
    for _, entry in ipairs(entries) do
        if #entry > #suffix and entry:sub(-#suffix) == suffix then
            local edid = read_binary_file("/sys/class/drm/" .. entry .. "/edid")
            local name = decode_edid_name(edid)
            if name then
                display_name_cache[connector] = name
                return name
            end
        end
    end

    display_name_cache[connector] = false
    return nil
end

local function readable_display_name(connector)
    -- Linux exposes monitor EDID through DRM sysfs. MPV already reports product
    -- names on macOS; Windows safely retains its native GDI display identifier.
    if package.config:sub(1, 1) == "/" then
        return linux_display_name(connector)
    end

    return nil
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
    local product_name = readable_display_name(display)
    local display_description = display
    if product_name and product_name ~= display then
        display_description = display .. " (" .. product_name .. ")"
    end

    if config.log_display_name then
        msg.info("Display: " .. display_description)
    else
        msg.verbose("Display: " .. display_description)
    end

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
