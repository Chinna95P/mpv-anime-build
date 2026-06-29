-- [[ 
--    FILENAME: skip_intro.lua
--    VERSION:  v2.2 (Performance Fix - Cached Chapters)
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
-- (Kept exactly as you had it)
local categories = {
    { 
        label = "OP", 
        keywords = { 
            "opening", " op ", "^op$", "op%d", "theme song", "main theme",
            "オープニング", "オープニングテーマ", "OPテーマ", "主題歌",
            "ncop", "creditless op", "creditless opening"
        } 
    },
    { 
        label = "ED", 
        keywords = { 
            "ending", " ed ", "^ed$", "ed%d", "credits", "outro", "end roll",
            "エンディング", "エンディングテーマ", "EDテーマ", "結び",
            "nced", "creditless ed", "creditless ending"
        } 
    },
    { 
        label = "PV", 
        keywords = { 
            "preview", " pv ", "^pv$", "pv%d", "trailer", "next episode",
            "予告", "次回予告", "特報", "プロモーション",
            "jikai", "yokoku"
        } 
    },
    { 
        label = "Intro", 
        keywords = { 
            "intro", "introduction", "prologue", "cold open", 
            "アバン", "アバンタイトル", "序章", "前説"
        } 
    }
}

-- [COLOR PALETTE]
local label_colors = {
    Intro = "0099FF", -- Orange
    OP    = "00FF00", -- Green
    PV    = "FF00FF", -- Magenta
    ED    = "FF8000"  -- Blue
}

local state = {
    key_bound = false,
    mouse_bound = false,
    active_label = nil,
    is_skipping = false,
    timer = nil,
    current_chapter_idx = -1,
    remaining_seconds = 0,
    -- [FIX] Added cache variable
    cached_chapters = nil 
}

local function get_chapter_label(title)
    if not title then return nil end
    local title_lower = title:lower()
    for _, category in ipairs(categories) do
        for _, keyword in ipairs(category.keywords) do
            if title_lower:find(keyword) or title:find(keyword) then
                return category.label
            end
        end
    end
    return nil
end

local function paint_canvas(ass_text)
    mp.set_osd_ass(1920, 1080, ass_text)
end

-- (Kept your exact button styling)
local function draw_button(label, remaining, is_hovering)
    local cx, cy = 1650, 980
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs40}{\\b1}"
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H000000&}{\\4c&H000000&}"
    
    if is_hovering then
        ass = ass .. "{\\1c&HFFFF00&}"
        ass = ass .. "▶ SKIP " .. string.upper(label) .. " [" .. opts.skip_key .. "] (" .. remaining .. ")"
    else
        local specific_color = label_colors[label] or "0099FF"
        ass = ass .. "{\\1c&H" .. specific_color .. "&}▶ "
        ass = ass .. "{\\1c&HFFFFFF&}SKIP "
        ass = ass .. "{\\1c&H" .. specific_color .. "&}" .. string.upper(label) .. " "
        ass = ass .. "{\\1c&HFFFFFF&}[" .. opts.skip_key .. "] (" .. remaining .. ")"
    end
    paint_canvas(ass)
end

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
    local scale_x = 1920 / osd_w
    local scale_y = 1080 / osd_h
    local target_x = mx * scale_x
    local target_y = my * scale_y
    if target_x > 1400 and target_x < 1860 and target_y > 950 and target_y < 1010 then
        return true
    end
    return false
end

-- [FIX] New Function: Reads chapters once per file
local function update_chapter_cache()
    state.cached_chapters = mp.get_property_native("chapter-list")
    state.is_skipping = false
    state.current_chapter_idx = -1
    paint_canvas("")
end

local function on_tick()
    if not opts.enabled then return end
    if state.is_skipping then return end

    -- [FIX] Safety check: Don't run if video hasn't actually started
    -- This prevents the "infinite wait" at 00:00
    local time = mp.get_property_number("time-pos")
    if not time or time < 0.5 then return end

    local current = mp.get_property_number("chapter")
    if current == nil then 
        paint_canvas("") 
        state.current_chapter_idx = -1
        return 
    end 
    
    -- [FIX] Use the CACHED list instead of asking MPV every 0.1s
    local list = state.cached_chapters
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
            if state.key_bound then mp.remove_key_binding("skip-intro-action"); state.key_bound = false end
            if state.mouse_bound then mp.remove_key_binding("mouse-skip-action"); state.mouse_bound = false end
        end
        
    else
        state.current_chapter_idx = -1
        paint_canvas("")
        if state.key_bound then mp.remove_key_binding("skip-intro-action"); state.key_bound = false end
        if state.mouse_bound then mp.remove_key_binding("mouse-skip-action"); state.mouse_bound = false end
    end
end

mp.register_script_message("toggle-state", function(val)
    opts.enabled = (val == "true")
    if not opts.enabled then
        paint_canvas("")
        state.is_skipping = false
        state.current_chapter_idx = -1
        if state.key_bound then mp.remove_key_binding("skip-intro-action"); state.key_bound = false end
        if state.mouse_bound then mp.remove_key_binding("mouse-skip-action"); state.mouse_bound = false end
    end
end)

mp.add_periodic_timer(0.1, on_tick)

-- [FIX] Trigger cache update on load
mp.register_event("file-loaded", update_chapter_cache)