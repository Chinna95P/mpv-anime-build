local mp = require "mp"

local function select_dialogue_sub()
    local tracks = mp.get_property_native("track-list")
    if not tracks then return end

    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            local lang = (t.lang or ""):lower()
            local title = (t.title or ""):lower()

            local lang_ok =
                lang == "eng" or lang == "en" or
                lang == "jpn" or lang == "jp" or lang == "ja"

            local title_ok =
                title:find("dialogue") or
                title:find("dialogues") or
                title:find("full")

            if lang_ok and title_ok then
                mp.set_property_number("sid", t.id)
                mp.commandv(
                    "show-text",
                    "Subtitles: " .. (t.title or "Dialogue"),
                    2000
                )
                return
            end
        end
    end
end

mp.register_event("file-loaded", select_dialogue_sub)
