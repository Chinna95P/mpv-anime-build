-- [[ 
--    scripts/hdr_detect.lua
--    VERSION: v1.7.1 (HDR Fallback Fix)
--    LOGIC:
--      1. Try Windows WMI (PowerShell).
--      2. If WMI fails/errors, check MPV 'display-params' (Fallback).
--      3. If either detects HDR -> Enable PASSTHROUGH.
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local last_state = nil 
local os_hdr_state = false 
local manual_override = false 

-- OSD Colors
local C = {
    GREEN  = "{\\c&H00FF00&}", 
    BLUE   = "{\\c&HFFFF00&}",
    RED    = "{\\c&H0000FF&}",
    WHITE  = "{\\c&HFFFFFF&}",
    ORANGE = "{\\c&H0080FF&}"
}

function show_hdr_osd(text)
    overlay.data = "{\\an9}{\\fs26}" .. text
    overlay:update()
    if timer then timer:kill() end
    timer = mp.add_timeout(4, function() overlay:remove() end)
end

-- --------------------------------------------------------------------------
-- 1. DETECT WINDOWS HDR STATUS (Hybrid Method)
-- --------------------------------------------------------------------------
local function check_windows_hdr()
    if mp.get_property("platform") ~= "windows" then return false end

    -- METHOD A: PowerShell WMI (The most accurate, if it works)
    -- We wrap this in a try/catch block to prevent "Invalid Class" errors from spamming the console.
    local cmd = 'powershell -NoProfile -Command "try { (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorAdvancedColorProperties -ErrorAction Stop).AdvancedColorEnabled } catch { Write-Output \'Fallback\' }"'
    
    local res = utils.subprocess({
        args = {"powershell", "-NoProfile", "-Command", cmd},
        playback_only = false,
        capture_stdout = true
    })

    if res.status == 0 and res.stdout then
        -- Clean string
        local output = res.stdout:gsub("%s+", "")
        
        -- Success Case
        if output == "True" then 
            print("[HDR-Detect] WMI Check: HDR ON")
            return true 
        elseif output == "False" then
            print("[HDR-Detect] WMI Check: HDR OFF")
            return false
        end
        -- If output is 'Fallback' or empty, we proceed to Method B
    end

    -- METHOD B: Internal MPV Fallback
    -- If WMI fails (Invalid Class), we check what MPV sees.
    -- If MPV detects BT.2020 primaries or PQ gamma on the output, Windows is likely in HDR mode.
    local d = mp.get_property_native("display-params")
    if d then
        if d.primaries == "bt.2020" or d.primaries == "dci-p3" or d.gamma == "pq" or d.gamma == "st2084" then
            print("[HDR-Detect] Fallback Check: HDR ON (Detected via display-params)")
            return true
        end
    end
    
    print("[HDR-Detect] Checks finished: HDR OFF")
    return false
end

-- --------------------------------------------------------------------------
-- 2. EVALUATE LOGIC
-- --------------------------------------------------------------------------
function evaluate_hdr_state()
    if manual_override then return end

    -- A. Get Video Properties
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr_video = (video_peak > 1) or (primaries == "bt.2020") or (primaries == "dci-p3")

    -- B. Get OS Properties
    local is_os_hdr = os_hdr_state

    -- C. Determine Target State
    local target = "sdr"
    
    if is_hdr_video then
        if is_os_hdr then
            target = "passthrough" -- True Passthrough
        else
            target = "tonemap"     -- Tone-Mapping
        end
    end

    -- D. Apply Settings (Only if changed)
    if target == last_state then return end

    if target == "passthrough" then
        print("[HDR-Auto] Mode: PASSTHROUGH (Metadata sent to Display)")
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "clip")
        show_hdr_osd(C.GREEN .. "HDR Mode: " .. C.WHITE .. "True Passthrough (Auto)")

    elseif target == "tonemap" then
        print("[HDR-Auto] Mode: TONE-MAP (Windows is SDR)")
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        show_hdr_osd(C.BLUE .. "HDR Mode: " .. C.WHITE .. "Tone-Mapping (Auto)")

    else -- "sdr"
        if last_state ~= nil and last_state ~= "sdr" then
            mp.set_property("target-colorspace-hint", "no")
        end
    end

    last_state = target
end

-- --------------------------------------------------------------------------
-- 3. MANUAL TOGGLE
-- --------------------------------------------------------------------------
function toggle_hdr_manual()
    manual_override = true
    os_hdr_state = check_windows_hdr()
    
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr_video = (video_peak > 1) or (primaries == "bt.2020") or (primaries == "dci-p3")
    
    if not is_hdr_video then
        show_hdr_osd(C.RED .. "Error: Not an HDR Video")
        return
    end

    if last_state == "passthrough" then
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        last_state = "tonemap"
        show_hdr_osd(C.ORANGE .. "HDR Manual: " .. C.WHITE .. "Tone-Mapping (Forced)")
    else
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "clip")
        last_state = "passthrough"
        show_hdr_osd(C.ORANGE .. "HDR Manual: " .. C.WHITE .. "True Passthrough (Forced)")
    end
end

-- --------------------------------------------------------------------------
-- 4. TRIGGERS
-- --------------------------------------------------------------------------

mp.register_event("file-loaded", function()
    manual_override = false 
    os_hdr_state = check_windows_hdr()
    evaluate_hdr_state()
end)

mp.observe_property("video-params", "native", function()
    evaluate_hdr_state()
end)

mp.observe_property("vo-configured", "bool", function(name, val) 
    if val then 
        os_hdr_state = check_windows_hdr()
        evaluate_hdr_state()
    end 
end)

mp.add_key_binding(nil, "toggle-hdr-hybrid", toggle_hdr_manual)
mp.register_script_message("toggle-hdr-mode", toggle_hdr_manual)