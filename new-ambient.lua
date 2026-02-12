local options = require 'mp.options'
local msg = require 'mp.msg'

local opts = {
    -- PERFORMANCE SETTINGS
    -- Lower this if you still get lag/black screen. 
    -- 2 is usually fine. 1 is fastest.
    blur_power = 10, 
    blur_radius = 15,
    
    -- Downscale background before blurring to save huge amounts of GPU power
    -- 480 (height) is enough for a blurry background.
    bg_processing_height = 480, 

    dim_brightness = true,
    reduce_saturation = true,
    active = true,
    reapply_delay = 0.5,
}
options.read_options(opts)

local active = opts.active
local update_timer = nil
local cached_crop = nil

function get_crop_params()
    -- Returns w, h, x, y. 
    -- If no crop is active, returns video native size (safest approach).
    if cached_crop and cached_crop ~= "" then
        local w, h, x, y = string.match(cached_crop, "(%d+)x(%d+)%+(%d+)%+(%d+)")
        if w and h and x and y then
            return w, h, x, y
        end
    end
    
    -- Fallback: If dynamic-crop hasn't kicked in, use full video.
    -- This prevents the "Black Screen" on startup.
    local vid_w = mp.get_property_number("width")
    local vid_h = mp.get_property_number("height")
    if vid_w and vid_h then
        return vid_w, vid_h, 0, 0
    end
    return nil
end

function update_filters()
    if not active then return end

    local osd_w, osd_h = mp.get_osd_size()
    if not osd_w or osd_w <= 0 or not osd_h or osd_h <= 0 then return end

    local cw, ch, cx, cy = get_crop_params()
    if not cw then return end -- Video hasn't loaded metadata yet

    -- 1. Construct Crop String
    local crop_str = string.format("crop=%s:%s:%s:%s", cw, ch, cx, cy)

    -- 2. Construct EQ String
    local eq_str = ""
    if opts.dim_brightness then eq_str = eq_str .. ":brightness=-0.15:contrast=0.85" end
    if opts.reduce_saturation then eq_str = eq_str .. ":saturation=0.6" end
    if eq_str ~= "" then eq_str = ",eq=gamma=1" .. eq_str end -- prepend dummy filter to attach params

    -- 3. Construct Graph
    -- We downscale the BG to `opts.bg_processing_height` (e.g. 480p) before blurring.
    -- This makes the blur operation ~10x faster on 4K/1080p videos.
    local graph = string.format(
        "lavfi=[split=2[fg][bg];" ..
        "[bg]%s,scale=-2:%d:flags=bicubic,boxblur=lr=%d:lp=%d%s,scale=%d:%d:force_original_aspect_ratio=increase:flags=bicubic,crop=%d:%d[bg_final];" ..
        "[fg]%s,scale=%d:%d:force_original_aspect_ratio=decrease:flags=bicubic[fg_final];" ..
        "[bg_final][fg_final]overlay=(W-w)/2:(H-h)/2]",
        
        -- BG Chain
        crop_str, opts.bg_processing_height, opts.blur_radius, opts.blur_power, eq_str, osd_w, osd_h, osd_w, osd_h,
        -- FG Chain
        crop_str, osd_w, osd_h
    )

    mp.set_property("vf", graph)
    mp.set_property("video-crop", "") -- Clear VO crop so we can see the ambient area
end

function request_update()
    if update_timer then update_timer:kill() end
    update_timer = mp.add_timeout(opts.reapply_delay, update_filters)
end

function on_crop_change(name, value)
    if value and value ~= "" then
        -- Only update if it's a NEW crop (ignore our own clears)
        if value ~= cached_crop then
            cached_crop = value
            if active then
                mp.set_property("video-crop", "")
                request_update()
            end
        end
    end
end

function clear_filters()
    mp.set_property("vf", "")
    if cached_crop then mp.set_property("video-crop", cached_crop) end
end

function toggle()
    if active then
        active = false
        clear_filters()
        mp.osd_message("Ambient: Off")
    else
        active = true
        request_update()
        mp.osd_message("Ambient: On")
    end
end

mp.add_key_binding(nil, "toggle-blur", toggle)
mp.observe_property("osd-width", "native", function() if active then request_update() end end)
mp.observe_property("osd-height", "native", function() if active then request_update() end end)
mp.observe_property("video-crop", "string", on_crop_change)

-- Initialize
mp.register_event("file-loaded", function()
    if active then mp.add_timeout(1.0, request_update) end
end)