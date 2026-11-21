local utils = require('mp.utils')
local self = {}

function self.is_empty(var)
    return var == nil or var == '' or (type(var) == 'table' and next(var) == nil)
end

function self.file_exists(filepath)
    if not self.is_empty(filepath) then
        local info = utils.file_info(filepath)
        if info and info.is_file then
            return true
        end
    end
    return false
end

function self.alt_dirs()
    return {
        '/opt/homebrew/bin',
        '/usr/local/bin',
        utils.join_path(os.getenv("HOME") or "~", '.local/bin'),
    }
end

function self.find_executable(name)
    local exec_path
    for _, path in pairs(self.alt_dirs()) do
        exec_path = utils.join_path(path, name)
        if self.file_exists(exec_path) then
            return exec_path
        end
    end
    return name
end

function self.is_path(str)
    return not not string.match(str, '[/\\]')
end

return self
