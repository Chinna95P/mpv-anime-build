-- [[
--    FILENAME: pip.lua
--    VERSION:  v1.27
--    DESCRIPTION: Toggles PiP Mode (Instant Snap + Nil-Safe Recovery)
-- ]]

local mp = require("mp")

local is_pip = false
local saved_fs = false
local saved_max = false
local saved_ontop = false
local saved_geom = {w=1280, h=720, x=100, y=100} -- Table storage is safer
local saved_scale = 1.0
local saved_keepaspect = true
local original_uosc_controls = nil

-- Robust geometry fetcher to prevent console errors
local function get_current_geometry()
    return {
        w = mp.get_property_number("osd-width") or 1280,
        h = mp.get_property_number("osd-height") or 720,
        x = mp.get_property_number("window-pos/x") or 0,
        y = mp.get_property_number("window-pos/y") or 0
    }
end

local function apply_pip()
    local disp_w = mp.get_property_number("display-width")
    local disp_h = mp.get_property_number("display-height")
    
    if not disp_w or not disp_h then return end

    -- 1. Ambient Mode Detection
    local is_ambient = false
    local shaders = mp.get_property_native("glsl-shaders") or {}
    for _, shader in pairs(shaders) do
        if type(shader) == "string" and shader:find("ambient_baked") then
            is_ambient = true
            break
        end
    end

    if is_ambient then
        -- Force 16:9 box for Ambient Mode
        mp.set_property_native("keepaspect-window", false)
        mp.set_property("geometry", "35%x35%-25-25") 
    else
        -- Wrap tightly for standard video
        mp.set_property_native("keepaspect-window", true)
        mp.set_property("geometry", "30%x30%-25-25") 
    end
    
    mp.set_property_native("ontop", true)
    
    -- Update uosc-controls
    local opts = mp.get_property_native("script-opts") or {}
    if not is_pip then original_uosc_controls = opts["uosc-controls"] end
    opts["uosc-controls"] = "cycle:repeat:loop-file:no/inf!?Loop File,command:shuffle:playlist-shuffle?Shuffle Playlist,space,prev,<has_chapter>command:fast_rewind:add chapter -1?Prev Chapter,play-pause,<has_chapter>command:fast_forward:add chapter 1?Next Chapter,next,space,command:picture_in_picture_alt:script-message toggle-pip?PiP Mode,fullscreen"
    mp.set_property_native("script-opts", opts)
    
    is_pip = true
    mp.osd_message("PiP Mode: ON", 2)
end

mp.register_script_message("toggle-pip", function()
    if not is_pip then
        -- SAVE STATE
        saved_fs = mp.get_property_native("fullscreen")
        saved_max = mp.get_property_native("window-maximized")
        saved_ontop = mp.get_property_native("ontop")
        saved_geom = get_current_geometry()
        saved_scale = mp.get_property_native("window-scale") or 1.0
        saved_keepaspect = mp.get_property_native("keepaspect-window") or true

        if saved_fs or saved_max then
            mp.set_property_native("fullscreen", false)
            mp.set_property_native("window-maximized", false)
            mp.add_timeout(0.15, apply_pip)
        else
            apply_pip()
        end
    else
        -- RESTORE STATE
        is_pip = false
        mp.set_property_native("ontop", saved_ontop)
        mp.set_property_native("keepaspect-window", saved_keepaspect)
        
        -- Instant restoration using our table values
        mp.set_property("geometry", string.format("%dx%d+%d+%d", saved_geom.w, saved_geom.h, saved_geom.x, saved_geom.y))
        
        local opts = mp.get_property_native("script-opts") or {}
        opts["uosc-controls"] = original_uosc_controls
        mp.set_property_native("script-opts", opts)
        
        if saved_fs or saved_max then
            mp.add_timeout(0.1, function()
                if saved_max then mp.set_property_native("window-maximized", true) end
                if saved_fs then mp.set_property_native("fullscreen", true) end
            end)
        end
        
        mp.osd_message("PiP Mode: OFF", 2)
    end
end)