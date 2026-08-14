-- [[ 
--    FILENAME: anime_profile_controller.lua
--    VERSION:  v4.8 (Added Track-Selector Smart Card Toggle)
--    UPDATED:  2026-08-12
-- ]]

local mp = require("mp")
local utils = require("mp.utils")
local opts = require("mp.options")

local config = { version = "v0.0.0" }
opts.read_options(config, "build_info")
local BUILD_VERSION = config.version

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

-- v2.2 Persistent Shader Swaps
-- Format: user_shaders[context][res] = "path/to/custom/shader.glsl"
local user_fsrcnnx = {
    anime = { SD = nil, HD = nil, FHD = nil },
    live  = { SD = nil, HD = nil, FHD = nil }
}
local user_nnedi = {
    anime = { SD = nil, HD = nil, FHD = nil },
    live  = { SD = nil, HD = nil, FHD = nil }
}

-------------------------------------------------
-- STATE
-------------------------------------------------
local anime_mode = "auto"
local current_profile = ""
local shaders_master_switch = true

-- Anime Fidelity State
local user_anime_fidelity = {
    SD     = true,
    HD     = true,
    FHD    = true,
    ["2K"] = true,
    ["4K"] = true,
    ["8K"] = true
} 

local zoom_mode = "fit" 

-- Audio Logic States
local spatial_active = false
local upmix_active = false
local night_mode_active = false
local audio_only_mode = "Auto" -- Defaults to Auto

-- Live Action States
local sd_mode = "clean"          
local sd_manual_override = false 
local hd_manual_override = false 
local sharpen_enabled = true -- New state for Adaptive Sharpen

-- External States (Synced via Broadcast)
local external_vsr_active = false
local external_power_active = false

-- Anime4K (persistent per resolution tier)
local user_anime4k = {
    SD   = { quality = "fast", mode = "A" },
    HD   = { quality = "fast", mode = "A" },
    FHD  = { quality = "fast", mode = "A" },
    ["2K"] = { quality = "fast", mode = "A" },
    ["4K"] = { quality = "fast", mode = "A" },
    ["8K"] = { quality = "fast", mode = "A" }
}

-------------------------------------------------
-- RESOLUTION LOGIC (FIXED)
-------------------------------------------------
local function get_resolution_mode()
    -- [Fix] Use get_property_number to prevent "bad argument #2" crash
    local w = mp.get_property_number("video-params/w") or 0
    local h = mp.get_property_number("video-params/h") or 0
    
    -- Safety check: If video hasn't loaded yet, return SD to prevent errors
    if w == 0 or h == 0 then return "SD" end
    
    local fn = mp.get_property("filename", ""):lower()
    
    if h < 577 or w < 960 then return "SD" end

    if fn:find("720p") or fn:find("1280x720") 
    or (h >= 577 and h <= 720) 
    or (w >= 960 and w <= 1280) then return "HD" end

    if fn:find("1080p") or fn:find("1920x1080") 
    or (h > 720 and h <= 1080) 
    or (w > 1280 and w <= 1920) then return "FHD" end

    if h < 1450 then return "2K" end
	
	if w > 3840 or h > 2160 then return "8K" end

    return "4K"
end


-- Helper function to fetch the active Anime4K state dynamically
local function get_current_a4k()
    local res = get_resolution_mode()
    if not user_anime4k[res] then return "fast", "A" end
    return user_anime4k[res].quality, user_anime4k[res].mode
end

