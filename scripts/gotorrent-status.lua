-- Centered BitTorrent status for mpv-gotorrent streams. Shown while the swarm
-- connects, while a stream starts, and whenever playback stops to buffer.

local mp = require("mp")
local utils = require("mp.utils")

local overlay = mp.create_osd_overlay("ass-events")
local tick_timer = nil
local shown = ""

local opening = false     -- from start-file until playback first starts
local opening_since = 0
local seeking_since = nil

local stats = nil         -- last /status reply from the companion
local stats_base = nil
local fetching = false
local last_fetch = -10

local function stream_base(path)
    return path and path:match("^(https?://127%.0%.0%.1:%d+)/torrent/%x+/")
end

-- Same sources mpv-gotorrent intercepts: magnet links, .torrent files and URLs,
-- bare 40-character infohashes, and its own stream URLs (resumed from history).
local function is_torrent_path(path)
    if not path or path == "" then return false end
    if stream_base(path) then return true end
    local lower = path:lower()
    if lower:find("magnet[:/%?]") then return true end
    if lower:match("%.torrent$") or lower:match("%.torrent%?") then return true end
    local name = path:match("([^/\\]+)$") or path
    return name:match("^" .. string.rep("%x", 40) .. "$") ~= nil and not utils.file_info(path)
end

local function format_speed(bytes)
    bytes = bytes or 0
    if bytes >= 1024 * 1024 then return string.format("%.1f MB/s", bytes / 1024 / 1024) end
    return string.format("%d KB/s", math.floor(bytes / 1024 + 0.5))
end

local function swarm_line()
    if not stats then return nil end
    if (stats.peers or 0) == 0 then return "Searching for peers..." end
    return string.format("↓ %s  ·  %d peers", format_speed(stats.download_speed), stats.peers)
end

local function fetch_stats(base)
    if base ~= stats_base then
        stats, stats_base = nil, base
    end
    if fetching or mp.get_time() - last_fetch < 1 then return end
    fetching, last_fetch = true, mp.get_time()
    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {"curl", "-s", "--max-time", "2", base .. "/status"},
    }, function(success, res)
        fetching = false
        if base ~= stats_base then return end
        local parsed = success and res and res.status == 0 and utils.parse_json(res.stdout or "")
        stats = parsed or nil
    end)
end

local function hide()
    if shown ~= "" then
        overlay:remove()
        shown = ""
    end
end

local function render(title, detail, below_spinner)
    local w, h = mp.get_osd_size()
    if not w or w <= 0 or h <= 0 then return end
    local title_size = math.floor(h / 22 + 0.5)
    local detail_size = math.floor(h / 32 + 0.5)
    local y = h / 2
    if below_spinner then
        -- uosc draws its buffering spinner in the middle; sit just below it.
        y = h / 2 + (30 + math.min(w, h) / 10) / 2 + title_size
    end
    local data = string.format(
        "{\\an5\\pos(%d,%d)\\fn%s\\bord%.1f\\shad1\\3c&H000000&\\4c&H000000&\\4a&H80&}" ..
        "{\\fs%d\\b1\\1c&H008CFB&}%s{\\b0}\\N{\\fs%d\\1c&HFFFFFF&}%s",
        w / 2, y, mp.get_property("osd-font", "sans-serif"), h / 400,
        title_size, title, detail_size, detail)
    if data == shown and overlay.res_x == w and overlay.res_y == h then return end
    overlay.res_x, overlay.res_y = w, h
    overlay.data = data
    overlay:update()
    shown = data
end

local function tick()
    local buffering = mp.get_property_bool("paused-for-cache", false)
    local long_seek = seeking_since and mp.get_time() - seeking_since >= 0.75
    if not (opening or buffering or long_seek) then
        hide()
        return
    end

    local base = stream_base(mp.get_property("path"))
    if base then fetch_stats(base) end

    if opening then
        local swarm = base and swarm_line()
        if swarm then
            local count = mp.get_property_number("playlist-count", 1)
            local title = "Starting stream"
            if count > 1 then
                title = string.format("Starting episode %d of %d", mp.get_property_number("playlist-pos", 0) + 1, count)
            end
            render(title, swarm, false)
        else
            local elapsed = math.floor(mp.get_time() - opening_since)
            local step = base and "Reconnecting" or "Fetching torrent info"
            render("Connecting to BitTorrent swarm", string.format("%s  ·  %ds", step, elapsed), false)
        end
        return
    end

    local title = "Buffering"
    local pct = mp.get_property_number("cache-buffering-state")
    if buffering and pct then title = string.format("Buffering %d%%", pct) end
    render(title, swarm_line() or "Waiting for data...", buffering)
end

local function start_timer()
    if not tick_timer then tick_timer = mp.add_periodic_timer(0.25, tick) end
    tick()
end

local function stop_timer()
    if tick_timer then
        tick_timer:kill()
        tick_timer = nil
    end
    opening, seeking_since, stats, stats_base = false, nil, nil, nil
    hide()
end

mp.register_event("start-file", function()
    if not is_torrent_path(mp.get_property("path")) then
        stop_timer()
        return
    end
    if not opening then
        opening, opening_since = true, mp.get_time()
    end
    start_timer()
end)

mp.register_event("playback-restart", function()
    opening = false
end)

mp.register_event("end-file", function(event)
    -- A magnet entry ends with "redirect" when it is replaced by its playlist.
    if event.reason ~= "redirect" then stop_timer() end
end)

mp.observe_property("seeking", "bool", function(_, seeking)
    if seeking then
        seeking_since = seeking_since or mp.get_time()
    else
        seeking_since = nil
    end
end)

mp.observe_property("osd-dimensions", "native", function()
    shown = ""
    if tick_timer then tick() end
end)
