-- [[ 
--    ANDROID MANAGER v11: SAFE ACTIVE MONITOR
--    * Base: Restored v6 detection logic (Working).
--    * Feature: Active Monitoring (Reacts to mid-playback toggles).
--    * Fix: "Safety Lock" prevents enforcing rules until detection finishes.
--    * Bonus: Added CRC32 detection for your [Hash] filenames.
-- ]]

local mp = require 'mp'

-- CONFIGURATION
local power_mode = "hq"
local audio_mode = "spatial"

-- STATE
local ignore_change = false       -- Lock to prevent infinite loops during apply
local detection_done = false      -- Safety Lock: Don't enforce rules until we know what the video is!
local is_anime_content = false    -- The result of our detection

-- 1. UTILS
local function show_status(text)
    mp.add_timeout(0.1, function()
        local shaders = mp.get_property("glsl-shaders") or ""
        local af = mp.get_property("af") or ""
        
        local shader_status = "🖥️ No Shaders"
        if shaders:find("Anime4K") then shader_status = "✨ Built-in Anime4K"
        elseif shaders:find("glsl") then shader_status = "✨ Custom Shaders" 
        end
        
        local audio_status = af:find("surround") and "🎧 Spatial Audio" or "🔊 Standard"
        
        -- Debug info to prove detection is working
        local type_debug = detection_done and (is_anime_content and "Type: Anime" or "Type: Live") or "Type: Scanning..."
        
        mp.commandv("show-text", text .. "\n" .. shader_status .. "\n" .. audio_status .. "\n" .. type_debug, 3000)
    end)
end

-- HELPER: Safe Apply (Prevents Loops)
local function safe_apply(profile, clear_first)
    ignore_change = true 
    if clear_first then
        mp.command("no-osd change-list glsl-shaders clr \"\"")
    end
    mp.commandv("apply-profile", profile)
    mp.add_timeout(0.5, function() ignore_change = false end)
end

-- 2. DETECTION LOGIC (Expanded v6 Logic)
local function run_detection()
    local path = mp.get_property("path", "") or ""
    local filename = mp.get_property("filename", "") or ""
    local title = mp.get_property("media-title", "") or ""
    
    local p_lo = path:lower()
    local f_lo = filename:lower()
    local t_lo = title:lower()

    -- A. CRC32 Check (Strongest Signal) - e.g. [CE676F93]
    local crc_pattern = "%[%x%x%x%x%x%x%x%x%]"
    local signal_crc = f_lo:match(crc_pattern) or t_lo:match(crc_pattern)

    -- B. Standard Checks (from v6)
    local signal_folder = p_lo:find("anime")
    local signal_brackets = f_lo:match("^%[.*%]") -- Starts with [Group]
    
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
    -- STRICT: Only match explicit "live action"
    local signal_live = f_lo:find("live action") or f_lo:find("live%-action")

    -- DECISION
    if signal_live then
        is_anime_content = false
    elseif signal_crc or signal_folder or signal_brackets or signal_audio then
        is_anime_content = true
    else
        is_anime_content = false -- Default to Live if no signals found
    end

    detection_done = true -- UNLOCK THE ACTIVE MONITOR
end

-- 3. ENFORCEMENT LOGIC (The "Active" Part)
local function enforce_rules()
    -- SAFETY: Stop if we are locked OR if detection hasn't run yet
    if ignore_change or not detection_done then return end

    -- Power Mode Check
    if power_mode == "eco" then
        if mp.get_property("glsl-shaders") ~= "" then
             mp.command("no-osd change-list glsl-shaders clr \"\"")
             show_status("⚡ Mode: Battery Saver (Locked)")
        end
        return
    end

    local current_shaders = mp.get_property("glsl-shaders", "")
    
    if is_anime_content then
        -- ANIME LOGIC
        if current_shaders:find("Anime4K") then
            show_status("Mode: Anime (Anime4K)") -- Allow App Anime4K
        elseif current_shaders:find("FSRCNNX") or current_shaders:find("SSim") then
            -- Allow Custom Shaders
        else
            -- No shaders? Fallback to FSRCNNX
            safe_apply("Anime-FSR", true)
            show_status("Mode: Anime (FSRCNNX)")
        end
    else
        -- LIVE ACTION LOGIC
        -- If user tries to turn on Anime4K, kill it.
        if current_shaders:find("Anime4K") or current_shaders == "" then
            safe_apply("Live-Action", true)
            show_status("Mode: Live Action (HQ)")
        end
    end
end

-- 4. AUDIO & TOGGLES (Unchanged)
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
        show_status("⚡ Mode: Battery Saver")
    else
        ignore_change = false
        enforce_rules()
    end
    apply_audio()
end

local function toggle_audio_mode()
    if audio_mode == "std" then
        audio_mode = "spatial"
        mp.commandv("apply-profile", "Cinema-Spatial")
        show_status("🎧 Audio: Spatial")
    else
        audio_mode = "std"
        mp.commandv("apply-profile", "Standard-Audio")
        show_status("🔊 Audio: Standard")
    end
end

-- 5. LISTENERS

-- A. Active Monitor
-- This watches for changes, BUT `enforce_rules` will exit immediately 
-- if `detection_done` is false. This fixes the race condition.
mp.observe_property("glsl-shaders", "string", function(name, val)
    if val and not ignore_change then enforce_rules() end
end)

-- B. File Load (The Sequence)
mp.register_event("file-loaded", function()
    -- Reset state for new file
    detection_done = false 
    
    -- Wait 0.5s for Metadata/Audio Tracks
    mp.add_timeout(0.5, function()
        run_detection()  -- 1. Decide what it is
        apply_audio()    -- 2. Apply Audio
        enforce_rules()  -- 3. Apply Video Rules (Now allowed to run)
    end)
end)

mp.register_script_message("toggle-power-mode", toggle_power_mode)
mp.register_script_message("toggle-audio-mode", toggle_audio_mode)