-- [[ 
--    FILENAME: anime_profile_controller.lua
--    VERSION:  v1.9 (Fidelity Mode Added)
--    UPDATED:  2026-01-20
-- ]]

local mp = require("mp")
local utils = require("mp.utils")
local BUILD_VERSION = "v1.9.1"

-------------------------------------------------
-- CONFIG FILES
-------------------------------------------------
local anime_opts_path = mp.command_native({
    "expand-path", "~~/script-opts/anime-mode.conf"
})
local anime4k_opts_path = mp.command_native({
    "expand-path", "~~/script-opts/anime4k.conf"
})

local hdr_opts_path = mp.command_native({
    "expand-path", "~~/script-opts/hdr-mode.conf"
})
local user_hdr_mode = nil -- Holds the saved setting

-------------------------------------------------
-- STATE
-------------------------------------------------
local anime_mode = "auto"
local current_profile = ""
local shaders_master_switch = true

-- Anime Fidelity State (New v1.9)
local anime_fidelity = true -- [CHANGED] Default is now True

local zoom_mode = "fit" -- [NEW]

-- Live Action States
local sd_mode = "clean"          
local sd_manual_override = false 
local hd_manual_override = false 

-- External States (Synced via Broadcast)
local external_vsr_active = false
local external_power_active = false

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

local function sync_state()
    -- 1. Determine active context
    local is_anime_active = (current_profile == "anime-shaders")
    
    -- 2. Define the state table
    local state = {
        shaders_enabled = shaders_master_switch,
        anime4k_hq = (anime4k_quality == "hq"),
        
        -- Fidelity State
        anime_fidelity = anime_fidelity,
        
		-- [NEW] Zoom State
        zoom_mode = zoom_mode,
		
        -- [NEW] Send Context flag for Menu Locking
        is_anime_context = is_anime_active,
        
        -- Live Action Logic
        sd_texture = (sd_mode == "texture"),
        logic_fsrcnnx = (sd_manual_override or hd_manual_override),
        
        mode_auto = (anime_mode == "auto"),
        mode_on = (anime_mode == "on"),
        mode_off = (anime_mode == "off"),
        
        -- Broadcast Anime4K Modes
        a4k_mode_a  = (anime4k_mode == "A"),
        a4k_mode_b  = (anime4k_mode == "B"),
        a4k_mode_c  = (anime4k_mode == "C"),
        a4k_mode_aa = (anime4k_mode == "AA"),
        a4k_mode_bb = (anime4k_mode == "BB"),
        a4k_mode_ca = (anime4k_mode == "CA"),
        
        -- [LOGIC] Grey out Anime4K if: Not in Anime Mode OR Fidelity is ON
        anime4k_allowed = (is_anime_active and not anime_fidelity), 
        
        audio_upmix = (string.find(mp.get_property("af") or "", "surround") ~= nil),
		-- [NEW] Detect Night Mode (DynAudNorm)
        night_mode = (string.find(mp.get_property("af") or "", "dynaudnorm") ~= nil),
		
        audio_passthrough = (function()
            local s = mp.get_property("audio-spdif")
            return (s ~= "no" and s ~= "" and s ~= nil)
        end)(),
        
        hdr_passthrough = (mp.get_property("target-colorspace-hint") == "yes"),
        
        vsr_active = external_vsr_active,
        power_active = external_power_active
    }

    -- 3. Broadcast to UOSC
    local json = utils.format_json(state)
    mp.commandv("script-message", "anime-state-broadcast", json)
    
    mp.set_property("user-data/anime_shaders_enabled", state.shaders_enabled and "yes" or "no")
end

-------------------------------------------------
-- RESOLUTION LOGIC (NEW ROBUST DETECTOR)
-------------------------------------------------
local function get_resolution_mode()
    local w = tonumber(mp.get_property("video-params/w")) or 0
    local h = tonumber(mp.get_property("video-params/h")) or 0
    local fn = mp.get_property("filename", ""):lower()
    
    -- 1. SD Logic
    if h < 496 or w < 960 then 
        return "SD" 
    end

    -- 2. HD (720p) Logic: Filename OR Resolution range
    if fn:find("720p") or fn:find("1280x720") 
    or (h >= 540 and h <= 720) 
    or (w >= 960 and w <= 1280) then 
        return "HD" 
    end

    -- 3. FullHD (1080p) Logic
    if fn:find("1080p") or fn:find("1920x1080") 
    or (h > 720 and h <= 1080) 
    or (w > 1280 and w <= 1920) then 
        return "FHD" 
    end

    -- 4. 2K/1440p (Logic Maintenance for Anime)
    if h < 1450 then 
        return "2K" 
    end

    -- 5. 4K/UHD
    return "4K"
