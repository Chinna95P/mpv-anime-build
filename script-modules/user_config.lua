local mp = require("mp")
local utils = require("mp.utils")

local M = {}
local config_root = mp.command_native({"expand-path", "~~/"})

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_setting(line)
    local stripped = trim(line)
    if stripped == "" or stripped:match("^[#;]") or stripped:match("^%[") then return nil end

    local key, value = stripped:match("^%-%-?([%w][%w_-]*)%s*=%s*(.-)%s*$")
    if not key then key, value = stripped:match("^([%w][%w_-]*)%s*=%s*(.-)%s*$") end
    if value and ((value:sub(1, 1) == '"' and value:sub(-1) == '"')
            or (value:sub(1, 1) == "'" and value:sub(-1) == "'")) then
        value = value:sub(2, -2)
    end
    return key, value
end

function M.files()
    local names = utils.readdir(config_root, "files") or {}
    local paths = {}
    for _, name in ipairs(names) do
        if name:match("^user%-.+%.conf$") then
            table.insert(paths, utils.join_path(config_root, name))
        end
    end
    table.sort(paths)
    return paths
end

function M.write_path()
    local paths = M.files()
    return paths[#paths] or utils.join_path(config_root, "user-settings.conf")
end

function M.read()
    local settings = {}
    for _, path in ipairs(M.files()) do
        local file = io.open(path, "r")
        if file then
            for line in file:lines() do
                local key, value = parse_setting(line)
                if key then settings[key] = value end
            end
            file:close()
        end
    end
    return settings
end

function M.update(values, ordered_keys)
    local path = M.write_path()
    local lines, seen = {}, {}
    local input = io.open(path, "r")

    if input then
        for line in input:lines() do table.insert(lines, line) end
        input:close()
    else
        table.insert(lines, "# User overrides saved by MPV Anime Build.")
        table.insert(lines, "# Rename this to user-<anything>.conf if desired; it will still be discovered.")
    end

    for index, line in ipairs(lines) do
        local key = parse_setting(line)
        if key and values[key] ~= nil then
            if not seen[key] then
                lines[index] = key .. "=" .. tostring(values[key])
                seen[key] = true
            else
                lines[index] = false
            end
        end
    end

    local keys = ordered_keys or {}
    if not ordered_keys then
        for key in pairs(values) do table.insert(keys, key) end
        table.sort(keys)
    end
    for _, key in ipairs(keys) do
        if values[key] ~= nil and not seen[key] then
            table.insert(lines, key .. "=" .. tostring(values[key]))
        end
    end

    local output, err = io.open(path, "w")
    if not output then return false, err end
    for _, line in ipairs(lines) do
        if line ~= false then output:write(line, "\n") end
    end
    output:close()
    return true, path
end

return M
