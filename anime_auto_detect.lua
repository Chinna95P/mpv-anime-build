-- [[ 
--    ANDROID MANAGER v1.2: SMART FALLBACK
--    * Logic: 'OFF' now defaults to 'FSRCNNX' instead of 'No Shaders'.
--    * Result: Toggling off Anime4K instantly activates FSRCNNX.
--    * Note: To disable shaders completely, use 'Battery Saver' mode.
-- ]]

local mp = require 'mp'

-- CONFIGURATION
local power_mode = "hq"
local audio_mode = "spatial"

-- STATE
local ignore_change = false       
local detection_done = false      
local is_anime_content = false    
local pref_anime4k = false 
local saved_shader_string = "" 
local osd_timer = nil 

-- COLORS (BGR Hex for ASS)
local C = {
    WHITE   = "{\\1c&HFFFFFF&}",
    GREEN   = "{\\1c&H00FF00&}", 
    CYAN    = "{\\1c&HFFFF00&}", 
    GOLD    = "{\\1c&H00D7FF&}", 
    RED     = "{\\1c&H0000FF&}", 
    MAGENTA = "{\\1c&HFF00FF&}", 
    GRAY    = "{\\1c&HAAAAAA&}"  
}

-- STYLES
local POS_STYLE = "{\\an7}{\\pos(30,50)}{\\fnSans-Serif}{\\fs50}{\\b1}{\\bord3}{\\3c&H000000&}"
local TEXT_STYLE = "{\\fnSans-Serif}{\\fs50}{\\b1}{\\bord3}{\\3c&H000000&}"

-- 1. UTILS (PAINTER)
local function paint(ass_text)
    mp.set_osd_ass(1920, 1080, ass_text)
end

local function show_status(header_text, color_code)
    if osd_timer then osd_timer:kill() end

    mp.add_timeout(0.1, function()
        local shaders = mp.get_property("glsl-shaders") or ""
        local af = mp.get_property("af") or ""
        
        -- SHADER STATUS
        local shader_status = ""
        if shaders:find("Anime4K") then 
            shader_status = C.MAGENTA .. "🎞️ Built-in Anime4K"
        elseif shaders:find("glsl") then 
            shader_status = C.GREEN .. "🎞️ Custom Shaders"
        else
            shader_status = C.RED .. "🎞️ Switching..."
        end
        
        -- AUDIO STATUS
        local audio_status = ""
        if af:find("surround") then
            audio_status = C.GOLD .. "🎧 Spatial Audio"
        else
            audio_status = C.WHITE .. "🔊 Standard Audio"
        end
        
        -- DEBUG INFO
        local type_debug = ""
        if detection_done then
            type_debug = is_anime_content and (C.GRAY.."Type: 📺 Anime") or (C.GRAY.."Type: 🎬 Live")
        else
            type_debug = C.GRAY.."Type: Scanning..."
        end
        
        -- COMPOSE
        local msg = POS_STYLE .. color_code .. header_text .. "\\N" 
                  .. TEXT_STYLE .. shader_status .. "\\N"
                  .. TEXT_STYLE .. audio_status .. "\\N"
                  .. TEXT_STYLE .. type_debug
        
        paint(msg)
        
        osd_timer = mp.add_timeout(3, function() paint("") end)
    end)
end

-- HELPER: Safe Apply
local function safe_apply(profile, clear_first)
    ignore_change = true 
    if clear_first then
        mp.command("no-osd change-list glsl-shaders clr \"\"")
    end
    mp.commandv("apply-profile", profile)
    mp.add_timeout(0.5, function() ignore_change = false end)
end

-- HELPER: Restore Raw Shaders (For Built-in Anime4K)
local function restore_shaders(shader_string)
    ignore_change = true
    mp.command("no-osd change-list glsl-shaders clr \"\"")
    if shader_string and shader_string ~= "" then
        mp.commandv("set", "glsl-shaders", shader_string)
    end
    mp.add_timeout(0.5, function() ignore_change = false end)
end