end

-------------------------------------------------
-- PROFILE MESSAGE
-------------------------------------------------
local function profile_message()
    if not shaders_master_switch then
        return C.RED .. "{\\b1}Shaders:{\\b0} " .. C.WHITE .. "Disabled (Master Switch OFF)"
    end

    local mode_color = C.GREEN 
    if anime_mode == "on" then mode_color = C.BLUE
    elseif anime_mode == "off" then mode_color = C.RED end
    
    local part1 = C.YELLOW .. "{\\b1}Anime Mode:{\\b0} " .. C.WHITE .. mode_color .. anime_mode:upper()
    local sep = C.WHITE .. " | "
    local part2 = ""
    
    if current_profile == "anime-shaders" then
        if anime_fidelity then
            -- Determine resolution for OSD using new logic
            local res = get_resolution_mode()
            local res_label = "FSRCNNX"
            
            if res == "SD" then res_label = "FSRCNNX (SD)"
            elseif res == "HD" then res_label = "FSRCNNX (720p)"
            elseif res == "FHD" or res == "2K" then res_label = "FSRCNNX (1080p/2K)"
            else res_label = "Sharpen (4K)" end
            
            part2 = C.YELLOW .. "{\\b1}Fidelity:{\\b0} " .. C.CYAN .. res_label
        else
            local a4k_str = anime4k_quality:upper() .. " (" .. anime4k_mode .. ")"
            part2 = C.YELLOW .. "{\\b1}Anime4K:{\\b0} " .. C.WHITE .. C.MAGENTA .. a4k_str
        end
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

-- Add this new variable
local user_target_peak = "auto" 

-- Update load_hdr_mode() to read the new value
local function load_hdr_mode()
    local f = io.open(hdr_opts_path, "r")
    if not f then return end
    for l in f:lines() do
        local v = l:match("tone_mapping=(%S+)")
        if v then user_hdr_mode = v end
        
        -- [NEW] Read Target Peak
        local p = l:match("target_peak=(%S+)")
        if p then user_target_peak = p end
    end
    f:close()
end

-- Update save_hdr_mode() to write the new value
local function save_hdr_mode()
    local f = io.open(hdr_opts_path, "w")
    if f then
        f:write("tone_mapping=" .. (user_hdr_mode or "bt.2390") .. "\n")
        f:write("target_peak=" .. (user_target_peak or "auto") .. "\n")
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

mp.register_script_message("anime-state-broadcast", function(json)
    local data = utils.parse_json(json)
    if not data then return end
    if data.vsr_active ~= nil then external_vsr_active = data.vsr_active end
    if data.power_active ~= nil then external_power_active = data.power_active end
end)

local function apply_profile(p)
    if p ~= current_profile then
        mp.commandv("apply-profile", p)
        current_profile = p
    end
end

-------------------------------------------------
-- SHADERS (DEFINITIONS)
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

-------------------------------------------------
-- ANIME4K APPLIER
-------------------------------------------------
local function apply_anime4k()
    -- Safety check: Only run if we are actually in the anime profile
    if current_profile ~= "anime-shaders" then return end
    
    -- Safety check: Ensure the mode exists in the A4K table
    if not A4K[anime4k_quality] or not A4K[anime4k_quality][anime4k_mode] then
        mp.msg.warn("Anime4K Profile not found: " .. anime4k_quality .. " / " .. anime4k_mode)
        return
    end

    local chain = A4K[anime4k_quality][anime4k_mode]
    mp.commandv("change-list", "glsl-shaders", "set", chain)
end

