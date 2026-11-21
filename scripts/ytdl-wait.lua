-- YouTube only serves the stream URLs that yt-dlp returns after a short delay
-- (yt-dlp reports it as "available_at" and sleeps for it itself). mpv builds
-- from before November 2026 open the URLs straight away, so YouTube often
-- answers with 403 Forbidden. Wait the same way newer mpv's ytdl_hook does;
-- with such a build the delay has already passed and this does nothing.

local mp = require("mp")
local msg = require("mp.msg")
local utils = require("mp.utils")

local function stream_delay()
    local result = mp.get_property_native("user-data/mpv/ytdl/json-subprocess-result")
    if type(result) ~= "table" or type(result.stdout) ~= "string" or result.stdout == "" then
        return 0
    end
    local json = utils.parse_json(result.stdout)
    if type(json) ~= "table" then return 0 end

    local available_at = 0
    for _, track in ipairs(json.requested_formats or json.requested_downloads or { json }) do
        if type(track.available_at) == "number" then
            available_at = math.max(available_at, track.available_at)
        end
    end
    return available_at > 0 and math.max(0, available_at - os.time()) or 0
end

local function wait_until_available(hook)
    local delay = stream_delay()
    if delay <= 0 then return end
    msg.info(string.format("Waiting %d s until YouTube serves the stream", delay))
    hook:defer()
    mp.add_timeout(delay, function() hook:cont() end)
end

-- Runs right after ytdl_hook (priority 10) has resolved the URL.
mp.add_hook("on_load", 15, wait_until_available)
mp.add_hook("on_load_fail", 15, wait_until_available)
