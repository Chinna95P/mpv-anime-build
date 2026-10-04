-- hdr_toys.lua  (mpv-anime-build integration)
-- Manages hdr-toys shader pipeline for both SDR and HDR content.
-- Opens a uosc menu (H / Ctrl+H) for tone/gamut picker, toggles, and options.
-- Remembers settings across sessions in ~~/script-opts/hdr_toys.conf.
--
-- Requirements: vo=gpu-next
-- Shaders:      ~~/shaders/hdr-toys/

local mp    = require 'mp'
local utils = require 'mp.utils'
local msg   = require 'mp.msg'
local opts  = require 'mp.options'

-------------------------------------------------
-- PERSISTENT OPTIONS  (script-opts/hdr_toys.conf)
-------------------------------------------------
local o = {
    enabled       = false,
    tone_mapping  = "astra",
    gamut_mapping = "bottosson",
    filmic        = false,
}
opts.read_options(o, "hdr_toys")

-------------------------------------------------
-- CATALOG
-------------------------------------------------
local TONE_MAPPERS = {
    { id = "astra",     label = "Astra (Recommended)" },
    { id = "bt2390",    label = "BT.2390" },
    { id = "bt2446a",   label = "BT.2446-A" },
    { id = "bt2446c",   label = "BT.2446-C" },
    { id = "linear",    label = "Linear (Pass-through)" },
    { id = "reinhard",  label = "Reinhard" },
    { id = "st2094-10", label = "ST2094-10" },
    { id = "st2094-40", label = "ST2094-40" },
    { id = "st2094-50", label = "ST2094-50" },
    { id = "uwa005-1",  label = "UWA005-1" },
    { id = "false",     label = "False Colors (Debug)" },
}

local GAMUT_MAPPERS = {
    { id = "bottosson", label = "Bottosson (Recommended)" },
    { id = "clip",      label = "Clip" },
    { id = "jedypod",   label = "Jedypod" },
    { id = "false",     label = "False Colors (Debug)" },
}

-------------------------------------------------
-- RUNTIME STATE
-------------------------------------------------
local state = {
    hdr_type    = "sdr", -- "pq", "hlg", "bt2020-sdr", or "sdr"
    applied     = false,
    inhibit_obs = false,
}

-------------------------------------------------
-- SETTINGS PERSISTENCE
-------------------------------------------------
local function save_settings()
    local path = mp.command_native({"expand-path", "~~/script-opts/hdr_toys.conf"})
    local f = io.open(path, "w")
    if not f then msg.warn("hdr_toys: cannot write settings"); return end
    f:write("enabled="       .. (o.enabled       and "yes" or "no") .. "\n")
    f:write("tone_mapping="  .. o.tone_mapping                       .. "\n")
    f:write("gamut_mapping=" .. o.gamut_mapping                      .. "\n")
    f:write("filmic="        .. (o.filmic         and "yes" or "no") .. "\n")
    f:close()
    msg.info("hdr_toys: saved settings")
end

-------------------------------------------------
-- SHADER HELPERS
-------------------------------------------------
local BASE = "~~/shaders/hdr-toys"

local function expand(rel)
    return mp.command_native({"expand-path", rel})
end

local function shader(subdir, name)
    return expand(BASE .. "/" .. subdir .. "/" .. name .. ".glsl")
end

local function is_hdr_shader(path)
    return path:find("hdr%-toys", 1, false) ~= nil or
           path:find("hdr-toys",  1, false) ~= nil
end

