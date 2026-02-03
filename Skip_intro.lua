-- [[ 
--    FILENAME: skip_intro.lua (Android Smart-Action v3.3)
--    LOGIC: Handles "Smart Context" (Skip vs Audio Toggle)
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
    feedback_timer = nil
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
    if state.remaining_seconds > 0 then
        -- === PATH A: SKIP INTRO ===
        mp.command("no-osd add chapter 1")
        draw_feedback(state.active_label or "CHAPTER")
        state.remaining_seconds = 0
        
        -- Clear feedback after 1.5s
        state.feedback_timer = mp.add_timeout(1.5, function() paint("") end)
    else
        -- === PATH B: TOGGLE AUDIO ===
        -- The intro timer is NOT running, so we pass the command to the other script
        mp.command("script-message toggle-audio-mode")
    end
end

-- REGISTER LISTENER
mp.register_script_message("smart-skip-audio", smart_context_action)

-- LOOP
local function on_tick()
    if not opts.enabled then return end

    local current = mp.get_property_number("chapter")
    if current == nil then 
        paint("") 
        state.current_chapter_idx = -1
        return 
    end 
    
    local list = mp.get_property_native("chapter-list")
    if not list or not list[current+1] then return end
    
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
        state.current_chapter_idx = -1
        if not state.feedback_timer or not state.feedback_timer:is_enabled() then paint("") end
    end
end

mp.add_periodic_timer(0.2, on_tick)