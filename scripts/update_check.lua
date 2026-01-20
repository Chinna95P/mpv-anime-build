-- [[ 
--    FILENAME: update_check.lua
--    DESCRIPTION: Simple version checker for MPV Anime Build
-- ]]

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- [CONFIGURATION]
local CURRENT_VERSION_STR = "v1.9"
local VERSION_URL = "https://github.com/Chinna95P/mpv-anime-build/blob/main/version.txt" 

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
        local remote_str = res.stdout:gsub("%s+", "")
        local remote_ver = parse_version(remote_str)
        local local_ver = parse_version(CURRENT_VERSION_STR)

        if remote_ver > local_ver then
            local msg_text = "Update Available: " .. remote_str .. " (Current: " .. CURRENT_VERSION_STR .. ")"
            mp.osd_message(msg_text, 5)
            msg.info(msg_text)
        else
            if user_initiated then mp.osd_message("Up to date (" .. CURRENT_VERSION_STR .. ")", 3) end
        end
    else
        if user_initiated then mp.osd_message("Update check failed: No internet?", 3) end
    end
end

mp.register_script_message("check-for-updates", function() check_updates(true) end)
mp.add_timeout(5, function() check_updates(false) end)