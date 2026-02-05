-- =================================================================================
-- MPV-PC: "UP NEXT" INTERACTIVE (v2.4 - Safe Startup)
-- =================================================================================

local mp = require 'mp'

local opts = {
    enabled      = true,
    trigger_time = 10,
    wrap_limit   = 24,
    text_color   = "FFFF00",
    accent_color = "50FF50",
    hover_color  = "00FFFF",
    bg_color     = "000000",
    bg_opacity   = "80",
}

local state = {
    is_visible = false,
    mouse_bound = false,
    next_filename = nil,
    next_title = nil
}

-- [1] CLEANER FUNCTION (Kept your latest robust regex)
function get_smart_details(filename, title)
    local display = filename
    if display then display = display:match("([^/\\]+)$") or display end
    
    if title and title ~= "" then 
        display = title 
    else
        if display then
            display = display:gsub("%.%w+$", "") 
            display = display:gsub("[%s._-][0-9]*[pP][%s._-]", " ")
            display = display:gsub("[%s._-][0-9]*[kK][%s._-]", " ")
            display = display:gsub("[%s._-][xX][2]6[45]", " ")
            display = display:gsub("[%s._-][hH][2]6[45]", " ")
            display = display:gsub("[%s._-][hH][eE][vV][cC]", " ")
            display = display:gsub("[%s._-][aA][vV]1", " ")
            display = display:gsub("[%s._-][fF][lL][aA][cC][%w%.]*", " ")
            display = display:gsub("[%s._-][aA][aA][cC][%w%.]*", " ")
            display = display:gsub("[%s._-][dD][dD][pP]?[%w%.]*", " ")
            display = display:gsub("[%s._-][aA][cC]3", " ")
            display = display:gsub("[%s._-][dD][tT][sS]", " ")
            display = display:gsub("[%s._-][tT][rR][uU][eE][hH][dD]", " ")
            display = display:gsub("[%s._-][bB]lu[rR]ay", " ")
            display = display:gsub("[%s._-][bB][dD][rR][iI][pP]", " ")
            display = display:gsub("[%s._-][wW][eE][bB].*", "")
            display = display:gsub("[%s._-][hH][dD][tT][vV]", " ")
            display = display:gsub("[%s._-][0-9]+[%s-]*[bB]it", " ")
            display = display:gsub("%b[]", ""):gsub("%b()", "")
            display = display:gsub("[%s._-]*-[%s._-]*[%w]*$", "")
            display = display:gsub("[._-]", " ")
        end
    end

    if display then
        display = display:gsub("^%s+", ""):gsub("%s+$", "")
        display = display:gsub("%s+", " ")
    else
        display = "Unknown"
    end

    local name, ep = display:match("^(.*)%s+-%s+(.*)$")
    return name or display, ep or ""
end

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
    if tx > 1450 and tx < 1850 and ty > 780 and ty < 920 then return true end
    return false
end

local function draw_ui(seconds, show_name, show_ep, is_hovering)
    local cx, cy = 1650, 850
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fnSource Sans Pro}{\\fs35}{\\b1}" 
    ass = ass .. "{\\bord8}{\\shad8}{\\blur8}{\\3c&H" .. opts.bg_color .. "&}{\\3a&H" .. opts.bg_opacity .. "&}"
    local main_c = is_hovering and opts.hover_color or opts.text_color
    local acc_c  = is_hovering and opts.hover_color or opts.accent_color
    ass = ass .. "{\\1c&H" .. acc_c .. "&}▶ {\\1c&HAAAAAA&}{\\fs25}UP NEXT {\\1c&H" .. acc_c .. "&}(" .. seconds .. "s)"
    local wrapped_title = smart_wrap(show_name, opts.wrap_limit)
    ass = ass .. "\\N{\\1c&H" .. main_c .. "&}{\\fs40}" .. wrapped_title
    if show_ep ~= "" then ass = ass .. "\\N{\\1c&HBBBBBB&}{\\fs28}" .. show_ep end
    paint(ass)
end

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
    if not opts.enabled then return end

    -- [SAFETY] Don't run logic if we are just starting (avoids property spam)
    local time_pos = mp.get_property_number("time-pos")
    if not time_pos or time_pos < 5 then return end

    local time_remaining = mp.get_property_number("time-remaining")
    local pos = mp.get_property_number("playlist-pos")
    local count = mp.get_property_number("playlist-count")

    if not time_remaining or not pos or not count then 
        if state.is_visible then paint(""); state.is_visible = false end
        return 
    end

    if time_remaining <= opts.trigger_time and (pos + 1) < count then
        if not state.next_filename then
            -- [SAFETY] Only fetch string properties once per trigger
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

mp.register_script_message("toggle-state", function(val)
    opts.enabled = (val == "true")
    if not opts.enabled then
        paint("")
        state.is_visible = false
        if state.mouse_bound then mp.remove_key_binding("click_next"); state.mouse_bound = false end
    end
end)

mp.add_periodic_timer(0.1, on_tick)

mp.register_event("file-loaded", function()
    state.is_visible = false
    state.next_filename = nil
    paint("")
end)