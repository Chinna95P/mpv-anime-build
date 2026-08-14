--[[ uosc | https://github.com/tomasklaen/uosc ]]
local uosc_version = '5.13.0'

mp.commandv('script-message', 'uosc-version', uosc_version)

mp.set_property('osc', 'no')

assdraw = require('mp.assdraw')
opt = require('mp.options')
utils = require('mp.utils')
msg = require('mp.msg')
osd = mp.create_osd_overlay('ass-events')
QUARTER_PI_SIN = math.sin(math.pi / 4)

require('lib/std')

-- [PHASE 7: DIRECT BROADCAST LISTENER (ROBUST FIX)]

-- 1. Create a local cache to store the latest state
local anime_cache = { history_enabled = true } -- UPDATED DEFAULT

-- =============================================================================
-- [NEW] HISTORY ENGINE (ROBUST VERSION)
-- =============================================================================
-- Save directly to root mpv folder to avoid missing directory errors
local history_file = mp.command_native({"expand-path", "~~/uosc_history.json"})
local watch_history = {}
local active_video = { path = nil, title = nil, percent = 0 }

local function load_watch_history()
    local f = io.open(history_file, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then watch_history = utils.parse_json(content) or {} end
    end
end

local function save_watch_history()
    local f = io.open(history_file, "w")
    if f then
        f:write(utils.format_json(watch_history))
        f:close()
    end
end

load_watch_history()

-- 1. Grab file details when it successfully starts
mp.register_event('file-loaded', function()
    active_video.path = mp.get_property("path")
    active_video.title = mp.get_property("media-title")
    if not active_video.title or active_video.title == "" then
        active_video.title = (active_video.path or ""):match("([^/\\]+)$") or active_video.path or "Unknown"
    end
    active_video.percent = 0
end)

-- 2. Constantly cache exact percent so we have it BEFORE the file closes
mp.observe_property("percent-pos", "number", function(_, percent)
    if percent then active_video.percent = math.floor(percent) end
end)
-- =============================================================================

-- 2. Define the Reader Helper (Uses cache instead of get_property)
function get_anime_state(key)
    -- Return true if the key exists and is true
    return anime_cache[key]
end

-- 3. Listen for the Broadcast (Merged Logic)
mp.register_script_message('anime-state-broadcast', function(json)
    local data = utils.parse_json(json)
    if not data then return end
    
    -- [FIX] Merge data into cache instead of replacing it
    for k, v in pairs(data) do
        anime_cache[k] = v
    end
    
    -- Force Redraw if Menu is Open
    if Menu:is_open('menu') then
        local items = create_default_menu_items()
        local menu_json = utils.format_json({ type = 'menu', items = items })
        mp.commandv("script-message-to", mp.get_script_name(), "update-menu", menu_json)
    end
end)

-- [PHASE 8: CUSTOM DENOISE (HQDN3D) ENGINE]
local denoise = { enabled = false, ls = 0, cs = 0, lt = 4, ct = 4 }
local previous_hwdec = nil -- To remember what hwdec you were using before

mp.register_script_message('update-denoise', function(param, val)
    -- 1. Update State Variables
    if param == "toggle" then
        denoise.enabled = not denoise.enabled
    elseif val == "reset" then
        if param == "lt" or param == "ct" then denoise[param] = 4 else denoise[param] = 0 end
    else
        denoise[param] = math.max(0, denoise[param] + tonumber(val)) 
    end

    -- 2. Apply to MPV Video Filters safely
    mp.command('no-osd vf remove @denoise') 
    
    if denoise.enabled then
        -- [AUTO-FIX] Force a -copy hwdec so CPU filters work
        local current_hwdec = mp.get_property("hwdec", "auto")
        if current_hwdec ~= "no" and not current_hwdec:match("-copy") then
            previous_hwdec = current_hwdec -- Save the original state
            mp.set_property("hwdec", "auto-copy")
        end

        local filter_str = string.format("hqdn3d=%s:%s:%s:%s", denoise.ls, denoise.cs, denoise.lt, denoise.ct)
        mp.command('no-osd vf add @denoise:' .. filter_str)
        mp.osd_message("Denoise ON: " .. filter_str, 2)
    else
        -- [AUTO-FIX] Restore original hwdec when denoise is turned off
        if previous_hwdec then
            mp.set_property("hwdec", previous_hwdec)
            previous_hwdec = nil
        end
        mp.osd_message("Denoise OFF", 2)
    end
end)

--[[ OPTIONS ]]

defaults = {
	timeline_style = 'line',
	timeline_line_width = 2,
	timeline_size = 40,
	progress = 'windowed',
	progress_size = 2,
	progress_line_width = 20,
	timeline_persistency = '',
	timeline_border = 1,
	timeline_step = '5',
	timeline_cache = true,
	timeline_heatmap = 'overlay',
	timeline_mbtn_right = '',

	controls =
	'menu,gap,<video,audio>subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,<video,audio>speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen',
	controls_size = 32,
	controls_margin = 8,
	controls_spacing = 2,
	controls_persistency = '',

	volume = 'right',
	volume_size = 40,
	volume_persistency = '',
	volume_border = 1,
	volume_step = 1,

	speed_persistency = '',
	speed_step = 0.1,
	speed_step_is_factor = false,

	menu_item_height = 36,
	menu_min_width = 260,
	menu_padding = 4,
	menu_type_to_search = true,

	top_bar = 'no-border',
	top_bar_size = 40,
	top_bar_persistency = '',
	top_bar_controls = 'right',
	top_bar_title = 'yes',
	top_bar_alt_title = '',
	top_bar_alt_title_place = 'below',
	top_bar_flash_on = 'video,audio',

	window_border_size = 1,

	autoload = false,
	shuffle = false,

	scale = 1,
	scale_fullscreen = 1.3,
	font_scale = 1,
	text_border = 1.2,
	border_radius = 4,
	color = '',
	opacity = '',
	animation_duration = 100,
	refine = '',
	flash_duration = 1000,
	proximity_in = 40,
	proximity_out = 120,
	total_time = false, -- deprecated by below
	destination_time = 'playtime-remaining',
	time_precision = 0,
	font_bold = false,
	autohide = false,
	buffered_time_threshold = 60,
	pause_indicator = 'flash',
	stream_quality_options = '4320,2160,1440,1080,720,480,360,240,144',
	video_types =
	'3g2,3gp,asf,avi,f4v,flv,h264,h265,m2ts,m4v,mkv,mov,mp4,mp4v,mpeg,mpg,ogm,ogv,rm,rmvb,ts,vob,webm,wmv,y4m',
	audio_types =
	'aac,ac3,aiff,ape,au,cue,dsf,dts,flac,m4a,mid,midi,mka,mp3,mp4a,oga,ogg,opus,spx,tak,tta,wav,weba,wma,wv',
	image_types = 'apng,avif,bmp,gif,j2k,jp2,jfif,jpeg,jpg,jxl,mj2,png,svg,tga,tif,tiff,webp',
	subtitle_types = 'aqt,ass,gsub,idx,jss,lrc,mks,pgs,pjs,psb,rt,sbv,slt,smi,sub,sup,srt,ssa,ssf,ttxt,txt,usf,vt,vtt',
	playlist_types = 'm3u,m3u8,pls,url,cue',
	load_types = 'video,audio,image',
	default_directory = '~/',
	show_hidden_files = false,
	use_trash = false,
	adjust_osd_margins = true,
	chapter_ranges = 'openings:30abf964,endings:30abf964,ads:c54e4e80',
	chapter_range_patterns = 'openings:オープニング;endings:エンディング',
	languages = 'slang,en',
	subtitles_directory = '~~/subtitles',
	disable_elements = '',
}
options = table_copy(defaults)
function handle_options(changed_options)
	if changed_options.time_precision then
		timestamp_zero_rep_clear_cache()
	end
	update_config()
	update_human_times()
	Manager:disable('user', options.disable_elements)
	Elements:trigger('options')
	Elements:update_proximities()
	request_render()
end
opt.read_options(options, 'uosc', handle_options)
-- Normalize values
options.proximity_out = math.max(options.proximity_out, options.proximity_in + 1)
if options.chapter_ranges:sub(1, 4) == '^op|' then options.chapter_ranges = defaults.chapter_ranges end
if options.total_time and options.destination_time == 'playtime-remaining' then
	msg.warn('`total_time` is deprecated. Use `destination_time` instead.')
	options.destination_time = 'total'
elseif not itable_index_of({'total', 'playtime-remaining', 'time-remaining'}, options.destination_time) then
	options.destination_time = 'playtime-remaining'
end
if not itable_index_of({'left', 'right'}, options.top_bar_controls) then
	options.top_bar_controls = options.top_bar_controls == 'yes' and 'right' or nil
end

--[[ INTERNATIONALIZATION ]]
local intl = require('lib/intl')
t = intl.t
require('lib/char_conv')
fzy = require('lib/fzy')

--[[ CONFIG ]]
local config_defaults = {
	color = {
		foreground = serialize_rgba('ffffff').color,
		foreground_text = serialize_rgba('000000').color,
		background = serialize_rgba('000000').color,
		background_text = serialize_rgba('ffffff').color,
		window_border = serialize_rgba('000000').color,
		curtain = serialize_rgba('111111').color,
		success = serialize_rgba('a5e075').color,
		error = serialize_rgba('ff616e').color,
		match = serialize_rgba('69c5ff').color,
		heatmap = serialize_rgba('00adee').color,
	},
	opacity = {
		timeline = 0.9,
		position = 1,
		chapters = 0.8,
		slider = 0.9,
		slider_gauge = 1,
		controls = 0,
		speed = 0.6,
		menu = 1,
		submenu = 0.4,
		border = 1,
		title = 1,
		tooltip = 1,
		thumbnail = 1,
		curtain = 0.8,
		idle_indicator = 0.8,
		audio_indicator = 0.5,
		buffering_indicator = 0.3,
		playlist_position = 0.8,
		heatmap = 0.4,
	},
}
config = {
	version = uosc_version,
	open_subtitles_api_key = 'b0rd16N0bp7DETMpO4pYZwIqmQkZbYQr',
	open_subtitles_agent = 'uosc v' .. uosc_version,
	-- sets max rendering frequency in case the
	-- native rendering frequency could not be detected
	render_delay = 1 / 60,
	font = mp.get_property('options/osd-font'),
	osd_margin_x = mp.get_property('osd-margin-x'),
	osd_margin_y = mp.get_property('osd-margin-y'),
	osd_alignment_x = mp.get_property('osd-align-x'),
	osd_alignment_y = mp.get_property('osd-align-y'),
	refine = create_set(comma_split(options.refine)),
	types = {
		video = comma_split(options.video_types),
		audio = comma_split(options.audio_types),
		image = comma_split(options.image_types),
		subtitle = comma_split(options.subtitle_types),
		playlist = comma_split(options.playlist_types),
		media = comma_split(options.video_types
			.. ',' .. options.audio_types
			.. ',' .. options.image_types
			.. ',' .. options.playlist_types),
		load = {}, -- populated by update_load_types() below
	},
	stream_quality_options = comma_split(options.stream_quality_options),
	top_bar_flash_on = comma_split(options.top_bar_flash_on),
	chapter_ranges = (function()
		---@type table<string, string[]> Alternative patterns.
		local alt_patterns = {}
		if options.chapter_range_patterns and options.chapter_range_patterns ~= '' then
			for _, definition in ipairs(split(options.chapter_range_patterns, ';+ *')) do
				local name_patterns = split(definition, ' *:')
				local name, patterns = name_patterns[1], name_patterns[2]
				if name and patterns then alt_patterns[name] = split(patterns, ',') end
			end
		end

		---@type table<string, {color: string; opacity: number; patterns?: string[]}>
		local ranges = {}
		if options.chapter_ranges and options.chapter_ranges ~= '' then
			for _, definition in ipairs(split(options.chapter_ranges, ' *,+ *')) do
				local name_color = split(definition, ' *:+ *')
				local name, color = name_color[1], name_color[2]
				if name and color
					and name:match('^[a-zA-Z0-9_]+$') and color:match('^[a-fA-F0-9]+$')
					and (#color == 6 or #color == 8) then
					local range = serialize_rgba(name_color[2])
					range.patterns = alt_patterns[name]
					ranges[name_color[1]] = range
				end
			end
		end
		return ranges
	end)(),
	color = table_copy(config_defaults.color),
	opacity = table_copy(config_defaults.opacity),
	cursor_leave_fadeout_elements = {'timeline', 'volume', 'top_bar', 'controls'},
	timeline_step = 5,
	timeline_step_flag = '',
}

function update_load_types()
	local extensions = {}
	local types = create_set(comma_split(options.load_types:lower()))

	if types.same then
		types.same = nil
		if state and state.type then types[state.type] = true end
	end

	for _, name in ipairs(table_keys(types)) do
		local type_extensions = config.types[name]
		if type(type_extensions) == 'table' then
			itable_append(extensions, type_extensions)
		else
			msg.warn('Unknown load type: ' .. name)
		end
	end

	config.types.load = extensions
end

-- Updates config with values dependent on options
function update_config()
	-- Required environment config
	if options.autoload then
		mp.commandv('set', 'keep-open', 'yes')
		mp.commandv('set', 'keep-open-pause', 'no')
	end

	-- Adds `{element}_persistency` config properties with forced visibility states (e.g.: `{paused = true}`)
	for _, name in ipairs({'timeline', 'controls', 'volume', 'top_bar', 'speed'}) do
		local option_name = name .. '_persistency'
		local value, flags = options[option_name], {}
		if type(value) == 'string' then
			for _, state in ipairs(comma_split(value)) do flags[state] = true end
		end
		config[option_name] = flags
	end

	-- Opacity
	config.opacity = table_assign({}, config_defaults.opacity, serialize_key_value_list(options.opacity,
		function(value, key)
			return clamp(0, tonumber(value) or config.opacity[key], 1)
		end
	))

	-- Color
	config.color = table_assign({}, config_defaults.color, serialize_key_value_list(options.color, function(value)
		return serialize_rgba(value).color
	end))

	-- Global color shorthands
	fg, bg = config.color.foreground, config.color.background
	fgt, bgt = config.color.foreground_text, config.color.background_text

	-- Timeline step
	do
		local is_exact = options.timeline_step:sub(-1) == '!'
		config.timeline_step = tonumber(is_exact and options.timeline_step:sub(1, -2) or options.timeline_step)
		config.timeline_step_flag = is_exact and 'exact' or ''
	end

	-- Other
	update_load_types()
end
update_config()

-- [PHASE 3: SMART UPDATER WITH SELECTION MEMORY]
mp.register_script_message('control-update', function(command, submenu_id, active_index)
    mp.command(command)
    
    -- [FIX] Wait 50ms for asynchronous mpv commands (like Denoise) to fully process
    -- before telling the UI to redraw. This eliminates the visual "lag" race condition.
    mp.add_timeout(0.05, function()
        -- 1. Refresh the Menu Content
        if Menu:is_open('menu') then
            local items = create_default_menu_items()
            local json = utils.format_json({ type = 'menu', items = items })
            mp.commandv("script-message-to", "uosc", "update-menu", json)
            if submenu_id and submenu_id ~= '' then
                mp.commandv("script-message-to", "uosc", "open-menu", json, submenu_id)
            end

        elseif Menu:is_open('controls') then
            local menu_data = create_controls_menu()
            menu_data.type = "controls"
            local json = utils.format_json(menu_data)
            mp.commandv("script-message-to", "uosc", "open-menu", json, submenu_id)
        end

        -- 2. Restore the Cursor/Selection Position
        -- If we passed an index (e.g. "2" for Decrease), force UOSC to select it now
        if active_index and active_index ~= '' then
            local type = Menu:is_open('menu') and 'menu' or 'controls'
            mp.commandv("script-message-to", "uosc", "select-menu-item", type, active_index, submenu_id)
        end
    end)
end)

-- [SUBTITLES ADDITION] Helper to scan the ~~/fonts folder
local cached_fonts = nil
local function get_available_fonts()
    if cached_fonts then return cached_fonts end
    cached_fonts = {}
    local fonts_dir = mp.command_native({"expand-path", "~~/fonts"})
    local files, err = utils.readdir(fonts_dir, "files")
    
    if files then
        for _, file in ipairs(files) do
            -- Match common font extensions (.ttf, .otf, .woff, .woff2)
            local name = file:match("^(.+)%.[tToO][tT][fF]$") or file:match("^(.+)%.[wW][oO][fF]2?$")
            if name then
                table.insert(cached_fonts, name)
            end
        end
        table.sort(cached_fonts)
    end
    return cached_fonts
end

-- Default menu items
-- Inside scripts/uosc/main.lua

-- [PHASE 5: FINAL CONTROLS (WITH SCALING SUITE)]
function create_controls_menu()
    -- Helpers
    local function prop(p) return mp.get_property(p) end
    local function is_true(p) return prop(p) == 'yes' end
    local function active(p, v) return prop(p) == v end
	
	-- Wrapper: Executes command + Refreshes menu + Selects specific index
    local function cmd(c, id, idx) 
        local menu_id = id or ''
        local item_idx = idx or ''
        return 'script-message-to uosc control-update "' .. c .. '" "' .. menu_id .. '" "' .. item_idx .. '"' 
    end
	
	-- Generator for Denoise Menus (+ / - / Reset)
    local function create_denoise_menu(title, param, step, submenu_id)
        local current = denoise[param]
        return {
            title = title,
            hint = tostring(current),
            id = submenu_id,
            items = {
                { title = 'Increase (+)', value = cmd('script-message-to uosc update-denoise ' .. param .. ' ' .. step, submenu_id, 1) },
                { title = 'Decrease (-)', value = cmd('script-message-to uosc update-denoise ' .. param .. ' -' .. step, submenu_id, 2) },
                { title = 'Reset', value = cmd('script-message-to uosc update-denoise ' .. param .. ' reset', submenu_id, 3) },
            }
        }
    end

    -- Generator for Value Menus (+ / - / Reset)
    local function create_adjust_menu(title, property, step, reset_val, unit, submenu_id)
        local current = tonumber(prop(property)) or 0
        local hint_str = unit and string.format("%s %s", current, unit) or tostring(current)
        return {
            title = title,
            hint = hint_str,
            id = submenu_id,
            items = {
                { title = 'Increase (+)', value = cmd('add ' .. property .. ' ' .. step, submenu_id, 1) },
                { title = 'Decrease (-)', value = cmd('add ' .. property .. ' -' .. step, submenu_id, 2) },
                { title = 'Reset (' .. reset_val .. ')', value = cmd('set ' .. property .. ' ' .. reset_val, submenu_id, 3) },
            }
        }
    end
	
	-- =============================================================================
    -- LOGIC: SUBTITLES MENU 
    -- =============================================================================
    -- 1. Build the dynamic font list
    local font_items = {
        -- MPV's native default or user's fallback
        { 
            title = 'Default', 
            active = (prop('sub-font') == '' or prop('sub-font') == 'sans-serif'),
            value = cmd("osd-msg set sub-font ''", 'sub_font_menu', 1) 
        }
    }
    
    local fonts = get_available_fonts()
    for i, font in ipairs(fonts) do
        table.insert(font_items, {
            title = font,
            active = active('sub-font', font),
            value = cmd("osd-msg set sub-font '" .. font .. "'", 'sub_font_menu', i + 1)
        })
    end

    -- 2. Build the Subtitle Menu tree based on mpv.conf settings
    local subtitles_menu = {
        title = 'Subtitles',
        id = 'subtitles_root',
        items = {
            -- A. Font Style Selector
            {
                title = 'Font Style >',
                hint = (prop('sub-font') ~= '' and prop('sub-font') or 'Default'),
                id = 'sub_font_menu',
                items = font_items
            },
            -- B. ASS Override Settings
            {
                title = 'ASS Override >',
                hint = prop('sub-ass-override') or 'no',
                id = 'sub_ass_override_menu',
                items = {
                    { title = 'no (Respect Script)', active = active('sub-ass-override', 'no'), value = cmd('set sub-ass-override no', 'sub_ass_override_menu', 1) },
                    { title = 'yes (Override Style)', active = active('sub-ass-override', 'yes'), value = cmd('set sub-ass-override yes', 'sub_ass_override_menu', 2) },
                    { title = 'force (Override All)', active = active('sub-ass-override', 'force'), value = cmd('set sub-ass-override force', 'sub_ass_override_menu', 3) },
                    { title = 'scale (Scale w/ Window)', active = active('sub-ass-override', 'scale'), value = cmd('set sub-ass-override scale', 'sub_ass_override_menu', 4) },
                    { title = 'strip (Remove Styling)', active = active('sub-ass-override', 'strip'), value = cmd('set sub-ass-override strip', 'sub_ass_override_menu', 5) },
                }
            },
            -- C. Values/Sliders (Defaults pulled from your mpv.conf)
            create_adjust_menu('Font Size', 'sub-font-size', 1, 40, nil, 'sub_font_size_menu'),
            create_adjust_menu('Blur', 'sub-blur', 0.1, 0.9, nil, 'sub_blur_menu'),
            create_adjust_menu('Gaussian Blur', 'sub-gauss', 0.1, 0.9, nil, 'sub_gauss_menu'),
            create_adjust_menu('Spacing', 'sub-spacing', 0.1, 0.5, nil, 'sub_spacing_menu'),
            
            -- D. Toggles
            { title = 'Scale with Window', active = is_true('sub-scale-with-window'), value = cmd('cycle sub-scale-with-window', 'subtitles_root', 7) },
            { title = 'Stretch Image Subs', active = is_true('stretch-image-subs-to-screen'), value = cmd('cycle stretch-image-subs-to-screen', 'subtitles_root', 8) },
            { title = 'Use Margins', active = is_true('sub-use-margins'), value = cmd('cycle sub-use-margins', 'subtitles_root', 9) },
            { title = 'Blend Subtitles', active = is_true('blend-subtitles'), value = cmd('cycle blend-subtitles', 'subtitles_root', 10) },
            { title = 'Fix Timing', active = is_true('sub-fix-timing'), value = cmd('cycle sub-fix-timing', 'subtitles_root', 11) },
        }
    }
    -- =============================================================================

    return {
        title = 'Controls',
        id = 'controls_root',
        items = {
            -- 1. MAIN TOGGLES
            { title = 'Interpolation (Motion)', active = is_true('interpolation'), value = cmd('cycle interpolation', 'controls_root', 1) },
            { title = 'Deband', active = is_true('deband'), value = cmd('cycle deband', 'controls_root', 2) },
			{
                title = 'Deband Settings >',
                id = 'deband_settings_menu',
                muted = not is_true('deband'),
                hint = is_true('deband') and 'Active' or 'Locked',
                items = {
                    create_adjust_menu('Iterations', 'deband-iterations', 1, 1, nil, 'deband_iter_menu'),
                    create_adjust_menu('Threshold', 'deband-threshold', 4, 32, nil, 'deband_thresh_menu'),
                    create_adjust_menu('Range', 'deband-range', 2, 16, nil, 'deband_range_menu'),
                    create_adjust_menu('Grain', 'deband-grain', 4, 48, nil, 'deband_grain_menu'),
                    { title = 'Reset Deband to Defaults', value = cmd('set deband-iterations 1; set deband-threshold 32; set deband-range 16; set deband-grain 48', 'deband_settings_menu', 5) },
                }
            },
            { title = 'Deinterlace', active = is_true('deinterlace'), value = cmd('cycle deinterlace', 'controls_root', 4) },
            
			-- [NEW] DENOISE FILTER
            { title = 'Denoise (hqdn3d)', active = denoise.enabled, value = cmd('script-message-to uosc update-denoise toggle', 'controls_root', 5) },
            {
                title = 'Denoise Settings >',
                id = 'denoise_settings_menu',
                muted = not denoise.enabled,
                hint = denoise.enabled and 'Active' or 'Locked',
                items = {
                    create_denoise_menu('Luma Spatial (ls)', 'ls', 1, 'denoise_ls_menu'),
                    create_denoise_menu('Chroma Spatial (cs)', 'cs', 1, 'denoise_cs_menu'),
                    create_denoise_menu('Luma Temporal (lt)', 'lt', 1, 'denoise_lt_menu'),
                    create_denoise_menu('Chroma Temporal (ct)', 'ct', 1, 'denoise_ct_menu'),
                }
            },
			
            -- 2. SYNC & COLORS
            {
                title = 'Synchronization',
                id = 'sync_root',
                items = {
                    create_adjust_menu('Audio Delay', 'audio-delay', 0.1, 0, 's', 'audio_delay_menu'),
                    create_adjust_menu('Subtitle Delay', 'sub-delay', 0.1, 0, 's', 'sub_delay_menu'),
                    create_adjust_menu('Subtitle Pos', 'sub-pos', 1, 100, '%', 'sub_pos_menu'),
                }
            },
            {
                title = 'Video Colors',
                id = 'color_root',
                items = {
                    { title = 'Reset All Colors', value = cmd('set contrast 0; set brightness 0; set gamma 0; set saturation 0; set hue 0', 'color_root', 1) },
                    create_adjust_menu('Contrast', 'contrast', 1, 0, nil, 'contrast_menu'),
                    create_adjust_menu('Brightness', 'brightness', 1, 0, nil, 'bright_menu'),
                    create_adjust_menu('Gamma', 'gamma', 1, 0, nil, 'gamma_menu'),
                    create_adjust_menu('Saturation', 'saturation', 1, 0, nil, 'sat_menu'),
                    create_adjust_menu('Hue', 'hue', 1, 0, nil, 'hue_menu'),
                }
            },
			
			-- [NEW] ADDING THE SUBTITLES MENU HERE
            subtitles_menu,

            -- 3. ADVANCED MENU
            {
                title = 'Advanced',
                id = 'advanced_root',
                items = {
                    -- A. Video Sync
                    {
                        title = 'Video Sync >',
                        hint = prop('video-sync'),
                        id = 'vsync_menu',
                        items = {
                            { title = 'Audio', active = active('video-sync', 'audio'), value = cmd('set video-sync audio', 'vsync_menu', 1) },
                            { title = 'Display Resample', active = active('video-sync', 'display-resample'), value = cmd('set video-sync display-resample', 'vsync_menu', 2) },
                            { title = 'Display Resample (Vdrop)', active = active('video-sync', 'display-resample-vdrop'), value = cmd('set video-sync display-resample-vdrop', 'vsync_menu', 3) },
							{ title = 'Display Vdrop', active = active('video-sync', 'display-vdrop'), value = cmd('set video-sync display-vdrop', 'vsync_menu', 4) },
                            { title = 'Desync', active = active('video-sync', 'desync'), value = cmd('set video-sync desync', 'vsync_menu', 5) },
                        }
                    },
                    -- B. Dither
                    {
                        title = 'Dither Settings >',
                        hint = prop('dither'),
                        id = 'dither_menu',
                        items = {
                            { title = 'fruit (Default)', active = active('dither', 'fruit'), value = cmd('set dither fruit', 'dither_menu', 1) },
                            { title = 'ordered', active = active('dither', 'ordered'), value = cmd('set dither ordered', 'dither_menu', 2) },
                            { title = 'Disable', active = active('dither', 'no'), value = cmd('set dither no', 'dither_menu', 3) },
                            { title = 'Depth: Auto', active = active('dither-depth', 'auto'), value = cmd('set dither-depth auto', 'dither_menu', 4) },
                            { title = 'Depth: 8', active = active('dither-depth', '8'), value = cmd('set dither-depth 8', 'dither_menu', 5) },
                            { title = 'Depth: 10', active = active('dither-depth', '10'), value = cmd('set dither-depth 10', 'dither_menu', 6) },
                        }
                    },
                    -- C. Hardware Decoding
                    {
                        title = 'Hardware Decoding >',
                        hint = prop('hwdec') or 'auto',
                        id = 'hwdec_menu',
                        items = {
                            { title = 'auto (Recommended)', active = active('hwdec', 'auto'), value = cmd('set hwdec auto', 'hwdec_menu', 1) },
                            { title = 'auto-copy', active = active('hwdec', 'auto-copy'), value = cmd('set hwdec auto-copy', 'hwdec_menu', 2) },
                            
                            { title = '=== Windows ===', value = 'ignore', bold = true },
                            { title = 'd3d11va (Modern Best)', active = active('hwdec', 'd3d11va'), value = cmd('set hwdec d3d11va', 'hwdec_menu', 4) },
                            { title = 'd3d11va-copy', active = active('hwdec', 'd3d11va-copy'), value = cmd('set hwdec d3d11va-copy', 'hwdec_menu', 5) },
                            { title = 'dxva2 (Legacy)', active = active('hwdec', 'dxva2'), value = cmd('set hwdec dxva2', 'hwdec_menu', 6) },
                            { title = 'dxva2-copy', active = active('hwdec', 'dxva2-copy'), value = cmd('set hwdec dxva2-copy', 'hwdec_menu', 7) },
                            
                            { title = '=== Linux ===', value = 'ignore', bold = true },
                            { title = 'vaapi (AMD/Intel Best)', active = active('hwdec', 'vaapi'), value = cmd('set hwdec vaapi', 'hwdec_menu', 9) },
                            { title = 'vaapi-copy', active = active('hwdec', 'vaapi-copy'), value = cmd('set hwdec vaapi-copy', 'hwdec_menu', 10) },
                            { title = 'vdpau (Legacy)', active = active('hwdec', 'vdpau'), value = cmd('set hwdec vdpau', 'hwdec_menu', 11) },
                            { title = 'vdpau-copy', active = active('hwdec', 'vdpau-copy'), value = cmd('set hwdec vdpau-copy', 'hwdec_menu', 12) },

                            { title = '=== Cross-Platform ===', value = 'ignore', bold = true },
                            { title = 'nvdec (Nvidia)', active = active('hwdec', 'nvdec'), value = cmd('set hwdec nvdec', 'hwdec_menu', 14) },
                            { title = 'nvdec-copy', active = active('hwdec', 'nvdec-copy'), value = cmd('set hwdec nvdec-copy', 'hwdec_menu', 15) },
                            { title = 'vulkan', active = active('hwdec', 'vulkan'), value = cmd('set hwdec vulkan', 'hwdec_menu', 16) },
                            { title = 'vulkan-copy', active = active('hwdec', 'vulkan-copy'), value = cmd('set hwdec vulkan-copy', 'hwdec_menu', 17) },

                            { title = '=== Software ===', value = 'ignore', bold = true },
                            { title = 'OFF (CPU Decoding)', active = active('hwdec', 'no'), value = cmd('set hwdec no', 'hwdec_menu', 19) },
                        }
                    },
					
					-- D. GPU API
                    {
                        title = 'GPU API >',
                        hint = prop('gpu-api') or 'auto',
                        id = 'gpu_api_menu',
                        items = {
                            { title = 'auto (Default)', active = active('gpu-api', 'auto'), value = cmd('set gpu-api auto', 'gpu_api_menu', 1) },
                            { title = 'vulkan (Modern/Fast)', active = active('gpu-api', 'vulkan'), value = cmd('set gpu-api vulkan', 'gpu_api_menu', 2) },
                            { title = 'd3d11 (Windows)', active = active('gpu-api', 'd3d11'), value = cmd('set gpu-api d3d11', 'gpu_api_menu', 3) },
                            { title = 'opengl (Legacy)', active = active('gpu-api', 'opengl'), value = cmd('set gpu-api opengl', 'gpu_api_menu', 4) },
                        }
                    },
                    -- E. GPU Context
                    {
                        title = 'GPU Context >',
                        hint = prop('gpu-context') or 'auto',
                        id = 'gpu_context_menu',
                        items = {
                            { title = 'auto (Default)', active = active('gpu-context', 'auto'), value = cmd('set gpu-context auto', 'gpu_context_menu', 1) },
                            { title = '=== Windows ===', value = 'ignore', bold = true },
                            { title = 'd3d11', active = active('gpu-context', 'd3d11'), value = cmd('set gpu-context d3d11', 'gpu_context_menu', 3) },
                            { title = 'winvk (Vulkan)', active = active('gpu-context', 'winvk'), value = cmd('set gpu-context winvk', 'gpu_context_menu', 4) },
                            { title = 'win (OpenGL)', active = active('gpu-context', 'win'), value = cmd('set gpu-context win', 'gpu_context_menu', 5) },
                            { title = '=== Linux ===', value = 'ignore', bold = true },
                            { title = 'waylandvk (Wayland Vulkan)', active = active('gpu-context', 'waylandvk'), value = cmd('set gpu-context waylandvk', 'gpu_context_menu', 7) },
                            { title = 'wayland (Wayland OpenGL)', active = active('gpu-context', 'wayland'), value = cmd('set gpu-context wayland', 'gpu_context_menu', 8) },
                            { title = 'x11vk (X11 Vulkan)', active = active('gpu-context', 'x11vk'), value = cmd('set gpu-context x11vk', 'gpu_context_menu', 9) },
                            { title = 'x11egl (X11 EGL/OpenGL)', active = active('gpu-context', 'x11egl'), value = cmd('set gpu-context x11egl', 'gpu_context_menu', 10) },
                        }
                    },
					
					-- F. Vulkan Settings
                    {
                        title = 'Vulkan Settings >',
                        id = 'vulkan_settings_menu',
                        muted = not active('gpu-api', 'vulkan'),
                        hint = active('gpu-api', 'vulkan') and 'Active' or 'Locked',
                        items = {
                            { title = '=== Async Compute ===', value = 'ignore', bold = true },
                            { title = 'yes (Default)', active = active('vulkan-async-compute', 'yes'), value = cmd('set vulkan-async-compute yes', 'vulkan_settings_menu', 2) },
                            { title = 'no', active = active('vulkan-async-compute', 'no'), value = cmd('set vulkan-async-compute no', 'vulkan_settings_menu', 3) },
                            
                            { title = '=== Queue Count ===', value = 'ignore', bold = true },
                            { title = '1 (Default)', active = active('vulkan-queue-count', '1'), value = cmd('set vulkan-queue-count 1', 'vulkan_settings_menu', 5) },
                            { title = '2', active = active('vulkan-queue-count', '2'), value = cmd('set vulkan-queue-count 2', 'vulkan_settings_menu', 6) },
                            { title = '3', active = active('vulkan-queue-count', '3'), value = cmd('set vulkan-queue-count 3', 'vulkan_settings_menu', 7) },

                            { title = '=== Async Transfer ===', value = 'ignore', bold = true },
                            { title = 'yes (Default)', active = active('vulkan-async-transfer', 'yes'), value = cmd('set vulkan-async-transfer yes', 'vulkan_settings_menu', 9) },
                            { title = 'no', active = active('vulkan-async-transfer', 'no'), value = cmd('set vulkan-async-transfer no', 'vulkan_settings_menu', 10) },

                            { title = 'Reset to Defaults', value = cmd('set vulkan-async-compute yes; set vulkan-queue-count 1; set vulkan-async-transfer yes', 'vulkan_settings_menu', 12) },
                        }
                    },
					
                    -- G. Scaling (FULL SUITE - UPDATED v1.9.6)
                    {
                        title = 'Scaling',
                        id = 'scaling_root',
                        items = {
                            -- Upscaler
                            {
                                title = 'Upscale >',
                                hint = prop('scale'),
                                id = 'scale_menu',
                                items = {
                                    { title = 'ewa_lanczossharp (Best)', active = active('scale', 'ewa_lanczossharp'), value = cmd('set scale ewa_lanczossharp', 'scale_menu', 1) },
                                    { title = 'spline64 (Sharp)', active = active('scale', 'spline64'), value = cmd('set scale spline64', 'scale_menu', 2) },
                                    { title = 'lanczos (Classic)', active = active('scale', 'lanczos'), value = cmd('set scale lanczos', 'scale_menu', 3) },
                                    { title = 'spline36 (Balanced)', active = active('scale', 'spline36'), value = cmd('set scale spline36', 'scale_menu', 4) },
                                    { title = 'bilinear (Fast)', active = active('scale', 'bilinear'), value = cmd('set scale bilinear', 'scale_menu', 5) },
                                }
                            },
                            -- Downscaler (Critical for 4K content)
                            {
                                title = 'Downscale >',
                                hint = prop('dscale'),
                                id = 'dscale_menu',
                                items = {
                                    { title = 'spline64 (Best/Sharp)', active = active('dscale', 'spline64'), value = cmd('set dscale spline64', 'dscale_menu', 1) },
                                    { title = 'mitchell (Smoothest)', active = active('dscale', 'mitchell'), value = cmd('set dscale mitchell', 'dscale_menu', 2) },
                                    { title = 'lanczos (Very Sharp)', active = active('dscale', 'lanczos'), value = cmd('set dscale lanczos', 'dscale_menu', 3) },
                                    { title = 'spline36 (Balanced)', active = active('dscale', 'spline36'), value = cmd('set dscale spline36', 'dscale_menu', 4) },
                                    { title = 'hermite (Soft)', active = active('dscale', 'hermite'), value = cmd('set dscale hermite', 'dscale_menu', 5) },
                                    { title = 'bilinear (Fast)', active = active('dscale', 'bilinear'), value = cmd('set dscale bilinear', 'dscale_menu', 6) },
									{ title = 'catmull_rom (Smooth)', active = active('dscale', 'catmull_rom'), value = cmd('set dscale catmull_rom', 'dscale_menu', 7) },
                                }
                            },
                            -- Chromascaler (Color)
                            {
                                title = 'Chromascale >',
                                hint = prop('cscale'),
                                id = 'cscale_menu',
                                items = {
                                    { title = 'spline64 (Best)', active = active('cscale', 'spline64'), value = cmd('set cscale spline64', 'cscale_menu', 1) },
                                    { title = 'spline36 (Balanced)', active = active('cscale', 'spline36'), value = cmd('set cscale spline36', 'cscale_menu', 2) },
                                    { title = 'lanczos (Sharp)', active = active('cscale', 'lanczos'), value = cmd('set cscale lanczos', 'cscale_menu', 3) },
                                    { title = 'bilinear (Fast)', active = active('cscale', 'bilinear'), value = cmd('set cscale bilinear', 'cscale_menu', 4) },
                                }
                            },
                            -- Temporalscaler (Interpolation Method)
                            {
                                title = 'Temporalscale >',
                                hint = prop('tscale'),
                                id = 'tscale_menu',
                                items = {
                                    { title = 'oversample (Sharpest)', active = active('tscale', 'oversample'), value = cmd('set tscale oversample', 'tscale_menu', 1) },
                                    { title = 'linear', active = active('tscale', 'linear'), value = cmd('set tscale linear', 'tscale_menu', 2) },
                                    { title = 'catmull_rom', active = active('tscale', 'catmull_rom'), value = cmd('set tscale catmull_rom', 'tscale_menu', 3) },
                                    { title = 'mitchell (Soft)', active = active('tscale', 'mitchell'), value = cmd('set tscale mitchell', 'tscale_menu', 4) },
                                    { title = 'bicubic', active = active('tscale', 'bicubic'), value = cmd('set tscale bicubic', 'tscale_menu', 5) },
									{ title = 'sphinx (Balanced)', active = active('tscale', 'sphinx'), value = cmd('set tscale sphinx', 'tscale_menu', 6) },
									{ title = 'box', active = active('tscale', 'box'), value = cmd('set tscale box', 'tscale_menu', 7) },
									{ title = 'quadric', active = active('tscale', 'quadric'), value = cmd('set tscale quadric', 'tscale_menu', 8) },
									{ title = 'spline16', active = active('tscale', 'spline16'), value = cmd('set tscale spline16', 'tscale_menu', 9) },
                                }
                            },
                            -- Toggles
                            { title = 'Linear Upscaling', active = is_true('linear-upscaling'), value = cmd('cycle linear-upscaling', 'scaling_root', 5) },
                            { title = 'Sigmoid Upscaling', active = is_true('sigmoid-upscaling'), value = cmd('cycle sigmoid-upscaling', 'scaling_root', 6) },
                            { title = 'Correct Downscaling', active = is_true('correct-downscaling'), value = cmd('cycle correct-downscaling', 'scaling_root', 7) },
                            { title = 'Linear Downscaling', active = is_true('linear-downscaling'), value = cmd('cycle linear-downscaling', 'scaling_root', 8) },
                        }
                    },
					
                }
            },
        }
    }
end

-- [PHASE 1: BUTTON BINDING]
mp.add_key_binding(nil, "open-controls-menu", function()
    local menu_data = create_controls_menu()
    menu_data.type = "controls"
    local json = utils.format_json(menu_data)
    mp.commandv("script-message-to", "uosc", "open-menu", json)
end)

-- [PHASE 6: MAIN MENU (WITH CHECKMARKS & SHADER TOGGLE)]
function create_default_menu_items()
    -- Generate dynamic controls
    local controls_data = create_controls_menu()
    
    -- [HELPER] Read Shared State from JSON Cache (Restores Checkmarks)
    -- This uses the global get_anime_state function defined at the bottom of main.lua
    
    -- Calculate Lock States
    local is_anime = get_anime_state("is_anime_context")
    local fidelity_active = get_anime_state("anime_fidelity")
    local a4k_allowed = get_anime_state("anime4k_allowed")

    local lock_hint = is_anime and "" or " (Locked)"
    local a4k_hint = a4k_allowed and "" or (is_anime and "Disabled (Fidelity ON)" or " (Locked)")

    -- Dynamic Labels for Ultra Mode Descriptions
    local is_ultra = (get_anime_state("anime4k_quality") == "ultra")
    local label_a  = is_ultra and "Mode A (FSR+Thin)" or "Mode A (Blur+Noise)"
    local label_b  = is_ultra and "Mode B (Post-Sharpen)" or "Mode B (Blur Only)"
    local label_c  = is_ultra and "Mode C (Pre-Sharpen)" or "Mode C (Noise Only)"
    local label_aa = is_ultra and "Mode A+A (DbL Recommended)" or "Mode A+A (High Fid.)"
    local label_bb = is_ultra and "Mode B+B (DbH Deblur)" or "Mode B+B (Sharpness)"
    local label_ca = is_ultra and "Mode C+A (DbH Sharp)" or "Mode C+A (Restore)"
	
	-- =============================================================================
    -- LOGIC: HDR TONE-MAPPING MENU (Calculated BEFORE table creation)
    -- =============================================================================
    -- 1. DETECT STATUS
    local primaries = mp.get_property("video-params/primaries")
    local hdr_passthrough = mp.get_property("target-colorspace-hint") == "yes"
    local is_hdr = (primaries == "bt.2020" or primaries == "dci-p3")

    -- 2. DETERMINE IF LOCKED
    local tm_locked = not (is_hdr and not hdr_passthrough)
    local tm_status_hint = ""

    if not is_hdr then
        tm_status_hint = " (Locked: SDR Content)"
    elseif hdr_passthrough then
        tm_status_hint = " (Locked: Passthrough Active)"
    else
        tm_status_hint = " (Active)"
    end

    -- 3. GET CURRENT ALGORITHM
    local current_tm = mp.get_property("tone-mapping") or "hable"

-- 4. BUILD THE SUBMENU
    local tm_menu = {
        type = "submenu",
        title = "Tone-Mapping Mode" .. tm_status_hint,
        icon = "brightness_medium",
        active = not tm_locked,
        items = {
            -- Standard Curves
            { 
                title = "BT.2390 (Recommended)", 
                active = (current_tm == "bt.2390"), 
                value = "script-message save-tone-mapping bt.2390" 
            },
            { 
                title = "ST.2094-40 (Active)", 
                active = (current_tm == "st2094-40"), 
                value = "script-message save-tone-mapping st2094-40" 
            },
			{ 
                title = "ST.2094-10 (Adaptive)", 
                active = (current_tm == "st2094-10"), 
                value = "script-message save-tone-mapping st2094-10" 
            },
            { 
                title = "BT.2446a (Static)", 
                active = (current_tm == "bt.2446a"), 
                value = "script-message save-tone-mapping bt.2446a" 
            },
            { 
                title = "Spline (Neutral)", 
                active = (current_tm == "spline"), 
                value = "script-message save-tone-mapping spline" 
            },
            
            -- Legacy / Artistic Curves
            { 
                title = "Hable", 
                active = (current_tm == "hable"), 
                value = "script-message save-tone-mapping hable" 
            },
            { 
                title = "Mobius", 
                active = (current_tm == "mobius"), 
                value = "script-message save-tone-mapping mobius" 
            },
            { 
                title = "Reinhard", 
                active = (current_tm == "reinhard"), 
                value = "script-message save-tone-mapping reinhard" 
            },
            
            -- Utility
            { 
                title = "Clip (Hard Cut)", 
                active = (current_tm == "clip"), 
                value = "script-message save-tone-mapping clip" 
            }
        }
    }
    -- =============================================================================

    return {
        {title = t('Subtitles'), value = 'script-binding uosc/subtitles'},
        {title = t('Audio tracks'), value = 'script-binding uosc/audio'},
        {title = t('Stream quality'), value = 'script-binding uosc/stream-quality'},
        {title = t('Playlist'), value = 'script-binding uosc/items'},
        {title = t('History'), value = 'script-binding uosc/history', icon = 'history'}, -- [v4.5] History Sub-Menu
        {title = t('Chapters'), value = 'script-binding uosc/chapters'},
        
        {
            title = t('Navigation'),
            items = {
                { title = t('Next'), hint = t('playlist or file'), value = 'script-binding uosc/next' },
                { title = t('Prev'), hint = t('playlist or file'), value = 'script-binding uosc/prev' },
                { title = t('Delete file & Next'), value = 'script-binding uosc/delete-file-next' },
                { title = t('Delete file & Prev'), value = 'script-binding uosc/delete-file-prev' },
                { title = t('Delete file & Quit'), value = 'script-binding uosc/delete-file-quit' },
                { title = t('Open file'), value = 'script-binding uosc/open-file' },
            },
        },

        -- [CONTROLS EMBEDDED]
        controls_data,

		-- [ANIME BUILD OPTIONS]
        {
            title = 'Anime Build Options',
            items = {
                -- 1. Anime Mode Sub-Menu
                {
                    title = 'Anime Detection Mode: ' .. (get_anime_state("mode_on") and "ON" or (get_anime_state("mode_off") and "OFF" or "AUTO")),
                    icon = 'tv',
                    items = {
                        { title = "====(Auto-Detection Modes)====", value = "ignore", bold = true },
                        { title = 'Mode: Auto (Auto Detection)', value = 'script-binding anime-mode-auto', active = get_anime_state("mode_auto") },
                        { title = 'Mode: Force On (Anime Mode)', value = 'script-binding anime-mode-on', active = get_anime_state("mode_on") },
                        { title = 'Mode: Force Off (Native HQ)', value = 'script-binding anime-mode-off', active = get_anime_state("mode_off") },
                        { title = 'Show Status Info', value = 'script-binding show-profile-info', icon = 'info' },
                    }
                },

				-- [NEW] Anime Fidelity Toggle
				-- Active: If Fidelity is ON
				-- Muted: ONLY if we are NOT in Anime Context. (Unlocked for both Fidelity and Anime4K modes)
				{
					title = "Anime Shaders Mode: " .. (fidelity_active and "FSRCNNX" or "Anime4K"),
					value = "script-message toggle-anime-fidelity",
					active = fidelity_active,
					muted = not is_anime,
					hint = lock_hint
				},

				-- Anime4K Quality Toggle (Greyed out if Fidelity ON or Not Anime)
				{
					title = "Anime4K Quality",
					icon = "high_quality",
					muted = not a4k_allowed,
					hint = not a4k_allowed and a4k_hint or (get_anime_state("anime4k_quality") and get_anime_state("anime4k_quality"):upper() or ""),
					items = {
						{ title = "Fast (Performance)", active = get_anime_state("anime4k_fast"), value = "script-message set-anime4k-quality fast" },
						{ title = "HQ (High Quality)", active = get_anime_state("anime4k_hq"), value = "script-message set-anime4k-quality hq" },
						{ title = "Ultra (Th-Underscore)", active = get_anime_state("anime4k_ultra"), value = "script-message set-anime4k-quality ultra" },
					}
				},

				-- 2. Anime4K Profiles
                {
                    title = 'Anime4K Profiles',
                    icon = 'palette',
                    muted = not a4k_allowed,
                    hint = a4k_hint,
                    items = {
                        { title = 'Mode Ani4Kv2 (ArtCNN)', value = 'script-message anime4k-mode Ani4Kv2', active = get_anime_state("a4k_mode_ani4kv2") },
                        { title = 'Mode AniSD (ArtCNN)', value = 'script-message anime4k-mode AniSD', active = get_anime_state("a4k_mode_anisd") },
                        { title = label_a,  value = 'script-message anime4k-mode A', active = get_anime_state("a4k_mode_a") },
                        { title = label_b,  value = 'script-message anime4k-mode B', active = get_anime_state("a4k_mode_b") },
                        { title = label_c,  value = 'script-message anime4k-mode C', active = get_anime_state("a4k_mode_c") },
                        { title = label_aa, value = 'script-message anime4k-mode AA', active = get_anime_state("a4k_mode_aa") },
                        { title = label_bb, value = 'script-message anime4k-mode BB', active = get_anime_state("a4k_mode_bb") },
                        { title = label_ca, value = 'script-message anime4k-mode CA', active = get_anime_state("a4k_mode_ca") },
                    }
                },

                -- 3. Fidelity & Restoration
                {
                    title = 'Fidelity & Restoration',
                    icon = 'brush',
                    items = {
						 { title = "====(Display Tools)====", value = "ignore", bold = true },
                         
                         -- [NEW] UltraWide Zoom Sub-Menu
                         {
                             title = 'UltraWide Zoom',
                             icon = 'aspect_ratio',
                             items = {
                                 -- We read anime_cache["zoom_mode"] directly
                                 { title = '1. Fit-to-Zoom (Original)', value = 'script-message zoom-mode-fit', active = (anime_cache["zoom_mode"] == "fit") },
                                 { title = '2. Fill-to-Zoom (Force)',   value = 'script-message zoom-mode-fill', active = (anime_cache["zoom_mode"] == "fill") },
                                 { title = '3. Crop-to-Zoom (Smart)',   value = 'script-message zoom-mode-crop', active = (anime_cache["zoom_mode"] == "crop") },
                             }
                         },
						 { title = "====(Quality Toggles)====", value = "ignore", bold = true },
                         { title = "Shaders: Toggle ON/OFF", value = "script-message toggle-global-shaders", active = get_anime_state("shaders_enabled") },
                         -- [RENAMED] SD Mode (NNEDI)
                         { 
                            title = 'SD Mode (NNEDI): ' .. (get_anime_state("sd_texture") and "Texture" or "Clean"), 
                            value = 'script-message toggle-hq-sd', 
                            active = get_anime_state("sd_texture"),
                            -- Locked if we are in SD and FSRCNNX profile is running
                            muted = (get_anime_state("current_res_label") == "SD" and get_anime_state("fsrcnnx_running")),
                            hint = (get_anime_state("current_res_label") == "SD" and get_anime_state("fsrcnnx_running")) and "(Locked by FSRCNNX)" or ""
                         },
                         
                         -- [RENAMED] SD/HD Logic
                         { 
                            title = 'SD/HD Logic: ' .. (get_anime_state("fsrcnnx_running") and "FSRCNNX" or "NNEDI3"), 
                            value = 'script-message toggle-hq-hd-nnedi', 
                            active = get_anime_state("fsrcnnx_running") 
                         },
                         
                         { 
                            title = "Adaptive Sharpen: " .. (get_anime_state("sharpen_active") and "ON" or "OFF"), 
                            value = "script-message toggle-adaptive-sharpen", 
                            active = get_anime_state("sharpen_active"),
                            muted = not get_anime_state("shaders_enabled"), 
                            hint = not get_anime_state("shaders_enabled") and "Locked (Master OFF)" or ""
                         },

                         {
                             title = 'Anime Line Thinner', -- [v4.5] Anime Line Thinner Toggle
                             value = 'script-message toggle-line-thinner',
                             active = get_anime_state("line_thinner_enabled"),
                             -- Dims the text if the parent Fidelity mode is not active
                             muted = not (get_anime_state("is_anime_context") and not get_anime_state("fidelity_active"))
                         },
						 
		-- [v2.2] FSRCNNX Swapper (Main Menu Version)
        {
            -- [FIXED] Title now matches Controller (Res / Context)
            title = "Swap FSRCNNX (" .. (get_anime_state("current_res_label") or "N/A") .. " / " .. (get_anime_state("active_context_label") or "LIVE"):upper() .. ")",
            icon = "shutter_speed",
            muted = not get_anime_state("fsrcnnx_running"),
            items = {
                { title = "== Variants (" .. (get_anime_state("active_context_label") or ""):upper() .. ") ==", value = "ignore", bold = true },
                
                -- Standard Variants
                { title = "FSRCNNX (Standard 16)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_16-0-4-1.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_16-0-4-1.glsl" },
                { title = "FSRCNNX (Standard 8)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_8-0-4-1.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_8-0-4-1.glsl" },

                -- Custom Variants
                { title = "FSRCNNX (Anime Mild)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_16-0-4-1_enhance_anime.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_enhance_anime.glsl" },
                { title = "FSRCNNX (Anime Aggressive)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_16-0-4-1_anime_enhance.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_anime_enhance.glsl" },
                { title = "FSRCNNX (Anime Distort)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_16-0-4-1_anime_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_anime_distort.glsl" },
                { title = "FSRCNNX (Anime Distort 1x Filter)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x1_16-0-4-1_anime_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x1_16-0-4-1_anime_distort.glsl" },
                { title = "FSRCNNX (Line Art)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_8-0-4-1_LineArt.glsl" },
                { title = "FSRCNNX (General Distort)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_16-0-4-1_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_distort.glsl" },
                { title = "FSRCNNX (General Distort 1x Filter)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x1_16-0-4-1_distort.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x1_16-0-4-1_distort.glsl" },
                { title = "FSRCNNX (Enhance General)", active = (get_anime_state("active_fsrcnnx") == "~~/shaders/FSRCNNX_x2_16-0-4-1_enhance.glsl"), value = "script-message set-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/FSRCNNX_x2_16-0-4-1_enhance.glsl" },
                { title = "RESET TO DEFAULT", value = "script-message reset-resolution-shader fsrcnnx " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD"), bold = true }
            }
        },

        -- [v2.2] NNEDI3 Swapper (Main Menu Version)
        {
            -- [FIXED] Title now matches Controller (Res / Context)
            title = "Swap NNEDI3 (" .. (get_anime_state("current_res_label") or "N/A") .. " / " .. (get_anime_state("active_context_label") or "LIVE"):upper() .. ")",
            icon = "architecture",
            muted = not get_anime_state("nnedi_running"), 
            items = {
                { title = "== Neurons (" .. (get_anime_state("active_context_label") or ""):upper() .. ") ==", value = "ignore", bold = true },
                { title = "NNEDI3 (256 - Ultra)", active = (get_anime_state("active_nnedi") == "~~/shaders/nnedi3-nns256-win8x4.hook"), value = "script-message set-resolution-shader nnedi " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/nnedi3-nns256-win8x4.hook" },
                { title = "NNEDI3 (128 - High)",  active = (get_anime_state("active_nnedi") == "~~/shaders/nnedi3-nns128-win8x4.hook"), value = "script-message set-resolution-shader nnedi " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/nnedi3-nns128-win8x4.hook" },
                { title = "NNEDI3 (64 - Mid)",    active = (get_anime_state("active_nnedi") == "~~/shaders/nnedi3-nns64-win8x4.hook"),  value = "script-message set-resolution-shader nnedi " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/nnedi3-nns64-win8x4.hook" },
                { title = "NNEDI3 (32 - Low)",    active = (get_anime_state("active_nnedi") == "~~/shaders/nnedi3-nns32-win8x4.hook"),  value = "script-message set-resolution-shader nnedi " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/nnedi3-nns32-win8x4.hook" },
                { title = "== Window Variants ==", value = "ignore", bold = true },
                { title = "NNEDI3 (nns256 win8x6)", active = (get_anime_state("active_nnedi") == "~~/shaders/nnedi3-nns256-win8x6.hook"), value = "script-message set-resolution-shader nnedi " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD") .. " ~~/shaders/nnedi3-nns256-win8x6.hook" },
                { title = "RESET TO DEFAULT",       value = "script-message reset-resolution-shader nnedi " .. (get_anime_state("active_context_label") or "live") .. " " .. (get_anime_state("current_res_label") or "SD"), bold = true }
            }
        },


                    }
                },

                -- 4. Hardware & Power
                {
                    title = 'Hardware & Power',
                    icon = 'memory',
                    items = {
                        { title = 'Power Mode: ' .. (get_anime_state("power_active") and "Eco" or "Perf"), value = 'script-binding toggle-power', active = get_anime_state("power_active") },
                        { title = 'RTX VSR: ' .. (get_anime_state("vsr_active") and "ON" or "OFF"), value = 'script-binding toggle-vsr', active = get_anime_state("vsr_active") },
                    }
                },

                -- 5. Audio & HDR
                {
                    title = 'Audio & HDR',
                    icon = 'volume_up',
                    items = {
						-- [NEW] Audio-Only Profile Toggle
						{
							title = 'Audio-Only Profile',
							hint = get_anime_state("audio_only_mode_state") or "Auto",
							value = 'script-message toggle-audio-only',
							active = get_anime_state("audio_only_mode_state") == "Auto"
						},
						-- [NEW] Night Mode
                        { title = 'Audio: Night Mode (DRC)', value = 'script-message toggle-audio-nightmode', active = get_anime_state("night_mode") },
						{ title = 'Audio: Spatial Mode', value = 'script-message toggle-audio-spatial', active = get_anime_state("spatial_active") },
                        { title = 'Audio: Toggle 7.1 Upmix', value = 'script-message toggle-audio-upmix', active = get_anime_state("audio_upmix") },
                        { title = 'Audio: Toggle Passthrough', value = 'script-message toggle-audio-passthrough', active = get_anime_state("audio_passthrough") },
                        {
                            title = "HDR Switch Mode",
                            icon = "hdr_on",
                            items = {
                                { title = "Auto (Detected)", active = (get_anime_state("hdr_display_mode") == "auto"), value = "script-message set-hdr-display-mode auto" },
                                { title = "HDR Display (Passthrough)", active = (get_anime_state("hdr_display_mode") == "hdr"), value = "script-message set-hdr-display-mode hdr" },
                                { title = "SDR Display (Tone-Map)", active = (get_anime_state("hdr_display_mode") == "sdr"), value = "script-message set-hdr-display-mode sdr" },
                            }
                        },
						tm_menu,
						
						-- [NEW] Target Peak Sub-Menu
            {
                title = "Target Peak (Brightness)",
                icon = "wb_sunny",
                items = (function()
                    local current_peak = mp.get_property("target-peak") or "auto"
                    local is_std = (current_peak=="auto" or current_peak=="100" or current_peak=="200" or current_peak=="300" or current_peak=="400" or current_peak=="600" or current_peak=="1000")
                    
                    return {
                       { title = "Auto (Default)", value = "script-message save-target-peak auto", active = (current_peak == "auto") },
                       { title = "100 nits (Dim Monitor)", value = "script-message save-target-peak 100", active = (current_peak == "100") },
                       { title = "200 nits (Standard)", value = "script-message save-target-peak 200", active = (current_peak == "200") },
                       { title = "300 nits (Bright LCD)", value = "script-message save-target-peak 300", active = (current_peak == "300") },
                       { title = "400 nits (HDR400)", value = "script-message save-target-peak 400", active = (current_peak == "400") },
                       { title = "600 nits (HDR600)", value = "script-message save-target-peak 600", active = (current_peak == "600") },
                       { title = "1000 nits (High-End)", value = "script-message save-target-peak 1000", active = (current_peak == "1000") },

                    }
                end)()
            },
						
					}
                },
				
				-- [NEW] Smart Features
                {
                    title = 'Smart Cards',
                    icon = 'smart_toy',
                    items = {
                        { title = 'History CARD', value = 'script-message toggle-history', active = get_anime_state("history_enabled") }, -- [v4.5] History Card Toggle
                        { title = 'Skip Intro/OP/ED CARD', value = 'script-message toggle-skip-intro', active = get_anime_state("skip_intro_enabled") },
                        { title = 'Up Next CARD', value = 'script-message toggle-up-next', active = get_anime_state("up_next_enabled") },
                        { title = 'Track Selector: ' .. (get_anime_state("track_selector_enabled") and 'AUTO' or 'DISABLED'), value = 'script-message toggle-track-selector', active = get_anime_state("track_selector_enabled") },
                    }
                },
				
				{
					title = 'System',
					icon = 'build',
					items = {
                        { title = 'Check for Updates', value = 'script-message check-for-updates', icon = 'update' },
                        -- [UPDATED] Replaced Version Info with Stats Overlay
                        { title = 'Show Statistics', value = 'script-binding toggle-stats', icon = 'info' },
                    }
				},	
				
                -- Advanced Controls Shortcut
                { title = 'Advanced Controls...', icon = 'tune', value = 'script-binding uosc/open-controls-menu', bold = true, active = true },
            },
        },

        {
            title = t('Utils'),
            items = {
                {
                    title = t('Aspect ratio'),
                    items = {
                        {title = t('Default'), value = 'set video-aspect-override no'},
                        {title = '16:9', value = 'set video-aspect-override "16:9"'},
                        {title = '4:3', value = 'set video-aspect-override "4:3"'},
                        {title = '2.35:1', value = 'set video-aspect-override "2.35:1"'},
                    },
                },
                {title = t('Audio devices'), value = 'script-binding uosc/audio-device'},
                {title = t('Editions'), value = 'script-binding uosc/editions'},
                {title = t('Screenshot'), value = 'async screenshot'},
                {title = t('Key bindings'), value = 'script-binding uosc/keybinds'},
                {title = t('Show in directory'), value = 'script-binding uosc/show-in-directory'},
                {title = t('Open config folder'), value = 'script-binding uosc/open-config-directory'},
                {title = t('Update uosc'), value = 'script-binding uosc/update'},
            },
        },
        {title = t('Quit'), value = 'quit'},
    }

end

--[[ STATE ]]

display = {ax = 0, ay = 0, bx = 1280, by = 720, width = 1280, height = 720, initialized = false}
cursor = require('lib/cursor')
state = {
	platform = (function()
		local platform = mp.get_property_native('platform')
		if platform then
			if itable_index_of({'windows', 'darwin'}, platform) then return platform end
		else
			if os.getenv('windir') ~= nil then return 'windows' end
			local homedir = os.getenv('HOME')
			if homedir ~= nil and string.sub(homedir, 1, 6) == '/Users' then return 'darwin' end
		end
		return 'linux'
	end)(),
	cwd = mp.get_property('working-directory'),
	path = nil, -- current file path or URL
	history = {}, -- history of last played files stored as full paths
	time = nil, -- current media playback time
	speed = 1,
	---@type number|nil
	duration = nil, -- current media duration
	max_seconds = nil, -- max seconds the time in timeline is expected to reach, accounted for speed
	time_human = nil, -- current playback time in human format
	destination_time_human = nil, -- depends on options.destination_time
	pause = mp.get_property_native('pause'),
	ime_active = mp.get_property_native('input-ime'),
	chapters = {},
	chapter_ranges = {},
	border = mp.get_property_native('border'),
	title_bar = mp.get_property_native('title-bar'),
	fullscreen = mp.get_property_native('fullscreen'),
	maximized = mp.get_property_native('window-maximized'),
	fullormaxed = mp.get_property_native('fullscreen') or mp.get_property_native('window-maximized'),
	render_timer = nil,
	render_last_time = 0,
	volume = mp.get_property_native('volume'),
	volume_max = mp.get_property_native('volume-max'),
	mute = nil,
	type = nil, -- video,image,audio
	is_idle = false,
	is_video = false,
	is_audio = false, -- true if file is audio only (mp3, etc)
	is_image = false,
	is_stream = false,
	has_image = false,
	has_audio = false,
	has_sub = false,
	has_chapter = false,
	has_playlist = false,
	shuffle = options.shuffle,
	---@type nil|{pos: number; paths: string[]}
	shuffle_history = nil,
	on_shuffle = function() state.shuffle_history = nil end,
	mouse_bindings_enabled = false,
	uncached_ranges = nil,
	cache = nil,
	cache_buffering = 100,
	cache_underrun = false,
	cache_duration = nil,
	core_idle = false,
	eof_reached = false,
	render_delay = config.render_delay,
	playlist_count = 0,
	playlist_pos = 0,
	margin_top = 0,
	margin_bottom = 0,
	margin_left = 0,
	margin_right = 0,
	hidpi_scale = 1,
	scale = 1,
	radius = 0,
}
buttons = require('lib/buttons')
thumbnail = {width = 0, height = 0, disabled = false}
external = {} -- Properties set by external scripts
key_binding_overwrites = {} -- Table of key_binding:mpv_command
Elements = require('elements/Elements')
Menu = require('elements/Menu')

-- State dependent utilities
require('lib/utils')
require('lib/text')
require('lib/ass')
require('lib/menus')

-- Determine path to ziggy
do
	local bin = 'ziggy-' .. (state.platform == 'windows' and 'windows.exe' or state.platform)
	config.ziggy_path = os.getenv('MPV_UOSC_ZIGGY') or join_path(mp.get_script_directory(), join_path('bin', bin))
end

--[[ STATE UPDATERS ]]

function update_display_dimensions()
	state.scale = (state.hidpi_scale or 1) * (state.fullormaxed and options.scale_fullscreen or options.scale)
	state.radius = round(options.border_radius * state.scale)
	local real_width, real_height = mp.get_osd_size()
	if real_width <= 0 then return end
	display.bx, display.width, display.by, display.height = real_width, real_width, real_height, real_height
	display.initialized = true

	-- Tell elements about this
	Elements:trigger('display')

	-- Some elements probably changed their rectangles as a reaction to `display`
	Elements:update_proximities()
	request_render()
end

function update_fullormaxed()
	state.fullormaxed = state.fullscreen or state.maximized
	update_display_dimensions()
	Elements:trigger('prop_fullormaxed', state.fullormaxed)
	cursor:leave()
end

function update_duration()
	local duration = state._duration and ((state.rebase_start_time == false and state.start_time)
		and (state._duration + state.start_time) or state._duration)
	set_state('duration', duration)
	update_human_times()
end

function update_human_times()
	state.speed = state.speed or 1
	if state.time then
		if state.duration then
			if options.destination_time == 'playtime-remaining' then
				state.destination_time_human = format_time((state.time - state.duration) / state.speed, state.duration)
			elseif options.destination_time == 'total' then
				state.destination_time_human = format_time(state.duration, state.duration)
			else
				state.destination_time_human = format_time(state.time - state.duration, state.duration)
			end
		else
			state.destination_time_human = nil
		end
		state.time_human = format_time(state.time, state.duration or state.time)
	else
		state.time_human, state.destination_time_human = nil, nil
	end
end

-- Notifies other scripts such as console about where the unoccupied parts of the screen are.
function update_margins()
	if display.height == 0 then return end

	local function causes_margin(element)
		return element and element.enabled and (element:is_persistent() or element.min_visibility > 0.5)
	end
	local timeline, top_bar, controls, volume = Elements.timeline, Elements.top_bar, Elements.controls, Elements.volume
	-- margins are normalized to window size
	local left, right, top, bottom = 0, 0, 0, 0

	if causes_margin(controls) then
		bottom = (display.height - controls.ay) / display.height
	elseif causes_margin(timeline) then
		bottom = (display.height - timeline.ay) / display.height
	end

	if causes_margin(top_bar) then top = top_bar.title_by / display.height end

	if causes_margin(volume) then
		if options.volume == 'left' then
			left = volume.bx / display.width
		elseif options.volume == 'right' then
			right = volume.ax / display.width
		end
	end

	if top == state.margin_top and bottom == state.margin_bottom and
		left == state.margin_left and right == state.margin_right then
		return
	end

	state.margin_top = top
	state.margin_bottom = bottom
	state.margin_left = left
	state.margin_right = right

	if utils.shared_script_property_set then
		utils.shared_script_property_set('osc-margins', string.format('%f,%f,%f,%f', 0, 0, top, bottom))
	end
	mp.set_property_native('user-data/osc/margins', {l = left, r = right, t = top, b = bottom})

	if not options.adjust_osd_margins then return end
	local osd_margin_y, osd_margin_x, osd_factor_x = 0, 0, display.width / display.height * 720
	if config.osd_alignment_y == 'bottom' then
		osd_margin_y = round(bottom * 720)
	elseif config.osd_alignment_y == 'top' then
		osd_margin_y = round(top * 720)
	end
	if config.osd_alignment_x == 'left' then
		osd_margin_x = round(left * osd_factor_x)
	elseif config.osd_alignment_x == 'right' then
		osd_margin_x = round(right * osd_factor_x)
	end
	mp.set_property_native('osd-margin-y', osd_margin_y + config.osd_margin_y)
	mp.set_property_native('osd-margin-x', osd_margin_x + config.osd_margin_x)
end
function create_state_setter(name, callback)
	return function(_, value)
		set_state(name, value)
		if callback then callback() end
		request_render()
	end
end

function set_state(name, value)
	state[name] = value
	local state_event = state['on_' .. name]
	if state_event then state_event(value) end
	Elements:trigger('prop_' .. name, value)
end

function handle_file_end()
	local resume = false
	if not state.loop_file then
		if state.has_playlist then
			resume = state.shuffle and navigate_playlist(1)
		else
			resume = options.autoload and navigate_directory(1)
		end
	end
	-- Resume only when navigation happened
	if resume then mp.command('set pause no') end
end
local file_end_timer = mp.add_timeout(1, handle_file_end)
file_end_timer:kill()

function load_file_index_in_current_directory(index)
	if not state.path or is_protocol(state.path) then return end

	local serialized = serialize_path(state.path)
	if serialized and serialized.dirname then
		local files, _dirs, error = read_directory(serialized.dirname, {
			types = config.types.load,
			hidden = options.show_hidden_files,
		})

		if error then
			msg.error(error)
			return
		end

		sort_strings(files)
		if index < 0 then index = #files + index + 1 end

		if files[index] then
			mp.commandv('loadfile', join_path(serialized.dirname, files[index]))
		end
	end
end

function update_render_delay(name, fps)
	if fps then state.render_delay = 1 / fps end
end

function observe_display_fps(name, fps)
	if fps then
		mp.unobserve_property(update_render_delay)
		mp.unobserve_property(observe_display_fps)
		mp.observe_property('display-fps', 'native', update_render_delay)
	end
end

--[[ STATE HOOKS ]]

mp.register_event('file-loaded', function()
	local path = normalize_path(mp.get_property_native('path'))
	itable_delete_value(state.history, path)
	state.history[#state.history + 1] = path
	set_state('path', path)

	-- Flash top bar on requested file types
	for _, type in ipairs(config.top_bar_flash_on) do
		if state['is_' .. type] then
			Elements:flash({'top_bar'})
			break
		end
	end
end)
mp.register_event('end-file', function(event)
    -- [v4.5] History Save Logic
    local is_url = active_video.path and active_video.path:match("^%a[%w.+-]-://")

    if active_video.path and not is_url and get_anime_state("history_enabled") then
        local final_percent = active_video.percent
        if event.reason == "eof" then final_percent = 100 end

        -- Save if we watched at least 1% or reached End of File
        if final_percent > 1 or event.reason == "eof" then
            -- Remove duplicate to bubble it to the top
            for i, entry in ipairs(watch_history) do
                if entry.path == active_video.path then table.remove(watch_history, i) break end
            end

            -- Insert at top
            table.insert(watch_history, 1, {
                path = active_video.path,
                title = active_video.title,
                percent = final_percent
            })

            -- Prune to max 50
            while #watch_history > 50 do table.remove(watch_history) end
            save_watch_history()
        end
    end

    -- Clear active state
    active_video.path = nil

    -- [ORIGINAL UOSC LOGIC]
    set_state('path', nil)
    if event.reason == 'eof' then
        if file_end_timer then file_end_timer:kill() end
        if handle_file_end then handle_file_end() end
    end
end)
mp.observe_property('playback-time', 'number', create_state_setter('time', function()
	-- Create a file-end event that triggers right before file ends
	file_end_timer:kill()
	if state.duration and state.time and not state.pause then
		local remaining = (state.duration - state.time) / state.speed
		if remaining < 5 then
			local timeout = remaining - 0.02
			if timeout > 0 then
				file_end_timer.timeout = timeout
				file_end_timer:resume()
			else
				handle_file_end()
			end
		end
	end

	update_human_times()
end))
mp.observe_property('rebase-start-time', 'bool', create_state_setter('rebase_start_time', update_duration))
mp.observe_property('demuxer-start-time', 'number', create_state_setter('start_time', update_duration))
mp.observe_property('duration', 'number', create_state_setter('_duration', update_duration))
mp.observe_property('speed', 'number', create_state_setter('speed', update_human_times))
mp.observe_property('track-list', 'native', function(name, value)
	-- checks the file dispositions
	local types = {sub = 0, image = 0, audio = 0, video = 0}
	for _, track in ipairs(value) do
		if track.type == 'video' then
			if track.image or track.albumart then
				types.image = types.image + 1
			else
				types.video = types.video + 1
			end
		elseif types[track.type] then
			types[track.type] = types[track.type] + 1
		end
	end
	set_state('is_audio', types.video == 0 and types.audio > 0)
	set_state('is_image', types.image > 0 and types.video == 0 and types.audio == 0)
	set_state('has_image', types.image > 0)
	set_state('has_audio', types.audio > 0)
	set_state('has_many_audio', types.audio > 1)
	set_state('has_sub', types.sub > 0)
	set_state('has_many_sub', types.sub > 1)
	set_state('is_video', types.video > 0)
	set_state('has_many_video', types.video > 1)
	set_state('type', state.is_video and 'video' or state.is_audio and 'audio' or state.is_image and 'image' or nil)
	update_load_types()
	Elements:trigger('dispositions')
end)
mp.observe_property('editions', 'number', function(_, editions)
	if editions then set_state('has_many_edition', editions > 1) end
	Elements:trigger('dispositions')
end)
mp.observe_property('chapter-list', 'native', function(_, chapters)
	local chapters, chapter_ranges = serialize_chapters(chapters), {}
	if chapters then chapters, chapter_ranges = serialize_chapter_ranges(chapters) end
	set_state('chapters', chapters)
	set_state('chapter_ranges', chapter_ranges)
	set_state('has_chapter', #chapters > 0)
	Elements:trigger('dispositions')
end)
mp.observe_property('border', 'bool', create_state_setter('border'))
mp.observe_property('title-bar', 'bool', create_state_setter('title_bar'))
mp.observe_property('loop-file', 'native', create_state_setter('loop_file'))
mp.observe_property('ab-loop-a', 'number', create_state_setter('ab_loop_a'))
mp.observe_property('ab-loop-b', 'number', create_state_setter('ab_loop_b'))
mp.observe_property('playlist-pos-1', 'number', create_state_setter('playlist_pos'))
mp.observe_property('playlist-count', 'number', function(_, value)
	set_state('playlist_count', value)
	set_state('has_playlist', value > 1)
	Elements:trigger('dispositions')
end)
mp.observe_property('fullscreen', 'bool', create_state_setter('fullscreen', update_fullormaxed))
mp.observe_property('window-maximized', 'bool', create_state_setter('maximized', update_fullormaxed))
mp.observe_property('idle-active', 'bool', function(_, idle)
	set_state('is_idle', idle)
	Elements:trigger('dispositions')
	mp.commandv('script-message-to', 'thumbfast', 'clear')
end)
mp.observe_property('pause', 'bool', create_state_setter('pause', function() file_end_timer:kill() end))
mp.observe_property('volume', 'number', create_state_setter('volume'))
mp.observe_property('volume-max', 'number', create_state_setter('volume_max'))
mp.observe_property('mute', 'bool', create_state_setter('mute'))
mp.observe_property('osd-dimensions', 'native', function(name, val)
	update_display_dimensions()
	request_render()
end)
mp.observe_property('display-hidpi-scale', 'native', create_state_setter('hidpi_scale', update_display_dimensions))
mp.observe_property('cache', 'string', create_state_setter('cache'))
mp.observe_property('cache-buffering-state', 'number', create_state_setter('cache_buffering'))
mp.observe_property('demuxer-via-network', 'native', create_state_setter('is_stream', function()
	Elements:trigger('dispositions')
end))
mp.observe_property('demuxer-cache-state', 'native', function(prop, cache_state)
	local cached_ranges, bof, eof, uncached_ranges = nil, nil, nil, nil
	if cache_state then
		cached_ranges, bof, eof = cache_state['seekable-ranges'], cache_state['bof-cached'], cache_state['eof-cached']
		set_state('cache_underrun', cache_state['underrun'])
		set_state('cache_duration', not cache_state.eof and cache_state['cache-duration'] or nil)
	else
		cached_ranges = {}
		set_state('cache_underrun', false)
	end

	if not (state.duration and (#cached_ranges > 0 or state.cache == 'yes' or
			(state.cache == 'auto' and state.is_stream))) then
		if state.uncached_ranges then set_state('uncached_ranges', nil) end
		set_state('cache_duration', nil)
		return
	end

	-- Normalize
	local ranges = {}
	for _, range in ipairs(cached_ranges) do
		ranges[#ranges + 1] = {
			math.max(range['start'] or 0, 0),
			math.min(range['end'] or state.duration --[[@as number]], state.duration),
		}
	end
	table.sort(ranges, function(a, b) return a[1] < b[1] end)
	if bof then ranges[1][1] = 0 end
	if eof then ranges[#ranges][2] = state.duration end
	-- Invert cached ranges into uncached ranges, as that's what we're rendering
	local inverted_ranges = {{0, state.duration}}
	for _, cached in pairs(ranges) do
		inverted_ranges[#inverted_ranges][2] = cached[1]
		inverted_ranges[#inverted_ranges + 1] = {cached[2], state.duration}
	end
	uncached_ranges = {}
	local last_range = nil
	for _, range in ipairs(inverted_ranges) do
		if last_range and last_range[2] + 0.5 > range[1] then -- fuse ranges
			last_range[2] = range[2]
		else
			if range[2] - range[1] > 0.5 then -- skip short ranges
				uncached_ranges[#uncached_ranges + 1] = range
				last_range = range
			end
		end
	end

	set_state('uncached_ranges', uncached_ranges)
end)
mp.observe_property('display-fps', 'native', observe_display_fps)
mp.observe_property('estimated-display-fps', 'native', update_render_delay)
mp.observe_property('eof-reached', 'native', create_state_setter('eof_reached'))
mp.observe_property('core-idle', 'native', create_state_setter('core_idle'))

--[[ KEY BINDS ]]

-- Adds a key binding that respects rerouting set by `key_binding_overwrites` table.
---@param name string
---@param callback fun(event: table)
---@param flags nil|string
function bind_command(name, callback, flags)
	mp.add_key_binding(nil, name, function(...)
		if key_binding_overwrites[name] then
			mp.command(key_binding_overwrites[name])
		else
			callback(...)
		end
	end, flags)
end

bind_command('toggle-ui', function() Elements:toggle({'timeline', 'controls', 'volume', 'top_bar'}) end)
bind_command('flash-ui', function() Elements:flash({'timeline', 'controls', 'volume', 'top_bar'}) end)
bind_command('flash-timeline', function() Elements:flash({'timeline'}) end)
bind_command('flash-top-bar', function() Elements:flash({'top_bar'}) end)
bind_command('flash-volume', function() Elements:flash({'volume'}) end)
bind_command('flash-speed', function() Elements:flash({'speed'}) end)
bind_command('flash-pause-indicator', function() Elements:flash({'pause_indicator'}) end)
bind_command('flash-progress', function() Elements:flash({'progress'}) end)
bind_command('toggle-progress', function() Elements:maybe('timeline', 'toggle_progress') end)
bind_command('toggle-title', function() Elements:maybe('top_bar', 'toggle_title') end)
bind_command('decide-pause-indicator', function() Elements:maybe('pause_indicator', 'decide') end)
-- [FIX: BYPASS CACHE AND FORCE REFRESH]
bind_command('menu', function() 
    if Menu:is_open('menu') then
        Menu:close()
    else
        -- Direct call to open_command_menu ensures we always use fresh items
        -- bypassing any internal caching in toggle_menu_with_items
        open_command_menu({ 
            type = 'menu', 
            items = create_default_menu_items(),
            search_style = 'palette' 
        })
    end
end)

bind_command('menu-blurred', function() 
    if Menu:is_open('menu') then
        Menu:close()
    else
        open_command_menu({ 
            type = 'menu', 
            items = create_default_menu_items(),
            search_style = 'palette',
            mouse_nav = true 
        })
    end
end)
bind_command('keybinds', function()
	if Menu:is_open('keybinds') then
		Menu:close()
	else
		open_command_menu({type = 'keybinds', items = get_keybinds_items(), search_style = 'palette'})
	end
end)
bind_command('download-subtitles', open_subtitle_downloader)
bind_command('load-subtitles', create_track_loader_menu_opener({
	prop = 'sub',
	title = t('Load subtitles'),
	loaded_message = t('Loaded subtitles'),
	allowed_types = itable_join(config.types.video, config.types.subtitle),
}))
bind_command('load-audio', create_track_loader_menu_opener({
	prop = 'audio',
	title = t('Load audio'),
	loaded_message = t('Loaded audio'),
	allowed_types = itable_join(config.types.video, config.types.audio),
}))
bind_command('load-video', create_track_loader_menu_opener({
	prop = 'video',
	title = t('Load video'),
	loaded_message = t('Loaded video'),
	allowed_types = config.types.video,
}))
bind_command('subtitles', create_select_tracklist_type_menu_opener({
	title = t('Subtitles'),
	type = 'sub',
	prop = 'sid',
	enable_prop = 'sub-visibility',
	secondary = {prop = 'secondary-sid', icon = 'vertical_align_top', enable_prop = 'secondary-sub-visibility'},
	load_command = 'script-binding uosc/load-subtitles',
	download_command = 'script-binding uosc/download-subtitles',
}))
bind_command('audio', create_select_tracklist_type_menu_opener({
	title = t('Audio'), type = 'audio', prop = 'aid', load_command = 'script-binding uosc/load-audio',
}))
bind_command('video', create_select_tracklist_type_menu_opener({
	title = t('Video'), type = 'video', prop = 'vid', load_command = 'script-binding uosc/load-video',
}))
bind_command('playlist', create_self_updating_menu_opener({
	title = t('Playlist (Type to Search)'),
	type = 'playlist',
	list_prop = 'playlist',
    
    -- [SEARCH SETTINGS]
    search_style = 'palette',             -- Enables the search bar
    search_subtext = 'Type to search...', -- Adds the visual hint text
    
	footnote = t('Paste path or url to add.') .. ' ' .. t('%s to reorder.', 'ctrl+up/down/pgup/pgdn/home/end'),
	serializer = function(playlist)
		local items = {}
		local force_filename = mp.get_property_native('osd-playlist-entry') == 'filename'
		for index, item in ipairs(playlist) do
			local title = type(item.title) == 'string' and #item.title > 0 and item.title or false
			items[index] = {
				title = (not force_filename and title) and title
					or (is_protocol(item.filename) and item.filename or serialize_path(item.filename).basename),
				hint = tostring(index),
				active = item.current,
				value = index,
			}
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'playlist-pos-1', tostring(event.value)) end,
	on_paste = function(event) mp.commandv('loadfile', tostring(event.value), 'append') end,
	on_key = function(event)
		if event.id == 'ctrl+c' and event.selected_item then
			local payload = mp.get_property_native('playlist/' .. (event.selected_item.value - 1) .. '/filename')
			set_clipboard(payload)
		end
	end,
	on_move = function(event)
		local from, to = event.from_index, event.to_index
		mp.commandv('playlist-move', tostring(from - 1), tostring(to - (to > from and 0 or 1)))
	end,
	on_remove = function(event) mp.commandv('playlist-remove', tostring(event.value - 1)) end,
}))
-- [v4.5] History UOSC Bind
bind_command('history', function()
    local items = {}
    for i, entry in ipairs(watch_history) do
        local is_watched = entry.percent >= 95

        -- Visual Progress Bar Generator (10 blocks long)
        local bar_length = 10
        local filled_blocks = math.floor((entry.percent / 100) * bar_length + 0.5)
        local empty_blocks = bar_length - filled_blocks

        local progress_bar = string.rep("■", filled_blocks) .. string.rep("□", empty_blocks)

        local hint_text = is_watched and "Watched" or string.format("%s  %d%%", progress_bar, entry.percent)

        items[i] = {
            title = entry.title,
            hint = hint_text,
            icon = is_watched and "check_circle" or "schedule",
            value = string.format("loadfile %q", entry.path),
            muted = is_watched -- [NEW] Greys out the entry if watched
        }
    end

    if #items == 0 then
        items[1] = { title = "Watch history is empty", value = "ignore", bold = true, icon = "info", muted = true }
    end

    open_command_menu({
        type = 'history',
        title = t('Watch History'),
        items = items,
        search_style = 'palette'
    })
end)
bind_command('chapters', create_self_updating_menu_opener({
	title = t('Chapters'),
	type = 'chapters',
	list_prop = 'chapter-list',
	active_prop = 'chapter',
	serializer = function(chapters, current_chapter)
		local items = {}
		chapters = normalize_chapters(chapters)
		for index, chapter in ipairs(chapters) do
			items[index] = {
				title = chapter.title or '',
				hint = format_time(chapter.time, state.duration),
				value = index,
				active = index - 1 == current_chapter,
			}
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'chapter', tostring(event.value - 1)) end,
}))
bind_command('editions', create_self_updating_menu_opener({
	title = t('Editions'),
	type = 'editions',
	list_prop = 'edition-list',
	active_prop = 'current-edition',
	serializer = function(editions, current_id)
		local items = {}
		for _, edition in ipairs(editions or {}) do
			local edition_id_1 = tostring(edition.id + 1)
			items[#items + 1] = {
				title = edition.title or t('Edition %s', edition_id_1),
				hint = edition_id_1,
				value = edition.id,
				active = edition.id == current_id,
			}
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'edition', event.value) end,
}))
bind_command('show-in-directory', function()
	-- Ignore URLs
	if not state.path or is_protocol(state.path) then return end

	if state.platform == 'windows' then
		utils.subprocess_detached({args = {'explorer', '/select,', state.path .. ' '}, cancellable = false})
	elseif state.platform == 'darwin' then
		utils.subprocess_detached({args = {'open', '-R', state.path}, cancellable = false})
	elseif state.platform == 'linux' then
		local result = utils.subprocess({args = {'nautilus', state.path}, cancellable = false})

		-- Fallback opens the folder with xdg-open instead
		if result.status ~= 0 then
			utils.subprocess({args = {'xdg-open', serialize_path(state.path).dirname}, cancellable = false})
		end
	end
end)
bind_command('stream-quality', open_stream_quality_menu)
bind_command('open-file', open_open_file_menu)
bind_command('shuffle', function()
	set_state('shuffle', not state.shuffle)
	mp.osd_message(state.shuffle and t('Shuffle ON') or t('Shuffle OFF'))
end)
bind_command('items', function()
	if state.has_playlist then
		mp.command('script-binding uosc/playlist')
	else
		mp.command('script-binding uosc/open-file')
	end
end)
bind_command('next', function() navigate_item(1) end)
bind_command('prev', function() navigate_item(-1) end)
bind_command('next-file', function() navigate_directory(1) end)
bind_command('prev-file', function() navigate_directory(-1) end)
bind_command('first', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', '1')
	else
		load_file_index_in_current_directory(1)
	end
end)
bind_command('last', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', tostring(state.playlist_count))
	else
		load_file_index_in_current_directory(-1)
	end
end)
bind_command('first-file', function() load_file_index_in_current_directory(1) end)
bind_command('last-file', function() load_file_index_in_current_directory(-1) end)
bind_command('delete-file-prev', function() delete_file_navigate(-1) end)
bind_command('delete-file-next', function() delete_file_navigate(1) end)
bind_command('delete-file-quit', function()
	mp.command('stop')
	if state.path and not is_protocol(state.path) then delete_file(state.path) end
	mp.command('quit')
end)
bind_command('menu-prev', function() Elements:maybe('menu', 'navigate_by_items', -1) end)
bind_command('menu-next', function() Elements:maybe('menu', 'navigate_by_items', 1) end)
bind_command('menu-prev-page', function() Elements:maybe('menu', 'navigate_by_page', -1) end)
bind_command('menu-next-page', function() Elements:maybe('menu', 'navigate_by_page', 1) end)
bind_command('menu-start', function() Elements:maybe('menu', 'navigate_by_items', -math.huge) end)
bind_command('menu-end', function() Elements:maybe('menu', 'navigate_by_items', math.huge) end)
bind_command('menu-activate', function() Elements:maybe('menu', 'activate_selected_item') end)
bind_command('menu-back', function() Elements:maybe('menu', 'back') end)
bind_command('audio-device', create_self_updating_menu_opener({
	title = t('Audio devices'),
	type = 'audio-device-list',
	list_prop = 'audio-device-list',
	active_prop = 'audio-device',
	serializer = function(audio_device_list, current_device)
		current_device = current_device or 'auto'
		local ao = mp.get_property('current-ao') or ''
		local items = {}
		for _, device in ipairs(audio_device_list) do
			if device.name == 'auto' or string.match(device.name, '^' .. ao) then
				local hint = string.match(device.name, ao .. '/(.+)')
				if not hint then hint = device.name end
				items[#items + 1] = {
					title = device.description:sub(1, 7) == 'Default'
						and t('Default %s', device.description:sub(9))
						or device.description,
					hint = hint,
					active = device.name == current_device,
					value = device.name,
				}
			end
		end
		return items
	end,
	on_activate = function(event) mp.commandv('set', 'audio-device', event.value) end,
}))
bind_command('paste', function()
	local has_playlist = mp.get_property_native('playlist-count') > 1
	mp.commandv('script-binding', 'uosc/paste-to-' .. (has_playlist and 'playlist' or 'open'))
end)
bind_command('paste-to-open', function()
	local payload = get_clipboard()
	if payload then mp.commandv('loadfile', payload) end
end)
bind_command('paste-to-playlist', function()
	-- If there's no file loaded, we use `paste-to-open`, which both opens and adds to playlist
	if state.is_idle then
		mp.commandv('script-binding', 'uosc/paste-to-open')
	else
		local payload = get_clipboard()
		if payload then
			mp.commandv('loadfile', payload, 'append')
			mp.commandv('show-text', t('Added to playlist') .. ': ' .. payload, 3000)
		end
	end
end)
bind_command('copy-to-clipboard', function()
	if state.path then
		set_clipboard(state.path)
	else
		mp.commandv('show-text', t('Nothing to copy'), 3000)
	end
end)
bind_command('open-config-directory', function()
	local config_path = mp.command_native({'expand-path', '~~/mpv.conf'})
	local config = serialize_path(normalize_path(config_path))

	if config then
		local args

		if state.platform == 'windows' then
			args = {'explorer', '/select,', config.path}
		elseif state.platform == 'darwin' then
			args = {'open', '-R', config.path}
		elseif state.platform == 'linux' then
			args = {'xdg-open', config.dirname}
		end

		utils.subprocess_detached({args = args, cancellable = false})
	else
		msg.error('Couldn\'t serialize config path "' .. config_path .. '".')
	end
end)
bind_command('update', function()
	if not Elements:has('updater') then require('elements/Updater'):new() end
end)

--[[ MESSAGE HANDLERS ]]


mp.register_script_message('show-submenu', function(id) toggle_menu_with_items({submenu = id}) end)
mp.register_script_message('show-submenu-blurred', function(id)
	toggle_menu_with_items({submenu = id, mouse_nav = true})
end)
mp.register_script_message('open-menu', function(json, submenu_id)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('open-menu: received json didn\'t produce a table with menu configuration')
	else
		open_command_menu(data, {submenu = submenu_id, on_close = data.on_close})
	end
end)
mp.register_script_message('update-menu', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('update-menu: received json didn\'t produce a table with menu configuration')
	else
		local menu = data.type and Menu:is_open(data.type)
		if menu then menu:update(data) end
	end
end)
mp.register_script_message('select-menu-item', function(type, item_index, menu_id)
	local menu = Menu:is_open(type)
	local index = tonumber(item_index)
	if menu and index and not menu.mouse_nav then
		index = round(index)
		if index > 0 and index <= #menu.current.items then
			menu:select_index(index, menu_id)
			menu:scroll_to_index(index, menu_id, true)
		end
	end
end)
mp.register_script_message('close-menu', function(type)
	if Menu:is_open(type) then Menu:close() end
end)

mp.register_script_message('menu-action', function(name, ...)
    local menu = Menu:is_open()
    if menu then
        local method = ({
            ['search-cancel'] = 'search_cancel',
            ['search-query-update'] = 'search_query_update',
        })[name]
        if method then menu[method](menu, ...) end
    end
end)

mp.register_script_message('thumbfast-info', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or not data.width or not data.height then
		thumbnail.disabled = true
		msg.error('thumbfast-info: received json didn\'t produce a table with thumbnail information')
	else
		thumbnail = data
		request_render()
	end
end)
mp.register_script_message('set', function(name, value)
	external[name] = value
	Elements:trigger('external_prop_' .. name, value)
end)
mp.register_script_message('toggle-elements', function(elements) Elements:toggle(comma_split(elements)) end)
mp.register_script_message('set-min-visibility', function(visibility, elements)
	local fraction = tonumber(visibility)
	local ids = comma_split(elements and elements ~= '' and elements or 'timeline,controls,volume,top_bar')
	if fraction then Elements:set_min_visibility(clamp(0, fraction, 1), ids) end
end)
mp.register_script_message('flash-elements', function(elements) Elements:flash(comma_split(elements)) end)
mp.register_script_message('overwrite-binding', function(name, command) key_binding_overwrites[name] = command end)
mp.register_script_message('disable-elements', function(id, elements) Manager:disable(id, elements) end)

--[[ ELEMENTS ]]

-- Dynamic elements
local constructors = {
	window_border = require('elements/WindowBorder'),
	buffering_indicator = require('elements/BufferingIndicator'),
	pause_indicator = require('elements/PauseIndicator'),
	top_bar = require('elements/TopBar'),
	timeline = require('elements/Timeline'),
	controls = options.controls and options.controls ~= 'never' and require('elements/Controls'),
	volume = itable_index_of({'left', 'right'}, options.volume) and require('elements/Volume'),
}

-- Required elements
require('elements/Curtain'):new()

-- Element manager
-- Handles creating and destroying elements based on disabled_elements user+script config.
Manager = {
	-- Managed disable-able element IDs
	_ids = itable_join(table_keys(constructors), {'idle_indicator', 'audio_indicator'}),
	---@type table<string, string[]> A map of clients and a list of element ids they disable
	_disabled_by = {},
	---@type table<string, boolean>
	disabled = {},
}

-- Set client and which elements it wishes disabled. To undo just pass an empty `element_ids` for the same `client`.
---@param client string
---@param element_ids string|string[]|nil `foo,bar` or `{'foo', 'bar'}`.
function Manager:disable(client, element_ids)
	self._disabled_by[client] = comma_split(element_ids)
	---@diagnostic disable-next-line: deprecated
	self.disabled = create_set(itable_join(unpack(table_values(self._disabled_by))))
	self:_commit()
end

function Manager:_commit()
	-- Create and destroy elements as needed
	for _, id in ipairs(self._ids) do
		local constructor = constructors[id]
		if not self.disabled[id] then
			if not Elements:has(id) and constructor then constructor:new() end
		else
			Elements:maybe(id, 'destroy')
		end
	end

	-- We use `on_display` event to tell elements to update their dimensions
	Elements:trigger('display')
end

-- Initial commit
Manager:disable('user', options.disable_elements)

-- [PHASE 7: LIVE STATE MIRROR (THE FIX)]
-- This listener waits for the Anime Controller to update status
local function on_anime_state_change(name, value)
    -- If the Main Menu is currently open, force it to redraw immediately
    if Menu:is_open('menu') then
        local items = create_default_menu_items()
        local json = utils.format_json({ type = 'menu', items = items })
        mp.commandv("script-message-to", "uosc", "update-menu", json)
    end
end


-- 4. Request state on load (in case Controller loaded first)
mp.register_event("file-loaded", function()
    -- Trigger the controller to resend state
    mp.commandv("script-message", "force-evaluate-profile") 
end)
