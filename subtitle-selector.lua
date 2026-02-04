local mp = require "mp"
local msg = require "mp.msg"

local function select_dialogue_sub()
    local tracks = mp.get_property_native("track-list")
    if not tracks then return end

    -- 1. DETECT CONTEXT (Is this Anime?)
    local is_anime = false
    for _, t in ipairs(tracks) do
        if t.type == "audio" then
            local lang = (t.lang or ""):lower()
            if lang == "jpn" or lang == "ja" or lang == "jp" then
                is_anime = true
                break
            end
        end
    end

    if is_anime then
        -- ==================================================
        -- ANIME LOGIC (Original "Dialogue" Priority)
        -- ==================================================
        local fallback_id = nil

        for _, t in ipairs(tracks) do
            if t.type == "sub" then
                local lang = (t.lang or ""):lower()
                local title = (t.title or ""):lower()

                -- A. Save Japanese fallback (Original Logic)
                if not fallback_id and (lang == "jpn" or lang == "jp" or lang == "ja") then
                    fallback_id = t.id
                end

                -- B. Look for "Dialogue" or "Full" in Eng/Jp
                local lang_ok =
                    lang == "jpn" or lang == "jp" or lang == "ja" or
                    lang == "eng" or lang == "en"

                local title_ok =
                    title:find("dialogue") or
                    title:find("dialogues") or
                    title:find("full")

                if lang_ok and title_ok then
                    mp.set_property_number("sid", t.id)
                    msg.info("Auto-selected Subtitles (Anime): " .. (t.title or "Dialogue"))
                    return
                end
            end
        end

        -- C. Fallback to Japanese if no Dialogue match found
        if fallback_id then
            mp.set_property_number("sid", fallback_id)
            msg.info("Auto-selected Subtitles (Anime): Japanese Fallback")
        end

    else
        -- ==================================================
        -- LIVE ACTION LOGIC (First English Priority)
        -- ==================================================
        for _, t in ipairs(tracks) do
            if t.type == "sub" then
                local lang = (t.lang or ""):lower()
                -- Check for various English codes
                if lang == "eng" or lang == "en" or lang == "enus" or lang == "en-us" then
                    mp.set_property_number("sid", t.id)
                    msg.info("Auto-selected Subtitles (Live Action): English Default")
                    return
                end
            end
        end
    end
end

mp.register_event("file-loaded", select_dialogue_sub)