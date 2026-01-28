-- [[ 
--    FILENAME: skip_intro.lua
--    VERSION:  v2.0 (Universal Language & Style Support)
--    AUTHOR:   mpv-anime-build
--    DESC:     Comprehensive detection for OP/ED/PV/Intro/Avant in ENG/JPN/ROMAJI.
-- ]]

local mp = require("mp")
local opts = {
    enabled = true,
    skip_key = "ENTER",
    timeout = 6
}

-- [COMPREHENSIVE PATTERN MATCHING]
-- Covers English, Japanese (Kanji/Kana), Romaji, and common abbreviations.
local categories = {
    { 
        label = "OP", 
        keywords = { 
            -- English / Common
            "opening", " op ", "^op$", "op%d", "theme song", "main theme",
            -- Japanese (Katakana/Kanji)
            "オープニング",         -- Opuningu (Opening)
            "オープニングテーマ",   -- Opuningu Tema (Opening Theme)
            "OPテーマ",             -- OP Tema
            "主題歌",               -- Shudaika (Theme Song)
            -- Romaji / Technical
            "ncop", "creditless op", "creditless opening"
        } 
    },
    
    { 
        label = "ED", 
        keywords = { 
            -- English / Common
            "ending", " ed ", "^ed$", "ed%d", "credits", "outro", "end roll",
            -- Japanese (Katakana/Kanji)
            "エンディング",         -- Endingu (Ending)
            "エンディングテーマ",   -- Endingu Tema (Ending Theme)
            "EDテーマ",             -- ED Tema
            "結び",                 -- Musubi (Conclusion/Ending - Rare but exists)
            -- Romaji / Technical
            "nced", "creditless ed", "creditless ending"
        } 
    },
    
    { 
        label = "PV", 
        keywords = { 
            -- English / Common
            "preview", " pv ", "^pv$", "pv%d", "trailer", "next episode",
            -- Japanese (Katakana/Kanji)
            "予告",                 -- Yokoku (Notice/Preview)
            "次回予告",             -- Jikai Yokoku (Next Episode Preview)
            "特報",                 -- Tokuho (Special News/Teaser)
            "プロモーション",       -- Puromoshon (Promotion)
            -- Romaji
            "jikai", "yokoku"
        } 
    },
    
    { 
        label = "Intro", 
        keywords = { 
            -- English
            "intro", "introduction", "prologue", "cold open", 
            -- Japanese / Technical
            "アバン",               -- Aban (Avant-title / Cold Open)
            "アバンタイトル",       -- Aban Taitoru (Avant Title)
            "序章",                 -- Joshou (Prologue)
            "前説"                  -- Maesetsu (Introductory remarks)
        } 
    }
}

-- [COLOR PALETTE] BGR Hex Codes (Assumed 0xBBGGRR)
local label_colors = {
    Intro = "0099FF", -- Orange (Standard)
    OP    = "00FF00", -- Green (Start)
    PV    = "FF00FF", -- Magenta (Teaser)
    ED    = "FF8000"  -- Blue (End)
}

local state = {
    key_bound = false,
    mouse_bound = false,
    active_label = nil,
    is_skipping = false,
    timer = nil,
    current_chapter_idx = -1,
    remaining_seconds = 0
}

local function get_chapter_label(title)
    if not title then return nil end
    
    -- Normalization: Lowercase for English matching
    local title_lower = title:lower()
    
    for _, category in ipairs(categories) do
        for _, keyword in ipairs(category.keywords) do
            -- Lua string.find works on bytes, so it handles UTF-8 Japanese text fine
            -- We check against the lowercased English title OR the raw UTF-8 characters
            if title_lower:find(keyword) or title:find(keyword) then
                return category.label
            end
        end
    end
    return nil
end

-- VISUAL: Canvas Painter
local function paint_canvas(ass_text)
    mp.set_osd_ass(1920, 1080, ass_text)
end

-- VISUAL: Construct the Button
local function draw_button(label, remaining, is_hovering)
    -- Position: Bottom Right (Adjusted for 1080p canvas)
    local cx, cy = 1650, 980
    
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs40}{\\b1}" -- Large, Bold Font
    
    -- STYLING: High Contrast Border for readability on any video
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H000000&}{\\4c&H000000&}"
    
    -- COLOR LOGIC
    if is_hovering then
        -- Hover State: Yellow text to indicate interactivity
        ass = ass .. "{\\1c&HFFFF00&}"
        ass = ass .. "▶ SKIP " .. string.upper(label) .. " [" .. opts.skip_key .. "] (" .. remaining .. ")"
    else
        -- Normal State: Segmented Colors
        local specific_color = label_colors[label] or "0099FF"
        
        -- Icon
        ass = ass .. "{\\1c&H" .. specific_color .. "&}▶ "
        -- "SKIP" text
        ass = ass .. "{\\1c&HFFFFFF&}SKIP "
        -- Label name
        ass = ass .. "{\\1c&H" .. specific_color .. "&}" .. string.upper(label) .. " "
        -- Hotkey hint
        ass = ass .. "{\\1c&HFFFFFF&}[" .. opts.skip_key .. "] (" .. remaining .. ")"
    end
    
    paint_canvas(ass)
