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
local BUILD_VERSION = "v1.9.4"

-- [STATE CACHE]
local anime_state = {
    mode_auto = true,
    mode_on = false,
    mode_off = false,
    vsr_active = false,   -- Track VSR State
    power_active = false  -- [NEW] Track Power State
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

local function get_active_shader()
    local shaders = mp.get_property("glsl-shaders") or ""
    if shaders == "" then return "Native (Lanczos/Spline)" end
    
    if string.find(shaders, "anime_enhance") then return "FSRCNNX 16 (Anime)" end
    if string.find(shaders, "LineArt") then return "FSRCNNX 8 (Anime)" end
    if string.find(shaders, "Anime4K") then return "Anime4K (Active)" end
    
    if string.find(shaders, "nnedi3") then 
        if string.find(shaders, "256") then return "NNEDI3 (High-256)" end
        return "NNEDI3 (Standard)"
    end
    if string.find(shaders, "FSRCNNX") then
        if string.find(shaders, "16%-0%-4%-1") then return "FSRCNNX 16 (Live)" end
        if string.find(shaders, "8%-0%-4%-1") then return "FSRCNNX 8 (Live)" end
        return "FSRCNNX (Generic)"
    end

    if string.find(shaders, "adaptive%-sharpen") then return "Adaptive Sharpen" end
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
    
    -- Check for HDR Content (BT.2020 or DCI-P3)
    if prim == "bt.2020" or prim == "dci-p3" then
        if hint == "yes" then 
            return GN .. "HDR (Passthrough)"
        else 
            -- Get the active algorithm name
            local tm_method = mp.get_property("tone-mapping") or "unknown"
            return CY .. "HDR (Tone-Mapping) [" .. tm_method .. "]" 
        end
    end
    return GR .. "SDR (Standard)"
end

function update_osd()
    if not active then return end
    
    -- INPUT RESOLUTION
    local w_in = mp.get_property_number("video-params/w") or 0
    local h_in = mp.get_property_number("video-params/h") or 0
    
    -- [NEW] OUTPUT RESOLUTION (Window Size)
    local w_out = mp.get_property_number("osd-width") or 0
    local h_out = mp.get_property_number("osd-height") or 0
    
    local drop_count = mp.get_property("frame-drop-count") or 0
    local fps = mp.get_property("estimated-vf-fps") or 0
    
    local scaler = get_active_shader()
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
    local BOX_W = 500  
    local BOX_H = 320  
    
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
                       "{\\fnSegoe UI Semibold}{\\fs25}{\\bord0}{\\shad1}{\\1c&HFFFFFF&}{\\3c&H000000&}"

    local content = ""
    -- HEADER
    content = content .. "{\\fs32}" .. CY .. "ANIME BUILD " .. BUILD_VERSION .. " STATS\\N"
    content = content .. "{\\fs25}" .. GR .. "--------------------------------------------------------\\N"
    
    -- DATA
    content = content .. GR .. "Mode:      " .. WH .. mode_str .. "\\N"
    content = content .. GR .. "Scaler:    " .. scaler_color .. scaler .. "\\N"
    
    -- [NEW] RESOLUTION LINE
    content = content .. GR .. "Res:       " .. WH .. w_in .. "x" .. h_in .. GR .. " -> " .. WH .. w_out .. "x" .. h_out .. "\\N"
    
    content = content .. GR .. "FPS:       " .. WH .. string.format("%.2f", fps) .. GR .. " (Drops: " .. RD .. drop_count .. GR .. ")\\N"
    content = content .. "\\N"
    
    -- SECTION 2 HEADER
    content = content .. "{\\fs32}" .. CY .. "AUDIO & HDR\\N"
    content = content .. "{\\fs25}" .. GR .. "--------------------------------------------------------\\N"
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