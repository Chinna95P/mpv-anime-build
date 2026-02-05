-- =================================================================================
-- MPV-ANDROID: "UP NEXT" NOTIFICATION SCRIPT (Fixed for mpvEx)
-- =================================================================================
-- Fix applied: Added directory scanning fallback to detect next files 
-- without relying on autoload.lua or the internal playlist buffer.
-- =================================================================================

local mp = require 'mp'
local utils = require 'mp.utils' -- Added for file scanning

-- =================================================================================
-- [1] USER CONFIGURATION (EDIT THESE VALUES)
-- =================================================================================
local opts = {
    -- TIMING
    trigger_time = 8,          -- How many seconds before the end to appear.

    -- POSITIONING
    lift_amount = 10,            -- 0 = Bottom Edge. Increase (e.g., 10) to move HIGHER.
    
    -- TEXT FORMATTING
    wrap_limit = 25,            -- Max characters per line before splitting text.

    -- COLORS (Format: BGR Hex -> Blue-Green-Red)
    text_color   = "FFFFFF",    -- Main Title Color (White)
    sub_color    = "BBBBBB",    -- Episode Number Color (Light Grey)
    accent_color = "50FF50",    -- Play Icon Color (Bright Green)
    timer_color  = "FFD700",    -- Countdown Numbers Color (Gold)
    bg_color     = "000000",    -- Card Background Color (Black)
    
    -- BACKGROUND OPACITY
    bg_opacity   = "40",        -- Hex: 00 (Invisible) to FF (Solid). "40" is nice glass.
}

-- =================================================================================
-- [2] INTERNAL VARIABLES & HELPERS
-- =================================================================================
local overlay = mp.create_osd_overlay("ass-events")
local is_visible = false

-- Caching variables for the fix
local cached_next_path = nil
local last_scanned_path = nil

-- Supported video extensions for the scanner
local video_extensions = {
    mkv=true, mp4=true, avi=true, webm=true, mov=true, 
    flv=true, wmv=true, m4v=true, mpg=true, mpeg=true
}

-- HELPER: Splits "Show Name - 01" into "Show Name" and "01"
function get_smart_details(path, title)
    -- 1. Fallback: If no metadata title, use filename
    if not title or title == "" then
        if not path then return nil, nil end
        title = path:match("([^/]+)$") or path
    end
    
    -- 2. Clean up: Remove file extensions and tags
    title = title:gsub("%.%w+$", "")            -- Remove extension
    title = title:gsub("%b[]", "")              -- Remove [Square Brackets]
    title = title:gsub("%b()", "")              -- Remove (Parentheses)
    title = title:gsub("^%s+", ""):gsub("%s+$", "") -- Trim spaces

    -- 3. Smart Split: Try to find "Name - Episode" pattern
    local name, ep = title:match("^(.*)%s+-%s+(.*)$")
    
    if name and ep then
        return name, ep
    else
        return title, "" 
    end
end

-- HELPER: Wraps long text
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

-- HELPER: Scans directory to find the next file (The Fix)
function find_next_file_in_dir(current_path)
    if not current_path then return nil end
    
    local dir, filename = utils.split_path(current_path)
    -- Safety check for protocols (http, etc)
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
                return media_files[i+1] -- Return just filename
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
    local time_remaining = mp.get_property_number("time-remaining")
    local pos = mp.get_property_number("playlist-pos")
    local count = mp.get_property_number("playlist-count")
    local current_path = mp.get_property("path")

    -- VALIDATION
    if not time_remaining or not pos or not count then 
        if is_visible then overlay:remove(); is_visible = false end
        return 
    end

    -- TRIGGER: Only show if within the last X seconds
    if time_remaining <= opts.trigger_time then
        
        local next_path = nil
        local next_title = nil

        -- STRATEGY A: Check Internal Playlist (If autoload is used or manual playlist)
        if (pos + 1) < count then
            next_path = mp.get_property("playlist/" .. (pos + 1) .. "/filename")
            next_title = mp.get_property("playlist/" .. (pos + 1) .. "/title")
        
        -- STRATEGY B: Check File System (The Fix for mpvEx)
        else
            -- Check if we already scanned for this file to save performance
            if last_scanned_path ~= current_path then
                cached_next_path = find_next_file_in_dir(current_path)
                last_scanned_path = current_path
            end
            next_path = cached_next_path
            next_title = next_path -- Metadata usually unavailable for non-loaded files
        end

        -- RENDER
        local show_name, show_ep = get_smart_details(next_path, next_title)

        if show_name then
            local seconds = math.floor(time_remaining)
            local wrapped_name = smart_wrap(show_name, opts.wrap_limit)
            
            -- [A] THE "STILT" (Height Control)
            local spacer = ""
            for i = 1, opts.lift_amount do spacer = spacer .. "\\N" end
            local style_invisible = "{\\alpha&HFF&}{\\fs20}" .. spacer

            -- [B] CARD BACKGROUND STYLE
            local style_card = string.format("{\\an3}{\\bord10}{\\blur10}{\\shad5}{\\3c&H%s&}{\\3a&H%s&}", opts.bg_color, opts.bg_opacity)
            
            -- [C] LINE 1: HEADER
            local header = string.format(
                "{\\fs24}{\\shad1}{\\c&H%s&}▶ {\\c&HAAAAAA&}{\\b1}Up Next {\\b0}{\\c&H%s&}(%ds)", 
                opts.accent_color, opts.timer_color, seconds
            )
            
            -- [D] LINE 2: MAIN TITLE
            local title_line = string.format("{\\fs40}{\\shad1}{\\c&H%s&}{\\b1}{\\i1}%s{\\i0}", opts.text_color, wrapped_name)
            
            -- [E] LINE 3: EPISODE
            local ep_line = ""
            if show_ep ~= "" then
                ep_line = string.format("\\N{\\fs26}{\\shad1}{\\c&H%s&}{\\b0}%s", opts.sub_color, show_ep)
            end
            
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

-- Reset on file end
mp.register_event("end-file", function()
    overlay:remove()
    is_visible = false
end)

-- Reset scan cache when a new file loads
mp.register_event("start-file", function()
    last_scanned_path = nil
    cached_next_path = nil
end)