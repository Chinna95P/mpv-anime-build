-- [[
--    FILENAME: audio-visualizer.lua
--    VERSION:  v3.5 (Window Resize Race-Condition Fix)
--    DESCRIPTION: Crash-free visualizer cycler + toggle for Audio files only
-- ]]

local mp = require("mp")

-- Visualizer Styles (Ported safely, matching UOSC background color: 101218)
local styles = {
    { name = "CQT Bars", filter = "showcqt=s=1280x720:fps=60:bar_h=200:axis_h=0" },
    { name = "Vectorscope", filter = "avectorscope=s=1280x720:draw=line" },
    { name = "Spectrum", filter = "showspectrum=s=1280x720:mode=separate:color=intensity:slide=scroll:scale=cbrt" },
    { name = "Waveform", filter = "showwaves=s=1280x720:mode=cline:colors=0x00FFFF" }
}

-- Default to 4 (Waveform)
local current_style_idx = 4 
local visualizer_active = false
local is_toggling = false

-- SAFETY LOCK: Only run if it's an audio file
local function is_audio_file()
    local track_list = mp.get_property_native("track-list") or {}
    local has_audio = false
    for _, track in ipairs(track_list) do
        if track.type == "video" and not track.image then
            return false 
        end
        if track.type == "audio" then
            has_audio = true
        end
    end
    return has_audio
end

local function get_audio_id()
    local track_list = mp.get_property_native("track-list") or {}
    for _, track in ipairs(track_list) do
        if track.type == "audio" and track.selected then
            return tostring(track.id)
        end
    end
    return "auto"
end

local function apply_visualizer()
    local aid = get_audio_id()
    if aid == "auto" then aid = "1" end -- Fallback to track 1 if auto fails

    local style = styles[current_style_idx]
    
    local filter_str = "[aid" .. aid .. "]asplit[ao][a]; " ..
                       "color=c=0x101218:s=1280x720:r=60[bg]; " ..
                       "[a]" .. style.filter .. "[fg]; " ..
                       "[bg][fg]overlay=shortest=1[vo]"
    
    mp.set_property("audio-display", "no")
    mp.set_property("vid", "no")
    mp.set_property("lavfi-complex", filter_str)
    mp.osd_message("🎵 Visualizer: " .. style.name, 2)
end

-- BUTTON 1: Cycle Styles
mp.register_script_message("cycle-vis-style", function()
    if not is_audio_file() or is_toggling then return end
    
    if not visualizer_active then
        visualizer_active = true
        -- If activating from off state, use current_style_idx instead of resetting to 1
    else
        current_style_idx = current_style_idx + 1
        if current_style_idx > #styles then
            current_style_idx = 1
        end
    end
    apply_visualizer()
end)

-- BUTTON 2: Toggle ON / OFF Mid-Playback
mp.register_script_message("toggle-vis-state", function()
    if not is_audio_file() or is_toggling then return end
    
    is_toggling = true
    visualizer_active = not visualizer_active
    
    if visualizer_active then
        apply_visualizer()
        is_toggling = false
    else
        -- Capture the audio track ID *before* destroying the filter
        local current_aid = get_audio_id()
        
        -- 1. Safely kill the complex filter FIRST
        mp.set_property("vid", "no")
        mp.set_property("lavfi-complex", "")
        
        -- CRITICAL FIX: Instantly catch the audio track before the OS window resize blocks the thread!
        mp.set_property("aid", current_aid)
        
        mp.osd_message("🎵 Visualizer: OFF", 2)
        
        -- 2. Wait 150ms for renderer to clear and window to resize, then restore album art
        mp.add_timeout(0.15, function()
            local track_list = mp.get_property_native("track-list") or {}
            local image_restored = false
            
            for _, track in ipairs(track_list) do
                if track.type == "video" and track.image then
                    mp.set_property("audio-display", "embedded-first")
                    mp.set_property("vid", tostring(track.id))
                    mp.osd_message("🖼️ Album Art Restored", 2)
                    image_restored = true
                    break
                end
            end
            
            if not image_restored then
                mp.set_property("vid", "auto")
            end
            is_toggling = false 
        end)
    end
end)

-- Cleanup on track end to prevent pipeline collision on next track
mp.register_event("end-file", function()
    is_toggling = false
    mp.set_property("lavfi-complex", "")
end)

-- Re-apply visualizer automatically on next track if it was left ON
mp.register_event("file-loaded", function()
    if visualizer_active and is_audio_file() then
        -- Wait a fraction of a second for the audio pipeline to establish itself safely
        mp.add_timeout(0.1, function()
            apply_visualizer()
        end)
    end
end)