-- [NEW] System States
local up_next_enabled = true
local skip_intro_enabled = true
local history_enabled = true -- [v4.5] History State
local line_thinner_enabled = true -- [v4.5] Line Thinner State
local track_selector_enabled = true -- [v4.7] Track Selector AUTO/DISABLED

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
	local res = get_resolution_mode()
    local current_fidelity = user_anime_fidelity[res]
	-- [v2.2 FIX] Determine Logic based strictly on Active Profile Name
    local p = current_profile or ""
    local fsr_active = (p == "HQ-SD-FSRCNNX") or (p == "HQ-HD-FSRCNNX") or (p == "High-Quality") or (p == "anime-shaders" and current_fidelity)
    local nnedi_active = (p == "HQ-SD-Clean") or (p == "HQ-SD-Texture") or (p == "HQ-HD-NNEDI")
    
    -- 2. Define the state table
    local a4k_q, a4k_m = get_current_a4k()
	
	local state = {
        shaders_enabled = shaders_master_switch,
        
        anime4k_hq = (a4k_q == "hq"),
        anime4k_ultra = (a4k_q == "ultra"),
        anime4k_fast = (a4k_q == "fast"),
        anime4k_quality = a4k_q,
        
        -- Fidelity State
        anime_fidelity = current_fidelity,
        
        -- Zoom State
        zoom_mode = zoom_mode,
		
		-- Adaptive Sharpen
		sharpen_active = sharpen_enabled,
        
        -- Send Context flag for Menu Locking
        is_anime_context = is_anime_active,
		
		-- [NEW] Robust Profile State Flags
        fsrcnnx_running = fsr_active,
        nnedi_running = nnedi_active,
		
		-- [UPDATED AUDIO STATES]
        audio_upmix = upmix_active,
        night_mode = night_mode_active,
        spatial_active = spatial_active,

        -- [NEW] Audio-Only Profile Toggle
        audio_only_mode_state = audio_only_mode,
		
		-- [NEW] Sync Smart Features
        up_next_enabled = up_next_enabled,
        skip_intro_enabled = skip_intro_enabled,
        history_enabled = history_enabled, -- [v4.5] History Sync
        line_thinner_enabled = line_thinner_enabled, -- [v4.5] Line Thinner Sync
        track_selector_enabled = track_selector_enabled, -- [v4.7] Track Selector Sync
        
        -- Live Action Logic
        sd_texture = (sd_mode == "texture"),
        
        mode_auto = (anime_mode == "auto"),
        mode_on = (anime_mode == "on"),
        mode_off = (anime_mode == "off"),
        
        -- Broadcast Anime4K Modes
        a4k_mode_a  = (a4k_m == "A"),
        a4k_mode_b  = (a4k_m == "B"),
        a4k_mode_c  = (a4k_m == "C"),
        a4k_mode_aa = (a4k_m == "AA"),
        a4k_mode_bb = (a4k_m == "BB"),
        a4k_mode_ca = (a4k_m == "CA"),
		a4k_mode_ani4kv2 = (a4k_m == "Ani4Kv2"),
		a4k_mode_anisd  = (a4k_m == "AniSD"),
        
		-- [v2.2] Selection Sync (Tells Main.lua what to checkmark)
        current_res_label = get_resolution_mode(),
        active_context_label = is_anime_active and "anime" or "live",
        
        -- Broadcast the specific active paths for the current res/context
        active_fsrcnnx = user_fsrcnnx[is_anime_active and "anime" or "live"][get_resolution_mode()],
        active_nnedi   = user_nnedi[is_anime_active and "anime" or "live"][get_resolution_mode()],
		
        -- [LOGIC] Grey out Anime4K if: Not in Anime Mode OR Fidelity is ON
        anime4k_allowed = (is_anime_active and not current_fidelity), 
        
        audio_upmix = (string.find(mp.get_property("af") or "", "surround") ~= nil),
        -- Detect Night Mode (DynAudNorm)
        night_mode = (string.find(mp.get_property("af") or "", "dynaudnorm") ~= nil),
        
        audio_passthrough = (function()
            local s = mp.get_property("audio-spdif")
            return (s ~= "no" and s ~= "" and s ~= nil)
        end)(),
        
        hdr_passthrough = (mp.get_property("target-colorspace-hint") == "yes"),
        hdr_display_mode = user_hdr_display_mode,
        
        vsr_active = external_vsr_active,
        power_active = external_power_active
    }

    -- 3. Broadcast to UOSC
    local json = utils.format_json(state)
    mp.commandv("script-message", "anime-state-broadcast", json)
    
    mp.set_property("user-data/anime_shaders_enabled", state.shaders_enabled and "yes" or "no")
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
    
    -- [PRIORITY 1] Check RTX VSR Status First
    if external_vsr_active then
         part2 = C.YELLOW .. "{\\b1}Nvidia VSR:{\\b0} " .. C.GREEN .. "Active (AI Upscaling)"
         return part1 .. sep .. part2
    end
    
    -- 2. Check Power Mode immediately after
    if external_power_active then
        part2 = C.YELLOW .. "{\\b1}Profile:{\\b0} " .. C.GREEN .. "⚡Power Saving Mode (ECO)"
        return part1 .. sep .. part2
    end
    
	-- Define the Sharpen Icon logic
    -- Icon shows IF enabled AND (Not in Anime Mode OR using Fidelity/FSRCNNX)
    local res = get_resolution_mode()
    local is_a4k = (current_profile == "anime-shaders" and not user_anime_fidelity[res])
    local shp_icon = (sharpen_enabled and not is_a4k) and (C.CYAN .. " ✨") or ""
	
    if current_profile == "anime-shaders" then
        local res = get_resolution_mode()
        if user_anime_fidelity[res] then
            local res_label = "FSRCNNX"
            
            if res == "SD" then res_label = "FSRCNNX (Anime SD)"
            elseif res == "HD" then res_label = "FSRCNNX (Anime 720p)"
            elseif res == "FHD" or res == "2K" then res_label = "FSRCNNX (Anime 1080p)"
            else res_label = "Sharpen 4K (Anime)" end
            
            part2 = C.YELLOW .. "{\\b1}Fidelity:{\\b0} " .. C.CYAN .. res_label .. shp_icon
        else
            local a4k_q, a4k_m = get_current_a4k()
            local a4k_str = a4k_q:upper() .. " (" .. a4k_m .. ")"
            part2 = C.YELLOW .. "{\\b1}Anime4K:{\\b0} " .. C.MAGENTA .. a4k_str .. shp_icon
        end
    else
        local prof_color = C.WHITE
        if current_profile == "High-Quality" or current_profile == "HQ-SD-FSRCNNX" then prof_color = C.CYAN
        elseif current_profile and current_profile:find("HQ%-HD") then prof_color = C.GOLD
        elseif current_profile and current_profile:find("HQ%-SD") then prof_color = C.ORANGE
        elseif current_profile == "4K-Native" then prof_color = C.GREEN
		elseif current_profile == "8K-Optimized" then prof_color = C.MAGENTA -- [NEW] Color for 8K
		elseif current_profile == "Audio-Only" then prof_color = C.CYAN -- [NEW] Color for Audio
        end
        part2 = C.YELLOW .. "{\\b1}Profile:{\\b0} " .. prof_color .. current_profile .. shp_icon
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
        -- Catch old migration format if present
        local fid = l:match("^fidelity=(%S+)")
        if fid then for k, v in pairs(user_anime_fidelity) do user_anime_fidelity[k] = (fid == "true") end end
        
        -- Load new per-resolution format
        local res_fid, f_val = l:match("fidelity_(%w+)=(%S+)")
        if res_fid and user_anime_fidelity[res_fid] then 
            user_anime_fidelity[res_fid] = (f_val == "true") 
        end
        local sd_m = l:match("sd_mode=(%S+)")
        if sd_m then sd_mode = sd_m end
        local sd_o = l:match("sd_override=(%S+)")
        if sd_o then sd_manual_override = (sd_o == "true") end
        local hd_o = l:match("hd_override=(%S+)")
        if hd_o then hd_manual_override = (hd_o == "true") end
        local se = l:match("shaders_enabled=(%S+)")
        if se then shaders_master_switch = (se == "true") end
		local shp = l:match("sharpen_enabled=(%S+)")
		if shp then sharpen_enabled = (shp == "true") end
		
		-- [NEW] Load Audio States
        local spa = l:match("spatial_active=(%S+)")
        if spa then spatial_active = (spa == "true") end
        local upm = l:match("upmix_active=(%S+)")
        if upm then upmix_active = (upm == "true") end
        local ngt = l:match("night_mode_active=(%S+)")
        if ngt then night_mode_active = (ngt == "true") end
		
		-- [v2.2] Load Custom Shader Paths
        -- Pattern: custom_TYPE_CONTEXT_RES=PATH
        local s_type, s_ctx, s_res, s_path = l:match("custom_(%a+)_(%a+)_(%w+)=(%S+)")
        if s_type == "fsrcnnx" then 
            if user_fsrcnnx[s_ctx] then user_fsrcnnx[s_ctx][s_res] = s_path end
        elseif s_type == "nnedi" then 
            if user_nnedi[s_ctx] then user_nnedi[s_ctx][s_res] = s_path end
        end
		
		-- [NEW] Load Smart Features
        local un = l:match("up_next_enabled=(%S+)")
        if un then up_next_enabled = (un == "true") end
        local si = l:match("skip_intro_enabled=(%S+)")
        if si then skip_intro_enabled = (si == "true") end
        local he = l:match("history_enabled=(%S+)") -- [v4.5] History Check
        if he then history_enabled = (he == "true") end -- [v4.5] History Load
        local lt = l:match("line_thinner_enabled=(%S+)") -- [v4.5] Line Thinner Check
        if lt then line_thinner_enabled = (lt == "true") end -- [v4.5] Line Thinner Load
        local ts = l:match("track_selector_enabled=(%S+)") -- [v4.7] Track Selector Check
        if ts then track_selector_enabled = (ts == "true") end -- [v4.7] Track Selector Load
		
    end
    f:close()
end

local function save_anime_mode()
    local f = io.open(anime_opts_path, "w")
    if f then 
        f:write("anime_mode=" .. anime_mode .. "\n")
        for res, val in pairs(user_anime_fidelity) do
            f:write("fidelity_" .. res .. "=" .. tostring(val) .. "\n")
        end
        f:write("sd_mode=" .. sd_mode .. "\n")
        f:write("sd_override=" .. tostring(sd_manual_override) .. "\n")
        f:write("hd_override=" .. tostring(hd_manual_override) .. "\n")
        f:write("shaders_enabled=" .. tostring(shaders_master_switch) .. "\n")
		f:write("sharpen_enabled=" .. tostring(sharpen_enabled) .. "\n")
		
		-- [NEW] Save Audio States
        f:write("spatial_active=" .. tostring(spatial_active) .. "\n")
        f:write("upmix_active=" .. tostring(upmix_active) .. "\n")
        f:write("night_mode_active=" .. tostring(night_mode_active) .. "\n")
		
		-- [v2.2] Save Custom FSRCNNX Paths
        for ctx, res_table in pairs(user_fsrcnnx) do
            for res, path in pairs(res_table) do
                if path then f:write("custom_fsrcnnx_" .. ctx .. "_" .. res .. "=" .. path .. "\n") end
            end
        end
        -- [v2.2] Save Custom NNEDI Paths
        for ctx, res_table in pairs(user_nnedi) do
            for res, path in pairs(res_table) do
                if path then f:write("custom_nnedi_" .. ctx .. "_" .. res .. "=" .. path .. "\n") end
            end
        end
		
		-- [NEW] Save Smart Features
        f:write("up_next_enabled=" .. tostring(up_next_enabled) .. "\n")
        f:write("skip_intro_enabled=" .. tostring(skip_intro_enabled) .. "\n")
        f:write("history_enabled=" .. tostring(history_enabled) .. "\n") -- [v4.5] History Save
        f:write("line_thinner_enabled=" .. tostring(line_thinner_enabled) .. "\n") -- [v4.5] Line Thinner Save
        f:write("track_selector_enabled=" .. tostring(track_selector_enabled) .. "\n") -- [v4.7] Track Selector Save
		
        f:close() 
    end
end

local function load_anime4k()
    local f = io.open(anime4k_opts_path, "r")
    if not f then return end
    for l in f:lines() do
        -- 1. Catch old formats (applies globally for migration)
        local old_q = l:match("^quality=(%S+)")
        local old_m = l:match("^mode=(%S+)")
        if old_q then for k, v in pairs(user_anime4k) do v.quality = old_q end end
        if old_m then for k, v in pairs(user_anime4k) do v.mode = old_m end end
        
        -- 2. Load new per-resolution format
        local res_q, q = l:match("quality_(%w+)=(%S+)")
        local res_m, m = l:match("mode_(%w+)=(%S+)")
        if res_q and user_anime4k[res_q] then user_anime4k[res_q].quality = q end
        if res_m and user_anime4k[res_m] then user_anime4k[res_m].mode = m end
    end
    f:close()