end

-- VISUAL: Feedback Message (When clicked)
local function draw_feedback(label, color_hex)
    local cx, cy = 1650, 980
    
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs40}{\\b1}"
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H000000&}"
    
    ass = ass .. "{\\1c&H" .. color_hex .. "&}▶ "
    ass = ass .. "{\\1c&HFFFFFF&}SKIPPED "
    ass = ass .. "{\\1c&H" .. color_hex .. "&}" .. string.upper(label)
    
    paint_canvas(ass)
end

local function skip_action()
    state.is_skipping = true
    mp.command("no-osd add chapter 1")
    
    local color = label_colors[state.active_label] or "0099FF"
    draw_feedback(state.active_label or "Chapter", color)
    
    if state.key_bound then
        mp.remove_key_binding("skip-intro-action")
        state.key_bound = false
    end
    if state.mouse_bound then
        mp.remove_key_binding("mouse-skip-action")
        state.mouse_bound = false
    end
    
    if state.timer then state.timer:kill() end
    state.timer = mp.add_timeout(2.0, function()
        state.is_skipping = false
        paint_canvas("") 
    end)
end

local function check_mouse_hover()
    local mx, my = mp.get_mouse_pos()
    local osd_w, osd_h = mp.get_osd_size()
    if not osd_w or osd_w == 0 then return false end
    
    -- Normalize mouse coordinates to 1920x1080 canvas
    local scale_x = 1920 / osd_w
    local scale_y = 1080 / osd_h
    
    local target_x = mx * scale_x
    local target_y = my * scale_y
    
    -- Hitbox area around the button (Approx 1650, 980)
    if target_x > 1400 and target_x < 1860 and target_y > 950 and target_y < 1010 then
        return true
    end
    return false
end

local function on_tick()
    if not opts.enabled then return end
    if state.is_skipping then return end

    local current = mp.get_property_number("chapter")
    if current == nil then 
        paint_canvas("") 
        state.current_chapter_idx = -1
        return 
    end 
    
    local list = mp.get_property_native("chapter-list")
    if not list or not list[current+1] then return end
    
    local title = list[current+1].title
    local label = get_chapter_label(title) 
    
    if label then
        if current ~= state.current_chapter_idx then
            state.current_chapter_idx = current
            state.remaining_seconds = opts.timeout
        end
        
        local is_paused = mp.get_property_bool("pause")
        if not is_paused then
            state.remaining_seconds = state.remaining_seconds - 0.1
        end
        
        if state.remaining_seconds > 0 then
            local is_hovering = check_mouse_hover()
            state.active_label = label
            draw_button(label, math.ceil(state.remaining_seconds), is_hovering)
            
            if is_hovering and not state.mouse_bound then
                mp.add_forced_key_binding("MBTN_LEFT", "mouse-skip-action", skip_action)
                state.mouse_bound = true
            elseif not is_hovering and state.mouse_bound then
                mp.remove_key_binding("mouse-skip-action")
                state.mouse_bound = false
            end
            
            if not state.key_bound then
                mp.add_forced_key_binding(opts.skip_key, "skip-intro-action", skip_action)
                state.key_bound = true
            end
        else
            paint_canvas("")
            if state.key_bound then
                mp.remove_key_binding("skip-intro-action")
                state.key_bound = false
            end
            if state.mouse_bound then
                mp.remove_key_binding("mouse-skip-action")
                state.mouse_bound = false
            end
        end
        
    else
        state.current_chapter_idx = -1
        paint_canvas("")
        
        if state.key_bound then
            mp.remove_key_binding("skip-intro-action")
            state.key_bound = false
        end
        if state.mouse_bound then
            mp.remove_key_binding("mouse-skip-action")
            state.mouse_bound = false
        end
    end
end

mp.add_periodic_timer(0.1, on_tick)
mp.register_event("file-loaded", function()
    state.is_skipping = false
    state.current_chapter_idx = -1
    paint_canvas("")
end)