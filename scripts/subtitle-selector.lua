local mp = require "mp"
local msg = require "mp.msg"

local function select_dialogue_sub()
    local tracks = mp.get_property_native("track-list")
    if not tracks then return end

    local fallback_id = nil

    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            local lang = (t.lang or ""):lower()
            local title = (t.title or ""):lower()

            -- 1. Check for English language to save as a fallback
            if not fallback_id and (lang == "eng" or lang == "en") then
                fallback_id = t.id
            end

            -- 2. Original Logic: Look for "Dialogue" or "Full" in Eng/Jp
            local lang_ok =
                lang == "eng" or lang == "en" or
                lang == "jpn" or lang == "jp" or lang == "ja"

            local title_ok =
                title:find("dialogue") or
                title:find("dialogues") or
                title:find("full")

            if lang_ok and title_ok then
                mp.set_property_number("sid", t.id)
                msg.info("Auto-selected Subtitles: " .. (t.title or "Dialogue"))
                return
            end
        end
    end

    -- 3. Fallback: Switch to the first found English track if no specific match
    if fallback_id then
        mp.set_property_number("sid", fallback_id)
        msg.info("Auto-selected Subtitles: English (Default)")
    end
end

mp.register_event("file-loaded", select_dialogue_sub)