end

local function save_anime4k()
    local f = io.open(anime4k_opts_path, "w")
    if f then
        for res, data in pairs(user_anime4k) do
            f:write("quality_" .. res .. "=" .. data.quality .. "\n")
            f:write("mode_" .. res .. "=" .. data.mode .. "\n")
        end
        f:close()
    end
end

local user_target_peak = "auto" 
local user_hdr_display_mode = "auto"

local function load_hdr_mode()
    local f = io.open(hdr_opts_path, "r")
    if not f then return end
    for l in f:lines() do
        local v = l:match("tone_mapping=(%S+)")
        if v then user_hdr_mode = v end
        local p = l:match("target_peak=(%S+)")
        if p then user_target_peak = p end
        local d = l:match("hdr_display_mode=(%S+)")
        if d then user_hdr_display_mode = d end
    end
    f:close()
end

local function save_hdr_mode()
    local f = io.open(hdr_opts_path, "w")
    if f then
        f:write("tone_mapping=" .. (user_hdr_mode or "bt.2390") .. "\n")
        f:write("target_peak=" .. (user_target_peak or "auto") .. "\n")
        f:write("hdr_display_mode=" .. (user_hdr_display_mode or "auto") .. "\n")
        f:close()
    end
end

-------------------------------------------------
-- HELPERS (UPDATED v2.0)
-------------------------------------------------

local function apply_shader_chain(chain)
    -- 1. Universally clear the shader list (Bulletproof across all OS)
    mp.set_property("glsl-shaders", "")
    
    if not chain or chain == "" then return end
    
    -- 2. Split by semicolon OR comma
    for shader_path in string.gmatch(chain, "([^;,]+)") do
        -- Trim any accidental whitespace
        shader_path = shader_path:match("^%s*(.-)%s*$")
        if shader_path and shader_path ~= "" then
            mp.commandv("change-list", "glsl-shaders", "append", shader_path)
        end
    end
end

local function is_anime_folder(p)
    if not p then return false end
    p = p:lower()
    return p:find("/anime/") or p:find("\\anime\\")
        or p:find("donghua") or p:find("cartoon") 
        or p:find("animation") or p:find("3d_anime")
end

-- [UPDATED] Live Action now checks Path AND Title
local function is_live_action(p, t)
    -- Combine path and title into one search string, handling potential nil values
    local search_str = ((p or "") .. " " .. (t or "")):lower()
    
    return search_str:find("live action") or search_str:find("live%-action") 
        or search_str:find("liveaction") or search_str:find("drama")
        or search_str:find("real person")
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

local function finalize_shader_chain(chain)
    if not sharpen_enabled then
        -- Remove sharpener, supporting both ; (tables) and , (mp.get_property)
        chain = chain:gsub("[;,]~~/shaders/adaptive%-sharpen.-%.glsl", "")
        chain = chain:gsub("~~/shaders/adaptive%-sharpen.-%.glsl[;,]", "")
        chain = chain:gsub("~~/shaders/adaptive%-sharpen.-%.glsl", "")
    end
    if not line_thinner_enabled then
        chain = chain:gsub("[^;]*Anime%-Line%-Thinner[^;]*%.glsl;?", "")
        chain = chain:gsub(";+$", "") -- Clean up any accidental trailing semicolons
    end
    return chain
end

local function force_apply_profile(p)
    mp.commandv("apply-profile", p)
    current_profile = p
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
		Ani4Kv2="~~/shaders/Ani4Kv2_ArtCNN_C4F32_i2.glsl",
		AniSD="~~/shaders/AniSD_ArtCNN_C4F32_i4.glsl",
	},
    hq = {
        A="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        B="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        C="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        AA="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_Restore_CNN_M.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        BB="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_M.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
        CA="~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_M.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl",
		Ani4Kv2="~~/shaders/Ani4Kv2_ArtCNN_C4F32_i2.glsl",
		AniSD="~~/shaders/AniSD_ArtCNN_C4F32_i4.glsl",
	},
	ultra = {
        A  = "~~/shaders/Anime4K-Ultra.glsl",
        B  = "~~/shaders/Anime4K-Ultra_Sh.glsl",
        C  = "~~/shaders/Anime4K-Ultra_SSh.glsl",
        AA = "~~/shaders/Anime4K-Ultra_DbL.glsl",
        BB = "~~/shaders/Anime4K-Ultra_DbH.glsl",
        CA = "~~/shaders/Anime4K-Ultra_DbH_Sharp.glsl",
        Ani4Kv2 = "~~/shaders/Ani4Kv2_ArtCNN_C4F32_i2.glsl",
        AniSD   = "~~/shaders/AniSD_ArtCNN_C4F32_i4.glsl",
    }
}

local function apply_anime4k()
    if current_profile ~= "anime-shaders" then return end
    local a4k_q, a4k_m = get_current_a4k()
    if not A4K[a4k_q] or not A4K[a4k_q][a4k_m] then return end
    local chain = A4K[a4k_q][a4k_m]
    apply_shader_chain(chain)
end

-------------------------------------------------
-- SHADERS (DEFINITIONS)
-------------------------------------------------
-- [v4.6] Added Anime Line Thinners with Anime4K Restore Shaders for anti-aliasing
local FSRCNNX = {
    SD = "~~/shaders/FSRCNNX_x2_16-0-4-1_enhance_anime.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-anime-SD.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_S.glsl;~~/shaders/Anime-Line-Thinner-SD.glsl",
    HD_720 = "~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-anime-720p.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_S.glsl;~~/shaders/Anime-Line-Thinner-HD.glsl",
    HD_1080 = "~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-anime-1080p.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_S.glsl;~~/shaders/Anime-Line-Thinner-FHD.glsl",
    UHD = "~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-anime-4K.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_S.glsl;~~/shaders/Anime-Line-Thinner-4K.glsl"
}

-- [v2.2] Live Action Defaults (Mirrors mpv.conf)
local LiveChains = {
    -- SD: NNEDI3 256 + SSim + Adaptive
    SD = "~~/shaders/nnedi3-nns256-win8x4.hook;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-modern-SD.glsl",
    
    -- [v2.2 FIX] SD FSRCNNX: FSR + Krig + SSim + Adaptive SD (Matches HQ-SD-FSRCNNX)
    SD_FSR = "~~/shaders/FSRCNNX_x2_16-0-4-1.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-modern-SD.glsl",

    -- HD: NNEDI3 64 + Krig + SSim + Adaptive
    HD_NNEDI = "~~/shaders/nnedi3-nns64-win8x4.hook;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-modern-HD.glsl",
    
    -- HD/FHD: FSRCNNX 16 + Krig + SSim + Adaptive
    HD_FSR = "~~/shaders/FSRCNNX_x2_16-0-4-1.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-modern-HD.glsl",
    FHD = "~~/shaders/FSRCNNX_x2_16-0-4-1.glsl;~~/shaders/KrigBilateral.glsl;~~/shaders/SSimSuperRes.glsl;~~/shaders/SSimDownscaler.glsl;~~/shaders/adaptive-sharpen-modern-1080p.glsl"
}

