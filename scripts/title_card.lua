--[[
   ╔═══════════════════════════════════════════════════════════════════════════╗
   ║                MPV-ANDROID TITLE CARD (TRUE FINAL v32)                  			  ║
   ╠═════════════════════════════════════════════════════════════════════════ ═╣
   ║  VERSION:     32.0 (Pure Regex + Resolution Fix + Full Docs)             			 ║
   ║  AUTHOR:      Gemini                                                    			  ║
   ║                                                                         			  ║
   ║  DESCRIPTION:                                                           			  ║
   ║  A professional, battery-efficient OSD overlay for mpv-android.          			 ║
   ║  It automatically parses filenames to show clean Show Titles and        			  ║
   ║  technical details (Resolution, HDR, Codecs) without clutter.             			║
   ║                                                                           			║
   ║  KEY FEATURES:                                                           			 ║
   ║  • Smart Metadata:  Cleans "Show.Name.S01E05.1080p.mkv" -> "Show Name".  			 ║
   ║  • Regex Master:    Handles "E01", "S01E01", and "2024" formats perfectly.			║
   ║  • Tech Detection:  Advanced detection for [HDR] [HLG] [WCG] [10bit].     			║
   ║  • Smart Res:       Detects 4K/1080p even if video is cropped (2536px). 			  ║
   ║  • Native Seek:     Uses system OSD for seeking (smooth & familiar).     			 ║
   ║  • Auto-layout:     Corrects layout if phone lags on startup.          		       ║
   ║  • Safe Layout:     Prevents text from being cut off by notches/corners.  			║
   ║  • Last played:     Show last played time on startup of video.           			 ║
   ║  • Auto position:   Auto position to a the video edge on any type of display. 		║
   ║ 																					  ║
   ║  INSTALLATION:                                                          			  ║
   ║  1. Save this file as 'title_card.lua'.                                			   ║
   ║  2. Move it to your mpv scripts folder:                                			   ║
   ║     /sdcard/Android/data/is.xyz.mpv/files/scripts/                        			║
   ║  3. Restart the mpv-android app.                                       		 	  ║
   ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

local mp = require 'mp'
local utils = require 'mp.utils'

-- Force mpv to display custom OSD messages
mp.set_property("osd-level", "1")

-- Force system OSD to use a background box style
mp.set_property("osd-border-style", "background-box")

-- =================================================================================
-- [1] USER CONFIGURATION
-- =================================================================================
-- Edit these values to customize the look and feel of your title card.

local opts = {
    -- [TIMING]
    duration      = 4.0,    -- How long the card stays on screen (in seconds)
    
    -- [SCALING]
    -- Multipliers for text size. The script automatically adjusts these based on your phone's screen resolution.
    scale_landscape = 1.5,  -- Normal Fullscreen mode
    scale_portrait  = 1.2,  -- Vertical phone mode (slightly smaller)
    scale_pip       = 0.7,  -- Picture-in-Picture mode
    
    -- [WRAPPING]
    -- Character limits before forcing text to a new line.
    wrap_landscape_title = 40,
    wrap_landscape_sub   = 60, 
    wrap_portrait_title  = 20,
    wrap_portrait_sub    = 30,
    
    -- [POSITIONING]
    margin_x        = 30,   -- Distance from the left edge of the inner video frame
    margin_y        = 30,   -- Distance from the top edge of the inner video frame
    safety_gap      = 30,   -- Minimum distance from the physical screen edge (protects against camera notches)
    
    -- [COLORS - BRAVIA STYLE] 
    -- Format is BGR Hex (Blue-Green-Red). Example: "0000FF" is Red.
    header_color  = "FFAA00", -- Electric Blue (Status Text)
    pause_color   = "FFAA00", -- Electric Blue (PAUSED)
    buffer_color  = "0000FF", -- Red (BUFFERING)
    seek_color    = "E0E0E0", -- Light Grey (SEEKING)
    title_color   = "FFFFFF", -- White (Main Show Title)
    sub_color     = "C0C0C0", -- Silver (Episode/Metadata)
    time_color    = "FFFFFF", -- White (Timestamps)
    
    -- [TAG COLORS]
    quality_color = "00D7FF", -- Gold (Resolution/HDR)
    audio_color   = "5050FF", -- Vivid Red (Audio Codec)
    lang_color    = "00FF00", -- Green (Language)
    sub_tag_color = "FFFF00", -- Cyan (Subtitle Info)
    size_color    = "909090", -- Dark Grey (File Size)
    list_color    = "00D7FF", -- Gold (Playlist position)
    chapter_color = "FFAA00", -- Electric Blue (Chapter names)
    
    -- [BACKGROUND BOX]
    bg_color      = "000000", -- Black
    bg_opacity    = "C0",     -- Transparency (00=Invisible, FF=Solid, C0=75%)
    
    -- [CLEANER LIST] 
    -- Words stripped from raw filenames to find the "real" title.
    ignore_list = {
        "1080p", "720p", "480p", "2160p", "4k", "8k", "x264", "x265", "h264", "h265",
        "web-dl", "webrip", "bluray", "aac", "ac3", "dts", "opus", "flac",
        "proper", "repack", "engsub", "uncensored", "mkv", "mp4", "ember", 
        "horriblesubs", "subsplease", "10bit", "8bit", "hevc", "avc", "hdr", "remux",
        "dual", "audio"
    }
}

-- =================================================================================
-- [2] INTERNAL STATE & CACHE
-- =================================================================================

local overlay = mp.create_osd_overlay("ass-events")
local hide_timer = nil
local is_seeking = false 
local is_startup = false 
local startup_ready = false -- Shield variable to prevent drawing before layout is calculated
local resume_text = false
local manual_seek_occurred = false
local time_checked = false
local file_load_time = 0

-- Cache table stores calculated layout and text strings so we don't recalculate every frame
local cache = {
    name = "", meta = "", 
    wrapped_name = "", wrapped_meta = "", tags_line = "",
    layout_x = 0, layout_y = 0, scale = 1, 
    wrap_title = 40, wrap_sub = 60
}

-- [PRE-COMPILE OPTIMIZATION]
-- Pre-compiles the ignore list into fast regex patterns when the script first loads
local compiled_ignore_list = {}
for _, tag in ipairs(opts.ignore_list) do 
    local ci_tag = tag:gsub("%a", function(c) return string.format("[%s%s]", c:lower(), c:upper()) end)
    table.insert(compiled_ignore_list, "%f[%w]" .. ci_tag .. "%f[%W]")
end
local cjk_brackets = {"【", "】", "「", "」", "（", "）", "《", "》", "“", "”", "‘", "’"}

-- =================================================================================
-- [3] PARSING LOGIC
-- =================================================================================

--- Scrubs raw filenames of junk tags, brackets, and un-renderable characters
function clean_text(text)
    if not text then return "" end
    
    -- Downloader Fix: Converts special Unicode characters (used by yt-dlp to bypass OS rules) to standard text
    text = text:gsub("⧸", "/"):gsub("꞉", ":"):gsub("⏐", "|")
    text = text:gsub("／", "/"):gsub("：", ":"):gsub("？", "?"):gsub("｜", "|")
    
    -- Emoji Nuke: Mathematically deletes 4-byte UTF-8 emojis (🎦, 😭) that cause missing font boxes in mpv
    text = text:gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", "")
    
    text = text:gsub("%%20", " "):gsub("[._]", " ") 
    text = text:gsub("[%[%]%(%)%{%}\\]", " ")
    for _, b in ipairs(cjk_brackets) do text = text:gsub(b, " ") end
    for _, pat in ipairs(compiled_ignore_list) do text = text:gsub(pat, " ") end
    
    text = text:gsub("^[%s%-%_]+", ""):gsub("[%s%-%_]+$", "")
    return text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
end

--- Smartly extracts the Show Title and Episode/Year using multiple Regex patterns
function get_smart_details_internal(path, title)
    local final_title = (title and title ~= "") and title or (path:match("([^/]+)$") or path)
    final_title = final_title:gsub("%?.*$", ""):gsub("%.%w+$", ""):gsub("%b[]", ""):gsub("%b()", "")
    local clean = clean_text(final_title)
    
    local prefix = "Episode"
    if clean:match("%f[%a]OVA%f[%A]") then prefix = "OVA" end
    if clean:match("%f[%a]Special%f[%A]") then prefix = "Special" end
    if clean:match("%f[%a]Movie%f[%A]") then prefix = "Movie" end

    local name, ep, matched = "", "", false

    -- S01E02 format
    local s_lead, e_lead, rest = clean:match("^[Ss](%d+)[Ee](%d+)(.*)$")
    if s_lead and e_lead then ep = "S" .. s_lead .. "E" .. e_lead; name = clean_text(rest); matched = true end

    -- Movie Year format (2024)
    if not matched then
        local m_name, yr = clean:match("^(.-)%s+(20%d%d)%s*.*")
        if not m_name then m_name, yr = clean:match("^(.-)%s+(19%d%d)%s*.*") end
        if m_name and yr then name = m_name; ep = yr; matched = true end
    end

    -- Standard embedded format (Title S01E01)
    if not matched then
        local s, e1, e2 = clean:match("[Ss](%d+)[Ee](%d+)[-][Ee](%d+)")
        local n = clean:match("^(.-)[%s%-_]*[Ss]%d+")
        if n and s then name = n; ep = "S" .. s .. "E" .. e1 .. "-" .. e2; matched = true end
    end
    if not matched then
        local s, e = clean:match("[Ss](%d+)[Ee](%d+)")
        local n = clean:match("^(.-)[%s%-_]*[Ss]%d+")
        if n and s then name = n; ep = "S" .. s .. "E" .. e; matched = true end
    end
    
    -- Fallbacks for short codes, x-notation, and trailing numbers
    if not matched then
        local n, e = clean:match("^(.-)[%s%-_]*[Ee][Pp]?(%d+)")
        if n and e then name = n; ep = prefix .. " " .. tonumber(e); matched = true end
    end
    if not matched then
        local s, e = clean:match("(%d+)x(%d+)")
        local n = clean:match("^(.-)[%s%-_]*%d+x")
        if n and s then name = n; ep = s .. "x" .. e; matched = true end
    end
    if not matched then
        local n, e = clean:match("^(.-)%s*(【.*】.*)$")
        if not n then n, e = clean:match("^(.-)%s*(%[.*%].*)$") end
        if n and e then name = n; ep = e; matched = true end
    end
    if not matched then
        name, ep = clean:match("^(.-)%s+-%s+(.*)$")
        if name and ep then matched = true end
    end
    if not matched then
        local n, e = clean:match("^(.*)%s+(%d%d)$")
        if not n then n, e = clean:match("^(.*)%s+(0%d%d)$") end
        if n and e then name = n; ep = prefix .. " " .. tonumber(e); matched = true end
    end
    
    if not matched then name = clean; ep = "" end
    name = name:gsub("[%s%-%_]+$", "")
    
    return name, ep
end

--- Reads mpv properties to detect resolution, HDR, and codec data
function get_tech_details()
    local w, h = mp.get_property_number("width"), mp.get_property_number("height")
    local res = ""
    local function is_close(val, target) return val and (val >= target - 40) and (val <= target + 40) end
    
    if w and h then
        if     is_close(w, 7680) or is_close(h, 4320) then res = "8K"
        elseif is_close(w, 3840) or is_close(h, 2160) then res = "4K"
        elseif is_close(h, 1440) then res = "2K"
        elseif is_close(w, 1920) or is_close(h, 1080) then res = "1080p"
        elseif is_close(w, 1280) or is_close(h, 720)  then res = "720p"
        elseif is_close(w, 854)  or is_close(h, 480)  then res = "480p"
        else res = string.format("%dx%d", w, h) end
    end
    
    local gamma, prim = mp.get_property("video-out-params/gamma"), mp.get_property("video-out-params/primaries")
    local hdr = ""
    if gamma == "pq" or gamma == "st2084" then hdr = "HDR" elseif gamma == "hlg" then hdr = "HLG" end
    if prim == "bt.2020" and hdr == "" then hdr = "WCG" end
    
    local fmt = mp.get_property("video-out-params/pixelformat")
    local bitdepth = (fmt and string.find(fmt, "10")) and "10bit" or ""
    
    local vcodec = mp.get_property("video-format")
    vcodec = vcodec and string.upper(vcodec):gsub("H264", "AVC"):gsub("H265", "HEVC") or ""

    local acodec = mp.get_property("audio-codec-name")
    local chans = mp.get_property_number("audio-params/channel-count") or mp.get_property_number("current-tracks/audio/channel-count")
    local audio = ""
    if acodec and acodec ~= "" then
        acodec = string.upper(acodec)
        if chans then
            if chans == 1 then acodec = acodec .. " Mono"
            elseif chans == 2 then acodec = acodec .. " 2.0"
            elseif chans == 6 then acodec = acodec .. " 5.1"
            elseif chans == 8 then acodec = acodec .. " 7.1"
            else acodec = string.format("%s %dch", acodec, chans) 
            end
        end
        audio = acodec
    end

    local track_list, lang, sub = mp.get_property_native("track-list"), "", ""
    if track_list then
        for _, track in ipairs(track_list) do
            if track.selected then
                if track.type == "audio" and track.lang then 
                    lang = string.upper(track.lang) 
                elseif track.type == "sub" then
                    sub = track.lang and string.upper(track.lang) or "UNK"
                    if track.title then
                        local t = string.lower(track.title)
                        if t:find("sign") then sub = sub .. " (Signs)"
                        elseif t:find("song") then sub = sub .. " (Songs)"
                        elseif t:find("forced") then sub = sub .. " (Forced)" end
                    end
                end
            end
        end
    end

    local fsize, size = mp.get_property_number("file-size"), ""
    if fsize then
        if fsize >= 1073741824 then size = string.format("%.1fGB", fsize/1073741824)
        elseif fsize >= 1048576 then size = string.format("%.0fMB", fsize/1048576) end
    end

    return res, hdr, bitdepth, vcodec, audio, lang, sub, size
end

--- Inserts line breaks (\N) into strings that exceed the defined wrap limit
function smart_wrap(text, limit)
    if not text then return "" end
    if #text <= limit then return text end
    local lines, current_line = {}, ""
    for word in text:gmatch("%S+") do
        if #current_line + #word + 1 > limit and #current_line > 0 then
            table.insert(lines, current_line)
            current_line = word
        else
            current_line = (#current_line > 0) and (current_line .. " " .. word) or word
        end
    end
    table.insert(lines, current_line)
    return table.concat(lines, "\\N")
end

-- =================================================================================
-- [4] UPDATERS & LAYOUT
-- =================================================================================

--- Formats all collected metadata and stores it in the cache
function update_metadata_cache()
    local path, title = mp.get_property("path"), mp.get_property("media-title")
    if not path then return end
    
    cache.name, cache.meta = get_smart_details_internal(path, title)
    local res, hdr, bitdepth, vcodec, audio, lang, sub, size = get_tech_details()
    
    local tags_tbl = {}
    if res ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[%s]", opts.quality_color, res)) end
    if hdr ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[%s]", opts.quality_color, hdr)) end
    if bitdepth ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[%s]", opts.quality_color, bitdepth)) end
    if vcodec ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[%s]", opts.quality_color, vcodec)) end
    if lang ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[%s]", opts.lang_color, lang)) end
    if audio ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[%s]", opts.audio_color, audio)) end
    if sub ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[Sub: %s]", opts.sub_tag_color, sub)) end
    if size ~= "" then table.insert(tags_tbl, string.format("{\\c&H%s&}[%s]", opts.size_color, size)) end
    cache.tags_line = #tags_tbl > 0 and ("  " .. table.concat(tags_tbl, " ")) or ""
    
    cache.wrapped_name = smart_wrap(cache.name, cache.wrap_title)
    cache.wrapped_meta = smart_wrap(cache.meta, cache.wrap_sub)
end

--- Calculates screen position, handles Android orientation, and finds the true video edges
function update_layout_cache()
    local osd_w, osd_h = mp.get_property_number("osd-width"), mp.get_property_number("osd-height")
    local osd_dim = mp.get_property_native("osd-dimensions")
    
    -- Locks the subtitle canvas to the exact screen resolution (Prevents distortion on 4:3 videos)
    if osd_w and osd_h then overlay.res_x, overlay.res_y = osd_w, osd_h end
    if not osd_w or not osd_h or osd_w <= 0 or osd_h <= 0 then return end
    
    -- Dynamically scales the font up on high-resolution displays (using 1080p as the baseline)
    local dynamic_scale = math.min(osd_w, osd_h) / 1080
    local bar_w, bar_h = 0, 0
    
    -- Retrieves the physical size of the black bars from mpv
    if osd_dim and osd_dim.ml and osd_dim.mt then
        bar_w, bar_h = osd_dim.ml, osd_dim.mt
    end
    
    -- Mode detection: Picture-in-Picture (< 600px), Portrait, or Landscape
    if osd_w < 600 then 
        cache.scale = dynamic_scale * opts.scale_pip
        cache.wrap_title, cache.wrap_sub = 20, 20
    elseif osd_h > osd_w then 
        cache.scale = dynamic_scale * opts.scale_portrait
        cache.wrap_title, cache.wrap_sub = opts.wrap_portrait_title, opts.wrap_portrait_sub
    else 
        cache.scale = dynamic_scale * opts.scale_landscape
        cache.wrap_title, cache.wrap_sub = opts.wrap_landscape_title, opts.wrap_landscape_sub
    end
    
    -- Calculates final coordinates, ensuring the box never overlaps physical screen notches (safety_gap)
    cache.layout_x = math.max(opts.safety_gap, math.floor(bar_w + opts.margin_x))
    cache.layout_y = math.max(opts.safety_gap, math.floor(bar_h + opts.margin_y))
    cache.wrapped_name = smart_wrap(cache.name, cache.wrap_title)
    cache.wrapped_meta = smart_wrap(cache.meta, cache.wrap_sub)
end

function format_time(seconds)
    if not seconds then return "00:00" end
    local h, m, s = math.floor(seconds/3600), math.floor((seconds%3600)/60), math.floor(seconds%60)
    return h > 0 and string.format("%d:%02d:%02d", h, m, s) or string.format("%02d:%02d", m, s)
end

-- =================================================================================
-- [5] RENDERER
-- =================================================================================

--- Compiles all cache data into an ASS subtitle string and draws it on screen
function show_overlay()
    -- Shield check: Abort drawing if the startup sequence hasn't unlocked the gate yet
    if is_startup and not startup_ready then return end
    if is_startup and (cache.layout_x <= 0 or cache.layout_y <= 0) then update_layout_cache() end

    local paused = mp.get_property_native("pause")
    local is_buffering = mp.get_property_bool("paused-for-cache", false)

    -- Auto-hide logic if the video is just playing normally
    if not is_startup and not paused and not is_buffering then 
        hide_overlay()
        return 
    end

    local x, y, scale = cache.layout_x, cache.layout_y, cache.scale
    local h_text, h_col = "NOW PLAYING", opts.header_color
    
    -- Priority status headers
    if is_buffering then h_text, h_col = "BUFFERING...", opts.buffer_color
    elseif is_seeking then h_text, h_col = "SEEKING...", opts.seek_color
    elseif paused then h_text, h_col = "PAUSED", opts.pause_color end
    
    local info = (cache.wrapped_meta ~= "") and string.format("{\\c&H%s&}%s\\N%s", opts.sub_color, cache.wrapped_meta, cache.tags_line) or cache.tags_line

    -- Build the footer string (Timestamps, Playlist, Chapters)
    local t_pos, dur = mp.get_property_number("time-pos", 0), mp.get_property_number("duration", 0)
    local t1 = format_time(t_pos)
    local footer = (dur and dur > 0) and string.format("{\\c&H%s&}%s / %s", opts.time_color, t1, format_time(dur)) or string.format("{\\c&H%s&}%s / LIVE", opts.time_color, t1)
    
    local p_pos, p_cnt = mp.get_property_number("playlist-pos-1"), mp.get_property_number("playlist-count")
    if p_cnt and p_cnt > 1 then footer = footer .. string.format("  {\\c&H%s&}[%d/%d]", opts.list_color, p_pos, p_cnt) end
    
    local chap_title, chap_curr, chap_count = mp.get_property("chapter-metadata/by-key/title"), mp.get_property_number("chapter"), mp.get_property_number("chapters")
    if chap_count and chap_count > 0 then
        footer = footer .. string.format("  {\\c&H%s&}• [%d/%d]", opts.chapter_color, (chap_curr and chap_curr + 1) or 1, chap_count)
        if chap_title and chap_title ~= "" then footer = footer .. " " .. chap_title:gsub("[%{%}\\]", "") end
    end

    -- Compile ASS Subtitle syntax
    local pad = "   "
    local style_card = string.format("{\\an7}{\\pos(%d,%d)}{\\bord10}{\\blur10}{\\shad0}{\\3c&H%s&}{\\3a&H%s&}", x, y, opts.bg_color, opts.bg_opacity)
    local l1 = string.format("{\\fs%d}{\\fsp2}{\\shad2}{\\c&H%s&}{\\b1}%s%s", 16*scale, h_col, pad, h_text)
    local l2 = string.format("\\N{\\fs%d}{\\shad2}{\\c&H%s&}{\\b1}%s%s", 38*scale, opts.title_color, pad, cache.wrapped_name)
    local l3 = string.format("\\N{\\fs%d}{\\shad1}{\\b0}%s%s", 23*scale, pad, (info == "") and footer or info)
    local l4 = (info == "") and "" or string.format("\\N{\\fs%d}{\\shad1}{\\b0}%s%s", 23*scale, pad, footer)
    
    -- Resume text detection
    if is_startup and not time_checked and t_pos > 0 then
        time_checked = true
        if t_pos > 5 and not manual_seek_occurred then
            resume_text = format_time(t_pos)
            if hide_timer then hide_timer:kill(); hide_timer = nil end
            hide_timer = mp.add_timeout(opts.duration, end_startup)
        end
    end

    local l5 = (is_startup and resume_text) and string.format("\\N{\\fs%d}{\\shad1}{\\b1}{\\c&H%s&}%s▶ Resumed at %s", 20*scale, opts.header_color, pad, resume_text) or ""
    
    -- Send data to mpv
    overlay.data = style_card .. l1 .. l2 .. l3 .. l4 .. l5
    overlay:update()
end

function hide_overlay() overlay.data = ""; overlay:update() end

function end_startup()
    is_startup = false
    update_layout_cache()
    if not mp.get_property_native("pause") then hide_overlay() end
end

-- =================================================================================
-- [6] EVENTS & OBSERVERS
-- =================================================================================

-- Triggers when you swipe, OR when mpv auto-resumes at startup
mp.register_event("seek", function()
    is_seeking = true
    if (mp.get_time() - file_load_time) > 2.5 then
        manual_seek_occurred = true 
    end
    if startup_ready then show_overlay() end
end)

mp.register_event("playback-restart", function()
    if is_startup then
        mp.add_timeout(0.15, function()
            startup_ready = true
            update_layout_cache()
            show_overlay()
            
            -- THE RESUME FLASH: If mpv auto-seeked to your saved time, 
            -- hold "SEEKING..." for 0.8 seconds before switching to "NOW PLAYING"
            if is_seeking then
                mp.add_timeout(0.4, function()
                    is_seeking = false
                    if overlay.data ~= "" then show_overlay() end
                end)
            end
            
            if hide_timer then hide_timer:kill(); hide_timer = nil end
            hide_timer = mp.add_timeout(opts.duration, end_startup)
        end)
    elseif mp.get_property_native("pause") then
        is_seeking = false
        show_overlay()
    else
        is_seeking = false
        if manual_seek_occurred then
            if hide_timer then hide_timer:kill(); hide_timer = nil end
            hide_timer = mp.add_timeout(2.0, function() 
                manual_seek_occurred = false
                if not mp.get_property_native("pause") then hide_overlay() end
            end)
            show_overlay()
        else
            hide_overlay()
        end
    end
end)

mp.register_event("file-loaded", function() 
    if hide_timer then hide_timer:kill(); hide_timer = nil end
    is_startup, startup_ready = true, false 
    is_seeking, resume_text = false, false -- Reset seeking state for fresh file
    manual_seek_occurred, time_checked = false, false
    file_load_time = mp.get_time() 
    update_metadata_cache()
end)

mp.observe_property("track-list", "native", function() update_metadata_cache(); if overlay.data ~= "" then show_overlay() end end)
mp.observe_property("video-format", "string", function(n, v) if v then update_metadata_cache(); if overlay.data ~= "" then show_overlay() end end end)

-- Throttle the clock to only update screen once per second (saves battery)
local last_second = -1
mp.observe_property("time-pos", "number", function(n, v) 
    if v and overlay.data and overlay.data ~= "" then 
        local current_second = math.floor(v)
        if current_second ~= last_second then last_second = current_second; show_overlay() end
    end 
end)

-- Background observers to recalculate position if phone rotates or UI changes
mp.observe_property("osd-width", "number", function() update_layout_cache(); if overlay.data ~= "" then show_overlay() end end)
mp.observe_property("osd-height", "number", function() update_layout_cache(); if overlay.data ~= "" then show_overlay() end end)
mp.observe_property("osd-dimensions", "native", function() update_layout_cache(); if overlay.data ~= "" then show_overlay() end end)
mp.observe_property("paused-for-cache", "bool", function(n, v) if v then show_overlay() elseif not mp.get_property_native("pause") and not is_startup then hide_overlay() end end)
mp.observe_property("pause", "bool", function(n, v) if v then show_overlay() elseif not is_startup then hide_overlay() end end)

-- Kill everything when video closes
mp.register_event("end-file", function() if hide_timer then hide_timer:kill(); hide_timer = nil end; overlay.data = ""; overlay:update() end)