-- [[ 
--    FILENAME: scripts/hdr_detect.lua
--    VERSION: v2.2 (DisplayConfig Detection + Cached Checks)
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local user_config_path = mp.command_native({"expand-path", "~~/script-modules/user_config.lua"})
local user_config = dofile(user_config_path)
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local last_state = nil 
local os_hdr_state = false 
local windows_hdr_checked = false
local manual_override = false 
local last_osd_state = nil

-- [NEW] Config Path
local hdr_defaults_path = mp.command_native({"expand-path", "~~/script-opts/hdr-mode.conf"})
local windows_hdr_script = mp.command_native({"expand-path", "~~/script-modules/windows_hdr_status.ps1"})

-- [NEW] Helper to read the user's saved preference
local function read_hdr_config()
    local mode = "bt.2390" -- Default fallback
    local d_mode = "auto"  -- Default display mode
    local f = io.open(hdr_defaults_path, "r")
    if f then
        for line in f:lines() do
            local v = line:match("tone_mapping=(%S+)")
            if v then mode = v end
            local dm = line:match("hdr_display_mode=(%S+)")
            if dm then d_mode = dm end
        end
        f:close()
    end
    local settings = user_config.read()
    if settings.tone_mapping then mode = settings.tone_mapping end
    if settings.hdr_display_mode then d_mode = settings.hdr_display_mode end
    return mode, d_mode
end

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
    if windows_hdr_checked then return os_hdr_state end
    windows_hdr_checked = true

    local res = utils.subprocess({
        args = {
            "powershell", "-NoProfile", "-NonInteractive",
            "-ExecutionPolicy", "Bypass", "-File", windows_hdr_script
        },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true
    })

    if res.status == 0 and res.stdout then
        local output = res.stdout:gsub("%s+", "")
        if output == "True" then 
            os_hdr_state = true
            print("[HDR-Detect] Windows DisplayConfig: HDR ON")
            return true 
        elseif output == "False" then
            os_hdr_state = false
            print("[HDR-Detect] Windows DisplayConfig: HDR OFF")
            return false
        end
    end

    os_hdr_state = false
    local helper_error = (res.stderr or ""):gsub("%s+$", "")
    if helper_error ~= "" then
        msg.warn("[HDR-Detect] " .. helper_error:gsub("%s*\n%s*", " | "))
    end
    print("[HDR-Detect] Windows HDR status unavailable; defaulting to HDR OFF")
    return false
end

-- --------------------------------------------------------------------------
-- 2. EVALUATE LOGIC
-- --------------------------------------------------------------------------
function evaluate_hdr_state()
    if manual_override then return end

    -- Read the current configuration state
    local tm_mode, d_mode = read_hdr_config()
    
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr_video = (video_peak > 1) or (primaries == "bt.2020") or (primaries == "dci-p3")

    -- Determine the target state based on user selection and video type
    local target_state = "auto"
    if is_hdr_video then
        if d_mode == "hdr" then
            target_state = "passthrough"
        elseif d_mode == "sdr" then
            target_state = "tonemap"
        else
            -- [GATE LOCK] Explicitly isolate Windows HDR checks to Auto Mode only
            os_hdr_state = check_windows_hdr()
            target_state = os_hdr_state and "passthrough" or "tonemap"
        end
    else
        target_state = "sdr_video"
    end

    -- 1. APPLY PROPERTIES
    if target_state == "passthrough" then
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", tm_mode)
    elseif target_state == "tonemap" then
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", tm_mode)
    else
        -- Standard SDR Video defaults
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "auto")
    end

    -- 2. ONLY SHOW OSD IF THE STATE ACTUALLY CHANGES
    local current_osd_id = d_mode .. "_" .. target_state

    if last_osd_state ~= current_osd_id then
        last_osd_state = current_osd_id
        
        if target_state ~= "sdr_video" then
            if d_mode == "hdr" then
                show_hdr_osd(C.ORANGE .. "HDR Switch: " .. C.WHITE .. "HDR Display (Passthrough)")
            elseif d_mode == "sdr" then
                show_hdr_osd(C.ORANGE .. "HDR Switch: " .. C.WHITE .. "SDR Display (Tone-Mapping)")
            else
                if target_state == "passthrough" then
                    show_hdr_osd(C.GREEN .. "HDR Switch: " .. C.WHITE .. "Auto (Passthrough)")
                elseif target_state == "tonemap" then
                    show_hdr_osd(C.GREEN .. "HDR Switch: " .. C.WHITE .. "Auto (Tone-Mapping)")
                end
            end
        end
    end

    -- 3. BROADCAST STATE TO UOSC FOR MENU HIGHLIGHTING
    local broadcast_data = { hdr_display_mode = d_mode }
    mp.commandv("script-message", "anime-state-broadcast", utils.format_json(broadcast_data))
end

-- --------------------------------------------------------------------------
-- 3. MANUAL TOGGLE (Hotkeys)
-- --------------------------------------------------------------------------
function toggle_hdr_manual()
    manual_override = true
    
    local video_peak = mp.get_property_number("video-params/sig-peak", 0)
    local primaries = mp.get_property("video-params/primaries")
    local is_hdr_video = (video_peak > 1) or (primaries == "bt.2020") or (primaries == "dci-p3")
    
    if not is_hdr_video then
        show_hdr_osd(C.RED .. "Error: Not an HDR Video")
        return
    end

    local tm_mode, _ = read_hdr_config()

    if last_state == "passthrough" then
        mp.set_property("target-colorspace-hint", "no")
        mp.set_property("target-trc", "srgb")
        mp.set_property("tone-mapping", tm_mode)
        last_state = "tonemap"
        show_hdr_osd(C.ORANGE .. "HDR Manual: " .. C.WHITE .. "Tone-Mapping (Forced)")
    else
        mp.set_property("target-colorspace-hint", "yes")
        mp.set_property("target-trc", "auto")
        mp.set_property("tone-mapping", tm_mode)
        last_state = "passthrough"
        show_hdr_osd(C.ORANGE .. "HDR Manual: " .. C.WHITE .. "HDR Output (Forced)")
    end
end

-- --------------------------------------------------------------------------
-- 4. TRIGGERS (Stripped of unconditional OS scanning)
-- --------------------------------------------------------------------------

mp.register_event("start-file", function()
    manual_override = false 
    windows_hdr_checked = false
    last_osd_state = nil 
end)

mp.register_event("file-loaded", function()
    evaluate_hdr_state()
end)

mp.observe_property("video-params", "native", function()
    evaluate_hdr_state()
end)

mp.observe_property("vo-configured", "bool", function(name, val) 
    if val then 
        evaluate_hdr_state()
    end 
end)

mp.add_key_binding(nil, "toggle-hdr-hybrid", toggle_hdr_manual)
mp.register_script_message("toggle-hdr-mode", toggle_hdr_manual)
mp.register_script_message("update-hdr-detect-mode", function()
    manual_override = false
    windows_hdr_checked = false
    evaluate_hdr_state()
end)