local function apply_fsrcnnx()
    local res = get_resolution_mode()
    local is_anime = (current_profile == "anime-shaders")
    local chain = ""
    local custom_path = nil

    -- 1. DETERMINE BASE CHAIN & CUSTOM PATH
    if is_anime then
        -- [ANIME LOGIC]
        if not user_anime_fidelity[res] then return end 
        
        -- A. Normalize Resolution Key (Treat 2K as FHD/1080p)
        local lookup_res = res
        if res == "2K" then lookup_res = "FHD" end

        -- B. Select Base Chain
        local key = "UHD"
        if res == "SD" then key = "SD"
        elseif res == "HD" then key = "HD_720"
        elseif res == "FHD" or res == "2K" then key = "HD_1080"
        end
        chain = FSRCNNX[key] or ""
        
        -- C. Look for Custom Swap (Using Normalized Resolution)
        -- This ensures 1440p content uses your 1080p settings
        custom_path = user_fsrcnnx.anime[lookup_res] or user_nnedi.anime[lookup_res]
        
    else
        -- [LIVE ACTION LOGIC]
        if res == "SD" then
            chain = LiveChains.SD
            if sd_manual_override then 
                chain = LiveChains.SD_FSR 
                custom_path = user_fsrcnnx.live.SD 
            else
                custom_path = user_nnedi.live.SD 
            end
            
        elseif res == "HD" then
            if hd_manual_override then
                chain = LiveChains.HD_FSR
                custom_path = user_fsrcnnx.live.HD
            else
                chain = LiveChains.HD_NNEDI
                custom_path = user_nnedi.live.HD
            end
            
        elseif res == "FHD" or res == "2K" then
            chain = LiveChains.FHD
            -- Use .FHD for both 1080p and 1440p
            custom_path = user_fsrcnnx.live.FHD or user_nnedi.live.FHD
        end
    end

    -- 2. APPLY SWAP
    if custom_path and chain ~= "" then
        chain = chain:gsub("^[^;]+", custom_path)
    end

    -- 3. INJECT
    if chain ~= "" then
        chain = finalize_shader_chain(chain)
        apply_shader_chain(chain)
    end
end

-------------------------------------------------
-- CORE EVALUATION LOGIC (UNIVERSAL DETECTION)
-------------------------------------------------
local function evaluate()
    -- 1. [SAFETY LOCKS]
    if external_vsr_active then return end
    if not shaders_master_switch then return end
    if external_power_active then return end

    -- 2. [GET METADATA]
    local path = mp.get_property("path", "")
    local title = mp.get_property("media-title", "")
    local filename = mp.get_property("filename", "") -- [NEW] Get filename for Hash check
    local res = get_resolution_mode()
    
    -- Check for Shiru App launch arg
    local shiru_opt = mp.get_opt("mode") 
	
    -- 3. [DETECT SIGNALS]
    
    -- A. Anime Signals (Logical OR)
    local signal_folder = is_anime_folder(path)
    local signal_shiru  = (shiru_opt == "anime")

    -- [v4.6] Strict Syntax Check: MUST have [Prefix] AND ([Suffix] OR " - 01" episode dash)
    local signal_syntax = false
    if filename:match("^%[.-%]") then
        if filename:match("^%[.-%].-%[.-%]") or filename:match("%s%-%s%d+") then
            signal_syntax = true
        end
    end

    -- [NEW] CRC32 Hash Check (The "Super Signal")
    -- Matches 8-digit Hex codes inside brackets (e.g., [A1B2C3D4])
    -- This is extremely specific to Anime releases.
    local crc_pattern = "%[%x%x%x%x%x%x%x%x%]"
    local signal_crc = filename:match(crc_pattern) or title:match(crc_pattern)

    -- [UPDATED] Audio Scan: Check ALL tracks for Japanese
    local signal_audio = false
    local track_list = mp.get_property_native("track-list") or {}
    for _, track in ipairs(track_list) do
        if track.type == "audio" and track.lang then
            local lang = track.lang:lower()
            if lang == "jpn" or lang == "ja" then
                signal_audio = true
                break
            end
        end
    end
	
	-- [NEW] AUDIO PRIORITY OVERRIDE
	local track_list = mp.get_property_native("track-list") or {}

	-- FIX: If the track list is completely empty, the file is still being demuxed
	-- (very common on iGPU/slower machines). Defer evaluation to let mpv catch up.
	if #track_list == 0 then
        mp.add_timeout(0.2, evaluate)
        return
        end

        local vid_state = mp.get_property("vid")
        local has_real_video = false

        for _, track in ipairs(track_list) do
            -- A real video track is of type "video" but is NOT an image attachment
            if track.type == "video" and not track.image then
                has_real_video = true
                break
                end
                end

                -- Apply Audio-Only ONLY if Auto mode is ON and no real video track exists
                if audio_only_mode == "Auto" and (vid_state == "no" or not has_real_video) then
                    apply_profile("Audio-Only")
                    return
                    end
	
	-- [NEW] 8K PRIORITY OVERRIDE
    -- If 8K is detected, force the optimized profile and exit immediately.
    -- This prevents heavy shaders (FSRCNNX/Anime4K) from crashing the GPU.
	if res == "8K" then
        apply_profile("8K-Optimized")
        return
    end
	
    -- 4. [DECISION LOGIC]
    local is_anime = false

    if anime_mode == "on" then
        is_anime = true
    elseif anime_mode == "auto" then
        -- Priority 1: Explicit Live Action Signal overrides almost everything
        if signal_live_action then
            is_anime = false
            
        -- Priority 2: CRC32 "Super Signal" (Strongest Anime indicator)
        elseif signal_crc then
            is_anime = true
            
        -- Priority 3: Standard Anime Signals
        elseif signal_folder or signal_audio or signal_syntax or signal_shiru then
            is_anime = true
        else
            -- Priority 4: Default fallback
            is_anime = false
        end
    end

    -- 5. [APPLY PROFILES]
    if is_anime then
        apply_profile("anime-shaders")
        
        local active_res = get_resolution_mode()
        if user_anime_fidelity[active_res] then
            apply_fsrcnnx()
        else
            apply_anime4k()
        end
        return
    end

    -- 6. [LIVE ACTION FALLBACK]
    -- Reset current_profile to force mpv to re-run the profile commands
    current_profile = ""
	
    if res == "SD" then
        if sd_manual_override then
            apply_profile("HQ-SD-FSRCNNX")
        else
            apply_profile(sd_mode == "texture" and "HQ-SD-Texture" or "HQ-SD-Clean")
        end
    elseif res == "4K" then
        apply_profile("4K-Native")
    elseif res == "2K" or res == "FHD" then
         apply_profile("High-Quality")
    else -- HD 720p
        apply_profile(hd_manual_override and "HQ-HD-FSRCNNX" or "HQ-HD-NNEDI")
    end
	
	-- [v2.2] Run the Swapper for Live Action overrides (if applicable)
    if not is_anime then apply_fsrcnnx() end

    -- 7. [POST-PROCESS TOGGLE]
    -- If sharpening is disabled, strip it from the chain we just built
    if not sharpen_enabled then
        local current_shaders = mp.get_property("glsl-shaders", "")
        if current_shaders ~= "" then
            apply_shader_chain(finalize_shader_chain(current_shaders))
        end
    end
	
end

