-- =================================================================================
-- MPV-PC: "UP NEXT" INTERACTIVE (v2.3 - Menu Toggle Support)
-- =================================================================================
-- * Feature: Added 'toggle-state' listener for UOSC Menu integration.
-- * Logic: Can be disabled/enabled dynamically without restarting MPV.
-- =================================================================================

local mp = require 'mp'

-- =================================================================================
-- [1] CONFIGURATION
-- =================================================================================
local opts = {
    enabled      = true,        -- Default State (Master Switch)
    trigger_time = 10,          -- Seconds before end to appear
    wrap_limit   = 24,          -- Characters per line before wrapping
    
    -- COLORS (BGR Hex)
    text_color   = "FFFF00",    -- Yellow/White
    accent_color = "50FF50",    -- Green
    hover_color  = "00FFFF",    -- Cyan (Hover State)
    bg_color     = "000000",    -- Black
    bg_opacity   = "80",        -- 00-FF
}

-- =================================================================================
-- [2] STATE & HELPERS
-- =================================================================================
local state = {
    is_visible = false,
    mouse_bound = false,
    next_filename = nil,
    next_title = nil
}

-- HELPER: Parse Title & Clean Path
function get_smart_details(filename, title)
    local display = filename
    if display then display = display:match("([^/\\]+)$") or display end
    
    -- Priority: Use Title if valid
    if title and title ~= "" then 
        display = title 
    else
        -- FALLBACK: Aggressive Filename Cleaning
        if display then
            -- 1. Remove File Extension
            display = display:gsub("%.%w+$", "") 
            
            -- 2. Remove Tech Specs
            -- We replace with a SPACE " " to prevent text merging (e.g., S01E01BluRay)
            -- Resolution
            display = display:gsub("[%s._-][0-9]*[pP][%s._-]", " ")      -- .1080p.
            display = display:gsub("[%s._-][0-9]*[kK][%s._-]", " ")       -- .4k.
            
            -- Codecs
            display = display:gsub("[%s._-][xX][2]6[45]", " ")           -- x265
            display = display:gsub("[%s._-][hH][2]6[45]", " ")           -- h265
            display = display:gsub("[%s._-][hH][eE][vV][cC]", " ")       -- HEVC
            display = display:gsub("[%s._-][aA][vV]1", " ")              -- AV1
            
            -- Audio (Fix for FLAC2.0, AAC, etc.)
            display = display:gsub("[%s._-][fF][lL][aA][cC][%w%.]*", " ") -- FLAC, FLAC2.0
            display = display:gsub("[%s._-][aA][aA][cC][%w%.]*", " ")     -- AAC, AAC2.0
            display = display:gsub("[%s._-][dD][dD][pP]?[%w%.]*", " ")    -- DDP5.1
            display = display:gsub("[%s._-][aA][cC]3", " ")               -- AC3
            display = display:gsub("[%s._-][dD][tT][sS]", " ")            -- DTS
            display = display:gsub("[%s._-][tT][rR][uU][eE][hH][dD]", " ")-- TrueHD
            
            -- Video Quality / Bitrate (Fix for 10-Bit, BluRay)
            display = display:gsub("[%s._-][bB]lu[rR]ay", " ")           -- BluRay
            display = display:gsub("[%s._-][bB][dD][rR][iI][pP]", " ")    -- BDRip
            display = display:gsub("[%s._-][wW][eE][bB].*", "")           -- WEB-DL (Cut rest)
            display = display:gsub("[%s._-][hH][dD][tT][vV]", " ")        -- HDTV
            display = display:gsub("[%s._-][0-9]+[%s-]*[bB]it", " ")      -- 10-Bit, 10bit, 8bit
            
            -- 3. Remove Brackets [] and Parentheses ()
            display = display:gsub("%b[]", ""):gsub("%b()", "")
            
            -- 4. Clean up Release Groups (Trailing dash + text)
            -- e.g., "Show -Group" -> "Show"
            display = display:gsub("[%s._-]*-[%s._-]*[%w]*$", "")

            -- 5. Replace remaining dots/underscores with spaces
            display = display:gsub("[._-]", " ")
        end
    end

    -- Final whitespace cleanup
    if display then
        display = display:gsub("^%s+", ""):gsub("%s+$", "")
        display = display:gsub("%s+", " ") -- Collapse multiple spaces
    else
        display = "Unknown"
    end

    local name, ep = display:match("^(.*)%s+-%s+(.*)$")
    return name or display, ep or ""
end

-- HELPER: Smart Text Wrap
function smart_wrap(text, limit)
    if not text or string.len(text) <= limit then return text end
    local len = string.len(text)
    local last_space = nil
    if len > limit then
         local s_sub = text:sub(1, limit + 5)
         last_space = s_sub:match(".*%s()")
    end
    if last_space then
        return string.sub(text, 1, last_space - 2) .. "\\N" .. string.sub(text, last_space)
    else
        return string.sub(text, 1, limit) .. "\\N" .. string.sub(text, limit + 1)
    end
