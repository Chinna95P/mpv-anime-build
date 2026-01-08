local mp = require("mp")

-------------------------------------------------
-- CONFIG FILES
-------------------------------------------------
local anime_opts_path = mp.command_native({
    "expand-path", "~~/script-opts/anime-mode.conf"
})
local anime4k_opts_path = mp.command_native({
    "expand-path", "~~/script-opts/anime4k.conf"
})

-------------------------------------------------
-- STATE
-------------------------------------------------
local anime_mode = "auto"
local current_profile = ""

local sd_mode = "clean"
local hd_manual_override = false

-- Anime4K (persistent, anime-only)
local anime4k_quality = "fast"   -- fast | hq
local anime4k_mode = "A"         -- A B C AA BB CA

local clear_timer = nil

-------------------------------------------------
-- OSD (NON-PERSISTENT)
-------------------------------------------------
local function show_temp_osd(text, duration)
    duration = duration or 2
    mp.osd_message(text, duration)
    if clear_timer then clear_timer:kill() end
    clear_timer = mp.add_timeout(duration, function()
        mp.osd_message("", 0)
    end)
end

-------------------------------------------------
-- PROFILE MESSAGE
-------------------------------------------------
local function profile_message()
    if current_profile == "anime-shaders" then
        return "Anime: " .. anime_mode:upper()
            .. " | Anime4K: "
            .. anime4k_quality:upper()
            .. " (" .. anime4k_mode .. ")"
    end
    return "Anime: " .. anime_mode:upper() .. " | " .. current_profile
end

-------------------------------------------------
-- LOAD / SAVE
-------------------------------------------------
local function load_anime_mode()
    local f = io.open(anime_opts_path, "r")
    if not f then return end
    for l in f:lines() do
        local v = l:match("anime_mode=(%S+)")
        if v then anime_mode = v end
    end
    f:close()
end

local function save_anime_mode()
    local f = io.open(anime_opts_path, "w")
    if f then
        f:write("anime_mode=" .. anime_mode .. "\n")
        f:close()
    end
end

local function load_anime4k()
    local f = io.open(anime4k_opts_path, "r")
    if not f then return end
    for l in f:lines() do
        local q = l:match("quality=(%S+)")
        local m = l:match("mode=(%S+)")
        if q then anime4k_quality = q end
        if m then anime4k_mode = m end
    end
    f:close()
end

local function save_anime4k()
    local f = io.open(anime4k_opts_path, "w")
    if f then
        f:write("quality=" .. anime4k_quality .. "\n")
        f:write("mode=" .. anime4k_mode .. "\n")
        f:close()
    end
end

-------------------------------------------------
-- HELPERS
-------------------------------------------------
local function is_anime_folder(p)
    if not p then return false end
    p = p:lower()
    return p:find("/anime/") or p:find("\\anime\\")
end

local function is_live_action(p)
    if not p then return false end
    p = p:lower()
    return p:find("live action")
        or p:find("live%-action")
        or p:find("liveaction")
        or p:find("drama")
end

-------------------------------------------------
-- APPLY PROFILE
-------------------------------------------------
local function apply_profile(p)
    if p ~= current_profile then
        mp.commandv("apply-profile", p)
        current_profile = p
    end
end

-------------------------------------------------
-- ANIME4K SHADERS (UNCHANGED)
-------------------------------------------------
local A4K = {
    fast = {
        A="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_L.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl",
        B="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_L.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl",
        C="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_L.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl",
        AA="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_L.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl;~~/shaders/Anime4K_Restore_CNN_L.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl",
        BB="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_L.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_L.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl",
        CA="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_L.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_L.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_L.glsl",
    },
    hq = {
        A="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        B="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        C="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        AA="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_Restore_CNN_M.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        BB="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_M.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        CA="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_M.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
    }
}

local function apply_anime4k()
    if current_profile ~= "anime-shaders" then return end
    local chain = A4K[anime4k_quality][anime4k_mode]
    if not chain then return end
    mp.commandv("change-list", "glsl-shaders", "clear", "")
    mp.commandv("change-list", "glsl-shaders", "set", chain)
end

-------------------------------------------------
-- CORE LOGIC
-------------------------------------------------
local function evaluate()
    local path = mp.get_property("path")
    local h = tonumber(mp.get_property("height")) or 0

    if anime_mode == "on"
        or (anime_mode == "auto" and is_anime_folder(path) and not is_live_action(path)) then
        apply_profile("anime-shaders")
        apply_anime4k()
        return
    end

    -- leaving anime: clear Anime4K shaders
    mp.commandv("change-list", "glsl-shaders", "clear", "")

    if h > 0 and h < 720 then
        apply_profile(sd_mode == "texture" and "HQ-SD-Texture" or "HQ-SD-Clean")
        return
    end

    if not hd_manual_override and h >= 576 and h < 1080 then
        apply_profile("HQ-HD-NNEDI")
    else
        apply_profile("High-Quality")
    end
end

-------------------------------------------------
-- SCRIPT-BINDINGS (MATCH input.conf)
-------------------------------------------------
mp.add_key_binding(nil, "anime-mode-auto", function()
    anime_mode = "auto"
    save_anime_mode()
    evaluate()
    show_temp_osd(profile_message(), 2)
end)

mp.add_key_binding(nil, "anime-mode-on", function()
    anime_mode = "on"
    save_anime_mode()
    evaluate()
    show_temp_osd(profile_message(), 2)
end)

mp.add_key_binding(nil, "anime-mode-off", function()
    anime_mode = "off"
    save_anime_mode()
    evaluate()
    show_temp_osd(profile_message(), 2)
end)

mp.add_key_binding(nil, "toggle-anime4k-quality", function()
    if current_profile ~= "anime-shaders" then return end
    anime4k_quality = (anime4k_quality == "fast") and "hq" or "fast"
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
end)

mp.add_key_binding(nil, "show-profile-info", function()
    show_temp_osd(profile_message(), 2)
end)

-------------------------------------------------
-- SCRIPT MESSAGES (CTRL+1..6)
-------------------------------------------------
mp.register_script_message("anime4k-mode", function(mode)
    if current_profile ~= "anime-shaders" then return end
    if not A4K[anime4k_quality][mode] then return end
    anime4k_mode = mode
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
end)

-------------------------------------------------
-- FILE LOAD
-------------------------------------------------
-------------------------------------------------
-- MANUAL TOGGLES (MISSING HANDLERS)
-------------------------------------------------

-- CTRL+q: Toggle SD Mode (Clean <-> Texture)
mp.register_script_message("toggle-hq-sd", function()
    sd_mode = (sd_mode == "clean") and "texture" or "clean"
    evaluate()
    show_temp_osd("SD Mode: " .. sd_mode:upper(), 2)
end)

-- Q: Toggle HD Strategy (NNEDI <-> FSRCNNX/High-Quality)
mp.register_script_message("toggle-hq-hd-nnedi", function()
    hd_manual_override = not hd_manual_override
    evaluate()
    local mode = hd_manual_override and "FSRCNNX (High-Quality)" or "NNEDI3 (Geometry)"
    show_temp_osd("HD Logic: " .. mode, 2)
end)

-- W: Reset HD Override to Auto
mp.register_script_message("hq-hd-return-auto", function()
    hd_manual_override = false
    evaluate()
    show_temp_osd("HD Logic: Auto (Reset)", 2)
end)

mp.register_event("file-loaded", function()
    load_anime_mode()
    load_anime4k()
    sd_mode = "clean"
    hd_manual_override = false
    evaluate()
    show_temp_osd(profile_message(), 2)
end)
