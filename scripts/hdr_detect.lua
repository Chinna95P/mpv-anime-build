-- scripts/hdr_detect.lua
-- Automatically enables HDR Passthrough if Windows HDR is active.
-- Falls back to high-quality Tone Mapping if Windows HDR is OFF.
-- Includes Manual Toggle with Safety Checks (Video must be HDR + Windows must be HDR).

local mp = require 'mp'

-- Create an OSD Overlay
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil

-- Color Codes (ASS Format: &HBBGGRR&)
local C_GREEN  = "{\\c&H00FF00&}"  -- Bright Green (Passthrough)
local C_BLUE   = "{\\c&HFFFF00&}"  -- Cyan/Blue (Tone Mapping)
local C_RED    = "{\\c&H0000FF&}"  -- Red (Error)
local C_WHITE  = "{\\c&HFFFFFF&}"  -- White (Reset)

-- Helper: Show OSD Message (Top-Right to avoid Profile OSD overlap)
function show_hdr_osd(text)
    overlay.data = "{\\an9}{\\fs26}" .. text
    overlay:update()
    if timer then timer:kill() end
    timer = mp.add_timeout(3, function() overlay:remove() end)
end

-- Helper: Check Windows HDR Status (Returns true/false)
function is_windows_hdr_active()
    local display_params = mp.get_property_native("display-params")
    if not display_params then return false end
    
    -- Check for BT.2020 or PQ Gamma (Indicators of OS-level HDR)
    if display_params.primaries == "bt.2020" or display_params.gamma == "pq" or display_params.gamma == "st2084" then
        return true
    end
    return false
end

-- 1. AUTOMATIC DETECTION (Runs on file load / OS switch)
function check_hdr_state()
    local is_windows_hdr = is_windows_hdr_active()
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local is_hdr_video = video_peak > 1

    if is_hdr_video and is_windows_hdr then
        -- Passthrough Mode
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "clip")
        show_hdr_osd(C_GREEN .. "HDR Mode: Passthrough " .. C_WHITE .. "(Windows HDR Detected)")
    elseif is_hdr_video then
        -- Tone Mapping Mode
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        show_hdr_osd(C_BLUE .. "HDR Mode: Tone Mapping " .. C_WHITE .. "(Windows HDR OFF)")
    else
        mp.set_property("target-colorspace-hint", "no")
    end
end

-- 2. MANUAL TOGGLE (Runs when you press 'H')
function toggle_hdr_manual()
    -- SAFETY CHECK 1: Is this video even HDR?
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    if video_peak <= 1 then
        show_hdr_osd(C_RED .. "Error: Not an HDR Video")
        return
    end

    local current_mode = mp.get_property("target-colorspace-hint")
    
    if current_mode == "yes" then
        -- User wants to switch OFF Passthrough (Go to Tone Mapping)
        -- This is always allowed.
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        show_hdr_osd(C_BLUE .. "HDR Mode: Tone Mapping " .. C_WHITE .. "(Manual Override)")
    else
        -- User wants to switch ON Passthrough
        -- SAFETY CHECK 2: Is Windows HDR actually on?
        if not is_windows_hdr_active() then
            show_hdr_osd(C_RED .. "Error: Enable HDR in Windows Display Settings for Passthrough")
            return
        end
        
        -- If check passes, enable Passthrough
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "clip")
        show_hdr_osd(C_GREEN .. "HDR Mode: Passthrough " .. C_WHITE .. "(Manual Override)")
    end
end

-- Bindings and Observers
mp.add_key_binding(nil, "toggle-hdr-hybrid", toggle_hdr_manual)
mp.observe_property("display-params", "native", check_hdr_state)
mp.observe_property("video-params", "native", check_hdr_state)