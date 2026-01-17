-- [[ 
--    FILENAME: anime_profile_controller.lua
--    VERSION:  v1.7 (UOSC Integration)
--    UPDATED:  2026-01-15
-- ]]

local mp = require("mp")
local utils = require("mp.utils")

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

-- Live Action States
local sd_mode = "clean"          
local sd_manual_override = false 
local hd_manual_override = false 

-- Anime4K (persistent)
local anime4k_quality = "fast"
local anime4k_mode = "A"

-------------------------------------------------
-- COLORS (BGR Hex)
-------------------------------------------------
local C = {
    YELLOW  = "{\\c&H00FFFF&}",
    WHITE   = "{\\c&HFFFFFF&}",
    GREEN   = "{\\c&H00FF00&}", 
    BLUE    = "{\\c&HFF0000&}", 
    RED     = "{\\c&H0000FF&}", 
    CYAN    = "{\\c&HFFFF00&}", 
    GOLD    = "{\\c&H00D7FF&}", 
    ORANGE  = "{\\c&H0080FF&}", 
    MAGENTA = "{\\c&HFF00FF&}", 
}

-------------------------------------------------
-- OSD OVERLAY SYSTEM
-------------------------------------------------
local osd_overlay = mp.create_osd_overlay("ass-events")
local osd_timer = nil

local function hide_osd()
    osd_overlay:remove()
end

local function show_temp_osd(text, duration)
    duration = duration or 2
    osd_overlay.data = "{\\an7}{\\fs26}{\\q1}" .. text
    osd_overlay:update()
    if osd_timer then osd_timer:kill() end
    osd_timer = mp.add_timeout(duration, hide_osd)
end

-------------------------------------------------
-- PROFILE MESSAGE
-------------------------------------------------
local function profile_message()
    local mode_color = C.GREEN 
    if anime_mode == "on" then mode_color = C.BLUE
    elseif anime_mode == "off" then mode_color = C.RED end
    
    local part1 = C.YELLOW .. "{\\b1}Anime Mode:{\\b0} " .. C.WHITE .. mode_color .. anime_mode:upper()
    local sep = C.WHITE .. " | "
    local part2 = ""
    
    if current_profile == "anime-shaders" then
        local a4k_str = anime4k_quality:upper() .. " (" .. anime4k_mode .. ")"
        part2 = C.YELLOW .. "{\\b1}Anime4K:{\\b0} " .. C.WHITE .. C.MAGENTA .. a4k_str
    else
        local prof_color = C.WHITE
        if current_profile == "High-Quality" or current_profile == "HQ-SD-FSRCNNX" then prof_color = C.CYAN
        elseif current_profile and current_profile:find("HQ%-HD") then prof_color = C.GOLD
        elseif current_profile and current_profile:find("HQ%-SD") then prof_color = C.ORANGE
        elseif current_profile == "4K-Native" then prof_color = C.GREEN
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
    if f then f:write("anime_mode=" .. anime_mode .. "\n"); f:close() end
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
    return p:find("live action") or p:find("live%-action") or p:find("liveaction") or p:find("drama")
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
    local w = tonumber(mp.get_property("video-params/w")) or 0
    local h = tonumber(mp.get_property("video-params/h")) or 0

    if anime_mode == "on"
        or (anime_mode == "auto" and is_anime_folder(path) and not is_live_action(path)) then
        apply_profile("anime-shaders")
        apply_anime4k()
        return
    end

    mp.commandv("change-list", "glsl-shaders", "clear", "")

    if h < 496 or w < 960 then
        if sd_manual_override then
            apply_profile("HQ-SD-FSRCNNX")
        else
            apply_profile(sd_mode == "texture" and "HQ-SD-Texture" or "HQ-SD-Clean")
        end
        return
    end

    if w > 2560 or h > 1440 then
        apply_profile("4K-Native")
        return
    end

    if w > 1280 or h > 720 then
        apply_profile("High-Quality")
        return
    end

    if not hd_manual_override then
        apply_profile("HQ-HD-NNEDI")
    else
        apply_profile("High-Quality")
    end
end

-------------------------------------------------
-- AUDIO FUNCTIONS (FIXED: no-osd overlap)
-------------------------------------------------

-- 7.1 Upmix Logic
mp.register_script_message("toggle-audio-upmix", function()
    -- FIXED: Added 'no-osd' to silence standard message
    mp.command('no-osd cycle-values af "lavfi=[surround=chl_out=7.1:lfe_low=80]" ""')
    
    local af = mp.get_property("af")
    if af and string.find(af, "surround") then
        show_temp_osd(C.GREEN .. "7.1 Upmix: " .. C.WHITE .. "ON (Enhanced Bass)", 2)
    else
        show_temp_osd(C.RED .. "7.1 Upmix: " .. C.WHITE .. "OFF", 2)
    end
end)

