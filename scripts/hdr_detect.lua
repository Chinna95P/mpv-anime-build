-- scripts/hdr_detect.lua
-- v1.6.1: Hybrid Detection (Internal + PowerShell Fallback)
-- HOTFIX: Fixed false negatives where MPV reported SDR despite Windows HDR being ON.
-- LOGGING: Added console output for Windows HDR status.

local mp = require 'mp'
local utils = require 'mp.utils'
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local last_auto_state = nil 
local os_hdr_confirmed = false -- Caches the PowerShell result

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

-- --------------------------------------------------------------------------
-- POWER CHECK: Queries Windows WMI directly to see if HDR is enabled
-- --------------------------------------------------------------------------
local function check_windows_hdr_powershell()
    -- Only run on Windows
    if mp.get_property("platform") ~= "windows" then return false end

    -- WMI Command: Checks 'AdvancedColorEnabled' status for active monitors
    local cmd = 'powershell -NoProfile -Command "Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorAdvancedColorProperties -ErrorAction SilentlyContinue | Where-Object { $_.AdvancedColorEnabled -eq $true } | Measure-Object | Select-Object -ExpandProperty Count"'
    
    local res = utils.subprocess({
        args = {"powershell", "-NoProfile", "-Command", cmd},
        playback_only = false,
        capture_stdout = true
    })

    if res.status == 0 and res.stdout then
        -- If Count > 0, at least one monitor has HDR (Advanced Color) enabled
        local count = tonumber(res.stdout:match("%d+"))
        if count and count > 0 then 
            return true 
        end
    end
    return false
end

-- Update the OS HDR status cache (Runs on file load or VO change)
local function refresh_os_hdr_status()
    os_hdr_confirmed = check_windows_hdr_powershell()
    
    -- DIAGNOSTIC LOG (v1.6.1 Feature)
    if mp.get_property("platform") == "windows" then
        if os_hdr_confirmed then
            print("[HDR-Detect] Windows Settings report HDR: ON")
        else
            print("[HDR-Detect] Windows Settings report HDR: OFF")
        end
    end

    -- Re-evaluate logic after refreshing status
    check_hdr_state()
end
-- --------------------------------------------------------------------------

function is_windows_hdr_active()
    local platform = mp.get_property("platform")
    if platform ~= "windows" then
        return true -- Linux: Assume True (Manual Toggle 'H' handles errors)
    end

    -- 1. Trust PowerShell (The Deep Check)
    if os_hdr_confirmed then return true end

    -- 2. Fallback to MPV internal detection (The Fast Check)
    local d = mp.get_property_native("display-params")
    if d then 
        if (d.primaries == "bt.2020" or d.primaries == "dci-p3") then return true end
        if (d.gamma == "pq" or d.gamma == "st2084" or d.gamma == "hybrid-log-gamma") then return true end
    end

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
        print("[HDR-Detect] Action: Enabling PASSTHROUGH")
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", "clip")
        
        show_hdr_osd(C_GREEN .. "HDR Mode: Passthrough " .. C_WHITE .. "(Auto)")
        
    elseif target_state == "tonemap" then
        print("[HDR-Detect] Action: Enabling TONE MAPPING")
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", "spline")
        show_hdr_osd(C_BLUE .. "HDR Mode: Tone Mapping " .. C_WHITE .. "(SDR Display)")
        
    else
        -- SDR Mode
        mp.set_property("target-colorspace-hint", "no")
    end
end

-- Manual Toggle
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

-- Triggers
mp.observe_property("video-params", "native", check_hdr_state)

-- Refresh OS status only on critical events to avoid lag
mp.observe_property("vo-configured", "bool", function(name, val) 
    if val then refresh_os_hdr_status() end 
end)