end

local function paint(ass_text)
    mp.set_osd_ass(1920, 1080, ass_text)
end

local function check_mouse_hover()
    local mx, my = mp.get_mouse_pos()
    local osd_w, osd_h = mp.get_osd_size()
    if not osd_w or osd_w == 0 then return false end
    
    local scale_x = 1920 / osd_w
    local scale_y = 1080 / osd_h
    local tx, ty = mx * scale_x, my * scale_y
    
    -- Hitbox (Centered at 1650, 850)
    if tx > 1450 and tx < 1850 and ty > 780 and ty < 920 then
        return true
    end
    return false
end

-- =================================================================================
-- [3] VISUALS
-- =================================================================================
local function draw_ui(seconds, show_name, show_ep, is_hovering)
    local cx, cy = 1650, 850
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs35}{\\b1}" 
    ass = ass .. "{\\bord8}{\\shad8}{\\blur8}{\\3c&H" .. opts.bg_color .. "&}{\\3a&H" .. opts.bg_opacity .. "&}"
    
    local main_c = is_hovering and opts.hover_color or opts.text_color
    local acc_c  = is_hovering and opts.hover_color or opts.accent_color
    
    ass = ass .. "{\\1c&H" .. acc_c .. "&}▶ "
    ass = ass .. "{\\1c&HAAAAAA&}{\\fs25}UP NEXT {\\1c&H" .. acc_c .. "&}(" .. seconds .. "s)"
    
    local wrapped_title = smart_wrap(show_name, opts.wrap_limit)
    ass = ass .. "\\N{\\1c&H" .. main_c .. "&}{\\fs40}" .. wrapped_title
    
    if show_ep ~= "" then
        ass = ass .. "\\N{\\1c&HBBBBBB&}{\\fs28}" .. show_ep
    end
    
    paint(ass)
end

-- =================================================================================
-- [4] CORE LOOP
-- =================================================================================
local function click_action()
    if state.is_visible and check_mouse_hover() then
        mp.command("playlist-next")
        paint("") 
        state.is_visible = false
        if state.mouse_bound then
            mp.remove_key_binding("click_next")
            state.mouse_bound = false
        end
    end
end

local function on_tick()
    -- [CHECK] Master Switch
    if not opts.enabled then return end

    local time_remaining = mp.get_property_number("time-remaining")
    local pos = mp.get_property_number("playlist-pos")
    local count = mp.get_property_number("playlist-count")

    if not time_remaining or not pos or not count then 
        if state.is_visible then paint(""); state.is_visible = false end
        if state.mouse_bound then mp.remove_key_binding("click_next"); state.mouse_bound = false end
        return 
    end

    if time_remaining <= opts.trigger_time and (pos + 1) < count then
        if not state.next_filename then
            state.next_filename = mp.get_property("playlist/" .. (pos + 1) .. "/filename")
            state.next_title = mp.get_property("playlist/" .. (pos + 1) .. "/title")
        end
        
        local show_name, show_ep = get_smart_details(state.next_filename, state.next_title)
        local seconds = math.floor(time_remaining)
        local is_hovering = check_mouse_hover()
        
        draw_ui(seconds, show_name, show_ep, is_hovering)
        state.is_visible = true

        if is_hovering and not state.mouse_bound then
            mp.add_forced_key_binding("MBTN_LEFT", "click_next", click_action)
            state.mouse_bound = true
        elseif not is_hovering and state.mouse_bound then
            mp.remove_key_binding("click_next")
            state.mouse_bound = false
        end

    else
        if state.is_visible then 
            paint(""); state.is_visible = false; state.next_filename = nil
        end
        if state.mouse_bound then mp.remove_key_binding("click_next"); state.mouse_bound = false end
    end
end

-- =================================================================================
-- [5] INIT & LISTENER
-- =================================================================================
-- LISTENER: Toggles the script on/off from the Controller
mp.register_script_message("toggle-state", function(val)
    opts.enabled = (val == "true")
    if not opts.enabled then
        paint("")
        state.is_visible = false
        if state.mouse_bound then
            mp.remove_key_binding("click_next")
            state.mouse_bound = false
        end
    end
end)

local timer = mp.add_periodic_timer(0.1, on_tick)

mp.register_event("file-loaded", function()
    state.is_visible = false
    state.next_filename = nil
    paint("")
    if state.mouse_bound then mp.remove_key_binding("click_next"); state.mouse_bound = false end
end)

mp.register_event("end-file", function()
    paint("")
    if state.mouse_bound then mp.remove_key_binding("click_next"); state.mouse_bound = false end
end)