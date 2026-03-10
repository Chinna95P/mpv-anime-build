-- [[ 
--    ANDROID MANAGER HQ v3.0 (Ambient-Aware Optimization)
-- ]]

local mp = require 'mp'

local power_mode = "hq"
local audio_mode = "spatial"
local shaders_enabled = true 

local SHADER_DIR = "~~/shaders/"

local ANIME_SHADERS = {
    SHADER_DIR.."FSRCNNX_x2_8-0-4-1_LineArt.glsl",
    SHADER_DIR.."SSimSuperRes.glsl",
    SHADER_DIR.."SSimDownscaler.glsl"
}
local LIVE_SHADERS = {
    SHADER_DIR.."FSRCNNX_x2_8-0-4-1.glsl",
    SHADER_DIR.."SSimSuperRes.glsl",
    SHADER_DIR.."SSimDownscaler.glsl"
}

local ignore_change = false       
local detection_done = false      
local is_anime_content = false    
local pref_anime4k = false 
local saved_shader_string = "" 
local cleanup_timer = nil

local C = { WHITE="{\\1c&HFFFFFF&}", GREEN="{\\1c&H00FF00&}", CYAN="{\\1c&HFFFF00&}", GOLD="{\\1c&H00D7FF&}", RED="{\\1c&H0000FF&}", MAGENTA="{\\1c&HFF00FF&}", GRAY="{\\1c&HAAAAAA&}" }
local POS_STYLE = "{\\an7}{\\pos(30,50)}{\\fnSans-Serif}{\\fs50}{\\b1}{\\bord3}{\\3c&H000000&}"
local TEXT_STYLE = "{\\fnSans-Serif}{\\fs50}{\\b1}{\\bord3}{\\3c&H000000&}"

local function paint(ass_text)
    local w, h = mp.get_osd_size()
    if not w or w <= 0 then w = 1920 end
    if not h or h <= 0 then h = 1080 end
    mp.set_osd_ass(w, h, ass_text)
end

local function show_status(header_text, color_code)
    if cleanup_timer then cleanup_timer:kill() end
    local shaders = mp.get_property("glsl-shaders") or ""
    local shader_status = ""
    if not shaders_enabled then shader_status = C.GRAY .. "🎞️ Shaders: Disabled"
    elseif shaders:find("Anime4K") then shader_status = C.MAGENTA .. "🎞️ Built-in Anime4K"
    elseif shaders:find("glsl") then shader_status = C.GREEN .. "🎞️ Custom Shaders"
    else shader_status = C.RED .. "🎞️ Switching..." end
    
    local audio_status = (audio_mode == "spatial") and (C.GOLD .. "🎧 Spatial Audio") or (C.WHITE .. "🔊 Standard Audio")
    local type_debug = detection_done and (is_anime_content and (C.GRAY.."Type: 📺 Anime") or (C.GRAY.."Type: 🎬 Live")) or (C.GRAY.."Type: Scanning...")
    
    local msg = POS_STYLE .. color_code .. header_text .. "\\N" .. TEXT_STYLE .. shader_status .. "\\N" .. TEXT_STYLE .. audio_status .. "\\N" .. TEXT_STYLE .. type_debug
    paint(msg)
    cleanup_timer = mp.add_timeout(3, function() paint("") end)
end

-- SMART FILTER: Suspends heavy shaders completely during orientation mismatch
local function get_safe_shaders(shader_data)
    local is_ambient = mp.get_property_bool("user-data/ambient_enabled", false)
    if not is_ambient then return shader_data end
    
    local osd_w = mp.get_property_number("osd-width", 0)
    local osd_h = mp.get_property_number("osd-height", 0)
    local vid_w = mp.get_property_number("video-params/w", 0)
    local vid_h = mp.get_property_number("video-params/h", 0)
    local rot = mp.get_property_number("video-params/rotate", 0)
    local par = mp.get_property_number("video-params/par", 1)
    
    if osd_w > 0 and vid_w > 0 then
        vid_w = vid_w * par
        if rot == 90 or rot == 270 then
            local temp = vid_w
            vid_w = vid_h
            vid_h = temp
        end
        local is_screen_portrait = (osd_h > osd_w)
        local is_video_portrait = (vid_h > vid_w)
        
        -- MISMATCH DETECTED: Video is tiny. Drop heavy shaders to save GPU.
        if is_screen_portrait ~= is_video_portrait then
            if type(shader_data) == "table" then return {} end
            if type(shader_data) == "string" then return "" end
        end
    end
    
    return shader_data