-------------------------------------------------
-- SHADERS (DEFINITIONS)
-------------------------------------------------
-- [UPDATED] Anime Fidelity (FSRCNNX) Shader Chains
local FSRCNNX = {
    -- SD Restoration (16-layer + Krig + Punchy Sharpen)
    SD = "~~/shaders/FSRCNNX_x2_16-0-4-1_anime_enhance.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/adaptive-sharpen-anime-SD.glsl",
    
    -- 720p Line Art (8-layer + Krig + Moderate Sharpen)
    HD_720 = "~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/adaptive-sharpen-anime-720p.glsl",
    
    -- 1080p Line Art (8-layer + Krig + Subtle Sharpen)
    HD_1080 = "~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/adaptive-sharpen-anime-1080p.glsl",

    -- 4K Native (No Upscale needed, just Sharpen)
    UHD = "~~/shaders/adaptive-sharpen-anime-4K.glsl"
}

-------------------------------------------------
-- SHADER APPLIERS
-------------------------------------------------
local function apply_fsrcnnx()
    if current_profile ~= "anime-shaders" then return end
    
    local res = get_resolution_mode()
    local chain = ""
    
    -- LOGIC TREE FOR ANIME FIDELITY
    if res == "SD" then
        chain = FSRCNNX.SD
    
    elseif res == "HD" then
        chain = FSRCNNX.HD_720
        
    elseif res == "FHD" or res == "2K" then
        -- 1080p & 1440p use the same "Line Art" Logic
        chain = FSRCNNX.HD_1080
        
    else
        -- 4K Content
        chain = FSRCNNX.UHD
    end
    
    mp.commandv("change-list", "glsl-shaders", "clear", "")
    mp.commandv("change-list", "glsl-shaders", "set", chain)
end

-------------------------------------------------
-- CORE EVALUATION LOGIC
-------------------------------------------------
local function evaluate()
    if not shaders_master_switch then return end

    local path = mp.get_property("path")
    local res = get_resolution_mode()

    -- 1. Anime Logic (Anime4K OR FSRCNNX)
    if anime_mode == "on"
        or (anime_mode == "auto" and is_anime_folder(path) and not is_live_action(path)) then
        
        apply_profile("anime-shaders")
        
        if anime_fidelity then
            apply_fsrcnnx()
        else
            apply_anime4k()
        end
        return
    end

    -- 2. Live Action Logic (Native Profiles)
    mp.commandv("change-list", "glsl-shaders", "clear", "")

    if res == "SD" then
        if sd_manual_override then
            apply_profile("HQ-SD-FSRCNNX")
        else
            apply_profile(sd_mode == "texture" and "HQ-SD-Texture" or "HQ-SD-Clean")
        end
        return
    end

    if res == "4K" then
        apply_profile("4K-Native")
        return
    end

    if res == "2K" or res == "FHD" then
        -- 1080p and 1440p use the same HQ profile
         apply_profile("High-Quality")
         return
    end

    -- HD (720p) Logic
    if not hd_manual_override then
        apply_profile("HQ-HD-NNEDI")
    else
        apply_profile("HQ-HD-FSRCNNX")
    end
end

-------------------------------------------------
-- EXTERNAL TOGGLES
-------------------------------------------------
mp.register_script_message("toggle-anime-fidelity", function()
    if not shaders_master_switch then show_temp_osd(profile_message(), 2) return end
    
    -- Lock: Only works if Anime Mode is active
    if current_profile ~= "anime-shaders" then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Anime Mode Required.", 2)
        return
    end
    
    anime_fidelity = not anime_fidelity
    evaluate() -- Re-run logic to switch shaders
    
    local status = anime_fidelity and (C.CYAN .. "FSRCNNX (Fidelity)") or (C.MAGENTA .. "Anime4K (Performance)")
    show_temp_osd(C.YELLOW .. "Anime Shader: " .. status, 2)
    sync_state()
end)

mp.register_script_message("toggle-audio-upmix", function()
    mp.command('no-osd cycle-values af "lavfi=[surround=chl_out=7.1:lfe_low=80]" ""')
    local af = mp.get_property("af")
    if af and string.find(af, "surround") then
        show_temp_osd(C.GREEN .. "7.1 Upmix: " .. C.WHITE .. "ON (Enhanced Bass)", 2)
    else
        show_temp_osd(C.RED .. "7.1 Upmix: " .. C.WHITE .. "OFF", 2)
    end
    sync_state()
end)

mp.register_script_message("toggle-audio-passthrough", function()
    mp.command('no-osd cycle-values audio-spdif "ac3,dts,eac3,truehd,dtshd" "no"')
    local spdif = mp.get_property("audio-spdif")
    if spdif == "no" or spdif == "" then
        show_temp_osd(C.CYAN .. "Audio: " .. C.WHITE .. "PCM (Upmix Active)", 2)
    else
        show_temp_osd(C.GOLD .. "Audio: " .. C.WHITE .. "Bitstream (Passthrough)", 2)
    end
    sync_state()
end)

