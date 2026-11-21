local mp = require("mp")
local assdraw = require("mp.assdraw")
local msg = require("mp.msg")
local utils = require("mp.utils")
local mpopts = require("mp.options")
local options = {
	-- Defaults to shift+w
	keybind = "W",
	-- If empty, saves on the same directory of the playing video.
	-- A starting "~" will be replaced by the home dir.
	-- This field is delimited by double-square-brackets - [[ and ]] - instead of
	-- quotes, because Windows users might run into a issue when using
	-- backslashes as a path separator. Examples of valid inputs for this field
	-- would be: [[]] (the default, empty value), [[C:\Users\John]] (on Windows),
	-- and [[/home/john]] (on Unix-like systems eg. Linux).
	-- The [[]] delimiter is not needed when using from a configuration file
	-- in the script-opts folder.
	output_directory = [[]],
	run_detached = false,
	-- Template string for the output file
	-- %f - Filename, with extension
	-- %F - Filename, without extension
	-- %T - Media title, if it exists, or filename, with extension (useful for some streams, such as YouTube).
	-- %s, %e - Start and end time, with milliseconds
	-- %S, %E - Start and end time, without milliseconds
	-- %M - "-audio", if audio is enabled, empty otherwise
	-- %R - "-(height)p", where height is the video's height, or scale_height, if it's enabled.
	-- %n - Sequence number (1, 2, 3, ...). The first filename (starting
	-- at 1) not already taken in the output directory is selected when
	-- formatting, so gaps left by deleted clips are filled. There is no
	-- persistent counter to reset; concurrent encodes may still race.
	-- Use %04n (or %02n, etc.) to zero-pad (clip_%04n -> clip_0001, ...).
	-- Templates without a counter keep the previous behavior (may overwrite).
	-- More specifiers are supported, see https://mpv.io/manual/master/#options-screenshot-template
	-- Property expansion is supported (with %{} at top level, ${} when nested), see https://mpv.io/manual/master/#property-expansion
	output_template = "%F-[%s-%e]%M",
	-- Scale video to a certain height, keeping the aspect ratio. -1 disables it.
	scale_height = -1,
	-- Change the FPS of the output video, dropping or duplicating frames as needed.
	-- -1 means the FPS will be unchanged from the source.
	fps = -1,
	-- Target filesize, in kB. This will be used to calculate the bitrate
	-- used on the encode. If this is set to <= 0, the video bitrate will be set
	-- to 0, which might enable constant quality modes, depending on the
	-- video codec that's used (VP8 and VP9, for example).
	target_filesize = 2500,
	-- If true, will use stricter flags to ensure the resulting file doesn't
	-- overshoot the target filesize. Not recommended, as constrained quality
	-- mode should work well, unless you're really having trouble hitting
	-- the target size.
	strict_filesize_constraint = false,
	strict_bitrate_multiplier = 0.95,
	-- In kilobits.
	strict_audio_bitrate = 64,
	-- Sets the output format, from a few predefined ones.
	-- Currently we have:
	-- av1
	-- hevc
	-- webm-vp9 (libvpx-vp9/libopus)
	-- webp
	-- avc (h264/AAC)
	-- avc-nvenc (h264-NVENC/AAC)
	-- webm-vp8 (libvpx/libvorbis)
	-- gif
	-- mp3 (libmp3lame)
	-- and raw (rawvideo/pcm_s16le).
	output_format = "webm-vp8",
	twopass = true,
	-- If set, applies the video filters currently used on the playback to the encode.
	apply_current_filters = true,
	-- If set, writes the video's filename to the "Title" field on the metadata.
	write_filename_on_metadata = false,
	-- Set the number of encoding threads, for codecs libvpx and libvpx-vp9
	threads = 4,
	additional_flags = "",
	-- Constant Rate Factor (CRF). The value meaning and limits may change,
	-- from codec to codec. Set to -1 to disable.
	crf = 10,
	-- Useful for flags that may impact output filesize, such as qmin, qmax etc
	-- Won't be applied when strict_filesize_constraint is on.
	non_strict_additional_flags = "",
	-- Display the encode progress, in %. Requires run_detached to be disabled.
	-- On Windows, it shows a cmd popup. "auto" will display progress on non-Windows platforms.
	display_progress = "auto",
	-- The font size used in the menu. Isn't used for the notifications (started encode, finished encode etc)
	font_size = 28,
	margin = 10,
	message_duration = 5,
	-- gif dither mode, 0-5 for bayer w/ bayer_scale 0-5, 6 for paletteuse default (sierra2_4a)
	gif_dither = 2,
	-- Force square pixels on output video
	-- Some players like recent Firefox versions display videos with non-square pixels with wrong aspect ratio
	force_square_pixels = false,
	-- MPV command to run upon successful encoding
	-- %{output} will be replaced with the path to the resulting file.
	completion_command = "",
	-- Where "encode & upload" (u) sends the clip. Only the Catbox services are
	-- supported: "catbox" (permanent until 2 years of inactivity) or
	-- "litterbox" (temporary, expires after litterbox_time).
	upload_host = "catbox",
	-- Expiry for litterbox uploads: 1h, 12h, 24h or 72h.
	litterbox_time = "24h",
	-- Optional Catbox account hash. Account uploads are permanent and can be
	-- managed (deleted) from the Catbox account.
	catbox_userhash = "",
	-- curl executable used for the multipart upload.
	upload_curl_path = "curl",
	-- Open the uploaded link in the browser as soon as it is ready.
	open_after_upload = false,
}

