-- Usage:
--  default keybinding: n
--  add the following to your input.conf to change the default keybinding:
--  keyname script_binding autosubsync-menu

local mp = require('mp')
local utils = require('mp.utils')
local mpopt = require('mp.options')
local menu = require('menu')
local sub = require('subtitle')
local h = require('helpers')
local ref_selector
local engine_selector
local track_selector

-- Config
-- Options can be changed here or in a separate config file.
-- Config path: ~/.config/mpv/script-opts/autosubsync.conf
local config = {
    -- Change the following lines if the locations of executables differ from the defaults
    -- If set to empty, the path will be guessed.
    ffmpeg_path = "",
    ffsubsync_path = "",
    alass_path = "",

    -- Choose what tool to use. Allowed options: ffsubsync, alass, ask.
    -- If set to ask, the add-on will ask to choose the tool every time.
    audio_subsync_tool = "ask",
    altsub_subsync_tool = "ask",

    -- After retiming, tell mpv to forget the original subtitle track.
    unload_old_sub = true,

    -- Overwrite the original subtitle file
    overwrite_old_sub = false,

    -- Directory to write the new subtitle file to.
    -- If set to empty, the directory of the original subtitle will be used.
    new_sub_directory = "",
}
mpopt.read_options(config, 'autosubsync')

-- Snippet borrowed from stackoverflow to get the operating system
-- originally found at: https://stackoverflow.com/a/30960054
local os_name = (function()
    if os.getenv("HOME") == nil then
        return function()
            return "Windows"
        end
    else
        return function()
            return "*nix"
        end
    end
end)()

local os_temp = (function()
    if os_name() == "Windows" then
        return function()
            return os.getenv('TEMP')
        end
    else
        return function()
            return '/tmp/'
        end
    end
end)()