mp.register_script_message("toggle-audio-nightmode", function()
    -- We use 'af toggle' with a label (@nightmode) so it doesn't wipe other filters like Upmix
    -- f=75:g=25:n=0:p=0.9 are standard values for natural sounding compression
    mp.command("no-osd af toggle @nightmode:lavfi=[dynaudnorm=f=75:g=25:n=0:p=0.9]")
    
    -- We delay the OSD slightly to allow the property to update
    mp.add_timeout(0.1, function()
        local af = mp.get_property("af") or ""
        if string.find(af, "dynaudnorm") then
            show_temp_osd(C.GREEN .. "Night Mode: " .. C.WHITE .. "ON (Dynamic Volume)", 2)
        else
            show_temp_osd(C.RED .. "Night Mode: " .. C.WHITE .. "OFF", 2)
        end
        sync_state()
    end)
end)

mp.register_script_message("toggle-global-shaders", function()
    shaders_master_switch = not shaders_master_switch
    if not shaders_master_switch then
        mp.set_property("glsl-shaders", "") 
        current_profile = ""
        show_temp_osd(C.RED .. "Shaders: " .. C.WHITE .. "Disabled", 2)
    else
        evaluate()
        show_temp_osd(C.GREEN .. "Shaders: " .. C.WHITE .. "Enabled", 2)
    end
    sync_state()
end)

mp.observe_property("af", "string", sync_state)
mp.observe_property("audio-spdif", "string", sync_state)
mp.observe_property("target-colorspace-hint", "string", sync_state)