-------------------------------------------------
-- MENU GENERATOR (Corrected: Uses Local Variables)
-------------------------------------------------
local function get_anime_menu_json()
    -- [v2.2 FIX] Force Context Detection if missing
    if current_profile == "" then evaluate() end

    local res = get_resolution_mode()
    local ctx = (current_profile == "anime-shaders" and "anime" or "live")
	
	local current_fidelity = user_anime_fidelity[res] --[New v4.1]
    
    -- Gather States
    local s_on = shaders_master_switch
    local s_auto = (anime_mode == "auto")
    local s_force = (anime_mode == "on")
    local s_off = (anime_mode == "off")
	
	local s_spatial = spatial_active
    
    -- [v2.2 FIX] Menu Visual State based strictly on Profile Name
    local p = current_profile or ""
    local fsr_active = (p == "HQ-SD-FSRCNNX") or (p == "HQ-HD-FSRCNNX") or (p == "High-Quality") or (p == "anime-shaders" and current_fidelity)
    local nnedi_active = (p == "HQ-SD-Clean") or (p == "HQ-SD-Texture") or (p == "HQ-HD-NNEDI")

    -- Logic for SD Mode Lock (Locked if we are in SD but FSRCNNX is running)
    local s_sd_locked = (res == "SD" and fsr_active)

    local a4k_q, a4k_m = get_current_a4k()
    local s_a4k_hq = (a4k_q == "hq")
    local s_fidelity = current_fidelity
    local s_anime4k_allowed = (current_profile == "anime-shaders" and not current_fidelity)
    
    -- Dynamic Labels for Ultra Mode Descriptions
    local is_ultra = (a4k_q == "ultra")
    local label_a  = is_ultra and "Mode A (FSR+Thin)" or "Mode A (Blur+Noise)"
    local label_b  = is_ultra and "Mode B (Post-Sharpen)" or "Mode B (Blur Only)"
    local label_c  = is_ultra and "Mode C (Pre-Sharpen)" or "Mode C (Noise Only)"
    local label_aa = is_ultra and "Mode A+A (DbL Recommended)" or "Mode A+A (High Fid.)"
    local label_bb = is_ultra and "Mode B+B (DbH Deblur)" or "Mode B+B (Sharpness)"
    local label_ca = is_ultra and "Mode C+A (DbH Sharp)" or "Mode C+A (Restore)"

    -- Anime4K Modes
    local s_m_a = (a4k_m == "A")
    local s_m_b = (a4k_m == "B")
    local s_m_c = (a4k_m == "C")
    local s_m_aa = (a4k_m == "AA")
    local s_m_bb = (a4k_m == "BB")
    local s_m_ca = (a4k_m == "CA")
	local s_m_ani4kv2 = (a4k_m == "Ani4Kv2")
	local s_m_anisd  = (a4k_m == "AniSD")
    
    -- Audio/HDR States
    local af = mp.get_property("af") or ""
    local s_upmix = string.find(af, "surround")
    local s_night_mode = (string.find(af, "dynaudnorm") ~= nil)
    local spdif = mp.get_property("audio-spdif") or "no"
    local s_pass = (spdif ~= "no" and spdif ~= "") 
    local s_hdr_active = (mp.get_property("target-colorspace-hint") == "yes")
    local s_vsr = external_vsr_active
    local s_power = external_power_active
    
    -- HDR Logic
    local primaries = mp.get_property("video-params/primaries")
    local hdr_passthrough = mp.get_property("target-colorspace-hint") == "yes"
    local is_hdr = (primaries == "bt.2020" or primaries == "dci-p3")
    local tm_locked = not (is_hdr and not hdr_passthrough)
    local tm_status_hint = not is_hdr and " (Locked: SDR)" or (hdr_passthrough and " (Locked: Passthrough)" or " (Active)")
    local current_tm = mp.get_property("tone-mapping") or "hable"

    local tm_menu = {
        type = "submenu",
        title = "Tone-Mapping Mode" .. tm_status_hint,
        icon = "brightness_medium",
        active = not tm_locked,
        items = {
            { title = "BT.2390 (Recommended)", active = (current_tm == "bt.2390"), value = "script-message save-tone-mapping bt.2390" },
            { title = "ST.2094-40 (Active)", active = (current_tm == "st2094-40"), value = "script-message save-tone-mapping st2094-40" },
			{ title = "ST.2094-10 (Adaptive)", active = (current_tm == "st2094-10"), value = "script-message save-tone-mapping st2094-10" },
            { title = "BT.2446a (Static)", active = (current_tm == "bt.2446a"), value = "script-message save-tone-mapping bt.2446a" },
            { title = "Spline (Neutral)", active = (current_tm == "spline"), value = "script-message save-tone-mapping spline" },
            { title = "Hable", active = (current_tm == "hable"), value = "script-message save-tone-mapping hable" },
            { title = "Mobius", active = (current_tm == "mobius"), value = "script-message save-tone-mapping mobius" },
            { title = "Reinhard", active = (current_tm == "reinhard"), value = "script-message save-tone-mapping reinhard" },
            { title = "Clip (Hard Cut)", active = (current_tm == "clip"), value = "script-message save-tone-mapping clip" }
        }
    }

    local items = {
        {
            title = "Anime Detection Mode: " .. (s_force and "ON" or (s_off and "OFF" or "AUTO")),
            icon = 'tv',
            items = {
                { title = "====(Auto-Detection Modes)====", value = "ignore", bold = true },
                { title = "Mode: Auto (Auto Detection)", value = "script-binding anime-mode-auto", active = s_auto },
                { title = "Mode: Force On (Anime Mode)", value = "script-binding anime-mode-on", active = s_force },
                { title = "Mode: Force Off (Native HQ)", value = "script-binding anime-mode-off", active = s_off },
                { title = "Show Status Info", value = "script-binding show-profile-info", icon = 'info' },
            }
        },

        { title = "Anime Shaders Fidelity: " .. (s_fidelity and "FSRCNNX" or "Anime4K"), value = "script-message toggle-anime-fidelity", active = s_fidelity },
        {
            title = "Anime4K Quality",
            icon = "high_quality",
            muted = not s_anime4k_allowed,
            hint = not s_anime4k_allowed and "Disabled (Fidelity ON)" or a4k_q:upper(),
            items = {
                { title = "Fast (Performance)", active = (a4k_q == "fast"), value = "script-message set-anime4k-quality fast" },
                { title = "HQ (High Quality)", active = (a4k_q == "hq"), value = "script-message set-anime4k-quality hq" },
                { title = "Ultra (Th-Underscore)", active = (a4k_q == "ultra"), value = "script-message set-anime4k-quality ultra" },
            }
        },

        {
            title = "Anime4K Profiles",
            icon = 'palette',
            muted = not s_anime4k_allowed,
            hint = not s_anime4k_allowed and "Disabled (Fidelity ON)" or "",
            items = {
                { title = "Mode Ani4Kv2 (ArtCNN)", value = "script-message anime4k-mode Ani4Kv2", active = s_m_ani4kv2 },
                { title = "Mode AniSD (ArtCNN)", value = "script-message anime4k-mode AniSD", active = s_m_anisd },
                { title = label_a,  value = "script-message anime4k-mode A", active = s_m_a },
                { title = label_b,  value = "script-message anime4k-mode B", active = s_m_b },
                { title = label_c,  value = "script-message anime4k-mode C", active = s_m_c },
                { title = label_aa, value = "script-message anime4k-mode AA", active = s_m_aa },
                { title = label_bb, value = "script-message anime4k-mode BB", active = s_m_bb },
                { title = label_ca, value = "script-message anime4k-mode CA", active = s_m_ca },
            }
        },
        {
            title = "Fidelity & Restoration",
            icon = 'brush',
            items = {
                { title = "====(Display Tools)====", value = "ignore", bold = true },
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
                
                -- [RENAMED] SD Mode (NNEDI)
                { 
                    title = "SD Mode (NNEDI): " .. (s_sd_tex and "Texture" or "Clean"), 
                    value = "script-message toggle-hq-sd", 
                    active = s_sd_tex,
                    muted = s_sd_locked,
                    hint = s_sd_locked and "(Locked by FSRCNNX)" or ""
                },
                
                -- [RENAMED] SD/HD Logic
                { 
                    title = "SD/HD Logic: " .. (fsr_active and "FSRCNNX" or "NNEDI3"), 
                    value = "script-message toggle-hq-hd-nnedi", 
                    active = fsr_active 
                },

                { 
                    title = "Adaptive Sharpen: " .. (sharpen_enabled and "ON" or "OFF"), 
                    value = "script-message toggle-adaptive-sharpen", 
                    active = sharpen_enabled,
                    muted = not shaders_master_switch,
                    hint = not shaders_master_switch and "Locked (Master OFF)" or ""
                },

                {
                    title = "Anime Line Thinner", -- [v4.5] Anime Line Thinner Toggle
                    value = "script-message toggle-line-thinner",
                    active = line_thinner_enabled,
                    -- Locks visually if not in Anime Mode or Fidelity Mode
                    muted = not (is_anime_context and user_anime_fidelity[get_resolution_mode()])
                },
                
                -- [v2.2] FSRCNNX Swapper (Controller Version)
                {
                    title = "Swap FSRCNNX (" .. res .. " / " .. ctx:upper() .. ")",
                    icon = "shutter_speed",
                    muted = not fsr_active,
                    items = {
                        { title = "== " .. res .. " Variants ==", value = "ignore", bold = true },
                        -- Standard
                        { title = "FSRCNNX (Standard 16)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_16-0-4-1.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_16-0-4-1.glsl" },
                        { title = "FSRCNNX (Standard 8)",  active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_8-0-4-1.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_8-0-4-1.glsl" },
                        -- Custom
                        { title = "FSRCNNX (Anime Mild)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_16-0-4-1_enhance_anime.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_enhance_anime.glsl" },
                        { title = "FSRCNNX (Anime Aggressive)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_16-0-4-1_anime_enhance.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_anime_enhance.glsl" },
                        { title = "FSRCNNX (Anime Distort)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_16-0-4-1_anime_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_anime_distort.glsl" },
                        { title = "FSRCNNX (Anime Distort 1x Filter)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x1_16-0-4-1_anime_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x1_16-0-4-1_anime_distort.glsl" },
						{ title = "FSRCNNX (Line Art)",      active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl" },
                        { title = "FSRCNNX (General Distort)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_16-0-4-1_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_distort.glsl" },        
                        { title = "FSRCNNX (General Distort 1x Filter)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x1_16-0-4-1_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x1_16-0-4-1_distort.glsl" },
						{ title = "FSRCNNX (Enhance General)", active = (user_fsrcnnx[ctx][res] == "~~/shaders/FSRCNNX_x2_16-0-4-1_enhance.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. ctx .. " " .. res .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_enhance.glsl" },
                        { title = "RESET TO DEFAULT",        value = "script-message reset-resolution-shader fsrcnnx " .. ctx .. " " .. res, bold = true }
                    }
                },
                -- [v2.2] NNEDI3 Swapper (Controller Version)
                {
                    title = "Swap NNEDI3 (" .. res .. " / " .. ctx:upper() .. ")",
                    icon = "architecture",
                    muted = not nnedi_active,
                    items = {
                        { title = "== " .. res .. " Neurons ==", value = "ignore", bold = true },
                        { title = "NNEDI3 (256 - Ultra)", active = (user_nnedi[ctx][res] == "~~/shaders/nnedi3-nns256-win8x4.hook"), value = "script-message set-resolution-shader nnedi " .. ctx .. " " .. res .. " ~~/shaders/nnedi3-nns256-win8x4.hook" },
                        { title = "NNEDI3 (128 - High)",  active = (user_nnedi[ctx][res] == "~~/shaders/nnedi3-nns128-win8x4.hook"), value = "script-message set-resolution-shader nnedi " .. ctx .. " " .. res .. " ~~/shaders/nnedi3-nns128-win8x4.hook" },
                        { title = "NNEDI3 (64 - Mid)",    active = (user_nnedi[ctx][res] == "~~/shaders/nnedi3-nns64-win8x4.hook"),  value = "script-message set-resolution-shader nnedi " .. ctx .. " " .. res .. " ~~/shaders/nnedi3-nns64-win8x4.hook" },
                        { title = "NNEDI3 (32 - Low)",    active = (user_nnedi[ctx][res] == "~~/shaders/nnedi3-nns32-win8x4.hook"),  value = "script-message set-resolution-shader nnedi " .. ctx .. " " .. res .. " ~~/shaders/nnedi3-nns32-win8x4.hook" },
                        { title = "== Window Variants ==", value = "ignore", bold = true },
                        { title = "NNEDI3 (nns256 win8x6)", active = (user_nnedi[ctx][res] == "~~/shaders/nnedi3-nns256-win8x6.hook"), value = "script-message set-resolution-shader nnedi " .. ctx .. " " .. res .. " ~~/shaders/nnedi3-nns256-win8x6.hook" },
                        { title = "RESET TO DEFAULT",       value = "script-message reset-resolution-shader nnedi " .. ctx .. " " .. res, bold = true }
                    }
                },
                
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
                -- [NEW] Audio-Only Profile Toggle
                {
                    title = "Audio-Only Profile",
                    hint = audio_only_mode,
                    value = "script-message toggle-audio-only",
                    active = audio_only_mode == "Auto"
                },
                -- Audio Enhancement Settings
                { title = "Audio: Night Mode (DRC)", value = "script-message toggle-audio-nightmode", active = s_night_mode },
				{ title = "Audio: Spatial Mode", value = "script-message toggle-audio-spatial", active = s_spatial },
                { title = "Audio: Toggle 7.1 Upmix", value = "script-message toggle-audio-upmix", active = s_upmix },
                { title = "Audio: Toggle Passthrough", value = "script-message toggle-audio-passthrough", active = s_pass },
                {
                    title = "HDR Switch Mode",
                    icon = "hdr_on",
                    items = {
                        { title = "Auto (Detected)", active = (user_hdr_display_mode == "auto"), value = "script-message set-hdr-display-mode auto" },
                        { title = "HDR Display (Passthrough)", active = (user_hdr_display_mode == "hdr"), value = "script-message set-hdr-display-mode hdr" },
                        { title = "SDR Display (Tone-Map)", active = (user_hdr_display_mode == "sdr"), value = "script-message set-hdr-display-mode sdr" },
                    }
                },
                tm_menu,
                {
                    title = "Target Peak (Brightness)",
                    icon = "wb_sunny",
                    items = {
                       { title = "Auto (Default)", value = "script-message save-target-peak auto", active = (user_target_peak == "auto") },
                       { title = "100 nits (Dim Monitor)", value = "script-message save-target-peak 100", active = (user_target_peak == "100") },
                       { title = "200 nits (Standard)", value = "script-message save-target-peak 200", active = (user_target_peak == "200") },
                       { title = "300 nits (Bright LCD)", value = "script-message save-target-peak 300", active = (user_target_peak == "300") },
                       { title = "400 nits (HDR400)", value = "script-message save-target-peak 400", active = (user_target_peak == "400") },
                       { title = "600 nits (HDR600)", value = "script-message save-target-peak 600", active = (user_target_peak == "600") },
                       { title = "1000 nits (High-End)", value = "script-message save-target-peak 1000", active = (user_target_peak == "1000") },
                    }
                },
            }
        },
		{
            title = "Smart Cards",
            icon = 'smart_toy',
            items = {
                { title = "History CARD", value = "script-message toggle-history", active = history_enabled }, -- [v4.5] History Toggle
                { title = "Skip Intro/OP/ED CARD", value = "script-message toggle-skip-intro", active = skip_intro_enabled },
                { title = "Up Next CARD", value = "script-message toggle-up-next", active = up_next_enabled },
                { title = "Track Selector: " .. (track_selector_enabled and "AUTO" or "DISABLED"), value = "script-message toggle-track-selector", active = track_selector_enabled },
            }
        },
        {
            title = "System",
            icon = 'build',
            items = {
                        { title = "Check for Updates", value = "script-message check-for-updates", icon = 'update' },
                        { title = "Show Statistics", value = "script-binding toggle-stats", icon = 'info' },
                    }
        },
        { title = "Advanced Controls...", icon = 'tune', value = "script-binding uosc/open-controls-menu", bold = true, active = true },
    }

    return utils.format_json({
        type = "menu",
        title = "Anime Build Options",
        items = items
    })
end

local function update_uosc_menu()
    mp.commandv("script-message-to", "uosc", "update-menu", get_anime_menu_json())
end

mp.add_key_binding(nil, "open-anime-menu", function()
    mp.commandv("script-message-to", "uosc", "open-menu", get_anime_menu_json())
end)

-------------------------------------------------
-- SMART AUDIO ENGINE (Spatial + Upmix)
-------------------------------------------------
local function evaluate_audio()
    if spatial_active then
        if upmix_active then
            -- Case 1: Virtual 7.1 (Spatial + Upmix)
            mp.commandv("apply-profile", "Cinema-Virtual-7.1")
            show_temp_osd("🎧 Audio: Virtual 7.1 Spatial (Immersive)", 2)
        else
            -- Case 2: Native Spatial (Spatial Only)
            mp.commandv("apply-profile", "Cinema-Spatial-Pure")
            show_temp_osd("🎧 Audio: Spatial (Native Source)", 2)
        end
    else
        if upmix_active then
            -- Case 3: Standard 7.1 Upmix (Speakers)
            mp.commandv("apply-profile", "Standard-Audio-PC")
            mp.command('no-osd af set "lavfi=[surround=chl_out=7.1:lfe_low=80]"')
            mp.set_property("audio-channels", "7.1")
            show_temp_osd("🔊 Audio: 7.1 Upmix (Bass Boost)", 2)
        else
            -- Case 4: Standard (Default)
            mp.commandv("apply-profile", "Standard-Audio-PC")
            show_temp_osd("🔊 Audio: Standard", 2)
        end
    end
    
    -- Restore Night Mode if active (since profiles clear filters)
    if night_mode_active then
        mp.command("no-osd af add @nightmode:lavfi=[dynaudnorm=f=75:g=25:n=0:p=0.9]")
    end
    
    sync_state()
    update_uosc_menu()
end

-------------------------------------------------
-- EXTERNAL TOGGLES
-------------------------------------------------
mp.register_script_message("toggle-anime-fidelity", function()
    if external_power_active then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Power Saving Mode Active", 2)
        return
    end

    if not shaders_master_switch then show_temp_osd(profile_message(), 2) return end
    
    if current_profile ~= "anime-shaders" then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Anime Mode Required.", 2)
        return
    end
    
    -- Toggle specifically for current resolution tier
    local res = get_resolution_mode()
    user_anime_fidelity[res] = not user_anime_fidelity[res]
    
    save_anime_mode() 
    evaluate() 
    
    local status = user_anime_fidelity[res] and (C.CYAN .. "FSRCNNX (Anime Fidelity)") or (C.MAGENTA .. "Anime4K (Performance)")
    show_temp_osd(C.YELLOW .. "Anime Shader [" .. res .. "]: " .. status, 2)
    sync_state()
    update_uosc_menu()
end)

mp.register_script_message("set-hdr-display-mode", function(mode)
    user_hdr_display_mode = mode
    save_hdr_mode() -- Save choice to config
    mp.commandv("script-message", "update-hdr-detect-mode") -- Tell hdr_detect to re-evaluate
    sync_state()
    update_uosc_menu()
end)

mp.register_script_message("toggle-audio-upmix", function()
    upmix_active = not upmix_active
    save_anime_mode() -- [PERSISTENCE]
    evaluate_audio()
end)

mp.register_script_message("toggle-audio-spatial", function()
    spatial_active = not spatial_active
    save_anime_mode() -- [PERSISTENCE]
    evaluate_audio()
end)

mp.register_script_message("toggle-audio-nightmode", function()
    night_mode_active = not night_mode_active
    save_anime_mode() -- [PERSISTENCE]
    
    if night_mode_active then
        mp.command("no-osd af add @nightmode:lavfi=[dynaudnorm=f=75:g=25:n=0:p=0.9]")
        show_temp_osd(C.GREEN .. "Night Mode: " .. C.WHITE .. "ON", 2)
    else
        mp.command("no-osd af remove @nightmode")
        show_temp_osd(C.RED .. "Night Mode: " .. C.WHITE .. "OFF", 2)
    end
    sync_state()
    update_uosc_menu()
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

mp.register_script_message("toggle-global-shaders", function()
    shaders_master_switch = not shaders_master_switch
    save_anime_mode() 
    
    if not shaders_master_switch then
        mp.set_property("glsl-shaders", "") 
        current_profile = ""
        show_temp_osd(C.RED .. "Shaders: " .. C.WHITE .. "Disabled", 2)
    else
        evaluate()
        show_temp_osd(C.GREEN .. "Shaders: " .. C.WHITE .. "Enabled", 2)
    end
    sync_state()
	update_uosc_menu()
end)

-- [v4.7] Track Selector AUTO/DISABLED Listener
mp.register_script_message("toggle-track-selector", function()
    track_selector_enabled = not track_selector_enabled
    save_anime_mode()
    mp.commandv("script-message-to", "track-selector", "set-enabled", tostring(track_selector_enabled))
    show_temp_osd("Track Selector: " .. (track_selector_enabled and "AUTO" or "DISABLED"), 2)
    sync_state()
    update_uosc_menu()
end)

-- [v4.5] History Listener
mp.register_script_message("toggle-history", function()
history_enabled = not history_enabled
save_anime_mode()
show_temp_osd("History Tracking: " .. (history_enabled and "Enabled" or "Disabled"), 2)
sync_state()
update_uosc_menu()
end)

-- [v4.5] Line Thinner Listener
mp.register_script_message("toggle-line-thinner", function()
    local res = get_resolution_mode()
    local is_fidelity = user_anime_fidelity[res]

    -- [FIXED] Changed is_anime_context to is_anime
    if current_profile ~= "anime-shaders" or not is_fidelity then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Only Available in Anime Fidelity Mode", 2)
        return
    end

    line_thinner_enabled = not line_thinner_enabled
    save_anime_mode()
    show_temp_osd("Anime Line Thinner: " .. (line_thinner_enabled and "ON" or "OFF"), 2)
    sync_state()
    update_uosc_menu()

    evaluate()
end)

mp.observe_property("af", "string", sync_state)
mp.observe_property("audio-spdif", "string", sync_state)
mp.observe_property("target-colorspace-hint", "string", sync_state)


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

mp.register_script_message("toggle-audio-only", function()
if audio_only_mode == "Auto" then
    audio_only_mode = "Disable"
    else
        audio_only_mode = "Auto"
        end

        sync_state() -- Broadcast the new state to UOSC
        show_temp_osd("🎵 Audio-Only Mode: " .. audio_only_mode, 2)

        -- Re-evaluate the current file to apply or remove the profile instantly
        evaluate()
        end)

mp.register_script_message("set-anime4k-quality", function(quality)
    if external_power_active then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Power Saving Mode Active", 2)
        return
    end
    if current_profile ~= "anime-shaders" then return end
    
    local res = get_resolution_mode()
    if user_anime_fidelity[res] then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Disable Fidelity Mode first.", 2)
        return
    end
    
    user_anime4k[res].quality = quality
    
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
    sync_state()
    update_uosc_menu()
end)

mp.add_key_binding(nil, "toggle-anime4k-quality", function()
    if external_power_active then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Power Saving Mode Active", 2)
        return
    end
    if current_profile ~= "anime-shaders" then return end
    
    local res = get_resolution_mode()
    if user_anime_fidelity[res] then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Disable Fidelity Mode first.", 2)
        return
    end
    
    -- Cycle through the 3 modes: fast -> hq -> ultra -> fast
    local current_q = user_anime4k[res].quality
    local next_q = "fast"
    
    if current_q == "fast" then 
        next_q = "hq"
    elseif current_q == "hq" then 
        next_q = "ultra"
    elseif current_q == "ultra" then 
        next_q = "fast"
    end
    
    user_anime4k[res].quality = next_q
    
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
    sync_state()
    update_uosc_menu()
end)

mp.add_key_binding(nil, "show-profile-info", function()
    show_temp_osd(profile_message(), 2)
end)

mp.register_script_message("anime4k-mode", function(mode)
    if external_power_active then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Power Saving Mode Active", 2)
        return
    end
    if current_profile ~= "anime-shaders" then return end

    -- [FIX] Correctly check the fidelity state for the current resolution
    local res = get_resolution_mode()
    if user_anime_fidelity[res] then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Switch to Anime4K Mode to use.", 2)
        return
    end

    local a4k_q = user_anime4k[res].quality
    if not A4K[a4k_q][mode] then return end

    user_anime4k[res].mode = mode
    save_anime4k()
    apply_anime4k()
    show_temp_osd(profile_message(), 2)
    sync_state()
end)

mp.register_script_message("toggle-hq-sd", function()
    if external_power_active then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Power Saving Mode Active", 2)
        return
    end
    if not shaders_master_switch then show_temp_osd(profile_message(), 2) return end
    if current_profile == "HQ-SD-FSRCNNX" then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Switch to NNEDI first.", 2)
        return
    end
    if not current_profile or not string.find(current_profile, "HQ%-SD") then 
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Only for SD (Live-Action).", 2)
        return 
    end
    sd_mode = (sd_mode == "clean") and "texture" or "clean"
    save_anime_mode()
    evaluate()
    show_temp_osd(C.YELLOW .. "SD Mode: " .. C.ORANGE .. sd_mode:upper(), 2)
    sync_state()
end)

mp.register_script_message("toggle-hq-hd-nnedi", function()
    if external_power_active then
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Power Saving Mode Active", 2)
        return
    end
    if not shaders_master_switch then show_temp_osd(profile_message(), 2) return end
    local res = get_resolution_mode()
    if current_profile == "anime-shaders" then 
		show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "only for SD & HD (Live-Action).", 2)
		return end
    if res == "FHD" or res == "2K" or res == "4K" then 
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "only for SD & HD (Live-Action).", 2)
        return 
    end
    local mode_name, mode_color = "", ""
    if res == "SD" then
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
    save_anime_mode()
    show_temp_osd(C.YELLOW .. "Logic Switch: " .. mode_color .. mode_name, 2)
    sync_state()
	update_uosc_menu()
end)

mp.register_script_message("show-current-version", function()
    show_temp_osd(C.GREEN .. "Anime Build: " .. C.WHITE .. BUILD_VERSION, 3)
end)

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

-- [NEW] Loading Lock Variable
local loading_lock = false

mp.register_script_message("force-evaluate-profile", function()
    -- IGNORE request if we are already running the main load process
    if loading_lock then return end 
    
    current_profile = "" 
    evaluate()
    show_temp_osd(profile_message(), 2)
end)

-- [UPDATED] File Loaded Logic
mp.register_event("file-loaded", function()
    loading_lock = true -- Lock out external requests
    
    load_anime_mode()
    load_anime4k()

    -- Synchronize the persisted Track Selector master mode immediately.
    mp.commandv("script-message-to", "track-selector", "set-enabled", tostring(track_selector_enabled))
    
	evaluate_audio()
	
    mp.add_timeout(0.1, function()
        evaluate()
        
        mp.commandv("script-message-to", "skip_intro", "toggle-state", tostring(skip_intro_enabled))
        mp.commandv("script-message-to", "Up_Next", "toggle-state", tostring(up_next_enabled))
        show_temp_osd(profile_message(), 2)
        sync_state()
        
        loading_lock = false -- Unlock after everything is done
    end)
end)

local function apply_hdr_preference()
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr = (primaries == "bt.2020" or primaries == "dci-p3")
    if is_hdr and user_hdr_mode then
        mp.set_property("tone-mapping", user_hdr_mode)
    end
    if user_target_peak and user_target_peak ~= "auto" then
        mp.set_property("target-peak", user_target_peak)
    else
        mp.set_property("target-peak", "auto")
    end
end

mp.register_script_message("save-tone-mapping", function(mode)
    user_hdr_mode = mode
    mp.set_property("tone-mapping", mode)
    save_hdr_mode() 
    mp.osd_message("Tone-Mapping: " .. mode .. " (Saved)")
    sync_state()
end)

mp.register_script_message("toggle-adaptive-sharpen", function()
    if not shaders_master_switch then 
        show_temp_osd(C.RED .. "Locked: " .. C.WHITE .. "Master Shader Switch is OFF", 2)
        return 
    end
    sharpen_enabled = not sharpen_enabled
    save_anime_mode()
    evaluate() -- Re-apply shaders without the sharpener
    local status = sharpen_enabled and (C.GREEN .. "ON") or (C.RED .. "OFF")
    show_temp_osd(C.YELLOW .. "Adaptive Sharpen: " .. status, 2)
    sync_state()
end)

mp.observe_property("video-params/primaries", "string", function() 
    mp.add_timeout(0.5, apply_hdr_preference) 
end)

-------------------------------------------------
-- GLOBAL INTERPOLATION SYNC
-------------------------------------------------
local user_preferred_sync = mp.get_property("video-sync")

mp.observe_property("interpolation", "bool", function(_, enabled)
    if enabled then
        local current_sync = mp.get_property("video-sync")
        if current_sync ~= "display-resample" then
            user_preferred_sync = current_sync
        end
        mp.set_property("video-sync", "display-resample")
    else
        if user_preferred_sync then
            mp.set_property("video-sync", user_preferred_sync)
        end
    end
end)

-------------------------------------------------
-- v2.2 RESOLUTION SHADER API
-------------------------------------------------
mp.register_script_message("set-resolution-shader", function(type, context, res, path)
    -- type is 'fsrcnnx' or 'nnedi'
    if type == "fsrcnnx" then
        user_fsrcnnx[context][res] = path
    elseif type == "nnedi" then
        user_nnedi[context][res] = path
    end
    save_anime_mode()
    evaluate()
    sync_state()
	update_uosc_menu()
    show_temp_osd("Shader Updated [" .. res .. "]: " .. path:match("([^/]+)$"), 2)
end)

mp.register_script_message("reset-resolution-shader", function(type, context, res)
    if type == "fsrcnnx" then
        user_fsrcnnx[context][res] = nil
    elseif type == "nnedi" then
        user_nnedi[context][res] = nil
    end
    save_anime_mode()
    evaluate()
    sync_state()
	update_uosc_menu()
    show_temp_osd("Shader Reset to Default [" .. res .. "]", 2)
end)

-- [NEW] Smart Feature Toggles
mp.register_script_message("toggle-up-next", function()
    up_next_enabled = not up_next_enabled
    save_anime_mode()
    -- Send command to Up_Next.lua
    mp.commandv("script-message-to", "Up_Next", "toggle-state", tostring(up_next_enabled))
    show_temp_osd("Up Next: " .. (up_next_enabled and "Enabled" or "Disabled"), 2)
    sync_state()
    update_uosc_menu()
end)

mp.register_script_message("toggle-skip-intro", function()
    skip_intro_enabled = not skip_intro_enabled
    save_anime_mode()
    -- Send command to skip_intro.lua
    mp.commandv("script-message-to", "skip_intro", "toggle-state", tostring(skip_intro_enabled))
    show_temp_osd("Skip Intro: " .. (skip_intro_enabled and "Enabled" or "Disabled"), 2)
    sync_state()
    update_uosc_menu()
end)

-------------------------------------------------
-- AUDIO METADATA OVERLAY
-------------------------------------------------
local function display_audio_metadata()
    -- Read metadata (accounting for upper/lowercase tag variations)
    local title = mp.get_property("metadata/by-key/title") or mp.get_property("metadata/by-key/TITLE") or mp.get_property("media-title", "Unknown Title")
    local artist = mp.get_property("metadata/by-key/artist") or mp.get_property("metadata/by-key/ARTIST", "Unknown Artist")
    local album = mp.get_property("metadata/by-key/album") or mp.get_property("metadata/by-key/ALBUM", "")
    local date = mp.get_property("metadata/by-key/date") or mp.get_property("metadata/by-key/DATE", "")
    
    -- Format the date to only show the year (e.g., "2026" instead of a full timestamp)
    if date ~= "" then date = " [" .. date:sub(1,4) .. "]" end
    
    -- Format album string to hide it if blank
    local album_string = ""
    if album ~= "" then album_string = "\\N" .. C.CYAN .. "{\\i1}" .. album .. date .. "{\\i0}" end

    -- Assemble the final overlay using your custom color table (C)
    local text = C.YELLOW .. "{\\fs34}{\\b1}" .. title .. "{\\b0}\\N" ..
                 C.WHITE .. "{\\fs26}" .. artist .. album_string
                 
    -- Display for 5 seconds
    show_temp_osd(text, 5) 
end

-- Triggered by the UOSC "Track Info" button
mp.register_script_message("show-audio-metadata", function()
    display_audio_metadata()
end)

-------------------------------------------------
-- ALBUM ART CYCLE
-------------------------------------------------
mp.register_script_message("cycle-album-art", function()
    local track_list = mp.get_property_native("track-list") or {}
    local video_tracks = {}
    local current_vid = tostring(mp.get_property("vid"))

    -- Collect all embedded images
    for _, track in ipairs(track_list) do
        if track.type == "video" and track.image then
            table.insert(video_tracks, tostring(track.id))
        end
    end

    -- If no images exist, notify the user and exit
    if #video_tracks == 0 then
        show_temp_osd("🖼️ No Album Art Found", 2)
        return
    end

    -- Find current image index
    local next_idx = 1
    for i, vid in ipairs(video_tracks) do
        if vid == current_vid then
            next_idx = i + 1
            break
        end
    end

    -- Loop back to the first image if we reach the end
    if next_idx > #video_tracks then
        next_idx = 1
    end

    -- Switch the track
    mp.set_property("vid", video_tracks[next_idx])
    show_temp_osd("🖼️ Album Art (" .. next_idx .. "/" .. #video_tracks .. ")", 2)
    display_audio_metadata()
end)

load_hdr_mode()
sync_state()
