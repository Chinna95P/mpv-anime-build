-- [[ 
--    FILENAME: skip_intro.lua (Android Smart-Action v3.7)
--    LOGIC: Handles "Smart Context" (Skip vs Audio Toggle)
--    FIX: Strict State Reset (Prevents ghost skips when OSD is gone)
-- ]]

local mp = require("mp")
local opts = {
    enabled = true,
    timeout = 6
}

-- [PATTERNS]
local categories = {
    { label = "OP", keywords = { "opening", " op ", "^op$", "op%d", "theme song", "オープニング", "OPテーマ" } },
    { label = "ED", keywords = { "ending", " ed ", "^ed$", "ed%d", "credits", "outro", "エンディング", "EDテーマ" } },
    { label = "PV", keywords = { "preview", " pv ", "^pv$", "pv%d", "trailer", "next episode", "予告" } },
    { label = "Intro", keywords = { "intro", "introduction", "prologue", "avant", "アバン" } }
}

-- [COLORS] (BGR Hex)
local label_colors = {
    Intro = "0099FF", -- Orange
    OP    = "00FF00", -- Green
    PV    = "FF00FF", -- Magenta
    ED    = "FF8000"  -- Blue
}

local state = {
    active_label = nil,
    current_chapter_idx = -1,
    remaining_seconds = 0,
    feedback_timer = nil,
    cached_chapters = nil -- [FIX] Cache Storage
}

-- UTILS
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

-- PAINTER
local function paint(ass_text)
    mp.set_osd_ass(1920, 1080, ass_text)
end

-- VISUALS: Button
local function draw_button(label, remaining)
    local color = label_colors[label] or "0099FF"
    -- Position: Bottom-Right
    local ass = "{\\an9}{\\pos(1880,950)}{\\fnSans-Serif}{\\fs60}{\\b1}{\\bord5}{\\3c&H000000&}{\\shad2}"
    
    ass = ass .. "{\\1c&HFFFFFF&}DOUBLE TAP TO "
    ass = ass .. "{\\1c&H" .. color .. "&}SKIP " .. string.upper(label)
    ass = ass .. "{\\1c&HFFFFFF&} (" .. remaining .. ")"
    paint(ass)
end

-- VISUALS: Feedback
local function draw_feedback(label)
    local color = label_colors[label] or "FFFFFF"
    local ass = "{\\an9}{\\pos(1880,950)}{\\fnSans-Serif}{\\fs60}{\\b1}{\\bord5}{\\3c&H000000&}{\\shad2}"
    ass = ass .. "{\\1c&H" .. color .. "&}⏩ SKIPPED " .. string.upper(label)
    paint(ass)
end

-- CORE LOGIC: THE SMART SWITCH
local function smart_context_action()
    -- KILL existing feedback timer if running
    if state.feedback_timer then state.feedback_timer:kill() end

    -- CHECK: Is the Intro Timer active?
    -- [CRITICAL] This variable must be 0 if OSD is not visible
    if state.remaining_seconds > 0 then
        -- === PATH A: SKIP INTRO ===
        mp.command("no-osd add chapter 1")
        draw_feedback(state.active_label or "CHAPTER")
        state.remaining_seconds = 0
        state.active_label = nil -- Reset immediately
        
        -- Clear feedback after 1.5s
        state.feedback_timer = mp.add_timeout(1.5, function() paint("") end)
    else
        -- === PATH B: TOGGLE AUDIO ===
        -- The intro timer is NOT running, so we pass the command to the other script
        mp.command("script-message toggle-audio-mode")
    end
end

-- [FIX] RESET CACHE (Does NOT fetch, just clears old data)
local function reset_cache()
    state.cached_chapters = nil
    state.remaining_seconds = 0
    state.active_label = nil
    paint("")
end

-- REGISTER LISTENER
mp.register_script_message("smart-skip-audio", smart_context_action)

-- LOOP
local function on_tick()
    if not opts.enabled then return end

    -- [OPTIMIZATION] Don't check during initial loading
    local time = mp.get_property_number("time-pos")
    if not time or time < 0.5 then return end

    local current = mp.get_property_number("chapter")
    if current == nil then 
        paint("") 
        state.current_chapter_idx = -1
        state.remaining_seconds = 0 -- Safety Reset
        return 
    end 
    
    -- [FIX] LAZY CACHING STRATEGY
    -- If cache is empty, try to fetch it.
    if not state.cached_chapters then
        state.cached_chapters = mp.get_property_native("chapter-list")
        
        -- If STILL empty (race condition), return and try again next tick
        if not state.cached_chapters then return end
    end
    
    local list = state.cached_chapters
    -- Safety check: index might be out of bounds if file changed rapidly or list is stale
    if not list[current+1] then return end
    
    local label = get_chapter_label(list[current+1].title) 
    
    if label then
        if current ~= state.current_chapter_idx then
            state.current_chapter_idx = current
            state.remaining_seconds = opts.timeout
        end
        
        if not mp.get_property_bool("pause") then
            state.remaining_seconds = state.remaining_seconds - 0.2
        end
        
        if state.remaining_seconds > 0 then
            state.active_label = label
            draw_button(label, math.ceil(state.remaining_seconds))
        else
            if not state.feedback_timer or not state.feedback_timer:is_enabled() then paint("") end
        end
    else
        -- [CRITICAL FIX] We are NOT in an intro chapter.
        -- We must strictly reset the timer so double-tap doesn't skip.
        state.current_chapter_idx = -1
        state.remaining_seconds = 0
        state.active_label = nil
        
        if not state.feedback_timer or not state.feedback_timer:is_enabled() then paint("") end
    end
end

mp.add_periodic_timer(0.2, on_tick)

-- [FIX] Only reset cache on file load, don't fetch yet
mp.register_event("file-loaded", reset_cache)