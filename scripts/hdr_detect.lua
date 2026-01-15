-- [[ 
--    scripts/hdr_detect.lua
--    VERSION: v1.7 (Manual Override Fix)
--    FIX: Prevents Auto-Detection from undoing Manual Toggles ('H' key).
--    LOGIC:
--      - Auto Mode: Runs on file load or system change.
--      - Manual Mode: Activates when you press 'H'. Disables Auto Mode for the current file.
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local last_state = nil 
local os_hdr_state = false 
local manual_override = false -- New Lock Variable

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
-- 1. DETECT WINDOWS HDR STATUS
-- --------------------------------------------------------------------------
local function check_windows_hdr()
    if mp.get_property("platform") ~= "windows" then return false end

    -- Safe PowerShell command with backticks for special chars
    local cmd = 'powershell -NoProfile -Command "@(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorAdvancedColorProperties -ErrorAction SilentlyContinue).AdvancedColorEnabled | Where-Object { `$_ -eq `$true } | Measure-Object | Select-Object -ExpandProperty Count"'
    
    local res = utils.subprocess({
        args = {"powershell", "-NoProfile", "-Command", cmd},
        playback_only = false,
        capture_stdout = true
    })

    if res.status == 0 and res.stdout then
        local count = tonumber(res.stdout:match("%d+"))
        if count and count > 0 then 
            return true 
        end
    end
    return false
end

-- --------------------------------------------------------------------------
-- 2. EVALUATE LOGIC (Auto)
-- --------------------------------------------------------------------------
function evaluate_hdr_state()
    -- STOP if user has manually overridden the settings for this file
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
-- 3. MANUAL TOGGLE (The Fix)
-- --------------------------------------------------------------------------
function toggle_hdr_manual()
    -- 1. Enable Override Lock
    manual_override = true
    
    -- 2. Refresh OS Status
    os_hdr_state = check_windows_hdr()
    
    -- 3. Check video type to ensure valid toggle
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr_video = (video_peak > 1) or (primaries == "bt.2020") or (primaries == "dci-p3")
    
    if not is_hdr_video then
        show_hdr_osd(C.RED .. "Error: Not an HDR Video")
        return
    end

    -- 4. Flip Logic
    if last_state == "passthrough" then
        -- Force Tone-Map
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        last_state = "tonemap"
        show_hdr_osd(C.ORANGE .. "HDR Manual: " .. C.WHITE .. "Tone-Mapping (Forced)")
    else
        -- Force Passthrough
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

-- Reset Override when loading a new file
mp.register_event("file-loaded", function()
    manual_override = false -- Unlock auto-mode
    os_hdr_state = check_windows_hdr() -- Refresh status
    evaluate_hdr_state()
end)

-- Auto-Detect on property changes (Only if not overridden)
mp.observe_property("video-params", "native", function()
    evaluate_hdr_state()
end)

-- Refresh OS status on window move (Only if not overridden)
mp.observe_property("vo-configured", "bool", function(name, val) 
    if val then 
        os_hdr_state = check_windows_hdr()
        evaluate_hdr_state()
    end 
end)

-- BINDING: Allows 'H' in input.conf to work
mp.add_key_binding(nil, "toggle-hdr-hybrid", toggle_hdr_manual)

-- LEGACY: Support for script-message calls
mp.register_script_message("toggle-hdr-mode", toggle_hdr_manual)