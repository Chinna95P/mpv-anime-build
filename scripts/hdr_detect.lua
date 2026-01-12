-- scripts/hdr_detect.lua
-- v1.5: Universal Windows/Linux HDR Detection
local mp = require 'mp'
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local last_auto_state = nil 

-- Colors
local C_GREEN  = "{\\c&H00FF00&}" 
local C_BLUE   = "{\\c&HFFFF00&}"
local C_RED    = "{\\c&H0000FF&}"
local C_WHITE  = "{\\c&HFFFFFF&}"

function show_hdr_osd(text)
    overlay.data = "{\\an9}{\\fs26}" .. text
    overlay:update()
    if timer then timer:kill() end
    timer = mp.add_timeout(3, function() overlay:remove() end)
end

function is_windows_hdr_active()
    -- On Linux, we cannot easily read "Windows HDR" status.
    -- We assume if the user is playing HDR content on Linux, they want Passthrough 
    -- unless they manually toggle it off.
    local platform = mp.get_property("platform")
    if platform ~= "windows" then
        return true -- Linux: Assume display supports HDR for now (let Manual Toggle fix it if not)
    end

    local d = mp.get_property_native("display-params")
    if not d then return false end
    
    -- Windows Check
    if (d.primaries == "bt.2020" or d.primaries == "dci-p3") then return true end
    if (d.gamma == "pq" or d.gamma == "st2084" or d.gamma == "hybrid-log-gamma") then return true end

    return false
end

function check_hdr_state()
    local is_display_hdr = is_windows_hdr_active()
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local is_hdr_video = video_peak > 1

    -- Decide State
    local target_state = "sdr"
    if is_hdr_video and is_display_hdr then
        target_state = "passthrough"
    elseif is_hdr_video then
        target_state = "tonemap"
    end

    if target_state == last_auto_state then return end
    last_auto_state = target_state

    -- Apply State
    if target_state == "passthrough" then
        print("[HDR-Detect] Enabling PASSTHROUGH")
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "clip")
        
        -- OSD Message (differentiate auto logic)
        local msg = (mp.get_property("platform") == "windows") and "(Auto)" or "(Linux Default)"
        show_hdr_osd(C_GREEN .. "HDR Mode: Passthrough " .. C_WHITE .. msg)
        
    elseif target_state == "tonemap" then
        print("[HDR-Detect] Enabling TONE MAPPING")
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        show_hdr_osd(C_BLUE .. "HDR Mode: Tone Mapping " .. C_WHITE .. "(SDR Display)")
        
    else
        -- SDR Mode
        mp.set_property("target-colorspace-hint", "no")
    end
end

-- Manual Toggle (Works on both OS)
function toggle_hdr_manual()
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    if video_peak <= 1 then
        show_hdr_osd(C_RED .. "Error: Not an HDR Video")
        return
    end

    local current_mode = mp.get_property("target-colorspace-hint")
    if current_mode == "yes" then
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        show_hdr_osd(C_BLUE .. "HDR Mode: Tone Mapping " .. C_WHITE .. "(Forced)")
        last_auto_state = "tonemap"
    else
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "clip")
        show_hdr_osd(C_GREEN .. "HDR Mode: Passthrough " .. C_WHITE .. "(Forced)")
        last_auto_state = "passthrough"
    end
end

mp.add_key_binding(nil, "toggle-hdr-hybrid", toggle_hdr_manual)
mp.observe_property("display-params", "native", check_hdr_state)
mp.observe_property("video-params", "native", check_hdr_state)
mp.observe_property("vo-configured", "bool", function(name, val) if val then check_hdr_state() end end)