-------------------------------------------------
-- UOSC MENU INTEGRATION
-------------------------------------------------
mp.add_key_binding(nil, "open-anime-menu", function()
    -- 1. Gather Local State
    local s_on = shaders_master_switch
    local s_auto = (anime_mode == "auto")
    local s_force = (anime_mode == "on")
    local s_off = (anime_mode == "off")
    
    local s_sd_tex = (sd_mode == "texture")
    local s_logic_fsr = (sd_manual_override or hd_manual_override)
    local s_a4k_hq = (anime4k_quality == "hq")
    
    local s_fidelity = anime_fidelity
    -- [LOGIC] Grey out Anime4K if Fidelity is Active OR Not in Anime Mode
    local s_anime4k_allowed = (current_profile == "anime-shaders" and not anime_fidelity)

    -- Anime4K Modes
    local s_m_a = (anime4k_mode == "A")
    local s_m_b = (anime4k_mode == "B")
    local s_m_c = (anime4k_mode == "C")
    local s_m_aa = (anime4k_mode == "AA")
    local s_m_bb = (anime4k_mode == "BB")
    local s_m_ca = (anime4k_mode == "CA")
    
    local af = mp.get_property("af") or ""
    local s_upmix = string.find(af, "surround")
	local s_night_mode = (string.find(af, "dynaudnorm") ~= nil)
    local spdif = mp.get_property("audio-spdif") or "no"
    local s_pass = (spdif ~= "no" and spdif ~= "") 
    local s_hdr_active = (mp.get_property("target-colorspace-hint") == "yes")
    
    local s_vsr = external_vsr_active
    local s_power = external_power_active
	
						-- =============================================================================
					-- LOGIC: HDR TONE-MAPPING MENU (With Memory)
					-- =============================================================================

					-- 1. DETECT STATUS
					local primaries = mp.get_property("video-params/primaries")
					local hdr_passthrough = mp.get_property("target-colorspace-hint") == "yes"
					local is_hdr = (primaries == "bt.2020" or primaries == "dci-p3")

					-- 2. DETERMINE IF LOCKED
					local tm_locked = not (is_hdr and not hdr_passthrough)
					local tm_status_hint = ""

					if not is_hdr then
						tm_status_hint = " (Locked: SDR Content)"
					elseif hdr_passthrough then
						tm_status_hint = " (Locked: Passthrough Active)"
					else
						tm_status_hint = " (Active)"
					end

					-- 3. GET CURRENT ALGORITHM
					local current_tm = mp.get_property("tone-mapping") or "hable"

-- 4. BUILD THE SUBMENU
    local tm_menu = {
        type = "submenu",
        title = "Tone-Mapping Mode" .. tm_status_hint,
        icon = "brightness_medium",
        active = not tm_locked,
        items = {
            -- Standard Curves
            { 
                title = "BT.2390 (Recommended)", 
                active = (current_tm == "bt.2390"), 
                value = "script-message save-tone-mapping bt.2390" 
            },
            { 
                title = "ST.2094-40 (Active)", 
                active = (current_tm == "st2094-40"), 
                value = "script-message save-tone-mapping st2094-40" 
            },
            { 
                title = "BT.2446a (Static)", 
                active = (current_tm == "bt.2446a"), 
                value = "script-message save-tone-mapping bt.2446a" 
            },
            { 
                title = "Spline (Neutral)", 
                active = (current_tm == "spline"), 
                value = "script-message save-tone-mapping spline" 
            },
            
            -- Legacy / Artistic Curves
            { 
                title = "Hable", 
                active = (current_tm == "hable"), 
                value = "script-message save-tone-mapping hable" 
            },
            { 
                title = "Mobius", 
                active = (current_tm == "mobius"), 
                value = "script-message save-tone-mapping mobius" 
            },
            { 
                title = "Reinhard", 
                active = (current_tm == "reinhard"), 
                value = "script-message save-tone-mapping reinhard" 
            },
            
            -- Utility
            { 
                title = "Clip (Hard Cut)", 
                active = (current_tm == "clip"), 
                value = "script-message save-tone-mapping clip" 
            }
        }
    }


    -- 2. Build Menu
    local items = {
        {
            title = "Anime Mode: " .. (s_force and "ON" or (s_off and "OFF" or "AUTO")),
            icon = 'tv',
            items = {
                { title = "====(Auto-Detection Modes)====", value = "ignore", bold = true },
                { title = "Mode: Auto (Default)", value = "script-binding anime-mode-auto", active = s_auto },
                { title = "Mode: Force On (Anime4K)", value = "script-binding anime-mode-on", active = s_force },
                { title = "Mode: Force Off (Native HQ)", value = "script-binding anime-mode-off", active = s_off },
                { title = "Show Status Info", value = "script-binding show-profile-info", icon = 'info' },
            }
        },
        {
            title = "Anime4K Profiles",
            icon = 'palette',
            muted = not s_anime4k_allowed,
            hint = not s_anime4k_allowed and "Disabled (Fidelity ON)" or "",
            items = {
                { title = "Mode A (Blur+Noise)", value = "script-message anime4k-mode A", active = s_m_a },
                { title = "Mode B (Blur Only)",  value = "script-message anime4k-mode B", active = s_m_b },
                { title = "Mode C (Noise Only)", value = "script-message anime4k-mode C", active = s_m_c },
                { title = "Mode A+A (High Fid.)",value = "script-message anime4k-mode AA", active = s_m_aa },
                { title = "Mode B+B (Sharpness)",value = "script-message anime4k-mode BB", active = s_m_bb },
                { title = "Mode C+A (Restore)",  value = "script-message anime4k-mode CA", active = s_m_ca },
            }
        },
        {
            title = "Fidelity & Restoration",
            icon = 'brush',
            items = {
				{ title = "====(Display Tools)====", value = "ignore", bold = true },
                -- [NEW] UltraWide Zoom Sub-Menu
                {
                    title = "UltraWide Zoom",
                    icon = 'aspect_ratio',
                    items = {
                        { title = "1. Fit-to-Zoom (Original)", value = "script-message zoom-mode-fit", active = (zoom_mode == "fit") },
                        { title = "2. Fill-to-Zoom (Force)",   value = "script-message zoom-mode-fill", active = (zoom_mode == "fill") },
                        { title = "3. Crop-to-Zoom (Smart)",   value = "script-message zoom-mode-crop", active = (zoom_mode == "crop") },
                    }
                },
				{ title = "====(Quality Toggles)====", value = "ignore", bold = true },
                { title = "Shaders: Toggle ON/OFF", value = "script-message toggle-global-shaders", active = s_on },
                { title = "SD Upscaler: " .. (s_sd_tex and "Texture" or "Clean"), value = "script-message toggle-hq-sd", active = s_sd_tex },
                { title = "HD Upscaler: " .. (s_logic_fsr and "FSRCNNX" or "NNEDI3"), value = "script-message toggle-hq-hd-nnedi", active = s_logic_fsr },
                -- Grey out Anime4K Quality toggle too
				{ title = "====(Anime Options)====", value = "ignore", bold = true },
                -- [NEW] Fidelity Toggle
                { title = "Anime Fidelity: " .. (s_fidelity and "FSRCNNX" or "Anime4K"), value = "script-message toggle-anime-fidelity", active = s_fidelity },
				{ title = "Anime4K Quality: " .. (s_a4k_hq and "HQ" or "Fast"), value = "script-binding toggle-anime4k-quality", active = s_a4k_hq, muted = not s_anime4k_allowed },
                
            }
        },
        {
            title = "Hardware & Power",
            icon = 'memory',
            items = {
                { title = "Power Mode: " .. (s_power and "Eco" or "Perf"), value = "script-binding toggle-power", active = s_power },
                { title = "RTX VSR: " .. (s_vsr and "ON" or "OFF"), value = "script-binding toggle-vsr", active = s_vsr },
            }
        },
        {
            title = "Audio & HDR",
            icon = 'volume_up',
            items = {
				-- [NEW] Night Mode Button
                { title = "Audio: Night Mode (DRC)", value = "script-message toggle-audio-nightmode", active = s_night_mode },
                { title = "Audio: Toggle 7.1 Upmix", value = "script-message toggle-audio-upmix", active = s_upmix },
                { title = "Audio: Toggle Passthrough", value = "script-message toggle-audio-passthrough", active = s_pass },
                { title = "HDR: Force Tone-Map/Passthrough", value = "script-binding toggle-hdr-hybrid", active = s_hdr_active },
				
				tm_menu,
				
				-- [NEW] Target Peak Sub-Menu
            {
                title = "Target Peak (Brightness)",
                icon = "wb_sunny",
                items = (function()
                    -- Helper to detect if current peak is standard
                    local p = user_target_peak
                    local is_std = (p=="auto" or p=="100" or p=="200" or p=="300" or p=="400" or p=="600" or p=="1000")
                    
                    return {
                       { title = "Auto (Default)", value = "script-message save-target-peak auto", active = (p == "auto") },
                       { title = "100 nits (Dim Monitor)", value = "script-message save-target-peak 100", active = (p == "100") },
                       { title = "200 nits (Standard)", value = "script-message save-target-peak 200", active = (p == "200") },
                       { title = "300 nits (Bright LCD)", value = "script-message save-target-peak 300", active = (p == "300") },
                       { title = "400 nits (HDR400)", value = "script-message save-target-peak 400", active = (p == "400") },
                       { title = "600 nits (HDR600)", value = "script-message save-target-peak 600", active = (p == "600") },
                       { title = "1000 nits (High-End)", value = "script-message save-target-peak 1000", active = (p == "1000") },
                       
                    }
                end)()
            },
				
            }
        },
		{
            title = "System",
            icon = 'build',
            items = {
                        { title = "Check for Updates", value = "script-message check-for-updates", icon = 'update' },
                        -- [UPDATED] Replaced Version Info with Stats Overlay
                        { title = "Show Statistics", value = "script-binding toggle-stats", icon = 'info' },
                    }
        },
        { title = "Advanced Controls...", icon = 'tune', value = "script-binding uosc/open-menu-controls", bold = true, active = true },
    }

    local menu_json = utils.format_json({
        type = "menu",
        title = "Anime Build Options",
        items = items
    })
    mp.commandv("script-message-to", "uosc", "open-menu", menu_json)
end)