end

local function safe_apply(profile, clear_first, shader_data)
    ignore_change = true 
    if clear_first then mp.command("no-osd change-list glsl-shaders clr \"\"") end
    mp.commandv("apply-profile", profile)
    
    local active_shaders = get_safe_shaders(shader_data)
    
    if shaders_enabled and active_shaders then
        if type(active_shaders) == "table" then
            for _, path in ipairs(active_shaders) do mp.commandv("change-list", "glsl-shaders", "append", path) end
        elseif type(active_shaders) == "string" and active_shaders ~= "" then
            mp.set_property("glsl-shaders", active_shaders)
        end
    end
    
    mp.commandv("script-message", "rehook-ambient")
    mp.add_timeout(0.5, function() ignore_change = false end)
end

local function restore_shaders(shader_string)
    ignore_change = true
    mp.command("no-osd change-list glsl-shaders clr \"\"")
    
    local safe_string = get_safe_shaders(shader_string)
    
    if shaders_enabled and safe_string and safe_string ~= "" then 
        mp.set_property("glsl-shaders", safe_string) 
    end
    
    mp.commandv("script-message", "rehook-ambient")
    mp.add_timeout(0.5, function() ignore_change = false end)
end

local function run_detection()
    local path, filename, title = mp.get_property("path", ""):lower(), mp.get_property("filename", ""):lower(), mp.get_property("media-title", ""):lower()
    local signal_crc, signal_folder, signal_brackets = filename:match("%[%x%x%x%x%x%x%x%x%]"), path:find("anime"), filename:match("^%[.*%]") 
    
    local signal_audio = false
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "audio" then
            local lang, t = (track.lang or ""):lower(), (track.title or ""):lower()
            if lang == "jpn" or lang == "ja" or t:find("jap") or t:find("jpn") then signal_audio = true break end
        end
    end

    if filename:find("live action") or filename:find("live%-action") then is_anime_content = false
    elseif signal_crc or signal_folder or signal_brackets or signal_audio then is_anime_content = true
    else is_anime_content = false end
    detection_done = true 
end

local function enforce_rules()
    if ignore_change or not detection_done then return end

    if power_mode == "eco" then
        if mp.get_property("glsl-shaders") ~= "" then
             mp.command("no-osd change-list glsl-shaders clr \"\"")
             mp.commandv("apply-profile", "Battery-Saver")
             show_status("Mode: ⚡ Battery Saver (Locked)", C.RED)
        end
        return
    end

    local w = mp.get_property_number("video-params/w") or 0
    if w > 3840 then
        if mp.get_property("glsl-shaders", "") ~= "" then
            mp.command("no-osd change-list glsl-shaders clr \"\"")
            mp.commandv("apply-profile", "8K-Optimized")
            show_status("⛔ 8K: Shaders Blocked", C.RED)
            ignore_change = true
            mp.add_timeout(0.5, function() ignore_change = false end)
        else
            safe_apply("8K-Optimized", false)
            show_status("Mode: ⚡ 8K Optimized", C.MAGENTA)
        end
        return
    end

    local current_shaders = mp.get_property("glsl-shaders", "")
    if is_anime_content then
        if current_shaders:find("Anime4K") and shaders_enabled then show_status("Mode: Anime (Anime4K)", C.MAGENTA)
        elseif (current_shaders:find("FSRCNNX") or current_shaders:find("SSim")) and shaders_enabled then 
        else
            if pref_anime4k and saved_shader_string ~= "" and shaders_enabled then
                restore_shaders(saved_shader_string)
                show_status("Mode: Anime (Restored)", C.MAGENTA)
            else
                safe_apply("Anime-FSR", true, ANIME_SHADERS)
                show_status("Mode: Anime " .. (shaders_enabled and "(FSRCNNX)" or "(Profile Only)"), C.GREEN)
            end
        end
    else
        if current_shaders:find("Anime4K") or current_shaders == "" or not shaders_enabled then
            safe_apply("Live-Action", true, LIVE_SHADERS)
            show_status("Mode: Live Action " .. (shaders_enabled and "(HQ)" or "(Profile Only)"), C.CYAN)
        end
    end
