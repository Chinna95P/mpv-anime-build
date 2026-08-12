-- [[
--    FILENAME: track-selector.lua
--    VERSION:  v3.3 (Added Manual Override Persistence for Resumed videos)
--    DESCRIPTION: Enhances mpv's intelligent audio/subtitle track selection.
-- ]]

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

-- ==================================================
-- STATE VARIABLES (New)
-- ==================================================
local manual_override = false
local ignore_track_changes = true

-- ==================================================
-- PERSISTENT MANUAL OVERRIDE (PER VIDEO)
-- ==================================================
-- Stores only the videos for which the user explicitly changed a track.
-- The override is used only when that same video is resumed later.
local override_file = mp.command_native({"expand-path", "~~/track-selector-overrides.json"})
local manual_overrides = {}

local function load_manual_overrides()
    local f = io.open(override_file, "r")
    if not f then return end

    local content = f:read("*all")
    f:close()

    if content and content ~= "" then
        local data = utils.parse_json(content)
        if type(data) == "table" then
            manual_overrides = data
        end
    end
end

local function save_manual_overrides()
    local f = io.open(override_file, "w")
    if not f then
        msg.warn("Smart Tracks: Could not save manual override state: " .. override_file)
        return
    end

    f:write(utils.format_json(manual_overrides))
    f:close()
end

local function get_current_video_key()
    local path = mp.get_property("path")
    if not path or path == "" then return nil end
    return path
end

local function has_saved_manual_override()
    local key = get_current_video_key()
    return key and manual_overrides[key] == true
end

local function save_current_video_manual_override()
    local key = get_current_video_key()
    if not key then return end

    manual_overrides[key] = true
    save_manual_overrides()
    msg.info("Smart Tracks: Saved manual override for this video.")
end

load_manual_overrides()

-- Helper function to split comma-separated strings (like "jpn,eng,en")
local function split_string(str)
    local t = {}
    if not str or str == "" then return t end
    for s in string.gmatch(str, "([^,]+)") do
        table.insert(t, s:gsub("%s+", ""):lower())
    end
    return t
end

-- Helper to check if a string contains any keyword from a list
local function contains_keyword(text, keywords)
    if not text then return false end
    for _, kw in ipairs(keywords) do
        if text:find(kw) then return true end
    end
    return false
end

-- Helper to check if a track language matches a preferred language
local function matches_lang(track_lang, pref_lang)
    if not track_lang then return false end
    return string.sub(track_lang, 1, string.len(pref_lang)) == pref_lang
end

-- Helper to verify if the file contains actual moving video
local function is_video_file()
    local track_list = mp.get_property_native("track-list") or {}
    for _, track in ipairs(track_list) do
        if track.type == "video" and not track.image then
            return true
        end
    end
    return false
end

-- ==================================================
-- AUTO-DETECTION HELPERS
-- ==================================================
local function is_anime_folder(p)
    if not p then return false end
    p = p:lower()
    return p:find("/anime/") or p:find("\\anime\\")
        or p:find("donghua") or p:find("cartoon")
        or p:find("animation") or p:find("3d_anime")
end

local function is_live_action(p, t)
    local search_str = ((p or "") .. " " .. (t or "")):lower()
    return search_str:find("live action") or search_str:find("live%-action")
        or search_str:find("liveaction") or search_str:find("drama")
        or search_str:find("real person")
end

local function detect_anime_context(tracks)
    local path = mp.get_property("path", "")
    local title = mp.get_property("media-title", "")
    local filename = mp.get_property("filename", "")
    local shiru_opt = mp.get_opt("mode")

    local signal_folder = is_anime_folder(path)
    local signal_live_action = is_live_action(path, title)
    local signal_syntax = (title:match("%[.*%]"))
    local signal_shiru  = (shiru_opt == "anime")

    local crc_pattern = "%[%x%x%x%x%x%x%x%x%]"
    local signal_crc = filename:match(crc_pattern) or title:match(crc_pattern)

    local signal_audio = false
    for _, track in ipairs(tracks) do
        if track.type == "audio" and track.lang then
            local lang = track.lang:lower()
            if lang == "jpn" or lang == "ja" then
                signal_audio = true
                break
            end
        end
    end

    if signal_live_action then
        return false
    elseif signal_crc then
        return true
    elseif signal_folder or signal_audio or signal_syntax or signal_shiru then
        return true
    else
        return false
    end
end

