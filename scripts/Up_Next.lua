-- =================================================================================
-- MPV-ANDROID: "UP NEXT" NOTIFICATION SCRIPT (Fixed for mpvEx)
-- =================================================================================
-- Fix applied: Added directory scanning fallback to detect next files 
-- without relying on autoload.lua or the internal playlist buffer.
-- [v2.2 FIX]: Added Startup Guard to prevent "Infinite Wait" at 00:00.
-- =================================================================================

local mp = require 'mp'
local utils = require 'mp.utils'

-- =================================================================================
-- [1] USER CONFIGURATION
-- =================================================================================
local opts = {
    trigger_time = 8,          
    lift_amount = 10,            
    wrap_limit = 25,            
    text_color   = "FFFFFF",    
    sub_color    = "BBBBBB",    
    accent_color = "50FF50",    
    timer_color  = "FFD700",    
    bg_color     = "000000",    
    bg_opacity   = "40",        
}

-- =================================================================================
-- [2] INTERNAL VARIABLES & HELPERS
-- =================================================================================
local overlay = mp.create_osd_overlay("ass-events")
local is_visible = false
local cached_next_path = nil
local last_scanned_path = nil

local video_extensions = {
    mkv=true, mp4=true, avi=true, webm=true, mov=true, 
    flv=true, wmv=true, m4v=true, mpg=true, mpeg=true
}

function get_smart_details(path, title)
    if not title or title == "" then
        if not path then return nil, nil end
        title = path:match("([^/]+)$") or path
    end
    title = title:gsub("%.%w+$", "")
    title = title:gsub("%b[]", "")
    title = title:gsub("%b()", "")
    title = title:gsub("^%s+", ""):gsub("%s+$", "")
    local name, ep = title:match("^(.*)%s+-%s+(.*)$")
    if name and ep then return name, ep else return title, "" end
end

function smart_wrap(text, limit)
    if string.len(text) <= limit then return text end
    local len = string.len(text)
    local middle = math.floor(len / 2)
    local best_space = nil
    local min_dist = 1000
    for space_pos in string.gmatch(text, "() ") do
        local dist = math.abs(space_pos - middle)
        if dist < min_dist then
            min_dist = dist
            best_space = space_pos
        end
    end
    if best_space then
        return string.sub(text, 1, best_space - 1) .. "\\N" .. string.sub(text, best_space + 1)
    end
    return text
end

function find_next_file_in_dir(current_path)
    if not current_path then return nil end
    local dir, filename = utils.split_path(current_path)
    if current_path:match("^%a+://") then return nil end
    local files = utils.readdir(dir, "files")
    if not files then return nil end
    local media_files = {}
    for _, f in ipairs(files) do
        local ext = f:match("%.([^%.]+)$")
        if ext and video_extensions[ext:lower()] then
            table.insert(media_files, f)
        end
    end
    table.sort(media_files)
    for i, f in ipairs(media_files) do
        if f == filename then
            if i < #media_files then
                return media_files[i+1]
            end
            break
        end
    end
    return nil
end

-- =================================================================================
-- [3] MAIN DISPLAY LOOP
-- =================================================================================
function check_progress()
    -- [CRITICAL FIX] Startup Guard
    -- Don't run logic if video just started (avoids infinite wait)
    local time_pos = mp.get_property_number("time-pos")
    if not time_pos or time_pos < 5 then return end

    local time_remaining = mp.get_property_number("time-remaining")
    local pos = mp.get_property_number("playlist-pos")
    local count = mp.get_property_number("playlist-count")
    local current_path = mp.get_property("path")

    if not time_remaining or not pos or not count then 
        if is_visible then overlay:remove(); is_visible = false end
        return 
    end

    if time_remaining <= opts.trigger_time then
        local next_path = nil
        local next_title = nil

        if (pos + 1) < count then
            next_path = mp.get_property("playlist/" .. (pos + 1) .. "/filename")
            next_title = mp.get_property("playlist/" .. (pos + 1) .. "/title")
        else
            if last_scanned_path ~= current_path then
                cached_next_path = find_next_file_in_dir(current_path)
                last_scanned_path = current_path
            end
            next_path = cached_next_path
            next_title = next_path
        end

        local show_name, show_ep = get_smart_details(next_path, next_title)

        if show_name then
            local seconds = math.floor(time_remaining)
            local wrapped_name = smart_wrap(show_name, opts.wrap_limit)
            local spacer = ""
            for i = 1, opts.lift_amount do spacer = spacer .. "\\N" end
            local style_invisible = "{\\alpha&HFF&}{\\fs20}" .. spacer
            local style_card = string.format("{\\an3}{\\bord10}{\\blur10}{\\shad5}{\\3c&H%s&}{\\3a&H%s&}", opts.bg_color, opts.bg_opacity)
            local header = string.format("{\\fs24}{\\shad1}{\\c&H%s&}▶ {\\c&HAAAAAA&}{\\b1}Up Next {\\b0}{\\c&H%s&}(%ds)", opts.accent_color, opts.timer_color, seconds)
            local title_line = string.format("{\\fs40}{\\shad1}{\\c&H%s&}{\\b1}{\\i1}%s{\\i0}", opts.text_color, wrapped_name)
            local ep_line = ""
            if show_ep ~= "" then ep_line = string.format("\\N{\\fs26}{\\shad1}{\\c&H%s&}{\\b0}%s", opts.sub_color, show_ep) end
            local padding = "    " 

            overlay.data = style_card .. header .. "\\N" .. title_line .. ep_line .. padding .. style_invisible
            overlay:update()
            is_visible = true
        end
    else
        if is_visible then
            overlay:remove()
            is_visible = false
        end
    end
end

-- =================================================================================
-- [4] INITIALIZATION
-- =================================================================================
local timer = mp.add_periodic_timer(0.5, check_progress)

mp.register_event("end-file", function()
    overlay:remove()
    is_visible = false
end)

mp.register_event("start-file", function()
    last_scanned_path = nil
    cached_next_path = nil
end)