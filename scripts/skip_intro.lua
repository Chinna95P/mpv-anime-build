-- [[ 
--    FILENAME: skip_intro.lua
--    VERSION:  v1.8 (Context-Aware Multi-Color Edition)
--    AUTHOR:   mpv-anime-build
--    DESC:     Auto-detects OP/ED/PV/Intro and displays a clickable skip button.
-- ]]

local mp = require("mp")
local opts = {
    enabled = true,
    skip_key = "ENTER",
    timeout = 6
}

local categories = {
    -- Added "ed%d" to catch ED1, ED2, etc.
    { label = "ED", keywords = { "credits", "ending", " ed ", "^ed$", "ed%d" } },
    
    -- Added "pv%d" to catch PV1, PV2, etc.
    { label = "PV", keywords = { "preview", "pv", "^pv$", "pv%d" } },
    
    -- Added "op%d" to catch OP1, OP4, etc.
    { label = "OP", keywords = { "opening", " op ", "^op$", "op%d", "song", "theme", "signs" } },
    
    { label = "Intro", keywords = { "intro" } }
}

-- [COLOR PALETTE] BGR Hex Codes
local label_colors = {
    Intro = "0099FF", -- Orange (Theme Default)
    OP    = "00FF00", -- Green (Start)
    PV    = "FF00FF", -- Magenta (Special)
    ED    = "FF8000"  -- Blue (Finish)
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
    title = title:lower()
    for _, category in ipairs(categories) do
        for _, keyword in ipairs(category.keywords) do
            if title:find(keyword) then
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
    -- Position: Bottom Right
    local cx, cy = 1650, 980
    
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs40}{\\b1}" -- Large, Bold Font
    
    -- STYLING: High Contrast Border
    -- \bord4: Thick black border for readability on any background
    -- \shad2: Drop shadow
    -- \blur4: Soft dark blur
    -- \3c:    Black Border
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H000000&}{\\4c&H000000&}"
    
    -- COLOR LOGIC
    if is_hovering then
        -- Hover State: Entire text turns Cyan
        ass = ass .. "{\\1c&HFFFF00&}"
        ass = ass .. "▶ SKIP " .. string.upper(label) .. " [" .. opts.skip_key .. "] (" .. remaining .. ")"
    else
        -- Normal State: Multi-Color Design
        
        -- Get the specific color for this label (default to Orange if unknown)
        local specific_color = label_colors[label] or "0099FF"
        
        -- Part 1: Arrow (Colored)
        ass = ass .. "{\\1c&H" .. specific_color .. "&}▶ "
        
        -- Part 2: "SKIP" (White)
        ass = ass .. "{\\1c&HFFFFFF&}SKIP "
        
        -- Part 3: Label (Colored)
        ass = ass .. "{\\1c&H" .. specific_color .. "&}" .. string.upper(label) .. " "
        
        -- Part 4: Key/Timer (White)
        ass = ass .. "{\\1c&HFFFFFF&}[" .. opts.skip_key .. "] (" .. remaining .. ")"
    end
    
    paint_canvas(ass)
end

-- VISUAL: Feedback Message
local function draw_feedback(label, color_hex)
    local cx, cy = 1650, 980
    
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs40}{\\b1}"
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H000000&}"
    
    -- Icon + Text
    -- "SKIPPED" is White, Label/Arrow matches the section color
    ass = ass .. "{\\1c&H" .. color_hex .. "&}▶ "
    ass = ass .. "{\\1c&HFFFFFF&}SKIPPED "
    ass = ass .. "{\\1c&H" .. color_hex .. "&}" .. string.upper(label)
    
    paint_canvas(ass)
end

local function skip_action()
    state.is_skipping = true
    mp.command("no-osd add chapter 1")
    
    -- Dynamic Feedback Color
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
    
    -- Hitbox (Approx 1650, 980)
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