-- ==================================================
-- MAIN TRACK SELECTION LOGIC
-- ==================================================
local function select_smart_tracks()
    local tracks = mp.get_property_native("track-list")
    if not tracks then return end

    -- Read user's preferred languages
    local pref_audio_langs = split_string(mp.get_property("alang"))
    local pref_sub_langs = split_string(mp.get_property("slang"))

    -- Keywords to ignore
    local ignore_audio = {"commentary", "description", "adh", "comment", "extra"}
    local ignore_subs = {"signs", "songs", "lyrics", "forced", "sdh", "colored", "karaoke"}

    -- Get Currently Active Tracks for the Check Gate
    local current_aid = mp.get_property_number("aid")
    local current_sid = mp.get_property_number("sid")

    -- Check Gate Helper Functions
    local function apply_audio(id, log_msg)
        if id == current_aid then
            msg.info("Smart Audio: " .. log_msg .. " (id=" .. id .. ") [Already Active. Skipping Change.]")
        else
            mp.set_property_number("aid", id)
            msg.info("Smart Audio: " .. log_msg .. " (id=" .. id .. ") [Applied]")
        end
        return id
    end

    local function apply_sub(id, log_msg)
        if id == current_sid then
            msg.info("Smart Sub: " .. log_msg .. " (id=" .. id .. ") [Already Active. Skipping Change.]")
        else
            mp.set_property_number("sid", id)
            msg.info("Smart Sub: " .. log_msg .. " (id=" .. id .. ") [Applied]")
        end
        return id
    end

    local selected_aid = nil

    -- 1. AUDIO SELECTION LOGIC
    for _, pref_lang in ipairs(pref_audio_langs) do
        for _, t in ipairs(tracks) do
            if t.type == "audio" and not selected_aid then
                local lang = (t.lang or ""):lower()
                local title = (t.title or ""):lower()

                if matches_lang(lang, pref_lang) and not contains_keyword(title, ignore_audio) then
                    selected_aid = apply_audio(t.id, "Selected " .. lang)
                    break
                end
            end
        end
        if selected_aid then break end
    end

    if not selected_aid then
        for _, t in ipairs(tracks) do
            if t.type == "audio" then
                local title = (t.title or ""):lower()
                if not contains_keyword(title, ignore_audio) then
                    selected_aid = apply_audio(t.id, "Fallback")
                    break
                end
            end
        end
    end

    local selected_audio_lang = ""
    if selected_aid then
        for _, t in ipairs(tracks) do
            if t.id == selected_aid then
                selected_audio_lang = (t.lang or ""):lower()
                break
            end
        end
    end

    -- 2. CONTEXT DETECTION
    local is_anime_context = detect_anime_context(tracks)
    msg.info("Smart Tracks: Context defined by Internal Auto-Detection -> " .. tostring(is_anime_context))

    -- 3. SUBTITLE SELECTION LOGIC
    local selected_sid = nil
    if #pref_sub_langs == 0 then pref_sub_langs = {"eng", "en"} end

    if is_anime_context and not selected_sid then
        local default_count = 0
        for _, t in ipairs(tracks) do
            if t.type == "sub" and t.default then
                default_count = default_count + 1
            end
        end

        if default_count == 1 then
            for _, t in ipairs(tracks) do
                if t.type == "sub" and t.default then
                    local lang = (t.lang or ""):lower()
                    if lang == "jpn" or lang == "ja" or lang == "jp" then
                        selected_sid = apply_sub(t.id, "Native File Default Japanese Sub")
                    end
                    break
                end
            end
        elseif default_count > 1 then
            msg.info("Smart Sub: Multiple default tracks detected (Muxing error). Ignoring and using slang.")
        end
    end

    if is_anime_context and not selected_sid then
        for _, pref_lang in ipairs(pref_sub_langs) do
            for _, t in ipairs(tracks) do
                if t.type == "sub" and not selected_sid then
                    local lang = (t.lang or ""):lower()
                    local title = (t.title or ""):lower()
                    if matches_lang(lang, pref_lang) then
                        if title:find("dialogue") or title:find("full") or title:find("script") then
                            selected_sid = apply_sub(t.id, "Anime Dialogue matched (Slang)")
                            break
                        end
                    end
                end
            end
            if selected_sid then break end
        end
    end

    if not selected_sid then
        for _, pref_lang in ipairs(pref_sub_langs) do
            for _, t in ipairs(tracks) do
                if t.type == "sub" and not selected_sid then
                    local lang = (t.lang or ""):lower()
                    local title = (t.title or ""):lower()
                    local is_forced = t.forced or false
                    local is_sdh = t["hearing-impaired"] or false

                    if matches_lang(lang, pref_lang) then
                        if not contains_keyword(title, ignore_subs) and not is_forced and not is_sdh then
                            selected_sid = apply_sub(t.id, "Clean Match (Slang)")
                            break
                        end
                    end
                end
            end
            if selected_sid then break end
        end
    end

    if not selected_sid then
        for _, pref_lang in ipairs(pref_sub_langs) do
            for _, t in ipairs(tracks) do
                if t.type == "sub" and not selected_sid then
                    local lang = (t.lang or ""):lower()
                    if matches_lang(lang, pref_lang) then
                        selected_sid = apply_sub(t.id, "Fallback Match (Slang)")
                        break
                    end
                end
            end
            if selected_sid then break end
        end
    end

    if not selected_sid then
        for _, t in ipairs(tracks) do
            if t.type == "sub" then
                local title = (t.title or ""):lower()
                if title:find("full") or title:find("dialogue") or title:find("script") then
                    selected_sid = apply_sub(t.id, "Anime Dialogue matched (Language Fallback)")
                    break
                end
            end
        end
    end

    if not selected_sid then
        for _, t in ipairs(tracks) do
            if t.type == "sub" then
                local title = (t.title or ""):lower()
                if t.default == true then
                    if not contains_keyword(title, ignore_subs) and not t.forced and not t["hearing-impaired"] then
                        selected_sid = apply_sub(t.id, "Default Track Match (Language Fallback)")
                        break
                    end
                end
            end
        end

        if not selected_sid then
            for _, t in ipairs(tracks) do
                if t.type == "sub" then
                    local title = (t.title or ""):lower()
                    if not contains_keyword(title, ignore_subs) and not t.forced and not t["hearing-impaired"] then
                        selected_sid = apply_sub(t.id, "Clean Match (Language Fallback)")
                        break
                    end
                end
            end
        end
    end
