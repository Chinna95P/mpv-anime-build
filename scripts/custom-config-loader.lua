-- [[
--    FILENAME: custom-config-loader.lua
--    DESCRIPTION: Loads one update-safe mpv-<custom-name>.conf override file.
-- ]]

local mp = require("mp")
local msg = require("mp.msg")
local utils = require("mp.utils")

local config_root = mp.command_native({"expand-path", "~~/"})

local function discover_custom_configs()
    local names = utils.readdir(config_root, "files") or {}
    local matches = {}

    for _, name in ipairs(names) do
        if name:match("^mpv%-.+%.conf$") then
            table.insert(matches, name)
        end
    end

    table.sort(matches)
    return matches
end

local function load_custom_config()
    local matches = discover_custom_configs()

    if #matches == 0 then return end

    if #matches > 1 then
        local filenames = table.concat(matches, ", ")
        msg.error("Custom config not loaded: multiple mpv-<custom-name>.conf files were found: " .. filenames)
        mp.osd_message("Custom MPV config not loaded\nKeep only one mpv-<custom-name>.conf file", 8)
        return
    end

    local filename = matches[1]
    local path = utils.join_path(config_root, filename)
    local call_ok, command_ok = pcall(mp.commandv, "load-config-file", path)

    if not call_ok or command_ok == false then
        local detail = not call_ok and tostring(command_ok) or "MPV rejected the configuration file"
        msg.error("Could not load custom config " .. filename .. ": " .. detail)
        mp.osd_message("Failed to load custom MPV config\n" .. filename, 8)
        return
    end

    msg.info("Loaded custom MPV config: " .. filename)
    mp.add_timeout(0, function()
        mp.osd_message("Custom MPV config loaded: " .. filename, 3)
    end)
end

load_custom_config()