-------------------------------------------------
-- SCRIPT-BINDINGS
-------------------------------------------------
mp.add_key_binding(nil, "anime-mode-auto", function()
    anime_mode = "auto"
    save_anime_mode()
    evaluate()
    show_temp_osd(profile_message(), 2)
    sync_state()
end)

mp.add_key_binding(nil, "anime-mode-on", function()
    anime_mode = "on"
    save_anime_mode()
    evaluate()
    show_temp_osd(profile_message(), 2)
    sync_state()
end)

mp.add_key_binding(nil, "anime-mode-off", function()
    anime_mode = "off"
    save_anime_mode()
    evaluate()
    show_temp_osd(profile_message(), 2)
    sync_state()
end)

mp.add_key_binding(nil, "toggle-anime4k-quality", function()
    if current_profile ~= "anime-shaders" then return end
    if anime_fidelity then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Disable Fidelity Mode first.", 2)
        return
    end
    anime4k_quality = (anime4k_quality == "fast") and "hq" or "fast"
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
    sync_state()
end)

mp.add_key_binding(nil, "show-profile-info", function()
    show_temp_osd(profile_message(), 2)
end)

mp.register_script_message("anime4k-mode", function(mode)
    if current_profile ~= "anime-shaders" then return end
    if anime_fidelity then return end -- Double protection
    if not A4K[anime4k_quality][mode] then return end
    anime4k_mode = mode
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
    sync_state()
end)

