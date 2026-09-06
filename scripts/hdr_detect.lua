-- [[ 
--    FILENAME: scripts/hdr_detect.lua
--    VERSION: v2.3 (Isolated Windows/Linux HDR Detection)
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local user_config_path = mp.command_native({"expand-path", "~~/script-modules/user_config.lua"})
local user_config = dofile(user_config_path)
local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local last_state = nil 
local os_hdr_state = nil
local os_hdr_checked = false
local manual_override = false 
local last_osd_state = nil

-- [NEW] Config Path
local hdr_defaults_path = mp.command_native({"expand-path", "~~/script-opts/hdr-mode.conf"})
local windows_hdr_script = mp.command_native({"expand-path", "~~/script-modules/windows_hdr_status.ps1"})

local function detect_platform()
    local value = (mp.get_property("platform") or ""):lower()
    if value == "windows" or value == "linux" then
        return value
    end
    return package.config:sub(1, 1) == "\\" and "windows" or "linux"
end

local platform = detect_platform()

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
    overlay.data = "{\\an9}{\\fs23}" .. text
    overlay:update()
    if timer then timer:kill() end
    timer = mp.add_timeout(4, function() overlay:remove() end)
end

-- --------------------------------------------------------------------------
-- 1. DETECT OS HDR STATUS
-- --------------------------------------------------------------------------
local function check_windows_hdr()
    if platform ~= "windows" then return nil end

    local res = utils.subprocess({
        args = {
            "powershell", "-NoProfile", "-NonInteractive",
            "-ExecutionPolicy", "Bypass", "-File", windows_hdr_script
        },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true
    }) or {}

    if res.status == 0 and res.stdout then
        local output = res.stdout:gsub("%s+", "")
        if output == "True" then 
            print("[HDR-Detect] Windows DisplayConfig: HDR ON")
            return true 
        elseif output == "False" then
            print("[HDR-Detect] Windows DisplayConfig: HDR OFF")
            return false
        end
    end

    local helper_error = (res.stderr or ""):gsub("%s+$", "")
    if helper_error ~= "" then
        msg.warn("[HDR-Detect] " .. helper_error:gsub("%s*\n%s*", " | "))
    end
    print("[HDR-Detect] Windows HDR status unavailable; defaulting to HDR OFF")
    return false
end

local function strip_ansi(text)
    return (text or ""):gsub("\27%[[0-9;]*m", "")
end

local function parse_kscreen_hdr(output)
    local outputs = {}
    local current = nil

    for raw_line in strip_ansi(output):gmatch("[^\r\n]+") do
        local line = raw_line:match("^%s*(.-)%s*$")
        if line:match("^Output:%s") then
            current = { enabled = false, connected = false, hdr = nil }
            outputs[#outputs + 1] = current
        elseif current then
            if line == "enabled" then
                current.enabled = true
            elseif line == "connected" then
                current.connected = true
            else
                local hdr_value = line:match("^HDR:%s*(%S+)")
                if hdr_value then
                    hdr_value = hdr_value:lower()
                    if hdr_value == "enabled" then
                        current.hdr = true
                    elseif hdr_value == "disabled" or hdr_value == "incapable" then
                        current.hdr = false
                    end
                end
            end
        end
    end

    local found_active_status = false
    for _, output in ipairs(outputs) do
        if output.enabled and output.connected and output.hdr ~= nil then
            found_active_status = true
            if output.hdr then return true end
        end
    end
    if found_active_status then return false end
    return nil
end

local function check_linux_hdr()
    if platform ~= "linux" then return nil end

    -- Plasma exposes the active output HDR state through kscreen-doctor.
    -- Other compositors have no common status API, so leave them to mpv's
    -- native target-colorspace negotiation instead of guessing.
    local desktop = ((os.getenv("XDG_CURRENT_DESKTOP") or "") .. ":" ..
        (os.getenv("KDE_FULL_SESSION") or "")):lower()
    if not desktop:find("kde", 1, true) and not desktop:find("plasma", 1, true) then
        msg.verbose("[HDR-Detect] Linux compositor has no supported HDR status API; using mpv auto negotiation.")
        return nil
    end

    local environment = utils.get_env_list()
    for index = #environment, 1, -1 do
        if environment[index]:match("^LC_ALL=") then
            table.remove(environment, index)
        end
    end
    environment[#environment + 1] = "LC_ALL=C"

    local res = utils.subprocess({
        args = {"kscreen-doctor", "-o"},
        env = environment,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true
    }) or {}

    if res.status == 0 and res.stdout then
        local state = parse_kscreen_hdr(res.stdout)
        if state ~= nil then
            print("[HDR-Detect] Linux KScreen: HDR " .. (state and "ON" or "OFF"))
            return state
        end
    end

    local helper_error = (res.stderr or ""):gsub("%s+$", "")
    if helper_error ~= "" then
        msg.verbose("[HDR-Detect] KScreen HDR status unavailable: " .. helper_error:gsub("%s*\n%s*", " | "))
    end
    print("[HDR-Detect] Linux HDR status unavailable; using mpv auto negotiation")
    return nil
end

local function check_os_hdr()
    if os_hdr_checked then return os_hdr_state end
    os_hdr_checked = true

    -- Keep platform backends mutually exclusive: Windows never launches a
    -- Linux helper, and Linux never launches PowerShell.
    if platform == "windows" then
        os_hdr_state = check_windows_hdr()
    elseif platform == "linux" then
        os_hdr_state = check_linux_hdr()
    else
        os_hdr_state = nil
    end
    return os_hdr_state
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
            -- OS detection remains locked to Auto mode. An unknown Linux
            -- state uses mpv's native Wayland/compositor negotiation.
            local detected_hdr = check_os_hdr()
            if detected_hdr == true then
                target_state = "passthrough"
            elseif detected_hdr == false then
                target_state = "tonemap"
            else
                target_state = "managed"
            end
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
    elseif target_state == "managed" then
        mp.set_property("target-colorspace-hint", "auto")
        mp.set_property("target-trc", "auto")
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
                elseif target_state == "managed" then
                    show_hdr_osd(C.GREEN .. "HDR Switch: " .. C.WHITE .. "Auto (Compositor Managed)")
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
    os_hdr_checked = false
    os_hdr_state = nil
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
    os_hdr_checked = false
    os_hdr_state = nil
    evaluate_hdr_state()
end)
