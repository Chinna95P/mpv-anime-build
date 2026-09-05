-- [[ 
--    FILENAME: update_check.lua
--    DESCRIPTION: Simple version checker for MPV Anime Build
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local opts = require 'mp.options' -- Import options module

-- [CONFIGURATION]
local config = { version = "v0.0.0" }
opts.read_options(config, "build_info")
local CURRENT_VERSION_STR = config.version
local VERSION_URL = "https://raw.githubusercontent.com/Chinna95P/mpv-anime-build/refs/heads/main/script-opts/build_info.conf"
local RELEASE_URL_BASE = "https://github.com/Chinna95P/mpv-anime-build/releases/tag/"

local function get_platform()
    local platform = mp.get_property_native("platform")
    if platform then return platform end
    if os.getenv("windir") then return "windows" end
    local home = os.getenv("HOME") or ""
    if home:sub(1, 7) == "/Users/" then return "darwin" end
    return "linux"
end

local function extract_version(value)
    if not value then return nil end
    return value:match("v%d+%.%d+%.?%d*")
end

local function open_release_page(version)
    local release_version = extract_version(version)
    if not release_version then
        msg.warn("Cannot open release page: invalid version returned by update check")
        return
    end

    local url = RELEASE_URL_BASE .. release_version
    local platform = get_platform()
    local args
    if platform == "windows" then
        args = {"rundll32.exe", "url.dll,FileProtocolHandler", url}
    elseif platform == "darwin" then
        args = {"open", url}
    else
        args = {"xdg-open", url}
    end

    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stdout = false,
        capture_stderr = true,
        args = args,
    }, function(success, result, error)
        if not success or not result or result.status ~= 0 then
            local detail = error or (result and result.stderr) or "unknown error"
            msg.warn("Failed to open release page: " .. tostring(detail))
            mp.osd_message("Could not open the release page in your browser", 3)
        end
    end)
end

local function parse_version(v)
    if not v then return 0 end
    local major, minor, patch = string.match(v, "v(%d+)%.(%d+)%.?(%d*)")
    return (tonumber(major) or 0) * 10000 + (tonumber(minor) or 0) * 100 + (tonumber(patch) or 0)
end

local function check_updates(user_initiated)
    if user_initiated then mp.osd_message("Checking for updates...", 2) end
    
    local args = {}
    if mp.get_property_native("platform") == "windows" then
        args = {"powershell", "-NoProfile", "-Command", "(Invoke-WebRequest -Uri '"..VERSION_URL.."' -UseBasicParsing).Content"}
    else
        args = {"curl", "-s", VERSION_URL}
    end

    local res = utils.subprocess({ args = args, cancellable = false })

    if res.status == 0 and res.stdout then
        local remote_str = extract_version(res.stdout)
        if not remote_str then
            if user_initiated then mp.osd_message("Update check failed: Invalid version response", 3) end
            msg.warn("Update check returned an invalid version response")
            return
        end
        local remote_ver = parse_version(remote_str)
        local local_ver = parse_version(CURRENT_VERSION_STR)

        if remote_ver > local_ver then
            local msg_text = "Update Available: " .. remote_str .. " (Current: " .. CURRENT_VERSION_STR .. ")"
            mp.osd_message(msg_text, 5)
            msg.info(msg_text)
        else
            if user_initiated then mp.osd_message("Up to date (Latest: " .. remote_str .. ")", 3) end
        end

        if user_initiated then open_release_page(remote_str) end
    else
        if user_initiated then mp.osd_message("Update check failed: No internet?", 3) end
    end
end

mp.register_script_message("check-for-updates", function() check_updates(true) end)
mp.add_timeout(5, function() check_updates(false) end)