mp.register_script_message("toggle-hq-sd", function()
    if not shaders_master_switch then show_temp_osd(profile_message(), 2) return end
    
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
    sync_state()
end)

mp.register_script_message("toggle-hq-hd-nnedi", function()
    if not shaders_master_switch then show_temp_osd(profile_message(), 2) return end
    
    local res = get_resolution_mode()

    if current_profile == "anime-shaders" then return end
    if res == "FHD" or res == "2K" or res == "4K" then 
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "only for SD & HD.", 2)
        return 
    end

    local mode_name, mode_color = "", ""
    if res == "SD" then
        sd_manual_override = not sd_manual_override
        evaluate()
        mode_name = sd_manual_override and "FSRCNNX (Sharp)" or "NNEDI3 (Clean/Texture)"
        mode_color = sd_manual_override and C.CYAN or C.ORANGE
    else 
        -- Assume HD
        hd_manual_override = not hd_manual_override
        evaluate()
        mode_name = hd_manual_override and "FSRCNNX (High-Quality)" or "NNEDI3 (Geometry)"
        mode_color = hd_manual_override and C.CYAN or C.GOLD
    end
    show_temp_osd(C.YELLOW .. "Logic Switch: " .. mode_color .. mode_name, 2)
    sync_state()
end)

mp.register_script_message("force-evaluate-profile", function()
    current_profile = "" 
    evaluate()
    show_temp_osd(profile_message(), 2)
end)

mp.register_script_message("show-current-version", function()
    show_temp_osd(C.GREEN .. "Anime Build: " .. C.WHITE .. BUILD_VERSION, 3)
end)

-- [NEW] Zoom State Listener
mp.register_script_message("zoom-state-update", function(val)
    zoom_mode = val
    sync_state()
end)

mp.register_script_message("save-target-peak", function(val)
    user_target_peak = val
    if val == "auto" then
        mp.set_property("target-peak", "auto")
        mp.osd_message("Target Peak: Auto")
    else
        mp.set_property("target-peak", val)
        mp.osd_message("Target Peak: " .. val .. " nits")
    end
    save_hdr_mode()
    sync_state()
end)

mp.register_event("file-loaded", function()
    load_anime_mode()
    load_anime4k()
    sd_mode = "clean"
    hd_manual_override = false
    sd_manual_override = false
    
    -- Reset Fidelity to False on new file? 
    -- User didn't specify, but usually persistent per session is better.
    -- For now we keep it persistent across session until restart.
    
    evaluate()
    show_temp_osd(profile_message(), 2)
    sync_state()
end)

-- [HDR PERSISTENCE LOGIC]
local function apply_hdr_preference()
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr = (primaries == "bt.2020" or primaries == "dci-p3")
    -- Only apply if HDR and we have a saved user preference
    if is_hdr and user_hdr_mode then
        mp.set_property("tone-mapping", user_hdr_mode)
    end
	-- [NEW] Apply Target Peak
        if user_target_peak and user_target_peak ~= "auto" then
            mp.set_property("target-peak", user_target_peak)
        else
            mp.set_property("target-peak", "auto")
        end
end

mp.register_script_message("save-tone-mapping", function(mode)
    user_hdr_mode = mode
    mp.set_property("tone-mapping", mode)
    save_hdr_mode() -- Save to disk immediately
    mp.osd_message("Tone-Mapping: " .. mode .. " (Saved)")
    sync_state()
end)

-- Re-apply when file loads or color primaries change
mp.observe_property("video-params/primaries", "string", function() 
    mp.add_timeout(0.5, apply_hdr_preference) 
end)


-- Load the settings file when script starts
load_hdr_mode()

sync_state()