local function strip_hdr(shaders)
    local out = {}
    for _, s in ipairs(shaders or {}) do
        if not is_hdr_shader(s) then out[#out+1] = s end
    end
    return out
end

local function determine_hdr_type()
    local params = mp.get_property_native("video-params")
    if not params then return "sdr" end
    local primaries = params.primaries or ""
    local gamma     = params.gamma     or ""
    if primaries == "bt.2020" and gamma == "pq" then
        return "pq"
    elseif primaries == "bt.2020" and gamma == "hlg" then
        return "hlg"
    elseif primaries == "bt.2020" then
        return "bt2020-sdr"
    else
        return "sdr"
    end
end

local function hdr_toys_shaders(hdr_type)
    local list = {}
    list[#list+1] = shader("utils", "clip_both")

    if hdr_type == "pq" then
        list[#list+1] = shader("transfer-function", "pq_inv")
        list[#list+1] = shader("tone-mapping",      o.tone_mapping)
        list[#list+1] = shader("gamut-mapping",     o.gamut_mapping)
        list[#list+1] = shader("transfer-function", "bt1886")
    elseif hdr_type == "hlg" then
        list[#list+1] = shader("transfer-function", "hlg_inv")
        list[#list+1] = shader("tone-mapping",      o.tone_mapping)
        list[#list+1] = shader("gamut-mapping",     o.gamut_mapping)
        list[#list+1] = shader("transfer-function", "bt1886")
    elseif hdr_type == "bt2020-sdr" then
        list[#list+1] = shader("transfer-function", "bt1886_inv")
        list[#list+1] = shader("tone-mapping",      o.tone_mapping)
        list[#list+1] = shader("gamut-mapping",     o.gamut_mapping)
        list[#list+1] = shader("transfer-function", "bt1886")
    else -- standard SDR (BT.709)
        list[#list+1] = shader("transfer-function", "bt709_inv")
        list[#list+1] = shader("tone-mapping",      o.tone_mapping)
        list[#list+1] = shader("gamut-mapping",     o.gamut_mapping)
        list[#list+1] = shader("transfer-function", "bt709")
    end

    return list
end

local function set_shader_opts()
    mp.commandv("no-osd", "change-list", "glsl-shader-opts", "clr", "")
    mp.commandv("no-osd", "change-list", "glsl-shader-opts", "append", "auto_exposure_limit_positive=1.02")
    if o.filmic then
        mp.commandv("no-osd", "change-list", "glsl-shader-opts", "append", "auto_exposure_anchor=0.5")
        mp.commandv("no-osd", "change-list", "glsl-shader-opts", "append", "contrast_bias=0.15")
        mp.commandv("no-osd", "change-list", "glsl-shader-opts", "append", "chroma_correction_rate=3.0")
    end
end

-------------------------------------------------
-- APPLY / RESTORE
-------------------------------------------------
local SAVED = {}

local function apply_hdr_toys()
    if not o.enabled then return end
    state.hdr_type = determine_hdr_type()

    if not state.applied then
        SAVED = {
            ["target-colorspace-hint"] = mp.get_property("target-colorspace-hint"),
            ["target-prim"]            = mp.get_property("target-prim"),
            ["target-trc"]             = mp.get_property("target-trc"),
            ["tone-mapping"]           = mp.get_property("tone-mapping"),
            ["gamut-mapping-mode"]     = mp.get_property("gamut-mapping-mode"),
        }
    end

    mp.set_property("target-colorspace-hint", "no")
    if state.hdr_type == "pq" then
        mp.set_property("target-prim", "bt.2020")
        mp.set_property("target-trc",  "pq")
    elseif state.hdr_type == "hlg" then
        mp.set_property("target-prim", "bt.2020")
        mp.set_property("target-trc",  "hlg")
    elseif state.hdr_type == "bt2020-sdr" then
        mp.set_property("target-prim", "bt.2020")
        mp.set_property("target-trc",  "bt.1886")
    else
        mp.set_property("target-prim", "bt.709")
        mp.set_property("target-trc",  "bt.709")
    end
    mp.set_property("tone-mapping",       "clip")
    mp.set_property("gamut-mapping-mode", "clip")

    set_shader_opts()

    state.inhibit_obs = true
    local current = mp.get_property_native("glsl-shaders") or {}
    local merged  = strip_hdr(current)
    for _, s in ipairs(hdr_toys_shaders(state.hdr_type)) do merged[#merged+1] = s end
    mp.set_property_native("glsl-shaders", merged)
    state.inhibit_obs = false

    state.applied = true
    msg.info(string.format("hdr_toys: ON [%s / %s / %s%s]",
        state.hdr_type:upper(), o.tone_mapping, o.gamut_mapping, o.filmic and " / filmic" or ""))
end

local function restore_hdr_toys()
    if not state.applied then return end
    for prop, val in pairs(SAVED) do
        if val and val ~= "" then
            mp.set_property(prop, val)
        else
            mp.set_property(prop, "auto")
        end
    end
    SAVED = {}
    mp.commandv("no-osd", "change-list", "glsl-shader-opts", "clr", "")
    state.inhibit_obs = true
    local current = mp.get_property_native("glsl-shaders") or {}
    mp.set_property_native("glsl-shaders", strip_hdr(current))
    state.inhibit_obs = false
    state.applied = false
    msg.info("hdr_toys: OFF")
end

local function refresh_shaders()
    if not state.applied then return end
    state.inhibit_obs = true
    local current = mp.get_property_native("glsl-shaders") or {}
    local merged  = strip_hdr(current)
    for _, s in ipairs(hdr_toys_shaders(state.hdr_type)) do merged[#merged+1] = s end
    mp.set_property_native("glsl-shaders", merged)
    state.inhibit_obs = false
    set_shader_opts()
end

-------------------------------------------------
-- RE-ASSERT after profile changes wipe glsl-shaders
-------------------------------------------------
mp.observe_property("glsl-shaders", "native", function(_, shaders)
    if state.inhibit_obs or not state.applied then return end
    for _, s in ipairs(shaders or {}) do
        if is_hdr_shader(s) then return end
    end
    msg.info("hdr_toys: re-asserting shaders after profile change")
    state.inhibit_obs = true
    local merged = strip_hdr(shaders or {})
    for _, s in ipairs(hdr_toys_shaders(state.hdr_type)) do merged[#merged+1] = s end
    mp.set_property_native("glsl-shaders", merged)
    state.inhibit_obs = false
end)

-------------------------------------------------
-- VIDEO PARAMS / FILE LOADED OBSERVER
-------------------------------------------------
local function on_video_changed()
    state.hdr_type = determine_hdr_type()
    if o.enabled then
        apply_hdr_toys()
    else
        restore_hdr_toys()
    end
    update_menu()
end

mp.observe_property("video-params", "native", function(_, params)
    if not params then
        state.hdr_type = "sdr"
        restore_hdr_toys()
        update_menu()
        return
    end
    mp.add_timeout(0.1, on_video_changed)
end)

mp.register_event("file-loaded", function()
    mp.add_timeout(0.2, on_video_changed)
end)

-------------------------------------------------
-- OSD
-------------------------------------------------
local osd_ov    = mp.create_osd_overlay("ass-events")
local osd_timer = nil

local function show_osd(text)
    osd_ov.data = "{\\an7}{\\fs28}{\\q1}\\N\\N" .. text
    osd_ov:update()
    if osd_timer then osd_timer:kill() end
    osd_timer = mp.add_timeout(2.5, function() osd_ov:remove() end)
end

local CY = "{\\c&H00FFFF&}"
local CG = "{\\c&H00FF00&}"
local CR = "{\\c&H0000FF&}"
local CC = "{\\c&HFFFF00&}"
local CW = "{\\c&HFFFFFF&}"

-------------------------------------------------
-- UOSC MENU
-------------------------------------------------
local function build_menu_json()
    local mode_label = state.hdr_type == "pq" and "HDR10/PQ"
        or (state.hdr_type == "hlg" and "HLG"
        or (state.hdr_type == "bt2020-sdr" and "BT.2020 SDR" or "SDR"))

    local en_icon = o.enabled and "check_circle" or "radio_button_unchecked"
    local en_hint = o.enabled and ("Active (" .. mode_label .. ")") or "Disabled"

    local tone_items = {}
    for _, tm in ipairs(TONE_MAPPERS) do
        tone_items[#tone_items+1] = {
            title  = tm.label,
            value  = "script-message hdr-toys-set-tone " .. tm.id,
            active = (o.tone_mapping == tm.id),
        }
    end

    local gamut_items = {}
    for _, gm in ipairs(GAMUT_MAPPERS) do
        gamut_items[#gamut_items+1] = {
            title  = gm.label,
            value  = "script-message hdr-toys-set-gamut " .. gm.id,
            active = (o.gamut_mapping == gm.id),
        }
    end

    local menu = {
        type  = "hdr_toys_menu",
        title = "HDR Toys  [" .. mode_label .. "]",
        items = {
            {
                title  = o.enabled and "Status: ENABLED" or "Status: DISABLED",
                hint   = en_hint,
                icon   = en_icon,
                value  = "script-message hdr-toys-toggle",
                active = o.enabled,
                bold   = true,
            },
            { title = "────────────────────────", value = "ignore", muted = true },
            {
                title = "Tone Mapping",
                hint  = o.tone_mapping,
                icon  = "tonality",
                items = tone_items,
            },
            {
                title = "Gamut Mapping",
                hint  = o.gamut_mapping,
                icon  = "palette",
                items = gamut_items,
            },
            { title = "────────────────────────", value = "ignore", muted = true },
            {
                title  = "Filmic Look",
                hint   = o.filmic and "ON" or "OFF",
                icon   = "movie_filter",
                value  = "script-message hdr-toys-toggle-filmic",
                active = o.filmic,
            },
            {
                title  = "Current Source Mode: " .. mode_label,
                hint   = "Works for SDR & HDR",
                icon   = "info",
                value  = "ignore",
            },
        },
    }
    return utils.format_json(menu)
end

function update_menu()
    mp.commandv("script-message-to", "uosc", "update-menu", build_menu_json())
end

local function open_menu()
    mp.commandv("script-message-to", "uosc", "open-menu", build_menu_json())
end

local function toggle_toys()
    o.enabled = not o.enabled
    save_settings()
    if o.enabled then
        apply_hdr_toys()
        show_osd(CY .. "{\\b1}HDR Toys:{\\b0} " .. CG .. "Enabled " .. CW .. "(" .. state.hdr_type:upper() .. ")")
    else
        restore_hdr_toys()
        show_osd(CY .. "{\\b1}HDR Toys:{\\b0} " .. CR .. "Disabled")
    end
    update_menu()
end

-------------------------------------------------
-- SCRIPT MESSAGES & KEY BINDINGS
-------------------------------------------------
mp.register_script_message("hdr-toys-toggle", toggle_toys)
mp.register_script_message("toggle-hdr-toys", toggle_toys)

mp.register_script_message("hdr-toys-open-menu", open_menu)
mp.register_script_message("open-hdr-toys-menu", open_menu)

mp.register_script_message("hdr-toys-set-tone", function(id)
    if not id or id == "" then return end
    o.tone_mapping = id
    save_settings()
    refresh_shaders()
    show_osd(CY .. "{\\b1}Tone Mapper:{\\b0} " .. CC .. id)
    update_menu()
end)

mp.register_script_message("hdr-toys-set-gamut", function(id)
    if not id or id == "" then return end
    o.gamut_mapping = id
    save_settings()
    refresh_shaders()
    show_osd(CY .. "{\\b1}Gamut Mapper:{\\b0} " .. CC .. id)
    update_menu()
end)

mp.register_script_message("hdr-toys-toggle-filmic", function()
    o.filmic = not o.filmic
    save_settings()
    refresh_shaders()
    show_osd(CY .. "{\\b1}Filmic Look:{\\b0} " .. (o.filmic and CG .. "ON" or CR .. "OFF"))
    update_menu()
end)

-- Bindings for input.conf and uosc controls
mp.add_key_binding(nil, "open-hdr-toys-menu", open_menu)
mp.add_key_binding(nil, "toggle-hdr-toys",    toggle_toys)
