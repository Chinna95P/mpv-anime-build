-- mpvSockets, one socket per instance, removes socket on exit

local utils = require 'mp.utils'
local ppid = utils.getpid()

-- Detect OS based on the directory separator
local is_windows = package.config:sub(1,1) == "\\"

if is_windows then
    -- WINDOWS: Use Named Pipes (No cmd flash, no directory needed)
    local pipe_name = "\\\\.\\pipe\\mpvSockets_" .. ppid
    mp.set_property("options/input-ipc-server", pipe_name)

    -- Note: Windows named pipes self-destruct when the process closes,
-- so we don't even need a shutdown cleanup handler here.
else
    -- UNIX-LIKE (Linux/macOS): Standard temp directory method
    local function get_temp_path()
    local directory_seperator = package.config:match("([^\n]*)\n?")
    local example_temp_file_path = os.tmpname()

    -- remove generated temp file
    pcall(os.remove, example_temp_file_path)

    local seperator_idx = example_temp_file_path:reverse():find(directory_seperator)
    local temp_path_length = #example_temp_file_path - seperator_idx

    return example_temp_file_path:sub(1, temp_path_length)
    end

    local tempDir = get_temp_path()

    local function join_paths(...)
    local arg={...}
    local path = ""
    for i,v in ipairs(arg) do
        path = utils.join_path(path, tostring(v))
        end
        return path;
    end

    local socket_dir = join_paths(tempDir, "mpvSockets")
    local socket_path = join_paths(socket_dir, ppid)

    -- Create directory (silently fails if it already exists)
    os.execute("mkdir -p '" .. socket_dir .. "' 2>/dev/null")

    mp.set_property("options/input-ipc-server", socket_path)

    local function shutdown_handler()
    os.remove(socket_path)
    end
    mp.register_event("shutdown", shutdown_handler)
    end
