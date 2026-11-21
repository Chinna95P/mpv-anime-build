-- Adds "Opening" / "Ending" chapters from AniSkip (api.aniskip.com) to anime
-- episodes that have no OP/ED chapters, e.g. most SubsPlease-style releases.
-- The build's skip_intro.lua then shows its Skip OP/ED button, and uosc
-- colours the ranges on the timeline, exactly as for files with real chapters.

local mp = require("mp")
local msg = require("mp.msg")
local utils = require("mp.utils")

local opts = {
    enabled = true,
    show_osd = true,
    -- Only episode-length files (seconds).
    min_duration = 600,
    max_duration = 2700,
    -- AniSkip times are per release length; ignore submissions for cuts that
    -- differ from this file by more than this many seconds.
    max_length_diff = 15,
}
require("mp.options").read_options(opts, "aniskip_chapters")

local mal_ids = {}   -- search title -> MAL id (false when not found)
local load_id = 0

local OPED_WORDS = { "opening", "ending", "^op$", "^ed$", "^op%d", "^ed%d", "ncop", "nced", "^op ", "^ed " }

local function has_oped_chapters(chapters)
    for _, c in ipairs(chapters or {}) do
        local t = (c.title or ""):lower()
        for _, w in ipairs(OPED_WORDS) do
            if t:find(w) then return true end
        end
    end
    return false
end

local function url_decode(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function trim(s)
    return (s:gsub("^[%s%-_|:]+", ""):gsub("[%s%-_|:]+$", ""))
end

-- "[SubsPlease] Sousou no Frieren - 05 (1080p) [ABCD1234].mkv" -> "Sousou no Frieren", 5
local function parse_release(name)
    name = url_decode(name):gsub("%.%w+$", "")
    name = name:gsub("%b[]", " "):gsub("%b()", " "):gsub("%b{}", " ")
    if not name:find(" ") then name = name:gsub("[._]", " ") end
    name = name:gsub("_", " "):gsub("%s+", " ")

    -- Specials like "- 05.5" have no AniSkip entry.
    if name:find("%s%-%s*%d+%.%d") then return nil end

    local title, season, ep = name:match("^(.-)%s*[Ss](%d+)%s*[Ee](%d+)")
    if not ep then title, ep = name:match("^(.-)%s+%-%s+[Ee]?[Pp]?(%d+)") end
    if not ep then title, ep = name:match("^(.-)%s+[Ee][Pp]?%.?%s*(%d+)%f[^%d]") end
    if not ep then title, ep = name:match("^(.-)%s+[Ee]pisode%s*(%d+)") end
    if not ep then title, ep = name:match("^(.-)%s+(%d%d?%d?%d?)%s*[vV]?%d?%s*$") end
    if not ep then return nil end

    title = trim(title or "")
    title = title:gsub("%s+[Ss](%d+)$", " Season %1")
    season = tonumber(season)
    if season and season > 1 then title = title .. " Season " .. season end
    if title == "" then return nil end
    return title, tonumber(ep)
end

local function run(args, callback)
    mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }, function(success, res)
        local data = success and res and res.status == 0 and utils.parse_json(res.stdout or "")
        callback(data)
    end)
end

local function find_mal_id(title, callback)
    if mal_ids[title] ~= nil then return callback(mal_ids[title]) end
    local body = utils.format_json({
        query = "query($s:String){Media(search:$s,type:ANIME){idMal}}",
        variables = { s = title },
    })
    run({ "curl", "-s", "--max-time", "8", "-X", "POST",
          "-H", "Content-Type: application/json", "-H", "Accept: application/json",
          "--data-binary", body, "https://graphql.anilist.co" }, function(data)
        local id = data and data.data and data.data.Media and data.data.Media.idMal
        if id == nil and not data then return callback(nil) end  -- network error: don't cache
        mal_ids[title] = id or false
        callback(id or false)
    end)
end

-- Pick the submission closest to this file's length, preferring pure OP/ED
-- over "mixed" ones (OP/ED playing over story content).
local function pick(results, kinds, duration)
    for _, kind in ipairs(kinds) do
        local best, best_diff
        for _, r in ipairs(results) do
            if r.skipType == kind and r.interval then
                local diff = math.abs((r.episodeLength or duration) - duration)
                if diff <= opts.max_length_diff and (not best or diff < best_diff) then
                    best, best_diff = r, diff
                end
            end
        end
        if best then return best.interval.startTime, best.interval.endTime end
    end
end