local function notify(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    mp.msg[level](message)
    mp.osd_message(message, duration)
end

local function subprocess(args)
    return mp.command_native {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    }
end

local url_decode = function(url)
    local function hex_to_char(x)
        return string.char(tonumber(x, 16))
    end
    if url ~= nil then
        url = url:gsub("^file://", "")
        url = url:gsub("+", " ")
        url = url:gsub("%%(%x%x)", hex_to_char)
        return url
    else
        return
    end
end

local function get_loaded_tracks(track_type)
    local result = {}
    local track_list = mp.get_property_native('track-list')
    for _, track in pairs(track_list) do
        if track.type == track_type then
            track['external-filename'] = track.external and url_decode(track['external-filename'])
            table.insert(result, track)
        end
    end
    return result
end

local function get_active_track(track_type)
    local track_list = mp.get_property_native('track-list')
    for num, track in ipairs(track_list) do
        if track.type == track_type and track.selected == true then
            if track.external and not h.file_exists(track['external-filename']) then
                track['external-filename'] = url_decode(track['external-filename'])
            end
            if not (track_type == 'sub' and track.id == mp.get_property_native('secondary-sid')) then
                return num, track
            end
        end
    end
    return notify(string.format("Error: no track of type '%s' selected", track_type), "error", 3)
end

local function remove_extension(filename)
    return filename:gsub('%.%w+$', '')
end

local function get_extension(filename)
    return filename:match("^.+(%.%w+)$")
end

local function startswith(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

local function get_retimed_sub_directory(sub_path)
    local sub_dir, sub_name = utils.split_path(sub_path)
    local video_dir, video_name = utils.split_path(mp.get_property("path"))

    if config.new_sub_directory ~= "" then
        return config.new_sub_directory
    elseif startswith(sub_dir, os_temp()) then
        return video_dir
    else
        return sub_dir
    end
end

local function get_retimed_sub_name(sub_path, suffix)
    local sub_dir, sub_name = utils.split_path(sub_path)
    local video_dir, video_name = utils.split_path(mp.get_property("path"))

    if startswith(sub_dir, os_temp()) then
        return table.concat { remove_extension(video_name), suffix, get_extension(sub_name) }
    else
        return table.concat { remove_extension(sub_name), suffix, get_extension(sub_name) }
    end
end

local function mkfp_retimed(sub_path, suffix)
    if config.overwrite_old_sub then
        return sub_path
    else
        return utils.join_path(
            get_retimed_sub_directory(sub_path),
            get_retimed_sub_name(sub_path, suffix)
        )
    end
end

local function engine_is_set()
    local subsync_tool = ref_selector:get_subsync_tool()
    if h.is_empty(subsync_tool) or subsync_tool == "ask" then
        return false
    else
        return true
    end
end

local function extract_to_file(subtitle_track)
    local codec_ext_map = { subrip = "srt", ass = "ass" }
    local ext = codec_ext_map[subtitle_track['codec']]
    if ext == nil then
        return notify(string.format("Error: unsupported codec: %s", subtitle_track['codec']), "error", 3)
    end
    local temp_sub_fp = utils.join_path(os_temp(), 'autosubsync_extracted.' .. ext)
    notify("Extracting internal subtitles...", nil, 3)
    local ret = subprocess {
        config.ffmpeg_path,
        "-hide_banner",
        "-nostdin",
        "-y",
        "-loglevel", "quiet",
        "-an",
        "-vn",
        "-i", mp.get_property("path"),
        "-map", "0:" .. (subtitle_track and subtitle_track['ff-index'] or 's'),
        "-f", ext,
        temp_sub_fp
    }
    if ret == nil or ret.status ~= 0 or not h.file_exists(temp_sub_fp) then
        return notify("Couldn't extract internal subtitle.\nMake sure the video has internal subtitles.", "error", 7)
    end
    return temp_sub_fp
end

local function sync_subtitles(ref_sub_path)
    local reference_file_path = ref_sub_path or mp.get_property("path")
    local _, sub_track = get_active_track('sub')
    if sub_track == nil then
        return
    end
    local subtitle_path = sub_track.external and sub_track['external-filename'] or extract_to_file(sub_track)
    local engine_name = engine_selector:get_engine_name()
    local engine_path = config[engine_name .. '_path']

    if h.is_path(config.ffmpeg_path) and not h.file_exists(engine_path) then
        return notify(
                string.format("Can't find %s executable.\nPlease specify the correct path in the config.", engine_name),
                "error",
                5
        )
    end

    if not h.file_exists(subtitle_path) then
        return notify(
                table.concat {
                    "Subtitle synchronization failed:\nCouldn't find ",
                    subtitle_path or "external subtitle file."
                },
                "error",
                3
        )
    end

    local retimed_subtitle_path = mkfp_retimed(subtitle_path, '_retimed')

    notify(string.format("Starting %s...", engine_name), nil, 2)

    local ret
    if engine_name == "ffsubsync" then
        local args = { config.ffsubsync_path, reference_file_path, "-i", subtitle_path, "-o", retimed_subtitle_path }
        if not ref_sub_path then
            table.insert(args, '--reference-stream')
            table.insert(args, '0:' .. get_active_track('audio'))
        end
        ret = subprocess(args)
    else
        ret = subprocess { config.alass_path, reference_file_path, subtitle_path, retimed_subtitle_path }
    end

    if ret == nil then
        return notify("Parsing failed or no args passed.", "fatal", 3)
    end

    if ret.status == 0 then
        local old_sid = mp.get_property("sid")
        if mp.commandv("sub_add", retimed_subtitle_path) then
            notify("Subtitle synchronized.", nil, 2)
            mp.set_property("sub-delay", 0)
            if config.unload_old_sub then
                mp.commandv("sub_remove", old_sid)
            end
        else
            notify("Error: couldn't add synchronized subtitle.", "error", 3)
        end
    else
        notify("Subtitle synchronization failed.", "error", 3)
    end
end

local function sync_to_subtitle()
    local selected_track = track_selector:get_selected_track()

    if selected_track and selected_track.external then
        sync_subtitles(selected_track['external-filename'])
    else
        if h.is_path(config.ffmpeg_path) and not h.file_exists(config.ffmpeg_path) then
            return notify("Can't find ffmpeg executable.\nPlease specify the correct path in the config.", "error", 5)
        end
        local temp_sub_fp = extract_to_file(selected_track)
        if temp_sub_fp then
            sync_subtitles(temp_sub_fp)
            os.remove(temp_sub_fp)
        end
    end
end

local function sync_to_manual_offset()
    local _, track = get_active_track('sub')
    local sub_delay = tonumber(mp.get_property("sub-delay"))
    if tonumber(sub_delay) == 0 then
        return notify("There were no manual timings set, nothing to do!", "error", 7)
    end
    local file_path = track.external and track['external-filename'] or extract_to_file(track)
    if file_path == nil then
        return
    end

    local ext = get_extension(file_path)
    local codec_parser_map = { ass = sub.ASS, subrip = sub.SRT }
    local parser = codec_parser_map[track['codec']]
    if parser == nil then
        return notify(string.format("Error: unsupported codec: %s", track['codec']), "error", 3)
    end
    local s = parser:populate(file_path)
    s:shift_timing(sub_delay)
    if track.external == false then
        os.remove(file_path)
    end
    s.filename = mkfp_retimed(file_path, '_manual_timing')
    s:save()
    mp.commandv("sub_add", s.filename)
    if config.unload_old_sub then
        mp.commandv("sub_remove", track.id)
    end
    mp.set_property("sub-delay", 0)
    return notify(string.format("Manual timings saved, loading '%s'", s.filename), "info", 7)
end

------------------------------------------------------------
-- Menu actions & bindings

ref_selector = menu:new {
    items = { 'Sync to audio', 'Sync to another subtitle', 'Save current timings', 'Cancel' },
    last_choice = 'audio',
    pos_x = 50,
    pos_y = 50,
    text_color = 'fff5da',
    border_color = '2f1728',
    active_color = 'ff6b71',
    inactive_color = 'fff5da',
}

function ref_selector:get_keybindings()
    return {
        { key = 'h', fn = function() self:close() end },
        { key = 'j', fn = function() self:down() end },
        { key = 'k', fn = function() self:up() end },
        { key = 'l', fn = function() self:act() end },
        { key = 'down', fn = function() self:down() end },
        { key = 'up', fn = function() self:up() end },
        { key = 'Enter', fn = function() self:act() end },
        { key = 'ESC', fn = function() self:close() end },
        { key = 'n', fn = function() self:close() end },
        { key = 'WHEEL_DOWN', fn = function() self:down() end },
        { key = 'WHEEL_UP', fn = function() self:up() end },
        { key = 'MBTN_LEFT', fn = function() self:act() end },
        { key = 'MBTN_RIGHT', fn = function() self:close() end },
    }
end

function ref_selector:new(o)
    self.__index = self
    o = o or {}
    return setmetatable(o, self)
end

function ref_selector:get_ref()
    if self.selected == 1 then
        return 'audio'
    elseif self.selected == 2 then
        return 'sub'
    else
        return nil
    end
end

function ref_selector:get_subsync_tool()
    if self.selected == 1 then
        return config.audio_subsync_tool
    elseif self.selected == 2 then
        return config.altsub_subsync_tool
    end
end

function ref_selector:act()
    self:close()

    if self.selected == 3 then
        return sync_to_manual_offset()
    end
    if self.selected == 4 then
        return
    end

    engine_selector:init()
end

function ref_selector:call_subsync()
    if self.selected == 1 then
        sync_subtitles()
    elseif self.selected == 2 then
        sync_to_subtitle()
    elseif self.selected == 3 then
        sync_to_manual_offset()
    end
end

function ref_selector:open()
    self.selected = 1
    for _, val in pairs(self:get_keybindings()) do
        mp.add_forced_key_binding(val.key, val.key, val.fn)
    end
    self:draw()
end

function ref_selector:close()
    for _, val in pairs(self:get_keybindings()) do
        mp.remove_key_binding(val.key)
    end
    self:erase()
end


------------------------------------------------------------
-- Engine selector

engine_selector = ref_selector:new {
    items = { 'ffsubsync', 'alass', 'Cancel' },
    last_choice = 'ffsubsync',
}

function engine_selector:init()
    if not engine_is_set() then
        engine_selector:open()
    else
        track_selector:init()
    end
end

function engine_selector:get_engine_name()
    return engine_is_set() and ref_selector:get_subsync_tool() or self.last_choice
end

function engine_selector:act()
    self:close()

    if self.selected == 1 then
        self.last_choice = 'ffsubsync'
    elseif self.selected == 2 then
        self.last_choice = 'alass'
    elseif self.selected == 3 then
        return
    end

    track_selector:init()
end

------------------------------------------------------------
-- Track selector

track_selector = ref_selector:new { }

local function is_supported_format(track)
    local supported_format = true
    if track.external then
        local ext = get_extension(track['external-filename'])
        if ext ~= '.srt' and ext ~= '.ass' then
            supported_format = false
        end
    end
    return supported_format
end

function track_selector:init()
    self.selected = 0

    if ref_selector:get_ref() == 'audio' then
        return ref_selector:call_subsync()
    end

    self.all_sub_tracks = get_loaded_tracks(ref_selector:get_ref())
    self.secondary_sid = mp.get_property_native('secondary-sid')
    self.tracks = {}
    self.items = {}

    for _, track in ipairs(self.all_sub_tracks) do
        if (not track.selected or track.id == self.secondary_sid) and is_supported_format(track) then
            table.insert(self.tracks, track)
            table.insert(
                    self.items,
                    string.format(
                            "%s #%s - %s%s",
                            (track.external and 'External' or 'Internal'),
                            track['id'],
                            (track.lang or (track.title and track.title:gsub('^.*%.', '') or 'unknown')),
                            (track.selected and ' (active)' or '')
                    )
            )
        end
    end

    if #self.items == 0 then
        notify("No supported subtitle tracks found.", "warn", 5)
        return
    end

    table.insert(self.items, "Cancel")
    self:open()
end

function track_selector:get_selected_track()
    if self.selected < 1 then
        return nil
    end
    return self.tracks[self.selected]
end

function track_selector:act()
    self:close()

    if self.selected == #self.items then
        return
    end

    ref_selector:call_subsync()
end

------------------------------------------------------------
-- Initialize the addon

local function init()
    for _, executable in pairs { 'ffmpeg', 'ffsubsync', 'alass' } do
        local config_key = executable .. '_path'
        config[config_key] = h.is_empty(config[config_key]) and h.find_executable(executable) or config[config_key]
    end
end

------------------------------------------------------------
-- Entry point

init()
mp.add_key_binding("n", "autosubsync-menu", function() ref_selector:open() end)
