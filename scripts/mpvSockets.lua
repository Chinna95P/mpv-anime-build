-- mpvSockets: provide one discoverable IPC endpoint per mpv instance without
-- replacing an endpoint supplied by an external controller such as MediaFlick.

local mp = require "mp"
local utils = require "mp.utils"

local pid = utils.getpid()
local is_windows = package.config:sub(1, 1) == "\\"
local existing_ipc = mp.get_property("options/input-ipc-server", "")

local function set_external_ipc_state(value)
    mp.set_property_native("user-data/mpv-sockets/external-ipc", value)
end

if existing_ipc ~= "" then
    -- An embedding application owns the real endpoint. Never replace it: doing
    -- so disconnects that application's controller. On Unix, expose a symlink
    -- under the usual mpvSockets path so SVP and other discovery tools can use
    -- the same endpoint simultaneously.
    set_external_ipc_state(true)

    if not is_windows then
        local temp_dir = os.getenv("TMPDIR") or "/tmp"
        local socket_dir = utils.join_path(temp_dir, "mpvSockets")
        local alias_path = utils.join_path(socket_dir, tostring(pid))

        utils.subprocess({
            args = { "mkdir", "-p", socket_dir },
            playback_only = false,
            cancellable = false,
        })
        pcall(os.remove, alias_path)
        local result = utils.subprocess({
            args = { "ln", "-s", existing_ipc, alias_path },
            playback_only = false,
            cancellable = false,
        })

        if result.status == 0 then
            mp.register_event("shutdown", function()
                pcall(os.remove, alias_path)
            end)
        else
            mp.msg.warn("Could not create IPC discovery alias: " .. (result.error_string or "unknown error"))
        end
    end

    return
end

set_external_ipc_state(false)

if is_windows then
    -- Windows named pipes disappear automatically when mpv exits.
    mp.set_property("options/input-ipc-server", "\\\\.\\pipe\\mpvSockets_" .. pid)
else
    local temp_dir = os.getenv("TMPDIR") or "/tmp"
    local socket_dir = utils.join_path(temp_dir, "mpvSockets")
    local socket_path = utils.join_path(socket_dir, tostring(pid))

    utils.subprocess({
        args = { "mkdir", "-p", socket_dir },
        playback_only = false,
        cancellable = false,
    })
    mp.set_property("options/input-ipc-server", socket_path)
    mp.register_event("shutdown", function()
        pcall(os.remove, socket_path)
    end)
end
