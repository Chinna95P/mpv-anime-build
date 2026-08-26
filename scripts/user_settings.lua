-- Persists settings changed through UOSC's Controls menu.
-- Existing user-*.conf files are loaded alphabetically; the last one is writable.

local mp = require("mp")
local msg = require("mp.msg")
local user_config_path = mp.command_native({"expand-path", "~~/script-modules/user_config.lua"})
local user_config = dofile(user_config_path)

local properties = {
    "interpolation",
    "deband", "deband-iterations", "deband-threshold", "deband-range", "deband-grain",
    "deinterlace",
    "audio-delay", "sub-delay", "sub-pos",
    "contrast", "brightness", "gamma", "saturation", "hue",
    "sub-font", "sub-ass-override", "sub-font-size", "sub-blur", "sub-gauss", "sub-spacing",
    "sub-scale-with-window", "stretch-image-subs-to-screen", "sub-use-margins",
    "blend-subtitles", "sub-fix-timing",
    "video-sync", "dither", "dither-depth", "hwdec", "gpu-api", "gpu-context",
    "vulkan-async-compute", "vulkan-queue-count", "vulkan-async-transfer",
    "scale", "dscale", "cscale", "tscale",
    "linear-upscaling", "sigmoid-upscaling", "correct-downscaling", "linear-downscaling",
}

local property_set = {}
for _, property in ipairs(properties) do property_set[property] = true end

local apply_timer = nil

local function apply_saved_settings()
    apply_timer = nil
    local settings = user_config.read()
    for key, value in pairs(settings) do
        if property_set[key] and mp.get_property(key) ~= value then
            mp.set_property(key, value)
        end
    end
end

local function schedule_apply_saved_settings()
    if apply_timer then apply_timer:kill() end
    apply_timer = mp.add_timeout(0, apply_saved_settings)
end

local function changed_properties(command)
    local changed, ordered = {}, {}
    for segment in (command or ""):gmatch("[^;]+") do
        local property = segment:match("^%s*set%s+([%w_-]+)")
            or segment:match("^%s*add%s+([%w_-]+)")
            or segment:match("^%s*cycle%s+([%w_-]+)")
            or segment:match("^%s*osd%-msg%s+set%s+([%w_-]+)")
        if property and property_set[property] and not changed[property] then
            changed[property] = true
            table.insert(ordered, property)
        end
    end
    return ordered
end

local function persist_current_settings(command)
    local values = {}
    local changed = changed_properties(command)
    for _, property in ipairs(changed) do
        local value = mp.get_property(property)
        if value ~= nil then values[property] = value end
    end

    if next(values) == nil then return end

    local ok, result = user_config.update(values, changed)
    if not ok then msg.error("Could not save user settings: " .. tostring(result)) end
end

apply_saved_settings()

-- Native conditional profiles are reevaluated as video metadata appears.
-- Queue the user layer for the next event-loop turn so it remains last.
mp.observe_property("video-params", "native", schedule_apply_saved_settings)
mp.observe_property("current-tracks/video/image", "bool", schedule_apply_saved_settings)
mp.register_event("file-loaded", schedule_apply_saved_settings)

mp.register_script_message("persist-user-settings", persist_current_settings)
mp.register_script_message("reapply-user-settings", schedule_apply_saved_settings)