-- 2. DETECTION LOGIC
local function run_detection()
    local path = mp.get_property("path", "") or ""
    local filename = mp.get_property("filename", "") or ""
    local title = mp.get_property("media-title", "") or ""
    
    local p_lo = path:lower()
    local f_lo = filename:lower()
    local t_lo = title:lower()

    -- A. CRC32 Check
    local crc_pattern = "%[%x%x%x%x%x%x%x%x%]"
    local signal_crc = f_lo:match(crc_pattern) or t_lo:match(crc_pattern)

    -- B. Standard Checks
    local signal_folder = p_lo:find("anime")
    local signal_brackets = f_lo:match("^%[.*%]") 
    
    -- C. Audio Check
    local signal_audio = false
    local track_list = mp.get_property_native("track-list") or {}
    for _, track in ipairs(track_list) do
        if track.type == "audio" then
            local lang = (track.lang or ""):lower()
            local t = (track.title or ""):lower()
            if lang == "jpn" or lang == "ja" or t:find("jap") or t:find("jpn") then
                signal_audio = true
                break
            end
        end
    end

    -- D. Live Action Override
    local signal_live = f_lo:find("live action") or f_lo:find("live%-action")

    -- DECISION
    if signal_live then
        is_anime_content = false
    elseif signal_crc or signal_folder or signal_brackets or signal_audio then
        is_anime_content = true
    else
        is_anime_content = false 
    end

    detection_done = true 
end

-- 3. ENFORCEMENT LOGIC (Updated v20)
local function enforce_rules()
    if ignore_change or not detection_done then return end

    -- Power Mode Check
    if power_mode == "eco" then
        if mp.get_property("glsl-shaders") ~= "" then
             mp.command("no-osd change-list glsl-shaders clr \"\"")
             show_status("Mode: ⚡ Battery Saver (Locked)", C.RED)
        end
        return
    end

    local current_shaders = mp.get_property("glsl-shaders", "")
    
    if is_anime_content then
        -- ANIME LOGIC
        if current_shaders:find("Anime4K") then
            -- Active Anime4K
            show_status("Mode: Anime (Anime4K)", C.MAGENTA)
            
        elseif current_shaders:find("FSRCNNX") or current_shaders:find("SSim") then
            -- Active Custom Shaders
            
        else
            -- [v20 LOGIC] No Shaders found?
            -- It means user turned off Anime4K, so we FALLBACK to FSRCNNX.
            
            if pref_anime4k and saved_shader_string ~= "" then
                -- This path is for restoring AFTER Battery Mode
                restore_shaders(saved_shader_string)
                show_status("Mode: Anime (Restored)", C.MAGENTA)
            else
                -- This path is for Manual Disable -> Auto Re-enable
                safe_apply("Anime-FSR", true)
                show_status("Mode: Anime (FSRCNNX)", C.GREEN)
            end
        end
    else
        -- LIVE ACTION LOGIC
        if current_shaders:find("Anime4K") or current_shaders == "" then
            safe_apply("Live-Action", true)
            show_status("Mode: Live Action (HQ)", C.CYAN)
        end
    end
end

-- 4. AUDIO & TOGGLES
local function apply_audio()
    if audio_mode == "spatial" then
        mp.commandv("apply-profile", "Cinema-Spatial")
    else
        mp.commandv("apply-profile", "Standard-Audio")
    end
end

local function toggle_power_mode()
    power_mode = (power_mode == "hq") and "eco" or "hq"
    if power_mode == "eco" then
        mp.command("no-osd change-list glsl-shaders clr \"\"")
        mp.commandv("apply-profile", "Battery-Saver")
        show_status("Mode: ⚡ Battery Saver", C.RED)
    else
        ignore_change = false
        enforce_rules() -- Triggers re-evaluation
    end
    apply_audio()
end

local function toggle_audio_mode()
    if audio_mode == "std" then
        audio_mode = "spatial"
        mp.commandv("apply-profile", "Cinema-Spatial")
        show_status("Audio: Spatial", C.GOLD)
    else
        audio_mode = "std"
        mp.commandv("apply-profile", "Standard-Audio")
        show_status("Audio: Standard", C.WHITE)
    end
end

-- 5. LISTENERS
mp.observe_property("glsl-shaders", "string", function(name, val)
    local v = val or ""
    
    -- [v20] Logic: Detect Manual Disable
    if power_mode == "hq" and not ignore_change then
        
        if v == "" then
            -- Shaders Cleared -> Reset preference to FSRCNNX
            -- This triggers enforce_rules -> applies Anime-FSR
            pref_anime4k = false
            saved_shader_string = "" 
            
        elseif v:find("Anime4K") then
            -- User manually enabled Anime4K
            pref_anime4k = true
            saved_shader_string = v 
            
        elseif v:find("FSRCNNX") or v:find("SSim") then
            -- User manually enabled Custom Shaders
            pref_anime4k = false
        end
    end

    if v and not ignore_change then enforce_rules() end
end)

mp.register_event("file-loaded", function()
    detection_done = false 
    mp.add_timeout(0.5, function()
        run_detection()  
        apply_audio()    
        enforce_rules()  
    end)
end)

mp.register_script_message("toggle-power-mode", toggle_power_mode)
mp.register_script_message("toggle-audio-mode", toggle_audio_mode)