end

function apply_audio()
    if audio_mode == "spatial" then mp.commandv("apply-profile", "Cinema-Spatial")
    else mp.commandv("apply-profile", "Standard-Audio") end
end

local function toggle_power_mode()
    power_mode = (power_mode == "hq") and "eco" or "hq"
    if power_mode == "eco" then
        mp.command("no-osd change-list glsl-shaders clr \"\"")
        mp.commandv("apply-profile", "Battery-Saver")
        show_status("Mode: ⚡ Battery Saver", C.RED)
    else ignore_change = false enforce_rules() end
    apply_audio()
end

local function toggle_audio_mode()
    audio_mode = (audio_mode == "std") and "spatial" or "std"
    apply_audio()
    show_status("Audio: " .. ((audio_mode == "spatial") and "Spatial" or "Standard"), (audio_mode == "spatial") and C.GOLD or C.WHITE)
end

local function toggle_shaders_mode()
    shaders_enabled = not shaders_enabled
    if not shaders_enabled then
        ignore_change = true
        mp.command("no-osd change-list glsl-shaders clr \"\"")
        show_status("Shaders: Disabled", C.GRAY)
        mp.add_timeout(0.5, function() ignore_change = false end)
    else ignore_change = false enforce_rules() end
end

mp.register_script_message("safe-enable-shader", function(shader_string)
    if (mp.get_property_number("video-params/w") or 0) > 3840 then show_status("⛔ 8K: Shaders Blocked", C.RED) return end
    if power_mode == "eco" then show_status("⛔ Battery Mode Active", C.RED) return end
    if not shaders_enabled then shaders_enabled = true end

    ignore_change = true
    mp.set_property("glsl-shaders", shader_string)
    
    pref_anime4k = true
    saved_shader_string = shader_string
    
    mp.commandv("script-message", "rehook-ambient")
    mp.add_timeout(0.5, function() ignore_change = false end)
end)

mp.observe_property("glsl-shaders", "string", function(name, val)
    local v = val or ""
    if power_mode == "hq" and shaders_enabled and not ignore_change then
        if v == "" then pref_anime4k = false saved_shader_string = "" 
        elseif v:find("Anime4K") then pref_anime4k = true saved_shader_string = v 
        elseif v:find("FSRCNNX") or v:find("SSim") then pref_anime4k = false end
    end
    if v and not ignore_change then enforce_rules() end
end)

mp.observe_property("osd-dimensions", "native", function()
    if mp.get_property_bool("user-data/ambient_enabled", false) then
        ignore_change = false
        enforce_rules()
    end
end)

mp.register_event("file-loaded", function()
    apply_audio()
    detection_done = false 
    mp.add_timeout(0.5, function()
        run_detection()  
        enforce_rules()  
    end)
end)

mp.register_script_message("reevaluate-hq-shaders", function()
    ignore_change = false
    enforce_rules()
end)

mp.register_script_message("toggle-power-mode", toggle_power_mode)
mp.register_script_message("toggle-audio-mode", toggle_audio_mode)
mp.register_script_message("toggle-shaders-mode", toggle_shaders_mode)