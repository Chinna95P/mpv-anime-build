local mp = require("mp")

local skip_ranges = {}
local skipping = false

local skip_names = {
    "intro",
    "op",
    "opening",
    "ed",
    "ending",
    "credits",
    "logo",
    "preview"
}

local skip_set = {}
for _, name in ipairs(skip_names) do
    skip_set[name] = true
end

local function should_skip_chapter(title)
    if not title then return false end
    return skip_set[title:lower()] == true
end

local function build_skip_ranges()
    skip_ranges = {}

    local chapters = mp.get_property_native("chapter-list")
    local duration = mp.get_property_number("duration")
    if not chapters or not duration then return end

    for i, ch in ipairs(chapters) do
        local start = ch.time
        local finish = chapters[i + 1] and chapters[i + 1].time or duration
        if not start or not finish then goto continue end

        local len = finish - start

        if should_skip_chapter(ch.title)
           or (not ch.title and len >= 88 and len <= 92) then
            table.insert(skip_ranges, {
                start = start,
                finish = finish,
                title = ch.title or "Unnamed Chapter"
            })
        end

        ::continue::
    end
end

local function check_skip(_, time)
    if skipping or not time then return end

    for _, r in ipairs(skip_ranges) do
        if time >= r.start and time < r.finish then
            skipping = true
            mp.osd_message("Skipping: " .. r.title, 1)
            mp.commandv("seek", r.finish, "absolute+exact")
            mp.add_timeout(0.1, function()
                skipping = false
            end)
            return
        end
    end
end

mp.register_event("file-loaded", build_skip_ranges)
mp.observe_property("time-pos", "number", check_skip)