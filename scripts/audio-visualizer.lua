-- [[
--    FILENAME: audio-visualizer.lua
--    VERSION:  v3.6 (Particle Visualizer)
--    DESCRIPTION: Crash-free visualizer cycler + toggle for Audio files only
-- ]]

local mp = require("mp")

-- Visualizer Styles (Ported safely, matching UOSC background color: 101218)
local styles = {
    { name = "CQT Bars", filter = "showcqt=s=1280x720:fps=60:bar_h=200:axis_h=0" },
    { name = "Vectorscope", filter = "avectorscope=s=1280x720:draw=line" },
    { name = "Spectrum", filter = "showspectrum=s=1280x720:mode=separate:color=intensity:slide=scroll:scale=cbrt" },
    { name = "Mirrored Stereo Lines", filter = "showwaves=s=1280x720:mode=cline:colors=0x00FFFF|0xFF00FF:split_channels=1" },
    { name = "Waveform", filter = "showwaves=s=1280x720:mode=cline:colors=0x00FFFF" },
    { name = "Smooth Flow Wave", filter = "showwaves=s=1280x720:mode=p2p:colors=0x00FFFF|0xFF00FF:scale=log" },
    { name = "Solid EQ Mountain", filter = "showfreqs=s=1280x720:mode=bar:fscale=log:ascale=cbrt:colors=0x00FFFF|0xFF00FF" },
    { name = "Frequency Axis", filter = "showfreqs=s=1280x720:mode=dot:ascale=log:fscale=log:colors=0x00FFFF|0xFF00FF,drawbox=x=(iw-1)/2:y=0:w=1:h=ih:color=white@0.3,drawbox=x=0:y=(ih-1)/2:w=iw:h=1:color=white@0.3" },

    -- [v4.7] New Visualizers
    -- [NEW] Modern Smooth & Solid Visualizers
    -- [NEW] X/Y Center-Origin Graph Visualizers
    { name = "Cartesian Particles", filter = "avectorscope=s=1280x720:mode=lissajous_xy:draw=dot:scale=cbrt:zoom=1.2:rc=0:gc=255:bc=255:ac=255,drawbox=x=(iw-1)/2:y=0:w=1:h=ih:color=white@0.4,drawbox=x=0:y=(ih-1)/2:w=iw:h=1:color=white@0.4" },

    {
        name = "Particles (Tri-Layer Ultra-Fast)",
        filter = table.concat({
            "aformat=channel_layouts=stereo,asplit=3[vert][horiz][core]",

            -- 1. Generate all three layers at half-resolution (640x360)
        "[vert]pan=stereo|c0=0.70*c0|c1=0.035*c1,avectorscope=s=640x360:r=60:mode=lissajous_xy:draw=dot:scale=lin:zoom=1:rc=95:gc=145:bc=210:ac=220:rf=5:gf=6:bf=3:af=8[v]",
        "[horiz]pan=stereo|c0=0.045*c0|c1=0.58*c1,avectorscope=s=640x360:r=60:mode=lissajous_xy:draw=dot:scale=lin:zoom=1:rc=165:gc=95:bc=190:ac=200:rf=7:gf=9:bf=5:af=10[h]",
        "[core]volume=0.34,avectorscope=s=640x360:r=60:mode=lissajous:draw=dot:scale=lin:zoom=1.1:rc=140:gc=190:bc=255:ac=180:rf=10:gf=7:bf=4:af=12[c]",

        -- 2. Blend them together at half-resolution (incredibly fast)
        "[v][h]blend=all_mode=screen:all_opacity=0.75[vh]",
        "[vh][c]blend=all_mode=screen:all_opacity=0.85[mixed]",

        -- 3. Scale the final blended image back to 720p to fit your MPV background
        "[mixed]scale=1280:720:flags=fast_bilinear,format=rgba"
        }, "; ")
    },
    {
        name = "Wisp Cloud",
        filter = table.concat({

            "aformat=channel_layouts=stereo,asplit=3[low][mid][core]",

            -- ------------------------------------------------------------
            -- 1. Low-frequency vertical plume
            -- ------------------------------------------------------------
            "[low]pan=stereo|c0=0.82*c0+0.08*c1|c1=0.08*c0+0.82*c1," ..
            "avectorscope=" ..
            "s=480x270:r=30:" ..
            "mode=lissajous_xy:" ..
            "draw=dot:" ..
            "scale=cbrt:" ..
            "zoom=1.15:" ..
            "rc=210:gc=245:bc=255:ac=190:" ..
            "rf=7:gf=6:bf=4:af=10[low_v]",

            -- ------------------------------------------------------------
            -- 2. Horizontal energy wisps
            -- ------------------------------------------------------------
            "[mid]pan=stereo|c0=0.10*c0+0.90*c1|c1=0.90*c0+0.10*c1," ..
            "avectorscope=" ..
            "s=480x270:r=30:" ..
            "mode=lissajous_xy:" ..
            "draw=dot:" ..
            "scale=cbrt:" ..
            "zoom=1.35:" ..
            "rc=255:gc=225:bc=245:ac=165:" ..
            "rf=6:gf=7:bf=5:af=9[mid_h]",

            -- ------------------------------------------------------------
            -- 3. Bright central particle core
            -- ------------------------------------------------------------
            "[core]volume=0.42," ..
            "avectorscope=" ..
            "s=480x270:r=30:" ..
            "mode=lissajous:" ..
            "draw=dot:" ..
            "scale=cbrt:" ..
            "zoom=1.0:" ..
            "rc=245:gc=255:bc=255:ac=210:" ..
            "rf=10:gf=8:bf=6:af=12[core_c]",

            -- ------------------------------------------------------------
            -- 4. Give the horizontal layer a very wide shape.
            -- ------------------------------------------------------------
            "[mid_h]scale=960x180:flags=fast_bilinear," ..
            "crop=960:180:0:45," ..
            "gblur=sigma=1.2:steps=1[hwide]",

            -- ------------------------------------------------------------
            -- 5. Give the vertical layer a tall/narrow shape.
            -- ------------------------------------------------------------
            "[low_v]scale=300x540:flags=fast_bilinear," ..
            "crop=300:540:0:135," ..
            "gblur=sigma=1.0:steps=1[vwide]",

            -- ------------------------------------------------------------
            -- 6. Keep the core sharper than the two wisp layers.
            -- ------------------------------------------------------------
            "[core_c]gblur=sigma=0.45:steps=1[core_soft]",

            -- ------------------------------------------------------------
            -- 7. Put the layers together.
            -- ------------------------------------------------------------
            "color=c=0x101218:s=960x540:r=30[canvas]",

            "[canvas][hwide]overlay=" ..
            "x=0:y=180:shortest=1[stage1]",

            "[stage1][vwide]overlay=" ..
            "x=330:y=0:shortest=1[stage2]",

            "[stage2][core_soft]overlay=" ..
            "x=240:y=135:shortest=1[mix]",

            -- ------------------------------------------------------------
            -- 8. Very light bloom.
            -- ------------------------------------------------------------
            "[mix]split=2[sharp][glow]",

            "[glow]gblur=sigma=5:steps=1,format=rgba[glow_blur]",

            "[sharp][glow_blur]blend=" ..
            "all_mode=screen:all_opacity=0.22[final]",

            -- ------------------------------------------------------------
            -- 9. Final MPV visualizer size.
            -- ------------------------------------------------------------
            "[final]scale=1280:720:flags=fast_bilinear,format=rgba"
        }, "; ")
    },


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
