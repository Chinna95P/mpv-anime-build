-- [[ 
--    FILENAME: track-selector.lua
--    VERSION:  v3.1 (Added Fallbacks for Selection)
--    DESCRIPTION: Enhances mpv's intelligent audio/subtitle track selection.
-- ]]

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

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

    -- ==================================================
    -- 1. AUDIO SELECTION LOGIC
    -- ==================================================
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

    -- Detect if the selected audio is Japanese
    local selected_audio_lang = ""
    if selected_aid then
        for _, t in ipairs(tracks) do
            if t.id == selected_aid then
                selected_audio_lang = (t.lang or ""):lower()
                break
            end
        end
    end
    local is_japanese_audio = (selected_audio_lang == "jpn" or selected_audio_lang == "ja" or selected_audio_lang == "jp")

    -- ==================================================
    -- 2. CONTEXT DETECTION (Anime vs Live-Action)
    -- ==================================================
    local is_anime_context = detect_anime_context(tracks)
    msg.info("Smart Tracks: Context defined by Internal Auto-Detection -> " .. tostring(is_anime_context))

    -- ==================================================
    -- 3. SUBTITLE SELECTION LOGIC
    -- ==================================================
    local selected_sid = nil
    
    if #pref_sub_langs == 0 then pref_sub_langs = {"eng", "en"} end

    -- Pass A0: KEEP FILE'S NATIVE DEFAULT JAPANESE SUBS FOR ANIME
    if is_anime_context and not selected_sid then
        -- Sanity check: Count how many sub tracks are flagged as default
        local default_count = 0
        for _, t in ipairs(tracks) do
            if t.type == "sub" and t.default then
                default_count = default_count + 1
            end
        end

        -- Only trust the default flag if the encoder properly flagged exactly ONE track
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

    -- Pass A: SMART ANIME DIALOGUE (Standard Preferred Langs - Runs only if Pass A0 didn't trigger or not anime)
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

    -- Pass B: CLEAN LANGUAGE MATCH
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

    -- Pass C: LAST RESORT MATCH
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

    -- ==================================================
    -- [NEW] ANY-LANGUAGE FALLBACKS
    -- Runs only if NO preferred languages (slang) were found
    -- ==================================================

    -- Pass D: Anime Dialogue matched (Language Fallback)
    -- This handles the "Full Subtitles" case for files with no language tags
    if not selected_sid then
        for _, t in ipairs(tracks) do
            if t.type == "sub" then
                local title = (t.title or ""):lower()
                -- Check for high-priority keywords regardless of language
                if title:find("full") or title:find("dialogue") or title:find("script") then
                    selected_sid = apply_sub(t.id, "Anime Dialogue matched (Language Fallback)")
                    break
                end
            end
        end
    end

    -- Pass E: CLEAN MATCH (The "Last Resort")
    if not selected_sid then
        -- Step 1: Check for the 'default' flag (using mpv's property name)
        for _, t in ipairs(tracks) do
            if t.type == "sub" then
                local title = (t.title or ""):lower()
                -- mpv often uses t.default (boolean). We also check for forced/sdh.
                if t.default == true then
                    if not contains_keyword(title, ignore_subs) and not t.forced and not t["hearing-impaired"] then
                        selected_sid = apply_sub(t.id, "Default Track Match (Language Fallback)")
                        break
                    end
                end
            end
        end

        -- Step 2: If no default, pick the first track that isn't "junk"
        if not selected_sid then
            for _, t in ipairs(tracks) do
                if t.type == "sub" then
                    local title = (t.title or ""):lower()
                    -- Ensure we skip "signs", "songs", "forced", etc.
                    if not contains_keyword(title, ignore_subs) and not t.forced and not t["hearing-impaired"] then
                        selected_sid = apply_sub(t.id, "Clean Match (Language Fallback)")
                        break
                    end
                end
            end
        end
    end
end

-- Wait a tiny bit after the file loads for mpv to parse all the tracks, then run logic
mp.register_event("file-loaded", function()
    if not is_video_file() then
        msg.info("Smart Tracks: Audio file detected. Script disabled.")
        return
    end

    local start_time = mp.get_property_number("start-time") or 0
    local resume_time = mp.get_property_number("playback-time") or 0
    
    if resume_time > 1 then
        msg.info("Smart Tracks: Resumed file, respecting saved state.")
        return
    end

    mp.add_timeout(0.2, function()
        select_smart_tracks()
    end)
end)