mpopts.read_options(options)
local base64_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function base64_encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return base64_chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function base64_decode(data)
    data = string.gsub(data, '[^'..base64_chars..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(base64_chars:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end
local emit_event
emit_event = function(event_name, ...)
  return mp.commandv("script-message", "webm-" .. tostring(event_name), ...)
end
local test_set_options
test_set_options = function(new_options_json)
  local new_options = utils.parse_json(new_options_json)
  for k, v in pairs(new_options) do
    options[k] = v
  end
  return emit_event("options-set")
end
mp.register_script_message("mpv-webm-set-options", test_set_options)
local register_test_handlers
register_test_handlers = function(main_page)
  mp.register_script_message("mpv-webm-set-range", function(range_json)
    local range = utils.parse_json(range_json)
    main_page.startTime = range.startTime
    main_page.endTime = range.endTime
    if range.region then
      local _list_0 = {
        "x",
        "y",
        "w",
        "h"
      }
      for _index_0 = 1, #_list_0 do
        local key = _list_0[_index_0]
        main_page.region[key] = range.region[key]
      end
    end
    return emit_event("range-set")
  end)
  mp.register_script_message("mpv-webm-encode", function()
    return main_page:encode()
  end)
  mp.register_script_message("mpv-webm-upload", function()
    return main_page:upload()
  end)
  return mp.register_script_message("mpv-webm-get-state", function()
    local mouse_x, mouse_y = mp.get_mouse_pos()
    local osd_w, osd_h = mp.get_osd_size()
    local state_json = utils.format_json({
      startTime = main_page.startTime,
      endTime = main_page.endTime,
      region = {
        x = main_page.region.x,
        y = main_page.region.y,
        w = main_page.region.w,
        h = main_page.region.h
      },
      mainVisible = main_page.visible or false,
      mouse = {
        x = mouse_x,
        y = mouse_y
      },
      osd = {
        w = osd_w,
        h = osd_h
      }
    })
    return emit_event("state", state_json)
  end)
end
local bold
bold = function(text)
  return "{\\b1}" .. tostring(text) .. "{\\b0}"
end
local message
message = function(text, duration)
  local ass = mp.get_property_osd("osd-ass-cc/0")
  ass = ass .. text
  return mp.osd_message(ass, duration or options.message_duration)
end
local append
append = function(a, b)
  for _, val in ipairs(b) do
    a[#a + 1] = val
  end
  return a
end
local seconds_to_time_string
seconds_to_time_string = function(seconds, no_ms, full)
  if seconds < 0 then
    return "unknown"
  end
  local ret = ""
  if not (no_ms) then
    ret = string.format(".%03d", seconds * 1000 % 1000)
  end
  ret = string.format("%02d:%02d%s", math.floor(seconds / 60) % 60, math.floor(seconds) % 60, ret)
  if full or seconds > 3600 then
    ret = string.format("%d:%s", math.floor(seconds / 3600), ret)
  end
  return ret
end
local seconds_to_path_element
seconds_to_path_element = function(seconds, no_ms, full)
  local time_string = seconds_to_time_string(seconds, no_ms, full)
  local _
  time_string, _ = time_string:gsub(":", ".")
  return time_string
end
local file_exists
file_exists = function(name)
  local info, err = utils.file_info(name)
  if info ~= nil then
    return true
  end
  return false
end
local expand_properties
expand_properties = function(text, magic)
  if magic == nil then
    magic = "$"
  end
  for prefix, raw, prop, colon, fallback, closing in text:gmatch("%" .. magic .. "{([?!]?)(=?)([^}:]*)(:?)([^}]*)(}*)}") do
    local err
    local prop_value
    local compare_value
    local original_prop = prop
    local get_property = mp.get_property_osd
    if raw == "=" then
      get_property = mp.get_property
    end
    if prefix ~= "" then
      for actual_prop, compare in prop:gmatch("(.-)==(.*)") do
        prop = actual_prop
        compare_value = compare
      end
    end
    if colon == ":" then
      prop_value, err = get_property(prop, fallback)
    else
      prop_value, err = get_property(prop, "(error)")
    end
    prop_value = tostring(prop_value)
    if prefix == "?" then
      if compare_value == nil then
        prop_value = err == nil and fallback .. closing or ""
      else
        prop_value = prop_value == compare_value and fallback .. closing or ""
      end
      prefix = "%" .. prefix
    elseif prefix == "!" then
      if compare_value == nil then
        prop_value = err ~= nil and fallback .. closing or ""
      else
        prop_value = prop_value ~= compare_value and fallback .. closing or ""
      end
    else
      prop_value = prop_value .. closing
    end
    if colon == ":" then
      local _
      text, _ = text:gsub("%" .. magic .. "{" .. prefix .. raw .. original_prop:gsub("%W", "%%%1") .. ":" .. fallback:gsub("%W", "%%%1") .. closing .. "}", expand_properties(prop_value))
    else
      local _
      text, _ = text:gsub("%" .. magic .. "{" .. prefix .. raw .. original_prop:gsub("%W", "%%%1") .. closing .. "}", prop_value)
    end
  end
  return text
end
local sequence_escape_placeholder = string.char(31) .. "MPVWEBMESC" .. string.char(31)
local sequence_placeholder_prefix = string.char(31) .. "MPVWEBMSEQ"
local format_sequence_number
format_sequence_number = function(n, width)
  if width and width > 0 then
    return string.format("%0" .. tostring(width) .. "d", n)
  end
  return tostring(n)
end
local format_filename
format_filename = function(startTime, endTime, videoFormat, outDir)
  local hasAudioCodec = videoFormat.audioCodec ~= ""
  local replaceFirst = {
    ["%%mp"] = "%%mH.%%mM.%%mS",
    ["%%mP"] = "%%mH.%%mM.%%mS.%%mT",
    ["%%p"] = "%%wH.%%wM.%%wS",
    ["%%P"] = "%%wH.%%wM.%%wS.%%wT"
  }
  local replaceTable = {
    ["%%wH"] = string.format("%02d", math.floor(startTime / (60 * 60))),
    ["%%wh"] = string.format("%d", math.floor(startTime / (60 * 60))),
    ["%%wM"] = string.format("%02d", math.floor(startTime / 60 % 60)),
    ["%%wm"] = string.format("%d", math.floor(startTime / 60)),
    ["%%wS"] = string.format("%02d", math.floor(startTime % 60)),
    ["%%ws"] = string.format("%d", math.floor(startTime)),
    ["%%wf"] = string.format("%s", startTime),
    ["%%wT"] = string.sub(string.format("%.3f", startTime % 1), 3),
    ["%%mH"] = string.format("%02d", math.floor(endTime / (60 * 60))),
    ["%%mh"] = string.format("%d", math.floor(endTime / (60 * 60))),
    ["%%mM"] = string.format("%02d", math.floor(endTime / 60 % 60)),
    ["%%mm"] = string.format("%d", math.floor(endTime / 60)),
    ["%%mS"] = string.format("%02d", math.floor(endTime % 60)),
    ["%%ms"] = string.format("%d", math.floor(endTime)),
    ["%%mf"] = string.format("%s", endTime),
    ["%%mT"] = string.sub(string.format("%.3f", endTime % 1), 3),
    ["%%s"] = seconds_to_path_element(startTime),
    ["%%S"] = seconds_to_path_element(startTime, true),
    ["%%e"] = seconds_to_path_element(endTime),
    ["%%E"] = seconds_to_path_element(endTime, true),
    ["%%M"] = (mp.get_property_native('aid') and not mp.get_property_native('mute') and hasAudioCodec) and '-audio' or '',
    ["%%R"] = (options.scale_height ~= -1) and "-" .. tostring(options.scale_height) .. "p" or "-" .. tostring(mp.get_property_native('height')) .. "p",
    ["%%mb"] = options.target_filesize / 1000,
    ["%%t%%"] = "%%"
  }
  local mediaTable = {
    ["%%f"] = mp.get_property("filename"),
    ["%%F"] = mp.get_property("filename/no-ext"),
    ["%%T"] = mp.get_property("media-title")
  }
  local filename = options.output_template
  local _
  filename, _ = filename:gsub("%%%%", sequence_escape_placeholder)
  local seq_widths = { }
  filename, _ = filename:gsub("%%(0?%d*)n", function(digits)
    local width = tonumber(digits) or 0
    seq_widths[#seq_widths + 1] = width
    return tostring(sequence_placeholder_prefix) .. tostring(#seq_widths) .. tostring(string.char(31))
  end)
  local has_seq = #seq_widths > 0
  filename, _ = filename:gsub(sequence_escape_placeholder, function()
    return "%"
  end)
  for format, value in pairs(replaceFirst) do
    filename, _ = filename:gsub(format, value)
  end
  for format, value in pairs(replaceTable) do
    filename, _ = filename:gsub(format, value)
  end
  for format, value in pairs(mediaTable) do
    if value ~= nil then
      local val = value
      filename, _ = filename:gsub(format, function()
        return val
      end)
    end
  end
  if mp.get_property_bool("demuxer-via-network", false) then
    filename, _ = filename:gsub("%%X{([^}]*)}", "%1")
    filename, _ = filename:gsub("%%x", "")
  else
    local x = string.gsub(mp.get_property("stream-open-filename", ""), string.gsub(mp.get_property("filename", ""), "%W", "%%%1") .. "$", "")
    filename, _ = filename:gsub("%%X{[^}]*}", function()
      return x
    end)
    filename, _ = filename:gsub("%%x", function()
      return x
    end)
  end
  filename = expand_properties(filename, "%")
  for format in filename:gmatch("%%t([aAbBcCdDeFgGhHIjmMnprRStTuUVwWxXyYzZ])") do
    filename, _ = filename:gsub("%%t" .. format, os.date("%" .. format))
  end
  filename, _ = filename:gsub("[<>:\"/\\|?*]", "")
  if not has_seq then
    return tostring(filename) .. "." .. tostring(videoFormat.outputExtension)
  end
  if filename:find(sequence_placeholder_prefix, 1, true) == nil then
    return tostring(filename) .. "." .. tostring(videoFormat.outputExtension)
  end
  local apply_sequence
  apply_sequence = function(n)
    local name = filename
    for i, width in ipairs(seq_widths) do
      local placeholder = tostring(sequence_placeholder_prefix) .. tostring(i) .. tostring(string.char(31))
      local formatted = format_sequence_number(n, width)
      name, _ = name:gsub(placeholder, formatted)
    end
    return name
  end
  if outDir == nil then
    return tostring(apply_sequence(1)) .. "." .. tostring(videoFormat.outputExtension)
  end
  local checkDir = outDir == "" and "." or outDir
  local n = 1
  while true do
    local candidate = tostring(apply_sequence(n)) .. "." .. tostring(videoFormat.outputExtension)
    if not (file_exists(utils.join_path(checkDir, candidate))) then
      return candidate
    end
    n = n + 1
  end
end
local parse_directory
parse_directory = function(dir)
  local home_dir = os.getenv("HOME")
  if not home_dir then
    home_dir = os.getenv("USERPROFILE")
  end
  if not home_dir then
    local drive = os.getenv("HOMEDRIVE")
    local path = os.getenv("HOMEPATH")
    if drive and path then
      home_dir = utils.join_path(drive, path)
    else
      msg.warn("Couldn't find home dir.")
      home_dir = ""
    end
  end
  local _
  dir, _ = dir:gsub("^~", home_dir)
  return dir
end
local is_windows = type(package) == "table" and type(package.config) == "string" and package.config:sub(1, 1) == "\\"
local trim
trim = function(s)
  return s:match("^%s*(.-)%s*$")
end
local get_null_path
get_null_path = function()
  if file_exists("/dev/null") then
    return "/dev/null"
  end
  return "NUL"
end
local run_subprocess
run_subprocess = function(params)
  local res = utils.subprocess(params)
  msg.verbose("Command stdout: ")
  msg.verbose(res.stdout)
  if res.status ~= 0 then
    msg.verbose("Command failed! Reason: ", res.error, " Killed by us? ", res.killed_by_us and "yes" or "no")
    return false
  end
  return true
end
local shell_escape
shell_escape = function(args)
  local ret = { }
  for i, a in ipairs(args) do
    local s = tostring(a)
    if string.match(s, "[^A-Za-z0-9_/:=-]") then
      if is_windows then
        s = '"' .. string.gsub(s, '"', '"\\""') .. '"'
      else
        s = "'" .. string.gsub(s, "'", "'\\''") .. "'"
      end
    end
    table.insert(ret, s)
  end
  local concat = table.concat(ret, " ")
  if is_windows then
    concat = '"' .. concat .. '"'
  end
  return concat
end
local run_subprocess_popen
run_subprocess_popen = function(command_line)
  local command_line_string = shell_escape(command_line)
  command_line_string = command_line_string .. " 2>&1"
  msg.verbose("run_subprocess_popen: running " .. tostring(command_line_string))
  return io.popen(command_line_string)
end
local calculate_scale_factor
calculate_scale_factor = function()
  local baseResY = 720
  local osd_w, osd_h = mp.get_osd_size()
  return osd_h / baseResY
end
local should_display_progress
should_display_progress = function()
  if options.display_progress == "auto" then
    return not is_windows
  end
  return options.display_progress
end
local reverse
reverse = function(list)
  local _accum_0 = { }
  local _len_0 = 1
  local _max_0 = 1
  for _index_0 = #list, _max_0 < 0 and #list + _max_0 or _max_0, -1 do
    local element = list[_index_0]
    _accum_0[_len_0] = element
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
local get_pass_logfile_path
get_pass_logfile_path = function(encode_out_path)
  return tostring(encode_out_path) .. "-video-pass1.log"
end
local dimensions_changed = true
local _video_dimensions = { }
local get_video_dimensions
get_video_dimensions = function()
  if not (dimensions_changed) then
    return _video_dimensions
  end
  local video_params = mp.get_property_native("video-out-params")
  if not video_params then
    return nil
  end
  dimensions_changed = false
  local keep_aspect = mp.get_property_bool("keepaspect")
  local w = video_params["w"]
  local h = video_params["h"]
  local dw = video_params["dw"]
  local dh = video_params["dh"]
  if mp.get_property_number("video-rotate") % 180 == 90 then
    w, h = h, w
    dw, dh = dh, dw
  end
  _video_dimensions = {
    top_left = { },
    bottom_right = { },
    ratios = { }
  }
  local window_w, window_h = mp.get_osd_size()
  if keep_aspect then
    local unscaled = mp.get_property_native("video-unscaled")
    local panscan = mp.get_property_number("panscan")
    local fwidth = window_w
    local fheight = math.floor(window_w / dw * dh)
    if fheight > window_h or fheight < h then
      local tmpw = math.floor(window_h / dh * dw)
      if tmpw <= window_w then
        fheight = window_h
        fwidth = tmpw
      end
    end
    local vo_panscan_area = window_h - fheight
    local f_w = fwidth / fheight
    local f_h = 1
    if vo_panscan_area == 0 then
      vo_panscan_area = window_h - fwidth
      f_w = 1
      f_h = fheight / fwidth
    end
    if unscaled or unscaled == "downscale-big" then
      vo_panscan_area = 0
      if unscaled or (dw <= window_w and dh <= window_h) then
        fwidth = dw
        fheight = dh
      end
    end
    local scaled_width = fwidth + math.floor(vo_panscan_area * panscan * f_w)
    local scaled_height = fheight + math.floor(vo_panscan_area * panscan * f_h)
    local split_scaling
    split_scaling = function(dst_size, scaled_src_size, zoom, align, pan)
      scaled_src_size = math.floor(scaled_src_size * 2 ^ zoom)
      align = (align + 1) / 2
      local dst_start = math.floor((dst_size - scaled_src_size) * align + pan * scaled_src_size)
      if dst_start < 0 then
        dst_start = dst_start + 1
      end
      local dst_end = dst_start + scaled_src_size
      if dst_start >= dst_end then
        dst_start = 0
        dst_end = 1
      end
      return dst_start, dst_end
    end
    local zoom = mp.get_property_number("video-zoom")
    local align_x = mp.get_property_number("video-align-x")
    local pan_x = mp.get_property_number("video-pan-x")
    _video_dimensions.top_left.x, _video_dimensions.bottom_right.x = split_scaling(window_w, scaled_width, zoom, align_x, pan_x)
    local align_y = mp.get_property_number("video-align-y")
    local pan_y = mp.get_property_number("video-pan-y")
    _video_dimensions.top_left.y, _video_dimensions.bottom_right.y = split_scaling(window_h, scaled_height, zoom, align_y, pan_y)
  else
    _video_dimensions.top_left.x = 0
    _video_dimensions.bottom_right.x = window_w
    _video_dimensions.top_left.y = 0
    _video_dimensions.bottom_right.y = window_h
  end
  _video_dimensions.ratios.w = w / (_video_dimensions.bottom_right.x - _video_dimensions.top_left.x)
  _video_dimensions.ratios.h = h / (_video_dimensions.bottom_right.y - _video_dimensions.top_left.y)
  return _video_dimensions
end
local set_dimensions_changed
set_dimensions_changed = function()
  dimensions_changed = true
end
local monitor_dimensions
monitor_dimensions = function()
  local properties = {
    "keepaspect",
    "video-out-params",
    "video-unscaled",
    "panscan",
    "video-zoom",
    "video-align-x",
    "video-pan-x",
    "video-align-y",
    "video-pan-y",
    "osd-width",
    "osd-height"
  }
  for _, p in ipairs(properties) do
    mp.observe_property(p, "native", set_dimensions_changed)
  end
end
local clamp
clamp = function(min, val, max)
  if val <= min then
    return min
  end
  if val >= max then
    return max
  end
  return val
end
local clamp_point
clamp_point = function(top_left, point, bottom_right)
  return {
    x = clamp(top_left.x, point.x, bottom_right.x),
    y = clamp(top_left.y, point.y, bottom_right.y)
  }
end
local VideoPoint
do
  local _class_0
  local _base_0 = {
    set_from_screen = function(self, sx, sy)
      local d = get_video_dimensions()
      local point = clamp_point(d.top_left, {
        x = sx,
        y = sy
      }, d.bottom_right)
      self.x = math.floor(d.ratios.w * (point.x - d.top_left.x) + 0.5)
      self.y = math.floor(d.ratios.h * (point.y - d.top_left.y) + 0.5)
      if point.x >= d.bottom_right.x - 1 and point.x > d.top_left.x then
        self.x = math.floor(d.ratios.w * (d.bottom_right.x - d.top_left.x) + 0.5)
      end
      if point.y >= d.bottom_right.y - 1 and point.y > d.top_left.y then
        self.y = math.floor(d.ratios.h * (d.bottom_right.y - d.top_left.y) + 0.5)
      end
    end,
    to_screen = function(self)
      local d = get_video_dimensions()
      return {
        x = math.floor(self.x / d.ratios.w + d.top_left.x + 0.5),
        y = math.floor(self.y / d.ratios.h + d.top_left.y + 0.5)
      }
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.x = -1
      self.y = -1
    end,
    __base = _base_0,
    __name = "VideoPoint"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  VideoPoint = _class_0
end
local Region
do
  local _class_0
  local _base_0 = {
    is_valid = function(self)
      return self.x > -1 and self.y > -1 and self.w > -1 and self.h > -1
    end,
    set_from_points = function(self, p1, p2)
      self.x = math.min(p1.x, p2.x)
      self.y = math.min(p1.y, p2.y)
      self.w = math.abs(p1.x - p2.x)
      self.h = math.abs(p1.y - p2.y)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.x = -1
      self.y = -1
      self.w = -1
      self.h = -1
    end,
    __base = _base_0,
    __name = "Region"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Region = _class_0
end
local make_fullscreen_region
make_fullscreen_region = function()
  local r = Region()
  local d = get_video_dimensions()
  local a = VideoPoint()
  local b = VideoPoint()
  local xa, ya
  do
    local _obj_0 = d.top_left
    xa, ya = _obj_0.x, _obj_0.y
  end
  a:set_from_screen(xa, ya)
  local xb, yb
  do
    local _obj_0 = d.bottom_right
    xb, yb = _obj_0.x, _obj_0.y
  end
  b:set_from_screen(xb, yb)
  r:set_from_points(a, b)
  return r
end
local read_double
read_double = function(bytes)
  local sign = 1
  local mantissa = bytes[2] % 2 ^ 4
  for i = 3, 8 do
    mantissa = mantissa * 256 + bytes[i]
  end
  if bytes[1] > 127 then
    sign = -1
  end
  local exponent = (bytes[1] % 128) * 2 ^ 4 + math.floor(bytes[2] / 2 ^ 4)
  if exponent == 0 then
    return 0
  end
  mantissa = (math.ldexp(mantissa, -52) + 1) * sign
  return math.ldexp(mantissa, exponent - 1023)
end
local write_double
write_double = function(num)
  local bytes = {
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  }
  if num == 0 then
    return bytes
  end
  local anum = math.abs(num)
  local mantissa, exponent = math.frexp(anum)
  exponent = exponent - 1
  mantissa = mantissa * 2 - 1
  local sign = num ~= anum and 128 or 0
  exponent = exponent + 1023
  bytes[1] = sign + math.floor(exponent / 2 ^ 4)
  mantissa = mantissa * 2 ^ 4
  local currentmantissa = math.floor(mantissa)
  mantissa = mantissa - currentmantissa
  bytes[2] = (exponent % 2 ^ 4) * 2 ^ 4 + currentmantissa
  for i = 3, 8 do
    mantissa = mantissa * 2 ^ 8
    currentmantissa = math.floor(mantissa)
    mantissa = mantissa - currentmantissa
    bytes[i] = currentmantissa
  end
  return bytes
end
local FirstpassStats
do
  local _class_0
  local duration_multiplier, fields_before_duration, fields_after_duration
  local _base_0 = {
    get_duration = function(self)
      local big_endian_binary_duration = reverse(self.binary_duration)
      return read_double(reversed_binary_duration) / duration_multiplier
    end,
    set_duration = function(self, duration)
      local big_endian_binary_duration = write_double(duration * duration_multiplier)
      self.binary_duration = reverse(big_endian_binary_duration)
    end,
    _bytes_to_string = function(self, bytes)
      return string.char(unpack(bytes))
    end,
    as_binary_string = function(self)
      local before_duration_string = self:_bytes_to_string(self.binary_data_before_duration)
      local duration_string = self:_bytes_to_string(self.binary_duration)
      local after_duration_string = self:_bytes_to_string(self.binary_data_after_duration)
      return before_duration_string .. duration_string .. after_duration_string
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, before_duration, duration, after_duration)
      self.binary_data_before_duration = before_duration
      self.binary_duration = duration
      self.binary_data_after_duration = after_duration
    end,
    __base = _base_0,
    __name = "FirstpassStats"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  duration_multiplier = 10000000.0
  fields_before_duration = 16
  fields_after_duration = 1
  self.data_before_duration_size = function(self)
    return fields_before_duration * 8
  end
  self.data_after_duration_size = function(self)
    return fields_after_duration * 8
  end
  self.size = function(self)
    return (fields_before_duration + 1 + fields_after_duration) * 8
  end
  self.from_bytes = function(self, bytes)
    local before_duration
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _max_0 = self:data_before_duration_size()
      for _index_0 = 1, _max_0 < 0 and #bytes + _max_0 or _max_0 do
        local b = bytes[_index_0]
        _accum_0[_len_0] = b
        _len_0 = _len_0 + 1
      end
      before_duration = _accum_0
    end
    local duration
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _max_0 = self:data_before_duration_size() + 8
      for _index_0 = self:data_before_duration_size() + 1, _max_0 < 0 and #bytes + _max_0 or _max_0 do
        local b = bytes[_index_0]
        _accum_0[_len_0] = b
        _len_0 = _len_0 + 1
      end
      duration = _accum_0
    end
    local after_duration
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = self:data_before_duration_size() + 8 + 1, #bytes do
        local b = bytes[_index_0]
        _accum_0[_len_0] = b
        _len_0 = _len_0 + 1
      end
      after_duration = _accum_0
    end
    return self(before_duration, duration, after_duration)
  end
  FirstpassStats = _class_0
end
local read_logfile_into_stats_array
read_logfile_into_stats_array = function(logfile_path)
  local file = assert(io.open(logfile_path, "rb"))
  local logfile_string = base64_decode(file:read())
  file:close()
  local stats_size = FirstpassStats:size()
  assert(logfile_string:len() % stats_size == 0)
  local stats = { }
  for offset = 1, #logfile_string, stats_size do
    local bytes = {
      logfile_string:byte(offset, offset + stats_size - 1)
    }
    assert(#bytes == stats_size)
    stats[#stats + 1] = FirstpassStats:from_bytes(bytes)
  end
  return stats
end
local write_stats_array_to_logfile
write_stats_array_to_logfile = function(stats_array, logfile_path)
  local file = assert(io.open(logfile_path, "wb"))
  local logfile_string = ""
  for _index_0 = 1, #stats_array do
    local stat = stats_array[_index_0]
    logfile_string = logfile_string .. stat:as_binary_string()
  end
  file:write(base64_encode(logfile_string))
  return file:close()
end
local vp8_patch_logfile
vp8_patch_logfile = function(logfile_path, encode_total_duration)
  local stats_array = read_logfile_into_stats_array(logfile_path)
  local average_duration = encode_total_duration / (#stats_array - 1)
  for i = 1, #stats_array - 1 do
    stats_array[i]:set_duration(average_duration)
  end
  stats_array[#stats_array]:set_duration(encode_total_duration)
  return write_stats_array_to_logfile(stats_array, logfile_path)
end
local hosts = {
  catbox = {
    id = "catbox",
    label = "catbox.moe",
    url = "https://catbox.moe/user/api.php",
    time = nil
  },
  litterbox = {
    id = "litterbox",
    label = "litterbox.catbox.moe",
    url = "https://litterbox.catbox.moe/resources/internals/api.php",
    time = function()
      return options.litterbox_time
    end
  }
}
local get_upload_host
get_upload_host = function(id)
  return hosts[id] or hosts.catbox
end
local upload_host_possible_values
upload_host_possible_values = function()
  return {
    {
      "catbox",
      "catbox.moe"
    },
    {
      "litterbox",
      "litterbox.catbox.moe"
    }
  }
end
local upload_available = nil
local is_upload_available
is_upload_available = function()
  if upload_available == nil then
    local res = utils.subprocess({
      args = {
        options.upload_curl_path,
        "--version"
      },
      playback_only = false
    })
    upload_available = res ~= nil and res.status == 0
  end
  return upload_available
end
local escape_form_path
escape_form_path = function(path)
  return path:gsub("([,;])", "\\%1")
end
local build_upload_args
build_upload_args = function(path, host_id, response_path, progress_path)
  local host = get_upload_host(host_id)
  local args = {
    options.upload_curl_path,
    "-#",
    "-S",
    "-o",
    response_path,
    "--stderr",
    progress_path,
    "-w",
    "%{http_code}"
  }
  append(args, {
    "-F",
    "reqtype=fileupload"
  })
  local time = host.time
  if type(time) == "function" then
    time = time()
  end
  if time and time ~= "" then
    append(args, {
      "-F",
      "time=" .. tostring(time)
    })
  end
  if host.id == "catbox" and options.catbox_userhash ~= "" then
    append(args, {
      "-F",
      "userhash=" .. tostring(options.catbox_userhash)
    })
  end
  append(args, {
    "-F",
    "fileToUpload=@" .. tostring(escape_form_path(path))
  })
  append(args, {
    host.url
  })
  return args
end
local read_file
read_file = function(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end
local is_macos = file_exists("/Applications") and not is_windows
local copy_to_clipboard
copy_to_clipboard = function(text)
  local ok, written = pcall(function()
    return mp.set_property("clipboard/text", text)
  end)
  if ok and written then
    return true
  end
  local candidates = { }
  if is_windows then
    candidates = {
      {
        "clip"
      }
    }
  elseif is_macos then
    candidates = {
      {
        "pbcopy"
      }
    }
  else
    candidates = {
      {
        "wl-copy"
      },
      {
        "xclip",
        "-selection",
        "clipboard"
      },
      {
        "xsel",
        "--clipboard",
        "--input"
      }
    }
  end
  for _index_0 = 1, #candidates do
    local args = candidates[_index_0]
    local handle = mp.command_native_async({
      name = "subprocess",
      args = args,
      stdin_data = text,
      playback_only = false
    }, (function()
      return nil
    end))
    if handle then
      return true
    end
  end
  return false
end
local open_url
open_url = function(url)
  if is_windows then
    return utils.subprocess_detached({
      args = {
        "cmd",
        "/c",
        "start",
        "",
        url
      }
    })
  elseif is_macos then
    return utils.subprocess_detached({
      args = {
        "open",
        url
      }
    })
  else
    return utils.subprocess_detached({
      args = {
        "xdg-open",
        url
      }
    })
  end
end
local formats = { }
local Format
do
  local _class_0
  local _base_0 = {
    getPreFilters = function(self)
      return { }
    end,
    getPostFilters = function(self)
      return { }
    end,
    getFlags = function(self)
      return { }
    end,
    getCodecFlags = function(self)
      local codecs = { }
      if self.videoCodec ~= "" then
        codecs[#codecs + 1] = "--ovc=" .. tostring(self.videoCodec)
      end
      if self.audioCodec ~= "" then
        codecs[#codecs + 1] = "--oac=" .. tostring(self.audioCodec)
      end
      return codecs
    end,
    postCommandModifier = function(self, command, region, times)
      return command
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "Basic"
      self.supportsTwopass = true
      self.videoCodec = ""
      self.audioCodec = ""
      self.outputExtension = ""
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "Format"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Format = _class_0
end
local RawVideo
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getColorspace = function(self)
      local csp = mp.get_property("colormatrix")
      local _exp_0 = csp
      if "bt.601" == _exp_0 then
        return "bt601"
      elseif "bt.709" == _exp_0 then
        return "bt709"
      elseif "bt.2020" == _exp_0 then
        return "bt2020"
      elseif "smpte-240m" == _exp_0 then
        return "smpte240m"
      else
        msg.info("Warning, unknown colorspace " .. tostring(csp) .. " detected, using bt.601.")
        return "bt601"
      end
    end,
    getPostFilters = function(self)
      return {
        "format=yuv444p16",
        "lavfi-scale=in_color_matrix=" .. self:getColorspace(),
        "format=bgr24"
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "Raw"
      self.supportsTwopass = false
      self.videoCodec = "rawvideo"
      self.audioCodec = "pcm_s16le"
      self.outputExtension = "avi"
      self.acceptsBitrate = false
    end,
    __base = _base_0,
    __name = "RawVideo",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  RawVideo = _class_0
end
formats["raw"] = RawVideo()
local WebmVP8
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getPreFilters = function(self)
      local colormatrixFilter = {
        ["bt.709"] = "bt709",
        ["bt.2020"] = "bt2020",
        ["smpte-240m"] = "smpte240m"
      }
      local ret = { }
      local colormatrix = mp.get_property_native("video-params/colormatrix")
      if colormatrixFilter[colormatrix] then
        append(ret, {
          "lavfi-colormatrix=" .. tostring(colormatrixFilter[colormatrix]) .. ":bt601"
        })
      end
      return ret
    end,
    getFlags = function(self)
      return {
        "--ovcopts-add=threads=" .. tostring(options.threads),
        "--ovcopts-add=auto-alt-ref=1",
        "--ovcopts-add=lag-in-frames=25",
        "--ovcopts-add=quality=good",
        "--ovcopts-add=cpu-used=0"
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "WebM"
      self.supportsTwopass = true
      self.videoCodec = "libvpx"
      self.audioCodec = "libvorbis"
      self.outputExtension = "webm"
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "WebmVP8",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  WebmVP8 = _class_0
end
formats["webm-vp8"] = WebmVP8()
local WebmVP9
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getFlags = function(self)
      return {
        "--ovcopts-add=threads=" .. tostring(options.threads)
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "WebM (VP9)"
      self.supportsTwopass = false
      self.videoCodec = "libvpx-vp9"
      self.audioCodec = "libopus"
      self.outputExtension = "webm"
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "WebmVP9",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  WebmVP9 = _class_0
end
formats["webm-vp9"] = WebmVP9()
local AVC
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getFlags = function(self)
      return {
        "--ovcopts-add=threads=" .. tostring(options.threads)
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "AVC (h264/AAC)"
      self.supportsTwopass = true
      self.videoCodec = "libx264"
      self.audioCodec = "aac"
      self.outputExtension = "mp4"
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "AVC",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  AVC = _class_0
end
formats["avc"] = AVC()
local AVCNVENC
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getFlags = function(self)
      return {
        "--ovcopts-add=bf=0"
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "AVC (h264-NVENC/AAC)"
      self.supportsTwopass = true
      self.videoCodec = "h264_nvenc"
      self.audioCodec = "aac"
      self.outputExtension = "mp4"
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "AVCNVENC",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  AVCNVENC = _class_0
end
formats["avc-nvenc"] = AVCNVENC()
local AV1
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getFlags = function(self)
      return {
        "--ovcopts-add=threads=" .. tostring(options.threads)
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "AV1"
      self.supportsTwopass = true
      self.videoCodec = "libaom-av1"
      self.audioCodec = "aac"
      self.outputExtension = "mp4"
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "AV1",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  AV1 = _class_0
end
formats["av1"] = AV1()
local HEVC
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getFlags = function(self)
      return {
        "--ovcopts-add=threads=" .. tostring(options.threads)
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "HEVC"
      self.supportsTwopass = true
      self.videoCodec = "libx265"
      self.audioCodec = "aac"
      self.outputExtension = "mp4"
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "HEVC",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  HEVC = _class_0
end
formats["hevc"] = HEVC()
local MP3
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "MP3 (libmp3lame)"
      self.supportsTwopass = false
      self.videoCodec = ""
      self.audioCodec = "libmp3lame"
      self.outputExtension = "mp3"
      self.acceptsBitrate = true
    end,
    __base = _base_0,
    __name = "MP3",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  MP3 = _class_0
end
formats["mp3"] = MP3()
local GIF
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    postCommandModifier = function(self, command, region, times)
      local new_command = { }
      local start_ts = seconds_to_time_string(times.sourceStart, false, true)
      local end_ts = seconds_to_time_string(times.sourceEnd, false, true)
      start_ts = start_ts:gsub(":", "\\\\:")
      end_ts = end_ts:gsub(":", "\\\\:")
      local cfilter = "[in]trim=start=" .. tostring(start_ts) .. ":end=" .. tostring(end_ts) .. "[vidtmp];"
      if times.speed ~= 1 then
        cfilter = cfilter .. "[vidtmp]setpts=(PTS-" .. tostring(times.sourceStart) .. "/TB)/" .. tostring(times.speed) .. "[vidtmp];"
        cfilter = cfilter .. "[vidtmp]setpts=PTS+" .. tostring(times.sourceStart) .. "/TB[vidtmp];"
      end
      if mp.get_property("deinterlace") == "yes" then
        cfilter = cfilter .. "[vidtmp]yadif=mode=1[vidtmp];"
      end
      for _, v in ipairs(command) do
        local _continue_0 = false
        repeat
          if v:match("^%-%-vf%-add=lavfi%-scale") or v:match("^%-%-vf%-add=lavfi%-crop") or v:match("^%-%-vf%-add=fps") or v:match("^%-%-vf%-add=lavfi%-eq") then
            local n = v:gsub("^%-%-vf%-add=", ""):gsub("^lavfi%-", "")
            cfilter = cfilter .. "[vidtmp]" .. tostring(n) .. "[vidtmp];"
          else
            if v:match("^%-%-video%-rotate=90") then
              cfilter = cfilter .. "[vidtmp]transpose=1[vidtmp];"
            else
              if v:match("^%-%-video%-rotate=270") then
                cfilter = cfilter .. "[vidtmp]transpose=2[vidtmp];"
              else
                if v:match("^%-%-video%-rotate=180") then
                  cfilter = cfilter .. "[vidtmp]transpose=1[vidtmp];[vidtmp]transpose=1[vidtmp];"
                else
                  if v:match("^%-%-deinterlace=") then
                    _continue_0 = true
                    break
                  else
                    append(new_command, {
                      v
                    })
                    _continue_0 = true
                    break
                  end
                end
              end
            end
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      cfilter = cfilter .. "[vidtmp]null[out]"
      append(new_command, {
        "--vf-add=lavfi=[" .. tostring(cfilter) .. "]",
        "--vf-add=sub"
      })
      local palette_filter = "[in]split[topal][vidf];"
      palette_filter = palette_filter .. "[topal]palettegen[pal];"
      palette_filter = palette_filter .. "[vidf][pal]paletteuse=diff_mode=rectangle"
      if options.gif_dither ~= 6 then
        palette_filter = palette_filter .. ":dither=bayer:bayer_scale=" .. tostring(options.gif_dither)
      end
      palette_filter = palette_filter .. "[out]"
      append(new_command, {
        "--vf-add=lavfi=[" .. tostring(palette_filter) .. "]"
      })
      return new_command
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "GIF"
      self.supportsTwopass = false
      self.videoCodec = "gif"
      self.audioCodec = ""
      self.outputExtension = "gif"
      self.acceptsBitrate = false
      self.handlesSpeedInFilterGraph = true
      self.rendersSubtitlesInSourceTime = false
    end,
    __base = _base_0,
    __name = "GIF",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  GIF = _class_0
end
formats["gif"] = GIF()
local WebP
do
  local _class_0
  local _parent_0 = Format
  local _base_0 = {
    getFlags = function(self)
      local qscale = math.max(0, math.min(100, 100 - (options.crf * 2.5)))
      return {
        "--ovcopts-add=threads=" .. tostring(options.threads),
        "--ovcopts-add=compression_level=6",
        "--ovcopts-add=qscale=" .. tostring(qscale),
        "--ofopts-add=loop=0"
      }
    end,
    postCommandModifier = function(self, command, region, times)
      local new_command = { }
      for _, v in ipairs(command) do
        if not v:match("^%-%-ovcopts%-add=crf=") then
          append(new_command, {
            v
          })
        end
      end
      return new_command
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.displayName = "WebP"
      self.supportsTwopass = false
      self.videoCodec = "libwebp"
      self.audioCodec = ""
      self.outputExtension = "webp"
      self.acceptsBitrate = false
    end,
    __base = _base_0,
    __name = "WebP",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  WebP = _class_0
end
formats["webp"] = WebP()
local Page
do
  local _class_0
  local _base_0 = {
    add_keybinds = function(self)
      if not self.keybinds then
        return 
      end
      for key, func in pairs(self.keybinds) do
        mp.add_forced_key_binding(key, key, func, {
          repeatable = true
        })
      end
    end,
    remove_keybinds = function(self)
      if not self.keybinds then
        return 
      end
      for key, _ in pairs(self.keybinds) do
        mp.remove_key_binding(key)
      end
    end,
    observe_properties = function(self)
      self.sizeCallback = function()
        return self:draw()
      end
      local properties = {
        "keepaspect",
        "video-out-params",
        "video-unscaled",
        "panscan",
        "video-zoom",
        "video-align-x",
        "video-pan-x",
        "video-align-y",
        "video-pan-y",
        "osd-width",
        "osd-height"
      }
      for _index_0 = 1, #properties do
        local p = properties[_index_0]
        mp.observe_property(p, "native", self.sizeCallback)
      end
    end,
    unobserve_properties = function(self)
      if self.sizeCallback then
        mp.unobserve_property(self.sizeCallback)
        self.sizeCallback = nil
      end
    end,
    clear = function(self)
      local window_w, window_h = mp.get_osd_size()
      mp.set_osd_ass(window_w, window_h, "")
      return mp.osd_message("", 0)
    end,
    prepare = function(self)
      return nil
    end,
    dispose = function(self)
      return nil
    end,
    show = function(self)
      if self.visible then
        return 
      end
      self.visible = true
      self:observe_properties()
      self:add_keybinds()
      self:prepare()
      self:clear()
      return self:draw()
    end,
    hide = function(self)
      if not self.visible then
        return 
      end
      self.visible = false
      self:unobserve_properties()
      self:remove_keybinds()
      self:clear()
      return self:dispose()
    end,
    setup_text = function(self, ass)
      local scale = calculate_scale_factor()
      local margin = options.margin * scale
      ass:append("{\\an7}")
      ass:pos(margin, margin)
      return ass:append("{\\fs" .. tostring(options.font_size * scale) .. "}")
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Page"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Page = _class_0
end
local EncodeWithProgress
do
  local _class_0
  local _parent_0 = Page
  local _base_0 = {
    draw = function(self)
      local progress = 100 * ((self.currentTime - self.startTime) / self.duration)
      local progressText = string.format("%d%%", progress)
      local window_w, window_h = mp.get_osd_size()
      local ass = assdraw.ass_new()
      ass:new_event()
      self:setup_text(ass)
      ass:append("Encoding (" .. tostring(bold(progressText)) .. ")\\N")
      return mp.set_osd_ass(window_w, window_h, ass.text)
    end,
    parseLine = function(self, line)
      local matchTime = string.match(line, "Encode time[-]pos: ([0-9.]+)")
      local matchExit = string.match(line, "Exiting... [(]([%a ]+)[)]")
      if matchTime == nil and matchExit == nil then
        return 
      end
      if matchTime ~= nil and tonumber(matchTime) > self.currentTime then
        self.currentTime = tonumber(matchTime)
      end
      if matchExit ~= nil then
        self.finished = true
        self.finishedReason = matchExit
      end
    end,
    startEncode = function(self, command_line)
      local copy_command_line
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #command_line do
          local arg = command_line[_index_0]
          _accum_0[_len_0] = arg
          _len_0 = _len_0 + 1
        end
        copy_command_line = _accum_0
      end
      append(copy_command_line, {
        '--term-status-msg=Encode time-pos: ${=time-pos}\\n'
      })
      self:show()
      local processFd = run_subprocess_popen(copy_command_line)
      for line in processFd:lines() do
        msg.verbose(string.format('%q', line))
        self:parseLine(line)
        self:draw()
      end
      processFd:close()
      self:hide()
      if self.finishedReason == "End of file" then
        return true
      end
      return false
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, startTime, endTime)
      self.startTime = startTime
      self.endTime = endTime
      self.duration = endTime - startTime
      self.currentTime = startTime
    end,
    __base = _base_0,
    __name = "EncodeWithProgress",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  EncodeWithProgress = _class_0
end
local UploadWithProgress
do
  local _class_0
  local _parent_0 = Page
  local _base_0 = {
    prepare = function(self)
      return self:startUpload()
    end,
    dispose = function(self)
      self:stopTimer()
      if self.responsePath then
        os.remove(self.responsePath)
      end
      if self.progressPath then
        return os.remove(self.progressPath)
      end
    end,
    stopTimer = function(self)
      if self.timer then
        self.timer:kill()
        self.timer = nil
      end
    end,
    startUpload = function(self)
      self.state = "uploading"
      self.percent = 0
      self.finished = false
      self.cancelled = false
      self.host = get_upload_host(options.upload_host)
      local file = io.open(self.progressPath, "w")
      if file then
        file:close()
      end
      local args = build_upload_args(self.path, options.upload_host, self.responsePath, self.progressPath)
      self.timer = mp.add_periodic_timer(0.2, (function()
        local _base_1 = self
        local _fn_0 = _base_1.pollProgress
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
      self.handle = mp.command_native_async({
        name = "subprocess",
        args = args,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = false,
        capture_size = 128
      }, (function()
        local _base_1 = self
        local _fn_0 = _base_1.onFinished
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
    end,
    pollProgress = function(self)
      if self.state ~= "uploading" then
        return 
      end
      local content = read_file(self.progressPath)
      if not content or content == "" then
        return 
      end
      local percent = nil
      for match in content:gmatch("(%d+%.?%d*)%%") do
        percent = tonumber(match)
      end
      if percent and math.floor(percent) ~= self.percent then
        self.percent = math.floor(percent)
        return self:draw()
      end
    end,
    onFinished = function(self, success, result, error)
      if self.finished then
        return 
      end
      self.finished = true
      self:stopTimer()
      if self.cancelled then
        emit_event("upload-finished", "cancelled")
        self:finish("cancelled")
        return 
      end
      local httpCode = result and tonumber(result.stdout)
      local response = trim(read_file(self.responsePath) or "")
      local uploadOk = success and result and result.status == 0 and httpCode and httpCode >= 200 and httpCode < 300 and response:match("^https?://")
      if uploadOk then
        self.url = response
        self.state = "done"
        pcall(function()
          return copy_to_clipboard(self.url)
        end)
        if options.open_after_upload then
          pcall(function()
            return open_url(self.url)
          end)
        end
      else
        self.state = "failed"
        self.errorMessage = response
        if self.errorMessage == "" then
          self.errorMessage = (result and result.error_string) or tostring(error) or "upload failed"
        end
        self.errorMessage = self.errorMessage:gsub("%s+", " "):sub(1, 300)
      end
      emit_event("upload-finished", self.state)
      return self:draw()
    end,
    onEscape = function(self)
      if self.state == "uploading" then
        self.cancelled = true
        self:stopTimer()
        if self.handle then
          mp.abort_async_command(self.handle)
        end
        return mp.add_timeout(0.5, (function()
          if not self.closing then
            return self:finish("cancelled")
          end
        end))
      else
        return self:finish(self.state)
      end
    end,
    copyAgain = function(self)
      if self.state == "done" and self.url then
        copy_to_clipboard(self.url)
        return message("Link copied to clipboard.")
      end
    end,
    openSomething = function(self)
      if self.state == "done" and self.url then
        return open_url(self.url)
      elseif self.state == "failed" then
        return self:finish("options")
      end
    end,
    retry = function(self)
      if self.state == "failed" then
        return self:startUpload()
      end
    end,
    finish = function(self, state)
      if self.closing then
        return 
      end
      self.closing = true
      self:hide()
      return self:callback(state)
    end,
    draw = function(self)
      local window_w, window_h = mp.get_osd_size()
      local ass = assdraw.ass_new()
      ass:new_event()
      self:setup_text(ass)
      if self.state == "uploading" then
        ass:append("Uploading (" .. tostring(bold(tostring(self.percent) .. "%")) .. ")\\N")
        ass:append(tostring(self.filename) .. "\\N")
        ass:append(tostring(self.sizeText) .. " to " .. tostring(self.host.label) .. "\\N\\N")
        ass:append(tostring(bold('ESC:')) .. " cancel upload\\N")
      elseif self.state == "done" then
        ass:append(tostring(bold('Upload complete')) .. "\\N\\N")
        ass:append(tostring(self.url) .. "\\N")
        ass:append("Link copied to clipboard.\\N\\N")
        ass:append(tostring(bold('c:')) .. " copy link again\\N")
        ass:append(tostring(bold('o:')) .. " open in browser\\N")
        ass:append(tostring(bold('ESC:')) .. " close\\N")
      elseif self.state == "failed" then
        ass:append(tostring(bold('Upload failed')) .. "\\N\\N")
        ass:append(tostring(self.errorMessage) .. "\\N")
        ass:append("The clip is still saved locally.\\N\\N")
        ass:append(tostring(bold('r:')) .. " retry upload\\N")
        ass:append(tostring(bold('o:')) .. " change upload options\\N")
        ass:append(tostring(bold('ESC:')) .. " close\\N")
      end
      return mp.set_osd_ass(window_w, window_h, ass.text)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, callback, path)
      self.callback = callback
      self.path = path
      local _
      _, self.filename = utils.split_path(path)
      local info = utils.file_info(path)
      self.sizeText = info and string.format("%.1f MB", info.size / 1000000) or "unknown size"
      self.responsePath = os.tmpname()
      self.progressPath = os.tmpname()
      self.state = "uploading"
      self.percent = 0
      self.finished = false
      self.cancelled = false
      self.keybinds = {
        ["ESC"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.onEscape
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["c"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.copyAgain
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["o"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.openSomething
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["r"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.retry
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      }
    end,
    __base = _base_0,
    __name = "UploadWithProgress",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  UploadWithProgress = _class_0
end
local get_active_tracks
get_active_tracks = function()
  local accepted = {
    video = true,
    audio = not mp.get_property_bool("mute"),
    sub = mp.get_property_bool("sub-visibility")
  }
  local active = {
    video = { },
    audio = { },
    sub = { }
  }
  for _, track in ipairs(mp.get_property_native("track-list")) do
    if track["selected"] and accepted[track["type"]] then
      local count = #active[track["type"]]
      active[track["type"]][count + 1] = track
    end
  end
  return active
end
local filter_tracks_supported_by_format
filter_tracks_supported_by_format = function(active_tracks, format)
  local has_video_codec = format.videoCodec ~= ""
  local has_audio_codec = format.audioCodec ~= ""
  local supported = {
    video = has_video_codec and active_tracks["video"] or { },
    audio = has_audio_codec and active_tracks["audio"] or { },
    sub = has_video_codec and active_tracks["sub"] or { }
  }
  return supported
end
local append_track
append_track = function(out, track)
  local external_flag = {
    ["audio"] = "audio-file",
    ["sub"] = "sub-file"
  }
  local internal_flag = {
    ["video"] = "vid",
    ["audio"] = "aid",
    ["sub"] = "sid"
  }
  if track['external'] and string.len(track['external-filename']) <= 2048 then
    return append(out, {
      "--" .. tostring(external_flag[track['type']]) .. "=" .. tostring(track['external-filename'])
    })
  else
    return append(out, {
      "--" .. tostring(internal_flag[track['type']]) .. "=" .. tostring(track['id'])
    })
  end
end
local append_audio_tracks
append_audio_tracks = function(out, tracks)
  local internal_tracks = { }
  for _index_0 = 1, #tracks do
    local track = tracks[_index_0]
    if track['external'] then
      append_track(out, track)
    else
      append(internal_tracks, {
        track
      })
    end
  end
  if #internal_tracks > 1 then
    local filter_string = ""
    for _index_0 = 1, #internal_tracks do
      local track = internal_tracks[_index_0]
      filter_string = filter_string .. "[aid" .. tostring(track['id']) .. "]"
    end
    filter_string = filter_string .. "amix[ao]"
    return append(out, {
      "--lavfi-complex=" .. tostring(filter_string)
    })
  else
    if #internal_tracks == 1 then
      return append_track(out, internal_tracks[1])
    end
  end
end
local get_scale_filters
get_scale_filters = function()
  local filters = { }
  if options.force_square_pixels then
    append(filters, {
      "lavfi-scale=iw*sar:ih"
    })
  end
  if options.scale_height > 0 then
    append(filters, {
      "lavfi-scale=-2:" .. tostring(options.scale_height)
    })
  end
  return filters
end
local get_fps_filters
get_fps_filters = function()
  if options.fps > 0 then
    return {
      "fps=" .. tostring(options.fps)
    }
  end
  return { }
end
local get_contrast_brightness_and_saturation_filters
get_contrast_brightness_and_saturation_filters = function()
  local mpv_brightness = mp.get_property_number("brightness", 0)
  local mpv_contrast = mp.get_property_number("contrast", 0)
  local mpv_saturation = mp.get_property_number("saturation", 0)
  if mpv_brightness == 0 and mpv_contrast == 0 and mpv_saturation == 0 then
    return { }
  end
  local eq_saturation = (mpv_saturation + 100) / 100.0
  local eq_contrast = (mpv_contrast + 100) / 100.0
  local eq_brightness = (mpv_brightness / 50.0 + eq_contrast - 1) / 2.0
  return {
    "lavfi-eq=contrast=" .. tostring(eq_contrast) .. ":saturation=" .. tostring(eq_saturation) .. ":brightness=" .. tostring(eq_brightness)
  }
end
local append_property
append_property = function(out, property_name, option_name)
  option_name = option_name or property_name
  local prop = mp.get_property(property_name)
  if prop and prop ~= "" then
    return append(out, {
      "--" .. tostring(option_name) .. "=" .. tostring(prop)
    })
  end
end
local append_list_options
append_list_options = function(out, property_name, option_prefix)
  option_prefix = option_prefix or property_name
  local prop = mp.get_property_native(property_name)
  if prop then
    for _index_0 = 1, #prop do
      local value = prop[_index_0]
      append(out, {
        "--" .. tostring(option_prefix) .. "-append=" .. tostring(value)
      })
    end
  end
end
local get_playback_options
get_playback_options = function()
  local ret = { }
  append_property(ret, "video-rotate")
  append_property(ret, "ytdl-format")
  append_property(ret, "deinterlace")
  return ret
end
local get_sub_options
get_sub_options = function()
  local ret = { }
  append_property(ret, "sub-ass-override")
  append_property(ret, "sub-ass-style-overrides")
  append_property(ret, "sub-ass-use-video-data")
  append_property(ret, "sub-auto")
  append_property(ret, "sub-pos")
  append_property(ret, "sub-scale")
  append_property(ret, "sub-font")
  append_property(ret, "sub-font-size")
  append_property(ret, "sub-bold")
  append_property(ret, "sub-italic")
  append_property(ret, "sub-color")
  append_property(ret, "sub-back-color")
  append_property(ret, "sub-border-color")
  append_property(ret, "sub-border-size")
  append_property(ret, "sub-shadow-color")
  append_property(ret, "sub-shadow-offset")
  append_property(ret, "sub-use-margins")
  append_property(ret, "sub-margin-x")
  append_property(ret, "sub-margin-y")
  append_property(ret, "sub-align-x")
  append_property(ret, "sub-align-y")
  append_property(ret, "sub-spacing")
  append_property(ret, "sub-justify")
  append_property(ret, "sub-gauss")
  append_property(ret, "sub-gray")
  return ret
end
local encode_times
encode_times = function(startTime, endTime, speed)
  local outputDuration = (endTime - startTime) / speed
  return {
    sourceStart = startTime,
    sourceEnd = endTime,
    speed = speed,
    encoderStart = startTime,
    encoderEnd = startTime + outputDuration,
    outputDuration = outputDuration
  }
end
local get_speed_video_flags
get_speed_video_flags = function(times)
  if times.speed == 1 then
    return { }
  end
  return {
    "--vf-add=trim=start=" .. tostring(times.sourceStart) .. ":end=" .. tostring(times.sourceEnd),
    "--vf-add=setpts=(PTS-" .. tostring(times.sourceStart) .. "/TB)/" .. tostring(times.speed),
    "--vf-add=setpts=PTS+" .. tostring(times.sourceStart) .. "/TB"
  }
end
local get_speed_audio_flags
get_speed_audio_flags = function(times)
  if times.speed == 1 then
    return { }
  end
  local atempo = { }
  local tempo = times.speed
  while tempo < 0.5 do
    atempo[#atempo + 1] = "atempo=0.5"
    tempo = tempo * 2
  end
  atempo[#atempo + 1] = "atempo=" .. tostring(tempo)
  return {
    "--af-add=atrim=start=" .. tostring(times.sourceStart) .. ":end=" .. tostring(times.sourceEnd),
    "--af-add=asetpts=(PTS-" .. tostring(times.sourceStart) .. "/TB)/" .. tostring(times.speed),
    "--af-add=" .. tostring(table.concat(atempo, ",")),
    "--af-add=asetpts=PTS+" .. tostring(times.sourceStart) .. "/TB"
  }
end
local get_sub_speed_flags
get_sub_speed_flags = function(times, source_time)
  if source_time == nil then
    source_time = false
  end
  local sub_speed = mp.get_property_number("sub-speed", 1)
  local sub_delay = mp.get_property_number("sub-delay", 0)
  if times.speed ~= 1 and not source_time then
    sub_speed = sub_speed * (1 / times.speed)
    sub_delay = sub_delay / times.speed + times.sourceStart - times.sourceStart / times.speed
  end
  local ret = { }
  if sub_speed ~= 1 then
    append(ret, {
      "--sub-speed=" .. tostring(sub_speed)
    })
  end
  if sub_delay ~= 0 then
    append(ret, {
      "--sub-delay=" .. tostring(sub_delay)
    })
  end
  return ret
end
local get_metadata_flags
get_metadata_flags = function()
  local title = mp.get_property("filename/no-ext")
  return {
    "--oset-metadata=title=%" .. tostring(string.len(title)) .. "%" .. tostring(title)
  }
end
local quote_filter_param
quote_filter_param = function(value)
  return "%" .. tostring(string.len(value)) .. "%" .. tostring(value)
end
local serialize_lavfi_filter
serialize_lavfi_filter = function(filter)
  local name = filter["name"]
  local params = filter["params"] or { }
  if name == "lavfi" then
    local graph = params["graph"]
    return graph and tostring(name) .. "=[" .. tostring(graph) .. "]" or name
  end
  local positional = { }
  local named = { }
  for key, value in pairs(params) do
    local index = key:match("^@(%d+)$")
    if index then
      positional[tonumber(index) + 1] = value
    else
      named[key] = value
    end
  end
  local args = { }
  if #positional > 0 then
    for _index_0 = 1, #positional do
      local value = positional[_index_0]
      append(args, {
        value
      })
    end
  else
    local keys
    do
      local _accum_0 = { }
      local _len_0 = 1
      for key in pairs(named) do
        _accum_0[_len_0] = key
        _len_0 = _len_0 + 1
      end
      keys = _accum_0
    end
    table.sort(keys)
    for _index_0 = 1, #keys do
      local key = keys[_index_0]
      append(args, {
        tostring(key) .. "=" .. tostring(named[key])
      })
    end
  end
  return #args > 0 and tostring(name) .. "=" .. tostring(table.concat(args, ":")) or name
end
local apply_current_filters
apply_current_filters = function(filters)
  local vf = mp.get_property_native("vf")
  msg.verbose("apply_current_filters: got " .. tostring(#vf) .. " currently applied.")
  for _index_0 = 1, #vf do
    local _continue_0 = false
    repeat
      local filter = vf[_index_0]
      msg.verbose("apply_current_filters: filter name: " .. tostring(filter['name']))
      if filter["enabled"] == false then
        _continue_0 = true
        break
      end
      local str = filter["name"]
      local params = filter["params"] or { }
      if str == "lavfi" or str:match("^lavfi%-") then
        str = serialize_lavfi_filter(filter)
      else
        for k, v in pairs(params) do
          str = str .. ":" .. tostring(k) .. "=" .. tostring(quote_filter_param(v))
        end
      end
      append(filters, {
        str
      })
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
local get_video_filters
get_video_filters = function(format, region)
  local filters = { }
  append(filters, format:getPreFilters())
  if options.apply_current_filters then
    apply_current_filters(filters)
  end
  if region and region:is_valid() then
    append(filters, {
      "lavfi-crop=" .. tostring(region.w) .. ":" .. tostring(region.h) .. ":" .. tostring(region.x) .. ":" .. tostring(region.y)
    })
  end
  append(filters, get_scale_filters())
  append(filters, get_fps_filters())
  if options.apply_current_filters then
    append(filters, get_contrast_brightness_and_saturation_filters())
  end
  append(filters, format:getPostFilters())
  return filters
end
local get_video_encode_flags
get_video_encode_flags = function(format, region, times)
  local flags = { }
  append(flags, get_playback_options())
  append(flags, get_sub_options())
  local filters = get_video_filters(format, region)
  for _index_0 = 1, #filters do
    local f = filters[_index_0]
    append(flags, {
      "--vf-add=" .. tostring(f)
    })
  end
  if not format.handlesSpeedInFilterGraph then
    append(flags, get_speed_video_flags(times))
  end
  append(flags, get_sub_speed_flags(times, format.rendersSubtitlesInSourceTime))
  return flags
end
local calculate_bitrate
calculate_bitrate = function(active_tracks, format, length)
  if format.videoCodec == "" then
    return nil, options.target_filesize * 8 / length
  end
  local video_kilobits = options.target_filesize * 8
  local audio_kilobits = nil
  local has_audio_track = #active_tracks["audio"] > 0
  if options.strict_filesize_constraint and has_audio_track then
    audio_kilobits = length * options.strict_audio_bitrate
    video_kilobits = video_kilobits - audio_kilobits
  end
  local video_bitrate = math.floor(video_kilobits / length)
  local audio_bitrate = audio_kilobits and math.floor(audio_kilobits / length) or nil
  return video_bitrate, audio_bitrate
end
local find_path
find_path = function(startTime, endTime)
  local path = mp.get_property('path')
  if not path then
    return nil, nil, nil, nil, nil
  end
  local is_stream = not file_exists(path)
  local is_temporary = false
  if is_stream then
    if mp.get_property('file-format') == 'hls' then
      path = utils.join_path(parse_directory('~'), 'cache_dump.ts')
      mp.command_native({
        'dump_cache',
        seconds_to_time_string(startTime, false, true),
        seconds_to_time_string(endTime + 5, false, true),
        path
      })
      endTime = endTime - startTime
      startTime = 0
      is_temporary = true
    end
  end
  return path, is_stream, is_temporary, startTime, endTime
end
local check_encoder
check_encoder = function()
  local result = utils.subprocess({
    args = {
      "mpv",
      "--no-config",
      "--version"
    },
    cancellable = false
  })
  if result.status == 0 then
    return true
  end
  local explanation = "Cannot start the mpv encoder. Add the folder containing mpv to PATH, then restart the player. See README: Encoder executable."
  if result.status and result.status > 0 then
    explanation = "The mpv encoder failed its startup check. Run mpv --version and check the logs for details."
  end
  msg.error(explanation)
  msg.error("Encoder startup check: ", result.error or "", result.stderr or "", result.stdout or "")
  message(explanation, 10)
  emit_event("encode-finished", "fail", explanation)
  return false
end
local encode
encode = function(region, startTime, endTime, onDone)
  local format = formats[options.output_format]
  if not check_encoder() then
    if onDone then
      onDone(false)
    end
    return 
  end
  local originalStartTime = startTime
  local originalEndTime = endTime
  local path, is_stream, is_temporary
  path, is_stream, is_temporary, startTime, endTime = find_path(startTime, endTime)
  if not path then
    message("No file is being played")
    if onDone then
      onDone(false)
    end
    return 
  end
  local speed = mp.get_property_native("speed") or 1
  local times = encode_times(startTime, endTime, speed)
  local command = {
    "mpv",
    path,
    "--start=" .. seconds_to_time_string(times.encoderStart, false, true),
    "--end=" .. seconds_to_time_string(times.encoderEnd, false, true),
    "--loop-file=no",
    "--no-pause"
  }
  append(command, format:getCodecFlags())
  local active_tracks = get_active_tracks()
  local supported_active_tracks = filter_tracks_supported_by_format(active_tracks, format)
  for track_type, tracks in pairs(supported_active_tracks) do
    if track_type == "audio" then
      append_audio_tracks(command, tracks)
    else
      for _index_0 = 1, #tracks do
        local track = tracks[_index_0]
        append_track(command, track)
      end
    end
  end
  for track_type, tracks in pairs(supported_active_tracks) do
    local _continue_0 = false
    repeat
      if #tracks > 0 then
        _continue_0 = true
        break
      end
      local _exp_0 = track_type
      if "video" == _exp_0 then
        append(command, {
          "--vid=no"
        })
      elseif "audio" == _exp_0 then
        append(command, {
          "--aid=no"
        })
      elseif "sub" == _exp_0 then
        append(command, {
          "--sid=no"
        })
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  if format.videoCodec ~= "" then
    append(command, get_video_encode_flags(format, region, times))
  end
  if format.audioCodec ~= "" then
    append(command, get_speed_audio_flags(times))
  end
  append(command, format:getFlags())
  if options.write_filename_on_metadata then
    append(command, get_metadata_flags())
  end
  if format.acceptsBitrate then
    if options.target_filesize > 0 then
      local length = times.outputDuration
      local video_bitrate, audio_bitrate = calculate_bitrate(supported_active_tracks, format, length)
      if video_bitrate then
        append(command, {
          "--ovcopts-add=b=" .. tostring(video_bitrate) .. "k"
        })
      end
      if audio_bitrate then
        append(command, {
          "--oacopts-add=b=" .. tostring(audio_bitrate) .. "k"
        })
      end
      if options.strict_filesize_constraint then
        local type = format.videoCodec ~= "" and "ovc" or "oac"
        local strict_bitrate = format.videoCodec ~= "" and video_bitrate or audio_bitrate
        append(command, {
          "--" .. tostring(type) .. "opts-add=minrate=" .. tostring(strict_bitrate) .. "k",
          "--" .. tostring(type) .. "opts-add=maxrate=" .. tostring(strict_bitrate) .. "k"
        })
      end
    else
      local type = format.videoCodec ~= "" and "ovc" or "oac"
      append(command, {
        "--" .. tostring(type) .. "opts-add=b=0"
      })
    end
  end
  for token in string.gmatch(options.additional_flags, "[^%s]+") do
    command[#command + 1] = token
  end
  if not options.strict_filesize_constraint then
    for token in string.gmatch(options.non_strict_additional_flags, "[^%s]+") do
      command[#command + 1] = token
    end
    if options.crf >= 0 then
      append(command, {
        "--ovcopts-add=crf=" .. tostring(options.crf)
      })
    end
  end
  local dir = ""
  if is_stream then
    dir = parse_directory("~")
  else
    local _
    dir, _ = utils.split_path(path)
  end
  if options.output_directory ~= "" then
    dir = parse_directory(options.output_directory)
  end
  local formatted_filename = format_filename(originalStartTime, originalEndTime, format, dir)
  local out_path = utils.join_path(dir, formatted_filename)
  append(command, {
    "--o=" .. tostring(out_path)
  })
  emit_event("encode-started")
  local constant_quality_x26x = options.target_filesize <= 0 and (format.videoCodec == "libx264" or format.videoCodec == "libx265")
  if options.twopass and format.supportsTwopass and not constant_quality_x26x and not is_stream then
    local first_pass_cmdline
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #command do
        local arg = command[_index_0]
        _accum_0[_len_0] = arg
        _len_0 = _len_0 + 1
      end
      first_pass_cmdline = _accum_0
    end
    append(first_pass_cmdline, {
      "--ovcopts-add=flags=+pass1"
    })
    message("Starting first pass...")
    msg.verbose("First-pass command line: ", table.concat(first_pass_cmdline, " "))
    local res = run_subprocess({
      args = first_pass_cmdline,
      cancellable = false
    })
    if not res then
      message("First pass failed! Check the logs for details.")
      emit_event("encode-finished", "fail")
      if onDone then
        onDone(false)
      end
      return 
    end
    append(command, {
      "--ovcopts-add=flags=+pass2"
    })
    if format.videoCodec == "libvpx" then
      msg.verbose("Patching libvpx pass log file...")
      vp8_patch_logfile(get_pass_logfile_path(out_path), times.outputDuration)
    end
  end
  command = format:postCommandModifier(command, region, times)
  msg.info("Encoding to", out_path)
  msg.verbose("Command line:", table.concat(command, " "))
  if options.run_detached and not onDone then
    message("Started encode, process was detached.")
    return utils.subprocess_detached({
      args = command
    })
  else
    local res = false
    if not should_display_progress() then
      message("Started encode...")
      res = run_subprocess({
        args = command,
        cancellable = false
      })
    else
      local ewp = EncodeWithProgress(times.encoderStart, times.encoderEnd)
      res = ewp:startEncode(command)
    end
    if res then
      message("Encoded successfully! Saved to\\N" .. tostring(bold(out_path)))
      emit_event("encode-finished", "success")
      if options.completion_command ~= "" then
        mp.command(options.completion_command:gsub("%%{output}", out_path))
      end
      if onDone then
        onDone(true, out_path)
      end
    else
      message("Encode failed! Check the logs for details.")
      emit_event("encode-finished", "fail")
      if onDone then
        onDone(false)
      end
    end
    os.remove(get_pass_logfile_path(out_path))
    os.remove("x264_2pass.log")
    os.remove("x264_2pass.log.mbtree")
    if is_temporary then
      return os.remove(path)
    end
  end
end
local CropPage
do
  local _class_0
  local _parent_0 = Page
  local _base_0 = {
    show = function(self)
      _class_0.__parent.show(self)
      return emit_event("show-crop-page")
    end,
    reset = function(self)
      local dimensions = get_video_dimensions()
      local xa, ya
      do
        local _obj_0 = dimensions.top_left
        xa, ya = _obj_0.x, _obj_0.y
      end
      self.pointA:set_from_screen(xa, ya)
      local xb, yb
      do
        local _obj_0 = dimensions.bottom_right
        xb, yb = _obj_0.x, _obj_0.y
      end
      self.pointB:set_from_screen(xb, yb)
      if self.visible then
        return self:draw()
      end
    end,
    setPointA = function(self)
      local posX, posY = mp.get_mouse_pos()
      self.pointA:set_from_screen(posX, posY)
      emit_event("crop-point-a", tostring(self.pointA.x), tostring(self.pointA.y))
      if self.visible then
        return self:draw()
      end
    end,
    setPointB = function(self)
      local posX, posY = mp.get_mouse_pos()
      self.pointB:set_from_screen(posX, posY)
      emit_event("crop-point-b", tostring(self.pointB.x), tostring(self.pointB.y))
      if self.visible then
        return self:draw()
      end
    end,
    cancel = function(self)
      self:hide()
      return self.callback(false, nil)
    end,
    finish = function(self)
      local region = Region()
      region:set_from_points(self.pointA, self.pointB)
      self:hide()
      return self.callback(true, region)
    end,
    draw_box = function(self, ass)
      local region = Region()
      region:set_from_points(self.pointA:to_screen(), self.pointB:to_screen())
      local d = get_video_dimensions()
      ass:new_event()
      ass:append("{\\an7}")
      ass:pos(0, 0)
      ass:append('{\\bord0}')
      ass:append('{\\shad0}')
      ass:append('{\\c&H000000&}')
      ass:append('{\\alpha&H77}')
      ass:draw_start()
      ass:rect_cw(d.top_left.x, d.top_left.y, region.x, region.y + region.h)
      ass:rect_cw(region.x, d.top_left.y, d.bottom_right.x, region.y)
      ass:rect_cw(d.top_left.x, region.y + region.h, region.x + region.w, d.bottom_right.y)
      ass:rect_cw(region.x + region.w, region.y, d.bottom_right.x, d.bottom_right.y)
      return ass:draw_stop()
    end,
    draw = function(self)
      local window = { }
      window.w, window.h = mp.get_osd_size()
      local ass = assdraw.ass_new()
      self:draw_box(ass)
      ass:new_event()
      self:setup_text(ass)
      ass:append(tostring(bold('Crop:')) .. "\\N")
      ass:append(tostring(bold('1:')) .. " change point A (" .. tostring(self.pointA.x) .. ", " .. tostring(self.pointA.y) .. ")\\N")
      ass:append(tostring(bold('2:')) .. " change point B (" .. tostring(self.pointB.x) .. ", " .. tostring(self.pointB.y) .. ")\\N")
      ass:append(tostring(bold('r:')) .. " reset to whole screen\\N")
      ass:append(tostring(bold('ESC:')) .. " cancel crop\\N")
      local width, height = math.abs(self.pointA.x - self.pointB.x), math.abs(self.pointA.y - self.pointB.y)
      ass:append(tostring(bold('ENTER:')) .. " confirm crop (" .. tostring(width) .. "x" .. tostring(height) .. ")\\N")
      return mp.set_osd_ass(window.w, window.h, ass.text)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, callback, region)
      self.pointA = VideoPoint()
      self.pointB = VideoPoint()
      self.keybinds = {
        ["1"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.setPointA
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["2"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.setPointB
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["r"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.reset
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["ESC"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.cancel
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["ENTER"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.finish
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      }
      self:reset()
      self.callback = callback
      if region and region:is_valid() then
        self.pointA.x = region.x
        self.pointA.y = region.y
        self.pointB.x = region.x + region.w
        self.pointB.y = region.y + region.h
      end
    end,
    __base = _base_0,
    __name = "CropPage",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CropPage = _class_0
end
local Option
do
  local _class_0
  local _base_0 = {
    hasPrevious = function(self)
      local _exp_0 = self.optType
      if "bool" == _exp_0 then
        return true
      elseif "int" == _exp_0 then
        if self.opts.min then
          return self.value > self.opts.min
        else
          return true
        end
      elseif "list" == _exp_0 then
        return self.value > 1
      end
    end,
    hasNext = function(self)
      local _exp_0 = self.optType
      if "bool" == _exp_0 then
        return true
      elseif "int" == _exp_0 then
        if self.opts.max then
          return self.value < self.opts.max
        else
          return true
        end
      elseif "list" == _exp_0 then
        return self.value < #self.opts.possibleValues
      end
    end,
    leftKey = function(self)
      local _exp_0 = self.optType
      if "bool" == _exp_0 then
        self.value = not self.value
      elseif "int" == _exp_0 then
        self.value = self.value - self.opts.step
        if self.opts.min and self.opts.min > self.value then
          self.value = self.opts.min
        end
      elseif "list" == _exp_0 then
        if self.value > 1 then
          self.value = self.value - 1
        end
      end
    end,
    rightKey = function(self)
      local _exp_0 = self.optType
      if "bool" == _exp_0 then
        self.value = not self.value
      elseif "int" == _exp_0 then
        self.value = self.value + self.opts.step
        if self.opts.max and self.opts.max < self.value then
          self.value = self.opts.max
        end
      elseif "list" == _exp_0 then
        if self.value < #self.opts.possibleValues then
          self.value = self.value + 1
        end
      end
    end,
    getValue = function(self)
      local _exp_0 = self.optType
      if "bool" == _exp_0 then
        return self.value
      elseif "int" == _exp_0 then
        return self.value
      elseif "list" == _exp_0 then
        local value, _
        do
          local _obj_0 = self.opts.possibleValues[self.value]
          value, _ = _obj_0[1], _obj_0[2]
        end
        return value
      end
    end,
    setValue = function(self, value)
      local _exp_0 = self.optType
      if "bool" == _exp_0 then
        self.value = value
      elseif "int" == _exp_0 then
        self.value = value
      elseif "list" == _exp_0 then
        local set = false
        for i, possiblePair in ipairs(self.opts.possibleValues) do
          local possibleValue, _
          possibleValue, _ = possiblePair[1], possiblePair[2]
          if possibleValue == value then
            set = true
            self.value = i
            break
          end
        end
        if not set then
          return msg.warn("Tried to set invalid value " .. tostring(value) .. " to " .. tostring(self.displayText) .. " option.")
        end
      end
    end,
    getDisplayValue = function(self)
      local _exp_0 = self.optType
      if "bool" == _exp_0 then
        return self.value and "yes" or "no"
      elseif "int" == _exp_0 then
        if self.opts.altDisplayNames and self.opts.altDisplayNames[self.value] then
          return self.opts.altDisplayNames[self.value]
        else
          return tostring(self.value)
        end
      elseif "list" == _exp_0 then
        local value, displayValue
        do
          local _obj_0 = self.opts.possibleValues[self.value]
          value, displayValue = _obj_0[1], _obj_0[2]
        end
        return displayValue or value
      end
    end,
    draw = function(self, ass, selected)
      if selected then
        ass:append(tostring(bold(self.displayText)) .. ": ")
      else
        ass:append(tostring(self.displayText) .. ": ")
      end
      if self:hasPrevious() then
        ass:append("◀ ")
      end
      ass:append(self:getDisplayValue())
      if self:hasNext() then
        ass:append(" ▶")
      end
      return ass:append("\\N")
    end,
    optVisible = function(self)
      if self.visibleCheckFn == nil then
        return true
      else
        return self.visibleCheckFn()
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, optType, displayText, value, opts, visibleCheckFn)
      self.optType = optType
      self.displayText = displayText
      self.opts = opts
      self.value = 1
      self.visibleCheckFn = visibleCheckFn
      return self:setValue(value)
    end,
    __base = _base_0,
    __name = "Option"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Option = _class_0
end
local EncodeOptionsPage
do
  local _class_0
  local _parent_0 = Page
  local _base_0 = {
    getCurrentOption = function(self)
      return self.options[self.currentOption][2]
    end,
    leftKey = function(self)
      (self:getCurrentOption()):leftKey()
      return self:draw()
    end,
    rightKey = function(self)
      (self:getCurrentOption()):rightKey()
      return self:draw()
    end,
    prevOpt = function(self)
      for i = self.currentOption - 1, 1, -1 do
        if self.options[i][2]:optVisible() then
          self.currentOption = i
          break
        end
      end
      return self:draw()
    end,
    nextOpt = function(self)
      for i = self.currentOption + 1, #self.options do
        if self.options[i][2]:optVisible() then
          self.currentOption = i
          break
        end
      end
      return self:draw()
    end,
    confirmOpts = function(self)
      for _, optPair in ipairs(self.options) do
        local optName, opt
        optName, opt = optPair[1], optPair[2]
        options[optName] = opt:getValue()
      end
      self:hide()
      return self.callback(true)
    end,
    cancelOpts = function(self)
      self:hide()
      return self.callback(false)
    end,
    draw = function(self)
      local window_w, window_h = mp.get_osd_size()
      local ass = assdraw.ass_new()
      ass:new_event()
      self:setup_text(ass)
      ass:append(tostring(bold('Options:')) .. "\\N\\N")
      for i, optPair in ipairs(self.options) do
        local opt = optPair[2]
        if opt:optVisible() then
          opt:draw(ass, self.currentOption == i)
        end
      end
      ass:append("\\N▲ / ▼: navigate\\N")
      ass:append(tostring(bold('ENTER:')) .. " confirm options\\N")
      ass:append(tostring(bold('ESC:')) .. " cancel\\N")
      return mp.set_osd_ass(window_w, window_h, ass.text)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, callback)
      self.callback = callback
      self.currentOption = 1
      local scaleHeightOpts = {
        possibleValues = {
          {
            -1,
            "no"
          },
          {
            144
          },
          {
            240
          },
          {
            360
          },
          {
            480
          },
          {
            540
          },
          {
            720
          },
          {
            1080
          },
          {
            1440
          },
          {
            2160
          }
        }
      }
      local filesizeOpts = {
        step = 250,
        min = 0,
        altDisplayNames = {
          [0] = "0 (constant quality)"
        }
      }
      local crfOpts = {
        step = 1,
        min = -1,
        altDisplayNames = {
          [-1] = "disabled"
        }
      }
      local fpsOpts = {
        possibleValues = {
          {
            -1,
            "source"
          },
          {
            4
          },
          {
            8
          },
          {
            10
          },
          {
            12
          },
          {
            15
          },
          {
            16
          },
          {
            20
          },
          {
            24
          },
          {
            30
          },
          {
            48
          },
          {
            50
          },
          {
            60
          },
          {
            90
          },
          {
            120
          },
          {
            240
          }
        }
      }
      local formatIds = {
        "av1",
        "hevc",
        "webm-vp9",
        "avc",
        "avc-nvenc",
        "webm-vp8",
        "webp",
        "gif",
        "mp3",
        "raw"
      }
      local formatOpts = {
        possibleValues = (function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #formatIds do
            local fId = formatIds[_index_0]
            _accum_0[_len_0] = {
              fId,
              formats[fId].displayName
            }
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)()
      }
      local uploadHostOpts = {
        possibleValues = upload_host_possible_values()
      }
      local gifDitherOpts = {
        possibleValues = {
          {
            0,
            "bayer_scale 0"
          },
          {
            1,
            "bayer_scale 1"
          },
          {
            2,
            "bayer_scale 2"
          },
          {
            3,
            "bayer_scale 3"
          },
          {
            4,
            "bayer_scale 4"
          },
          {
            5,
            "bayer_scale 5"
          },
          {
            6,
            "sierra2_4a"
          }
        }
      }
      self.options = {
        {
          "output_format",
          Option("list", "Output Format", options.output_format, formatOpts)
        },
        {
          "upload_host",
          Option("list", "Upload Destination", options.upload_host, uploadHostOpts, function()
            return is_upload_available()
          end)
        },
        {
          "twopass",
          Option("bool", "Two Pass", options.twopass)
        },
        {
          "apply_current_filters",
          Option("bool", "Apply Current Video Filters", options.apply_current_filters)
        },
        {
          "scale_height",
          Option("list", "Scale Height", options.scale_height, scaleHeightOpts)
        },
        {
          "strict_filesize_constraint",
          Option("bool", "Strict Filesize Constraint", options.strict_filesize_constraint)
        },
        {
          "write_filename_on_metadata",
          Option("bool", "Write Filename on Metadata", options.write_filename_on_metadata)
        },
        {
          "target_filesize",
          Option("int", "Target Filesize", options.target_filesize, filesizeOpts)
        },
        {
          "crf",
          Option("int", "CRF", options.crf, crfOpts)
        },
        {
          "fps",
          Option("list", "FPS", options.fps, fpsOpts)
        },
        {
          "gif_dither",
          Option("list", "GIF Dither Type", options.gif_dither, gifDitherOpts, function()
            return self.options[1][2]:getValue() == "gif"
          end)
        },
        {
          "force_square_pixels",
          Option("bool", "Force Square Pixels", options.force_square_pixels)
        }
      }
      self.keybinds = {
        ["LEFT"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.leftKey
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["RIGHT"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.rightKey
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["UP"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.prevOpt
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["DOWN"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.nextOpt
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["ENTER"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.confirmOpts
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["ESC"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.cancelOpts
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      }
    end,
    __base = _base_0,
    __name = "EncodeOptionsPage",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  EncodeOptionsPage = _class_0
end
local PreviewPage
do
  local _class_0
  local _parent_0 = Page
  local _base_0 = {
    prepare = function(self)
      local vf = mp.get_property_native("vf")
      if self.region:is_valid() then
        vf[#vf + 1] = {
          name = "crop",
          params = {
            w = tostring(self.region.w),
            h = tostring(self.region.h),
            x = tostring(self.region.x),
            y = tostring(self.region.y)
          }
        }
      end
      vf[#vf + 1] = {
        name = "sub"
      }
      mp.set_property_native("vf", vf)
      if self.startTime > -1 and self.endTime > -1 then
        mp.set_property_native("ab-loop-a", self.startTime)
        mp.set_property_native("ab-loop-b", self.endTime)
        mp.set_property_native("time-pos", self.startTime)
      end
      return mp.set_property_native("pause", false)
    end,
    dispose = function(self)
      mp.set_property("ab-loop-a", "no")
      mp.set_property("ab-loop-b", "no")
      for prop, value in pairs(self.originalProperties) do
        mp.set_property_native(prop, value)
      end
    end,
    draw = function(self)
      local window_w, window_h = mp.get_osd_size()
      local ass = assdraw.ass_new()
      ass:new_event()
      self:setup_text(ass)
      ass:append("Press " .. tostring(bold('ESC')) .. " to exit preview.\\N")
      return mp.set_osd_ass(window_w, window_h, ass.text)
    end,
    cancel = function(self)
      self:hide()
      return self.callback()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, callback, region, startTime, endTime)
      self.callback = callback
      self.originalProperties = {
        ["vf"] = mp.get_property_native("vf"),
        ["time-pos"] = mp.get_property_native("time-pos"),
        ["pause"] = mp.get_property_native("pause")
      }
      self.keybinds = {
        ["ESC"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.cancel
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      }
      self.region = region
      self.startTime = startTime
      self.endTime = endTime
      self.isLoop = false
    end,
    __base = _base_0,
    __name = "PreviewPage",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  PreviewPage = _class_0
end
local MainPage
do
  local _class_0
  local _parent_0 = Page
  local _base_0 = {
    setStartTime = function(self)
      self.startTime = mp.get_property_number("time-pos")
      if self.visible then
        self:clear()
        return self:draw()
      end
    end,
    setEndTime = function(self)
      self.endTime = mp.get_property_number("time-pos")
      if self.visible then
        self:clear()
        return self:draw()
      end
    end,
    jumpToStartTime = function(self)
      return mp.set_property("time-pos", self.startTime)
    end,
    jumpToEndTime = function(self)
      return mp.set_property("time-pos", self.endTime)
    end,
    setupStartAndEndTimes = function(self)
      if mp.get_property_native("duration") then
        self.startTime = 0
        self.endTime = mp.get_property_native("duration")
      else
        self.startTime = -1
        self.endTime = -1
      end
      if self.visible then
        self:clear()
        return self:draw()
      end
    end,
    draw = function(self)
      local window_w, window_h = mp.get_osd_size()
      local ass = assdraw.ass_new()
      ass:new_event()
      self:setup_text(ass)
      ass:append(tostring(bold('WebM maker')) .. "\\N\\N")
      ass:append(tostring(bold('c:')) .. " crop\\N")
      ass:append(tostring(bold('1:')) .. " set start time (current is " .. tostring(seconds_to_time_string(self.startTime)) .. ")\\N")
      ass:append(tostring(bold('2:')) .. " set end time (current is " .. tostring(seconds_to_time_string(self.endTime)) .. ")\\N")
      ass:append(tostring(bold('!:')) .. " jump to start time\\N")
      ass:append(tostring(bold('@:')) .. " jump to end time\\N")
      ass:append(tostring(bold('o:')) .. " change encode options\\N")
      ass:append(tostring(bold('p:')) .. " preview\\N")
      ass:append(tostring(bold('e:')) .. " encode\\N")
      if is_upload_available() then
        ass:append(tostring(bold('u:')) .. " encode & upload\\N")
      end
      ass:append("\\N")
      ass:append(tostring(bold('ESC:')) .. " close\\N")
      return mp.set_osd_ass(window_w, window_h, ass.text)
    end,
    show = function(self)
      _class_0.__parent.show(self)
      return emit_event("show-main-page")
    end,
    onUpdateCropRegion = function(self, updated, newRegion)
      if updated then
        self.region = newRegion
      end
      return self:show()
    end,
    crop = function(self)
      self:hide()
      local cropPage = CropPage((function()
        local _base_1 = self
        local _fn_0 = _base_1.onUpdateCropRegion
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)(), self.region)
      return cropPage:show()
    end,
    onOptionsChanged = function(self, updated)
      return self:show()
    end,
    changeOptions = function(self)
      self:hide()
      local encodeOptsPage = EncodeOptionsPage((function()
        local _base_1 = self
        local _fn_0 = _base_1.onOptionsChanged
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
      return encodeOptsPage:show()
    end,
    onPreviewEnded = function(self)
      return self:show()
    end,
    preview = function(self)
      self:hide()
      local previewPage = PreviewPage((function()
        local _base_1 = self
        local _fn_0 = _base_1.onPreviewEnded
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)(), self.region, self.startTime, self.endTime)
      return previewPage:show()
    end,
    onEncodedForUpload = function(self, success, outPath)
      if not success or not outPath then
        self:show()
        return 
      end
      local uploadPage = UploadWithProgress((function()
        local _base_1 = self
        local _fn_0 = _base_1.onUploadEnded
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)(), outPath)
      return uploadPage:show()
    end,
    onUploadEnded = function(self, state)
      if state == "options" then
        return self:changeOptions()
      else
        return self:show()
      end
    end,
    upload = function(self)
      if not is_upload_available() then
        message("Uploads need curl on PATH. Set upload_curl_path in webm.conf.")
        return 
      end
      if self.startTime < 0 then
        message("No start time, aborting")
        return 
      end
      if self.endTime < 0 then
        message("No end time, aborting")
        return 
      end
      if self.startTime >= self.endTime then
        message("Start time is ahead of end time, aborting")
        return 
      end
      self:hide()
      return encode(self.region, self.startTime, self.endTime, (function()
        local _base_1 = self
        local _fn_0 = _base_1.onEncodedForUpload
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
    end,
    encode = function(self)
      self:hide()
      if self.startTime < 0 then
        message("No start time, aborting")
        return 
      end
      if self.endTime < 0 then
        message("No end time, aborting")
        return 
      end
      if self.startTime >= self.endTime then
        message("Start time is ahead of end time, aborting")
        return 
      end
      return encode(self.region, self.startTime, self.endTime)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self)
      self.keybinds = {
        ["c"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.crop
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["1"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.setStartTime
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["2"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.setEndTime
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["!"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.jumpToStartTime
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["@"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.jumpToEndTime
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["o"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.changeOptions
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["p"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.preview
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["e"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.encode
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["u"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.upload
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)(),
        ["ESC"] = (function()
          local _base_1 = self
          local _fn_0 = _base_1.hide
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)()
      }
      self.startTime = -1
      self.endTime = -1
      self.region = Region()
    end,
    __base = _base_0,
    __name = "MainPage",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  MainPage = _class_0
end
monitor_dimensions()
local mainPage = MainPage()
register_test_handlers(mainPage)
mp.add_key_binding(options.keybind, "display-webm-encoder", (function()
  local _base_0 = mainPage
  local _fn_0 = _base_0.show
  return function(...)
    return _fn_0(_base_0, ...)
  end
end)(), {
  repeatable = false
})
mp.register_event("file-loaded", (function()
  local _base_0 = mainPage
  local _fn_0 = _base_0.setupStartAndEndTimes
  return function(...)
    return _fn_0(_base_0, ...)
  end
end)())
msg.verbose("Loaded mpv-webm script!")
return emit_event("script-loaded")
