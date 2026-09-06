-- [[ 
--    FILENAME: stats_overlay.lua
--    DESCRIPTION: "Neon Glass" Stats Overlay (Layout Shifted Down)
--    DESIGN: Hard-coded 720p Canvas. Shifted Y-axis to clear OSD messages.
--    TRIGGER: script-binding toggle-stats
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local osd = mp.create_osd_overlay("ass-events")
local active = false
local timer = nil

-- [VERSION INFO]
local opts = require 'mp.options'
local config = { version = "v0.0.0" } -- Fallback default
opts.read_options(config, "build_info")
local BUILD_VERSION = config.version

-- [STATE CACHE]
local anime_state = {
    mode_auto = true,
    mode_on = false,
    mode_off = false,
    shaders_enabled = true,
    anime_fidelity = false,
    is_anime_context = false,
    current_res_label = "",
    vsr_active = false,   -- Track VSR State
    power_active = false,  -- [NEW] Track Power State
    hdr_display_mode = "auto" -- [NEW v4.0] Track 3-Way HDR Switch
}

-- [COLORS]
local CY = "{\\c&HFFFF00&}" -- Cyan
local WH = "{\\c&HFFFFFF&}" -- White
local GR = "{\\c&HB0B0B0&}" -- Grey
local GN = "{\\c&H00FF00&}" -- Green
local RD = "{\\c&H0000FF&}" -- Red

mp.register_script_message('anime-state-broadcast', function(json)
    local data = utils.parse_json(json)
    if not data then return end
    for k, v in pairs(data) do anime_state[k] = v end
    if active then update_osd() end
end)

local function get_anime_mode_string()
    if anime_state.mode_on then return CY .. "ON (Forced)"
    elseif anime_state.mode_off then return RD .. "OFF (Native)"
    else return GN .. "AUTO (Detection)" end
end

local function shader_has(shaders, name)
    return string.find(shaders, name, 1, true) ~= nil
end

local function get_processing_context()
    if not anime_state.shaders_enabled then return "Shaders Disabled" end
    if anime_state.is_anime_context then
        return anime_state.anime_fidelity and "Anime Fidelity" or "Anime Performance"
    end
    return "Live Action"
end

-- [v2.2] ADVANCED SHADER DETECTION (Updated for Fidelity restoration chains)
local function get_active_shader()
    local shaders = mp.get_property("glsl-shaders") or ""
    if shaders == "" then return "Native (Lanczos/Spline)" end

    local fidelity_active = anime_state.is_anime_context and anime_state.anime_fidelity

    -- Fidelity uses Anime4K_Restore as a supporting anti-aliasing pass. Detect
    -- the primary FSRCNNX scaler before looking for complete Anime4K chains.
    if shader_has(shaders, "FSRCNNX") then
        -- Anime Specific
        if shader_has(shaders, "LineArt") then return "FSRCNNX 8 (LineArt)" end
        if shader_has(shaders, "anime_mild") or shader_has(shaders, "enhance_anime") then
            return "FSRCNNX 16 (Anime Mild)"
        end
        if shader_has(shaders, "anime_aggressive") or shader_has(shaders, "anime_enhance") then
            return "FSRCNNX 16 (Anime Aggressive)"
        end
        if shader_has(shaders, "anime_distort") then return "FSRCNNX 16 (Anime Distort)" end

        -- Live/General Specific
        if shader_has(shaders, "distort") then return "FSRCNNX 16 (General Distort)" end
        if shader_has(shaders, "enhance") then return "FSRCNNX 16 (General Enhance)" end

        -- Standard / Live Default
        if shader_has(shaders, "16-0-4-1") then return "FSRCNNX 16 (Standard)" end
        if shader_has(shaders, "8-0-4-1") then return "FSRCNNX 8 (Standard)" end

        return "FSRCNNX (Generic)"
    end

    -- Native 4K Fidelity intentionally has no upscaler. Its Anime4K Restore
    -- shader is still only one supporting stage, not Anime4K Performance mode.
    local restoration_only = shader_has(shaders, "Anime4K_Restore")
        and not shader_has(shaders, "Anime4K_Upscale")
        and not shader_has(shaders, "Anime4K-Ultra")
    if fidelity_active and restoration_only then
        if anime_state.current_res_label == "4K" then
            return "Native 4K (Fidelity Restore)"
        end
        return "Fidelity Restoration Chain"
    end

    -- Anime4K Performance / ArtCNN detection.
    if shader_has(shaders, "Ani4Kv2") then return "Anime4K (ArtCNN Ani4Kv2)" end
    if shader_has(shaders, "AniSD") then return "Anime4K (ArtCNN AniSD)" end
    if shader_has(shaders, "Anime4K-Ultra") then return "Anime4K (Ultra)" end
    if shader_has(shaders, "Anime4K") then
        return restoration_only and "Anime4K (Restoration Only)" or "Anime4K (Performance)"
    end

    -- NNEDI3 Detection (Neuron Count)
    if shader_has(shaders, "nnedi3") then
        if shader_has(shaders, "nns256-win8x6") then return "NNEDI3 256 (Win8x6)" end
        if shader_has(shaders, "nns256") then return "NNEDI3 256 (Ultra)" end
        if shader_has(shaders, "nns128") then return "NNEDI3 128 (High)" end
        if shader_has(shaders, "nns64") then return "NNEDI3 64 (Mid)" end
        if shader_has(shaders, "nns32") then return "NNEDI3 32 (Low)" end
        return "NNEDI3 (Standard)"
    end

    if shader_has(shaders, "adaptive-sharpen") then return "Adaptive Sharpen (Only)" end
    return "Custom Shaders"
end

local function get_audio_status()
    local spdif = mp.get_property("audio-spdif")
    local af = mp.get_property("af") or ""
    
    local out_type = (spdif ~= "no" and spdif ~= "") and (CY.."Passthrough") or "PCM"
    local upmix = string.find(af, "surround") and (GN.."ON") or (GR.."OFF")
    local night = string.find(af, "dynaudnorm") and (GN.."ON") or (GR.."OFF")
    
    return string.format("%s %s| Upmix: %s %s| Night: %s", out_type, GR, upmix, GR, night)
end

local function get_hdr_status()
    local prim = mp.get_property("video-params/primaries")
    local hint = mp.get_property("target-colorspace-hint")
    
    -- Get the 3-Way Switch State
    local switch_mode = ""
    if anime_state.hdr_display_mode == "hdr" then switch_mode = " [Forced HDR]"
    elseif anime_state.hdr_display_mode == "sdr" then switch_mode = " [Forced SDR]"
    else switch_mode = " [Auto]" end
    
    -- Check for HDR Content (BT.2020 or DCI-P3)
    if prim == "bt.2020" or prim == "dci-p3" then
        if hint == "yes" then 
            return GN .. "HDR (Passthrough)" .. GR .. switch_mode
        else 
            -- Get the active algorithm name
            local tm_method = mp.get_property("tone-mapping") or "unknown"
            return CY .. "HDR (Tone-Mapping) [" .. tm_method .. "]" .. GR .. switch_mode
        end
    end
    return GR .. "SDR (Standard)"
end

function update_osd()
    if not active then return end
    
    -- INPUT RESOLUTION
    local w_in = mp.get_property_number("video-params/w") or 0
    local h_in = mp.get_property_number("video-params/h") or 0
    
    -- [v2.2 FIX] OUTPUT RESOLUTION (Calculated Target Size)
    -- Start with Window Size (OSD Size)
    local w_out = mp.get_property_number("osd-width") or 0
    local h_out = mp.get_property_number("osd-height") or 0
    
    -- Get Video Aspect Ratio (Display AR)
    local par = mp.get_property_number("video-params/aspect") or 0
    
    -- Calculate actual fit if we have valid dimensions
    if w_out > 0 and h_out > 0 and par > 0 then
        local osd_ar = w_out / h_out
        
        if osd_ar > par then
            -- Window is wider than video (Pillarbox) -> Video fills Height, Width is scaled
            -- Example: 1920x1080 screen playing 4:3 content
            w_out = math.floor(h_out * par + 0.5)
        else
            -- Window is narrower than video (Letterbox) -> Video fills Width, Height is scaled
            -- Example: 1920x1080 screen playing 2.35:1 content
            h_out = math.floor(w_out / par + 0.5)
        end
    end
    
    local drop_count = mp.get_property("frame-drop-count") or 0
    local fps = mp.get_property("estimated-vf-fps") or 0
    
    local scaler = get_active_shader()
    local processing_context = get_processing_context()
    local scaler_color = WH
    
    -- Scaler Display Logic (Priority: Power > VSR > Standard)
    if anime_state.power_active then
        scaler = "Power Saving Mode (Eco)"
        scaler_color = GN 
    elseif anime_state.vsr_active then
        scaler = "Nvidia VSR (AI Upscale)"
        scaler_color = GN 
    end
    
    local audio = get_audio_status()
    local hdr = get_hdr_status()
    local mode_str = get_anime_mode_string()
    
    -- =========================================================================
    -- LAYOUT CONFIGURATION (720p Virtual Canvas)
    -- =========================================================================
    
    -- BOX DIMENSIONS
    local BOX_W = 560
    local BOX_H = 350
    
    local POS_X = 40   -- Left margin
    local POS_Y = 110  -- Shifted Y-axis
    
    local PAD_X = 20   -- Text padding inside box
    local PAD_Y = 15   -- Text padding inside box

    -- =========================================================================
    -- LAYER 1: THE GLASS BOX
    -- =========================================================================
    local box = "{\\playresy720}{\\an7}{\\pos("..POS_X..","..POS_Y..")}" ..
                "{\\bord2}{\\blur2}{\\3c&HFFFF00&}{\\1c&H101010&}{\\1a&H40&}" ..
                "{\\p1}m 0 0 l " .. BOX_W .. " 0 l " .. BOX_W .. " " .. BOX_H .. " l 0 " .. BOX_H .. "{\\p0}"
    
    -- =========================================================================
    -- LAYER 2: THE TEXT
    -- =========================================================================
    local text_x = POS_X + PAD_X
    local text_y = POS_Y + PAD_Y
    
    -- Monolithic Text Block
    local text_style = "{\\playresy720}{\\r}{\\an7}{\\pos("..text_x..","..text_y..")}" ..
                       "{\\fnMicrosoft Sans Serif}{\\fs22}{\\bord0}{\\shad1}{\\1c&HFFFFFF&}{\\3c&H000000&}"

    local content = ""
    -- HEADER
    content = content .. "{\\fs28}" .. CY .. "ANIME BUILD " .. BUILD_VERSION .. " STATS\\N"
    content = content .. "{\\fs22}" .. GR .. "--------------------------------------------------------\\N"
    
    -- DATA
    content = content .. GR .. "Mode:      " .. WH .. mode_str .. "\\N"
    content = content .. GR .. "Context:   " .. WH .. processing_context .. "\\N"
    content = content .. GR .. "Scaler:    " .. scaler_color .. scaler .. "\\N"
    
    -- RESOLUTION LINE
    content = content .. GR .. "Res:       " .. WH .. w_in .. "x" .. h_in .. GR .. " -> " .. WH .. w_out .. "x" .. h_out .. "\\N"
    
    content = content .. GR .. "FPS:       " .. WH .. string.format("%.2f", fps) .. GR .. " (Drops: " .. RD .. drop_count .. GR .. ")\\N"
    content = content .. "\\N"
    
    -- SECTION 2 HEADER
    content = content .. "{\\fs28}" .. CY .. "AUDIO & HDR\\N"
    content = content .. "{\\fs22}" .. GR .. "--------------------------------------------------------\\N"
    content = content .. GR .. "Audio:     " .. WH .. audio .. "\\N"
    content = content .. GR .. "Video:     " .. WH .. hdr .. "\\N"

    -- COMBINE LAYERS
    osd.data = box .. "\n" .. text_style .. content
    osd:update()
end

mp.add_key_binding(nil, "toggle-stats", function()
    active = not active
    if active then
        mp.commandv("script-message", "force-evaluate-profile")
        timer = mp.add_periodic_timer(0.5, update_osd)
        update_osd()
    else
        if timer then timer:kill() end
        osd:remove()
    end
end)
