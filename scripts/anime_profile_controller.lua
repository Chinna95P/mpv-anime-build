-- [[ 
--    FILENAME: anime_profile_controller.lua
--    VERSION:  v1.6 (Hyphen Pattern Fix)
--    UPDATED:  2026-01-08
--    
--    CHANGES:
--    - Fixed Lua pattern matching bug: 'HQ-HD' was failing because '-' is a special char.
--    - Changed: 'W' (Reset) OSD text color is now Green (was White).
--    - Verified: 'K' Status now correctly colors HQ-HD (Gold) and HQ-SD (Orange).
-- ]]

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

-------------------------------------------------
-- COLORS (BGR Hex)
-------------------------------------------------
-- BGR Format: &HBBGGRR&
local C = {
    YELLOW  = "{\\c&H00FFFF&}",
    WHITE   = "{\\c&HFFFFFF&}",
    GREEN   = "{\\c&H00FF00&}", -- Auto / Success
    BLUE    = "{\\c&HFF0000&}", -- On
    RED     = "{\\c&H0000FF&}", -- Off
    CYAN    = "{\\c&HFFFF00&}", -- High-Quality (Premium)
    GOLD    = "{\\c&H00D7FF&}", -- NNEDI (Mid-High)
    ORANGE  = "{\\c&H0080FF&}", -- SD (Standard)
    MAGENTA = "{\\c&HFF00FF&}"  -- Anime4K (Special)
}

-------------------------------------------------
-- OSD OVERLAY SYSTEM (Pro API)
-------------------------------------------------
local osd_overlay = mp.create_osd_overlay("ass-events")
local osd_timer = nil

local function hide_osd()
    osd_overlay:remove()
end

local function show_temp_osd(text, duration)
    duration = duration or 2
    
    -- {\an7} Top-Left, {\fs32} Font Size 32, {\q1} Outline Quality
    osd_overlay.data = "{\\an7}{\\fs32}{\\q1}" .. text
    osd_overlay:update()
    
    if osd_timer then osd_timer:kill() end
    osd_timer = mp.add_timeout(duration, hide_osd)
end

-------------------------------------------------
-- PROFILE MESSAGE (Status Info)
-------------------------------------------------
local function profile_message()
    -- 1. Anime Mode Section
    local mode_color = C.GREEN -- Default Auto
    if anime_mode == "on" then mode_color = C.BLUE
    elseif anime_mode == "off" then mode_color = C.RED end
    
    local part1 = C.YELLOW .. "{\\b1}Anime Mode:{\\b0} " .. C.WHITE .. mode_color .. anime_mode:upper()
    
    -- Separator
    local sep = C.WHITE .. " | "
    
    -- 2. Profile / Anime4K Section (COLORIZED)
    local part2 = ""
    
    if current_profile == "anime-shaders" then
        local a4k_str = anime4k_quality:upper() .. " (" .. anime4k_mode .. ")"
        part2 = C.YELLOW .. "{\\b1}Anime4K:{\\b0} " .. C.WHITE .. C.MAGENTA .. a4k_str
    else
        -- Logic to colorize the Live Action profile names
        -- FIX: Escaped hyphens (%-) so Lua finds the string correctly
        local prof_color = C.WHITE
        if current_profile == "High-Quality" then prof_color = C.CYAN
        elseif current_profile:find("HQ%-HD") then prof_color = C.GOLD
        elseif current_profile:find("HQ%-SD") then prof_color = C.ORANGE
        end
        
        part2 = C.YELLOW .. "{\\b1}Profile:{\\b0} " .. C.WHITE .. prof_color .. current_profile
    end
    
    return part1 .. sep .. part2
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
-- ANIME4K SHADERS
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
-- SCRIPT-BINDINGS
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

mp.register_script_message("anime4k-mode", function(mode)
    if current_profile ~= "anime-shaders" then return end
    if not A4K[anime4k_quality][mode] then return end
    anime4k_mode = mode
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
end)

-------------------------------------------------
-- MANUAL TOGGLES (NOW COLORED)
-------------------------------------------------

-- CTRL+q: Toggle SD Mode (Clean <-> Texture)
mp.register_script_message("toggle-hq-sd", function()
    sd_mode = (sd_mode == "clean") and "texture" or "clean"
    evaluate()
    show_temp_osd(C.YELLOW .. "{\\b1}SD Mode:{\\b0} " .. C.ORANGE .. sd_mode:upper(), 2)
end)

-- Q: Toggle HD Strategy (NNEDI <-> FSRCNNX/High-Quality)
mp.register_script_message("toggle-hq-hd-nnedi", function()
    hd_manual_override = not hd_manual_override
    evaluate()
    
    local mode_name = hd_manual_override and "FSRCNNX (High-Quality)" or "NNEDI3 (Geometry)"
    local mode_color = hd_manual_override and C.CYAN or C.GOLD
    
    show_temp_osd(C.YELLOW .. "{\\b1}HD Logic:{\\b0} " .. mode_color .. mode_name, 2)
end)

-- W: Reset HD Override to Auto
mp.register_script_message("hq-hd-return-auto", function()
    hd_manual_override = false
    evaluate()
    -- FIX: Changed C.WHITE to C.GREEN to make "Auto (Reset)" visible/positive
    show_temp_osd(C.YELLOW .. "{\\b1}HD Logic:{\\b0} " .. C.GREEN .. "Auto (Reset)", 2)
end)

mp.register_event("file-loaded", function()
    load_anime_mode()
    load_anime4k()
    sd_mode = "clean"
    hd_manual_override = false
    evaluate()
    show_temp_osd(profile_message(), 2)
end)