end

-- ==================================================
-- MANUAL OVERRIDE DETECTION
-- ==================================================

-- We reset the tracker when a new file starts so mpv's native initial track switching doesn't trip it
mp.register_event("start-file", function()
    ignore_track_changes = true
end)

mp.observe_property("aid", "string", function(name, val)
    if not ignore_track_changes then
        msg.info("Smart Tracks: User manually changed AUDIO track. Disabling script for this video.")
        manual_override = true
        save_current_video_manual_override()
    end
end)

mp.observe_property("sid", "string", function(name, val)
    if not ignore_track_changes then
        msg.info("Smart Tracks: User manually changed SUBTITLE track. Disabling script for this video.")
        manual_override = true
        save_current_video_manual_override()
    end
end)

-- ==================================================
-- INITIALIZATION
-- ==================================================
mp.register_event("file-loaded", function()
    -- manual_override intentionally persists across files in the same MPV
    -- session/playlist. It is only reset when the Lua script/MPV process starts.
    ignore_track_changes = true

    if not is_video_file() then
        msg.info("Smart Tracks: Audio file detected. Script disabled.")
        return
    end

    local resume_time = mp.get_property_number("playback-time") or 0
    local saved_override = has_saved_manual_override()

    -- On a new MPV session, restore the saved override only when this exact
    -- video is being resumed. Once restored, manual_override stays true for
    -- the rest of this MPV session/playlist, including next/previous files.
    if not manual_override and resume_time > 1 and saved_override then
        manual_override = true
        msg.info("Smart Tracks: Resumed video has a saved manual override. "
            .. "Manual override will remain active for this MPV session/playlist.")
    end

    if manual_override then
        msg.info("Smart Tracks: Manual override is active. Skipping script selection.")
        mp.add_timeout(0.5, function()
            ignore_track_changes = false
        end)
        return
    end

    if resume_time > 1 then
        msg.info("Smart Tracks: Resumed video with no saved manual override. Respecting saved track state.")
        mp.add_timeout(0.5, function()
            ignore_track_changes = false
        end)
        return
    end

    mp.add_timeout(0.2, function()
        select_smart_tracks()

        -- After the script finishes its job, wait 0.5s for mpv's properties to settle.
        -- Then, any subsequent change is considered a user manual change.
        mp.add_timeout(0.5, function()
            ignore_track_changes = false
        end)
    end)
end)