-- Passthrough Logic
mp.register_script_message("toggle-audio-passthrough", function()
    -- FIXED: Added 'no-osd' to silence standard message
    mp.command('no-osd cycle-values audio-spdif "ac3,dts,eac3,truehd,dtshd" "no"')

    local spdif = mp.get_property("audio-spdif")
    if spdif == "no" then
        show_temp_osd(C.CYAN .. "Audio: " .. C.WHITE .. "PCM (Upmix Active)", 2)
    else
        show_temp_osd(C.GOLD .. "Audio: " .. C.WHITE .. "Bitstream (Passthrough)", 2)
    end
end)

-------------------------------------------------
-- UOSC MENU INTEGRATION
-------------------------------------------------
mp.add_key_binding(nil, "open-anime-menu", function()
    -- Check if content is HDR
    local is_hdr = false
    local prim = mp.get_property_native("video-params/primaries")
    if prim == "bt.2020" or prim == "apple" then is_hdr = true end

    -- Base Menu Items
    local items = {
		{ title = "====(Auto-Detection Modes)====", value = "ignore" },
        { title = "Auto Mode (Default)", value = "script-binding anime-mode-auto" },
        { title = "Force On (Anime4K)", value = "script-binding anime-mode-on" },
        { title = "Force Off (Native HQ)", value = "script-binding anime-mode-off" },
        { title = "Show Current Status", value = "script-binding show-profile-info" },        
        { title = "====(Quality Toggles)====", value = "ignore" },
        { title = "Toggle SD Mode (Texture/Clean)", value = "script-message toggle-hq-sd" },
        { title = "Toggle SD/HD Logic (NNEDI/FSR)", value = "script-message toggle-hq-hd-nnedi" },
        { title = "Toggle Anime4K Quality (Fast/HQ)", value = "script-binding toggle-anime4k-quality" },
        -- RTX VSR Integration
        { title = "RTX VSR: Toggle ON/OFF", value = "script-binding toggle-vsr" }
    }

    -- Audio Options Section
    table.insert(items, { title = "====(Audio)====", value = "ignore" })
    table.insert(items, { title = "Audio: Toggle 7.1 Upmix (Enhanced Bass)", value = "script-message toggle-audio-upmix" })
    table.insert(items, { title = "Audio: Toggle Passthrough / Bitstream", value = "script-message toggle-audio-passthrough" })

    -- HDR Integration
    if is_hdr then
        table.insert(items, { title = "====(HDR)====", value = "ignore" })
        table.insert(items, { title = "HDR: Force Tone-Mapping / Passthrough", value = "script-binding toggle-hdr-hybrid" })
    end

    -- Power Manager Integration
    table.insert(items, { title = "====(Power Mode)====", value = "ignore" })
    table.insert(items, { title = "Power: Toggle Low Power Mode", value = "script-binding toggle-power" })

    -- Send to UOSC
    local menu_json = utils.format_json({
        type = "menu",
        title = "Anime Build Options",
        items = items
    })
    mp.commandv("script-message-to", "uosc", "open-menu", menu_json)
end)

-------------------------------------------------
-- SCRIPT-BINDINGS (EXISTING)
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

mp.register_script_message("toggle-hq-sd", function()
    if current_profile == "HQ-SD-FSRCNNX" then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Switch to NNEDI first.", 2)
        return
    end
    if not current_profile or not string.find(current_profile, "HQ%-SD") then 
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Only for SD.", 2)
        return 
    end
    sd_mode = (sd_mode == "clean") and "texture" or "clean"
    evaluate()
    show_temp_osd(C.YELLOW .. "SD Mode: " .. C.ORANGE .. sd_mode:upper(), 2)
end)

mp.register_script_message("toggle-hq-hd-nnedi", function()
    local w = tonumber(mp.get_property("video-params/w")) or 0
    local h = tonumber(mp.get_property("video-params/h")) or 0

    if current_profile == "anime-shaders" then return end
    if w > 1280 or h > 720 then 
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "only for SD & HD.", 2)
        return 
    end

    local mode_name, mode_color = "", ""
    if h < 496 or w < 960 then
        sd_manual_override = not sd_manual_override
        evaluate()
        mode_name = sd_manual_override and "FSRCNNX (Sharp)" or "NNEDI3 (Clean/Texture)"
        mode_color = sd_manual_override and C.CYAN or C.ORANGE
    else 
        hd_manual_override = not hd_manual_override
        evaluate()
        mode_name = hd_manual_override and "FSRCNNX (High-Quality)" or "NNEDI3 (Geometry)"
        mode_color = hd_manual_override and C.CYAN or C.GOLD
    end
    show_temp_osd(C.YELLOW .. "Logic Switch: " .. mode_color .. mode_name, 2)
end)

mp.register_script_message("force-evaluate-profile", function()
    current_profile = "" 
    evaluate()
    show_temp_osd(profile_message(), 2)
end)

mp.register_event("file-loaded", function()
    load_anime_mode()
    load_anime4k()
    sd_mode = "clean"
    hd_manual_override = false
    sd_manual_override = false
    evaluate()
    show_temp_osd(profile_message(), 2)
end)