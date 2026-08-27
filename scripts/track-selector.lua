-- [[
--    FILENAME: track-selector.lua
--    VERSION:  v3.5 (Added priorities for User selection)
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

-- Changes made by this script are explicitly marked so the aid/sid observers
-- never mistake them for a user action. This replaces the old timing-only
-- assumption used by v3.4.
local internal_aid_change = nil
local internal_sid_change = nil
local file_transition = true
local settle_timer = nil
local session_manual_selection = nil

-- ==================================================
-- TRACK SELECTOR MASTER MODE
-- ==================================================
-- AUTO = run the existing smart selector.
-- DISABLED = leave MPV's native track selection completely alone.
local track_selector_enabled = true
local track_selector_opts = mp.command_native({"expand-path", "~~/script-opts/anime-mode.conf"})

local function load_track_selector_mode()
    local f = io.open(track_selector_opts, "r")
    if not f then return end

    for line in f:lines() do
        local value = line:match("^track_selector_enabled=(%S+)")
        if value then
            track_selector_enabled = (value == "true")
            break
        end
    end
    f:close()
end

local function set_track_selector_mode(enabled, announce)
    track_selector_enabled = enabled == true
    ignore_track_changes = true

    -- When disabled, discard the selector's session-only override state too.
    -- The persistent per-video override file itself is intentionally preserved.
    if not track_selector_enabled then
        manual_override = false
    end

    mp.set_property("user-data/track-selector-enabled", track_selector_enabled and "yes" or "no")

    -- If AUTO is enabled while a file is already playing, allow manual
    -- changes after a short settling period. File transitions are handled
    -- separately by file-loaded, so this timer cannot misclassify startup
    -- changes from the next/previous file as user input.
    if track_selector_enabled then
        mp.add_timeout(0.5, function()
            if track_selector_enabled and not file_transition then
                ignore_track_changes = false
            end
        end)
    end

    if announce then
        msg.info("Smart Tracks: Track Selector mode -> " .. (track_selector_enabled and "AUTO" or "DISABLED"))
    end
end

load_track_selector_mode()
set_track_selector_mode(track_selector_enabled, false)

-- Controller/UOSC uses this message to synchronize the persisted setting.
mp.register_script_message("set-enabled", function(value)
    local enabled = not (value == "false" or value == "0" or value == "off" or value == "disabled")
    set_track_selector_mode(enabled, true)
end)

mp.register_script_message("toggle-enabled", function()
    set_track_selector_mode(not track_selector_enabled, true)
end)

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

local function get_saved_manual_override()
    local key = get_current_video_key()
    if not key then return nil end

    local entry = manual_overrides[key]

    -- Backward compatibility with v3.3/v3.4 files that stored only `true`.
    if entry == true then
        return { manual_override = true }
    end

    if type(entry) == "table" and entry.manual_override == true then
        return entry
    end

    return nil
end

local function get_track_snapshot(track_id, tracks, track_type)
    if track_id == "no" then
        return { type = track_type, disabled = true }
    end

    local numeric_id = tonumber(track_id)
    if not numeric_id or numeric_id <= 0 then return nil end

    for _, t in ipairs(tracks or {}) do
        if t.id == numeric_id and t.type == track_type then
            return {
                type = t.type,
                lang = (t.lang or ""):lower(),
                title = (t.title or ""):lower(),
                forced = t.forced == true,
                hearing_impaired = t["hearing-impaired"] == true,
                codec = (t.codec or ""):lower(),
            }
        end
    end

    return nil
end

local function capture_current_selection()
    local tracks = mp.get_property_native("track-list") or {}
    return {
        audio = get_track_snapshot(mp.get_property("aid"), tracks, "audio"),
        subtitle = get_track_snapshot(mp.get_property("sid"), tracks, "sub"),
    }
end

local function save_current_video_manual_override()
    local key = get_current_video_key()
    if not key then return end

    local selection = capture_current_selection()
    session_manual_selection = selection
    manual_overrides[key] = {
        manual_override = true,
        audio = selection.audio,
        subtitle = selection.subtitle,
    }

    save_manual_overrides()
    msg.info("Smart Tracks: Saved manual override selections for this video.")
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
-- TRACK APPLICATION / MANUAL SELECTION HELPERS
-- ==================================================

local function mark_internal_change(kind, id)
    if kind == "audio" then
        internal_aid_change = tostring(id)
    elseif kind == "subtitle" then
        internal_sid_change = tostring(id)
    end
end

local function apply_internal_track(kind, id, log_msg)
    if not id then return nil end

    local property = kind == "audio" and "aid" or "sid"
    local current = mp.get_property_number(property)

    if current == id then
        msg.info(log_msg .. " (id=" .. id .. ") [Already Active. Skipping Change.]")
        return id
    end

    mark_internal_change(kind, id)
    mp.set_property_number(property, id)
    msg.info(log_msg .. " (id=" .. id .. ") [Applied]")
    return id
end

local function track_is_ignored_subtitle(track)
    if not track then return true end

    local title = (track.title or ""):lower()
    local ignore_subs = {"signs", "songs", "lyrics", "forced", "sdh", "colored", "karaoke"}

    return contains_keyword(title, ignore_subs)
        or track.forced == true
        or track["hearing-impaired"] == true
end

local function subtitle_match_score(track, wanted)
    if not track or track.type ~= "sub" or not wanted then return -1 end

    local score = 0
    local lang = (track.lang or ""):lower()
    local title = (track.title or ""):lower()

    if wanted.title ~= "" and title == wanted.title then
        score = score + 1000
    elseif wanted.title ~= "" and title:find(wanted.title, 1, true) then
        score = score + 500
    end

    if wanted.lang ~= "" and matches_lang(lang, wanted.lang) then
        score = score + 200
    end

    if track.forced == wanted.forced then
        score = score + 40
    elseif wanted.forced then
        return -1
    else
        -- A previously non-forced selection should never be replaced by a
        -- forced track during manual override.
        if track.forced then return -1 end
    end

    if track["hearing-impaired"] == wanted.hearing_impaired then
        score = score + 20
    elseif not wanted.hearing_impaired and track["hearing-impaired"] then
        return -1
    end

    if not wanted.forced and track_is_ignored_subtitle(track) then
        return -1
    end

    if wanted.codec ~= "" and (track.codec or ""):lower() == wanted.codec then
        score = score + 5
    end

    return score
end

local function audio_match_score(track, wanted)
    if not track or track.type ~= "audio" or not wanted then return -1 end

    local score = 0
    local lang = (track.lang or ""):lower()
    local title = (track.title or ""):lower()

    if wanted.title ~= "" and title == wanted.title then
        score = score + 1000
    elseif wanted.title ~= "" and title:find(wanted.title, 1, true) then
        score = score + 500
    end

    if wanted.lang ~= "" and matches_lang(lang, wanted.lang) then
        score = score + 200
    end

    local ignore_audio = {"commentary", "description", "adh", "comment", "extra"}
    if contains_keyword(title, ignore_audio) then
        return -1
    end

    if wanted.codec ~= "" and (track.codec or ""):lower() == wanted.codec then
        score = score + 5
    end

    return score
end

local function find_manual_track(kind, wanted, tracks)
    if not wanted or wanted.disabled then return nil end

    local best_id = nil
    local best_score = -1

    for _, t in ipairs(tracks or {}) do
        local score
        if kind == "audio" then
            score = audio_match_score(t, wanted)
        else
            score = subtitle_match_score(t, wanted)
        end

        if score > best_score then
            best_score = score
            best_id = t.id
        end
    end

    return best_score > 0 and best_id or nil
end

local function apply_manual_override_selection(saved)
    local tracks = mp.get_property_native("track-list") or {}
    if not saved then return end

    -- Mark the entire application phase as internal. The observer also has
    -- per-property markers, so later MPV changes can still be detected.
    ignore_track_changes = true

    local audio_id = find_manual_track("audio", saved.audio, tracks)
    local sub_id = find_manual_track("subtitle", saved.subtitle, tracks)

    if saved.audio then
        if saved.audio.disabled then
            mark_internal_change("audio", "no")
            mp.set_property("aid", "no")
            msg.info("Smart Audio: Manual Override carried AUDIO disabled state.")
        elseif audio_id then
            apply_internal_track("audio", audio_id, "Smart Audio: Manual Override carried selection")
        else
            msg.info("Smart Audio: Manual Override selection not found in this file; leaving MPV selection unchanged.")
        end
    end

    if saved.subtitle then
        if saved.subtitle.disabled then
            mark_internal_change("subtitle", "no")
            mp.set_property("sid", "no")
            msg.info("Smart Sub: Manual Override carried SUBTITLE disabled state.")
        elseif sub_id then
            apply_internal_track("subtitle", sub_id, "Smart Sub: Manual Override carried selection")
        else
            msg.info("Smart Sub: Manual Override selection not found in this file; leaving MPV selection unchanged.")
        end
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
    local incomplete_subs = {"signs", "songs", "lyrics", "forced", "colored", "karaoke"}

    -- Get Currently Active Tracks for the Check Gate
    local current_aid = mp.get_property_number("aid")
    local current_sid = mp.get_property_number("sid")

    -- Check Gate Helper Functions
    local function apply_audio(id, log_msg)
        if id == current_aid then
            msg.info("Smart Audio: " .. log_msg .. " (id=" .. id .. ") [Already Active. Skipping Change.]")
        else
            mark_internal_change("audio", id)
            mp.set_property_number("aid", id)
            msg.info("Smart Audio: " .. log_msg .. " (id=" .. id .. ") [Applied]")
        end
        return id
    end

    local function apply_sub(id, log_msg)
        if id == current_sid then
            msg.info("Smart Sub: " .. log_msg .. " (id=" .. id .. ") [Already Active. Skipping Change.]")
        else
            mark_internal_change("subtitle", id)
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
                        if (title:find("dialogue") or title:find("full") or title:find("script"))
                                and not track_is_ignored_subtitle(t) then
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
                    local title = (t.title or ""):lower()
                    local is_sdh = title:find("sdh", 1, true)
                        or t["hearing-impaired"] == true
                    local is_incomplete = contains_keyword(title, incomplete_subs)
                        or t.forced == true

                    -- An accessible full-dialogue track in the requested
                    -- language is more useful than a clean subtitle in an
                    -- unrelated language. Keep incomplete forced/signs-only
                    -- tracks excluded from this fallback.
                    if matches_lang(lang, pref_lang) and is_sdh and not is_incomplete then
                        selected_sid = apply_sub(t.id, "Preferred SDH Match (Slang)")
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
                if (title:find("full") or title:find("dialogue") or title:find("script"))
                        and not track_is_ignored_subtitle(t) then
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

local function finish_file_settling(delay)
    if settle_timer then settle_timer:kill() end

    settle_timer = mp.add_timeout(delay or 0.75, function()
        settle_timer = nil
        if track_selector_enabled then
            file_transition = false
            ignore_track_changes = false
        end
    end)
end

-- A new file always starts with change detection suppressed. This prevents
-- MPV's native track initialization from being interpreted as a user action.
mp.register_event("start-file", function()
    load_track_selector_mode()
    set_track_selector_mode(track_selector_enabled, false)

    file_transition = true
    ignore_track_changes = true
    internal_aid_change = nil
    internal_sid_change = nil
end)

mp.observe_property("aid", "string", function(name, val)
    if not track_selector_enabled or ignore_track_changes or file_transition then
        return
    end

    if internal_aid_change and val == internal_aid_change then
        internal_aid_change = nil
        return
    end

    internal_aid_change = nil

    msg.info("Smart Tracks: User manually changed AUDIO track. Manual override is now active for the rest of this session/playlist.")
    manual_override = true
    save_current_video_manual_override()
end)

mp.observe_property("sid", "string", function(name, val)
    if not track_selector_enabled or ignore_track_changes or file_transition then
        return
    end

    if internal_sid_change and val == internal_sid_change then
        internal_sid_change = nil
        return
    end

    internal_sid_change = nil

    msg.info("Smart Tracks: User manually changed SUBTITLE track. Manual override is now active for the rest of this session/playlist.")
    manual_override = true
    save_current_video_manual_override()
end)

-- ==================================================
-- INITIALIZATION
-- ==================================================
mp.register_event("file-loaded", function()
    load_track_selector_mode()
    set_track_selector_mode(track_selector_enabled, false)

    if not track_selector_enabled then
        file_transition = false
        ignore_track_changes = true
        msg.info("Smart Tracks: Track Selector is DISABLED. Respecting MPV native track selection.")
        return
    end

    file_transition = true
    ignore_track_changes = true
    internal_aid_change = nil
    internal_sid_change = nil

    if not is_video_file() then
        msg.info("Smart Tracks: Audio file detected. Script disabled.")
        finish_file_settling(0.75)
        return
    end

    local resume_time = mp.get_property_number("playback-time") or 0
    local saved_override = get_saved_manual_override()

    -- A saved override is restored only when the exact video is actually
    -- resumed. Once restored, it remains active for the rest of this MPV
    -- session/playlist.
    if not manual_override and resume_time > 1 and saved_override then
        manual_override = true
        msg.info("Smart Tracks: Resumed video has a saved manual override. "
            .. "Manual override will remain active for this MPV session/playlist.")

        -- Old v3.3/v3.4 entries contain only `true`. In that case the
        -- watch-later state already restored the user's tracks, so capture
        -- the restored selection and use it as the carried selection.
        if not saved_override.audio and not saved_override.subtitle then
            saved_override = {
                manual_override = true,
                audio = get_track_snapshot(mp.get_property("aid"), mp.get_property_native("track-list") or {}, "audio"),
                subtitle = get_track_snapshot(mp.get_property("sid"), mp.get_property_native("track-list") or {}, "sub"),
            }
        end

        session_manual_selection = {
            audio = saved_override.audio,
            subtitle = saved_override.subtitle,
        }

        mp.add_timeout(0.15, function()
            apply_manual_override_selection(saved_override)
            finish_file_settling(0.75)
        end)
        return
    end

    if manual_override then
        msg.info("Smart Tracks: Manual override is active. Carrying current audio/subtitle selections.")
        mp.add_timeout(0.2, function()
            -- The current session snapshot is stored in `session_manual_selection`.
            -- If it is unavailable, capture the last known selection from the
            -- current file before proceeding.
            if session_manual_selection then
                apply_manual_override_selection(session_manual_selection)
            end
            finish_file_settling(0.75)
        end)
        return
    end

    if resume_time > 1 then
        msg.info("Smart Tracks: Resumed video with no saved manual override. Respecting saved track state.")
        finish_file_settling(0.75)
        return
    end

    mp.add_timeout(0.2, function()
        select_smart_tracks()
        finish_file_settling(0.75)
    end)
end)
