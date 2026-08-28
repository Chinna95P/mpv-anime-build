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

-- Power Saving owns the options declared by [Low-End] while it is active.
-- Read the profile so this follows future profile changes automatically.
local power_owned = {}
local low_end_found = false
for _, profile in ipairs(mp.get_property_native("profile-list") or {}) do
    if profile.name == "Low-End" then
        low_end_found = true
        for _, entry in ipairs(profile.options or {}) do
            power_owned[entry.key] = true
        end
        break
    end
end

-- Supported mpv versions expose profile-list, but retain the shipped overlap
-- as a safe fallback instead of silently allowing saved settings to undo Eco.
if not low_end_found then
    msg.warn("Could not inspect [Low-End]; using the built-in ownership fallback")
    for _, property in ipairs({
        "scale", "cscale", "dscale", "dither-depth",
        "correct-downscaling", "linear-downscaling", "sigmoid-upscaling",
    }) do
        power_owned[property] = true
    end
end

local function power_is_active()
    -- String reads of user-data are JSON-quoted; native reads are not.
    return mp.get_property_native("user-data/power_active") == "yes"
end

local function apply_saved_settings()
    apply_timer = nil
    local power_active = power_is_active()
    local settings = user_config.read()
    for key, value in pairs(settings) do
        if property_set[key] and not (power_active and power_owned[key])
                and mp.get_property(key) ~= value then
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

    -- The UOSC command has already changed the live property. Preserve the
    -- choice for later, but immediately restore Eco's owned values.
    if power_is_active() then
        for _, property in ipairs(changed) do
            if power_owned[property] then
                mp.commandv("script-message-to", "power_manager", "reassert-low-power")
                break
            end
        end
    end
end

apply_saved_settings()

-- Native conditional profiles are reevaluated as video metadata appears.
-- Queue the user layer for the next event-loop turn so it remains last.
mp.observe_property("video-params", "native", schedule_apply_saved_settings)
mp.observe_property("current-tracks/video/image", "bool", schedule_apply_saved_settings)
mp.register_event("file-loaded", schedule_apply_saved_settings)

mp.register_script_message("persist-user-settings", persist_current_settings)
mp.register_script_message("reapply-user-settings", schedule_apply_saved_settings)