local function add_chapters(segments, duration)
    local existing = mp.get_property_native("chapter-list") or {}

    local function title_at(t)
        local title
        for _, c in ipairs(existing) do
            if c.time <= t + 0.01 then title = c.title end
        end
        return (title and title ~= "") and title or "Episode"
    end

    local list = {}
    for _, c in ipairs(existing) do
        local inside = false
        for _, s in ipairs(segments) do
            if c.time > s.start + 0.5 and c.time < s.stop - 0.5 then inside = true end
        end
        if not inside then table.insert(list, { time = c.time, title = c.title }) end
    end
    if #existing == 0 and segments[1].start > 1 then
        table.insert(list, { time = 0, title = "Episode" })
    end
    for _, s in ipairs(segments) do
        table.insert(list, { time = s.start, title = s.title, seg = true })
        if s.stop < duration - 1 then
            table.insert(list, { time = s.stop, title = title_at(s.stop) })
        end
    end
    table.sort(list, function(a, b) return a.time < b.time end)

    -- Drop near-duplicates, keeping the AniSkip entry.
    local chapters = {}
    for _, c in ipairs(list) do
        local prev = chapters[#chapters]
        if prev and c.time - prev.time < 1 then
            if c.seg then chapters[#chapters] = c end
        else
            table.insert(chapters, c)
        end
    end
    for i, c in ipairs(chapters) do chapters[i] = { time = c.time, title = c.title } end
    mp.set_property_native("chapter-list", chapters)
end

local function lookup(id, title, ep, duration)
    find_mal_id(title, function(mal)
        if id ~= load_id then return end
        if not mal then
            msg.info(string.format("No MyAnimeList entry found for '%s'", title))
            return
        end
        local url = string.format(
            "https://api.aniskip.com/v2/skip-times/%d/%d?types[]=op&types[]=ed&types[]=mixed-op&types[]=mixed-ed&episodeLength=0",
            mal, ep)
        run({ "curl", "-s", "-g", "--max-time", "8", url }, function(data)
            if id ~= load_id then return end
            if not (data and data.found and data.results) then
                msg.info(string.format("No AniSkip times for '%s' episode %d (MAL %d)", title, ep, mal))
                return
            end
            -- The chapters may have changed while waiting (another script, or a reload).
            if has_oped_chapters(mp.get_property_native("chapter-list")) then return end

            local segments = {}
            local op_start, op_end = pick(data.results, { "op", "mixed-op" }, duration)
            local ed_start, ed_end = pick(data.results, { "ed", "mixed-ed" }, duration)
            if op_start then table.insert(segments, { start = op_start, stop = op_end, title = "Opening" }) end
            if ed_start then table.insert(segments, { start = ed_start, stop = ed_end, title = "Ending" }) end
            if #segments == 0 then
                msg.info(string.format("AniSkip times for '%s' episode %d are for a different cut", title, ep))
                return
            end
            table.sort(segments, function(a, b) return a.start < b.start end)
            add_chapters(segments, duration)

            local found = (op_start and ed_start) and "opening and ending" or (op_start and "opening" or "ending")
            msg.info(string.format("AniSkip: added %s for '%s' episode %d", found, title, ep))
            if opts.show_osd then mp.osd_message("AniSkip: " .. found .. " found", 2) end
        end)
    end)
end

local function start(id)
    local path = mp.get_property("path", "")
    -- Local files and mpv-gotorrent streams only; other URLs are not anime releases.
    if path:find("^%a[%w+.-]*://") and not path:find("^https?://127%.0%.0%.1:%d+/torrent/") then return end

    local duration = mp.get_property_number("duration")
    if not duration or duration < opts.min_duration or duration > opts.max_duration then return end
    if has_oped_chapters(mp.get_property_native("chapter-list")) then return end

    local title, ep = parse_release(mp.get_property("filename", ""))
    if not title and not path:find("://") then
        -- "E05.mkv" in a folder named after the show.
        local dir = utils.split_path(path)
        local folder = dir:gsub("[/\\]+$", ""):match("([^/\\]+)$")
        local _, file_ep = parse_release("x - " .. mp.get_property("filename", ""))
        if folder and file_ep then title, ep = trim(folder:gsub("%b[]", " "):gsub("%b()", " ")), file_ep end
    end
    if not title or not ep or ep < 1 then return end

    msg.verbose(string.format("Looking up '%s' episode %d", title, ep))
    lookup(id, title, ep, duration)
end

mp.register_event("file-loaded", function()
    load_id = load_id + 1
    if not opts.enabled then return end
    local id = load_id
    if mp.get_property_number("duration") then return start(id) end
    -- Some streams only know their length a little later.
    local function on_duration(_, d)
        if d then
            mp.unobserve_property(on_duration)
            if id == load_id then start(id) end
        end
    end
    mp.observe_property("duration", "number", on_duration)
    mp.add_timeout(10, function() mp.unobserve_property(on_duration) end)
end)
