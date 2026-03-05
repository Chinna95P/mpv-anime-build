-- [[ 
--    AMBIENT MANAGER v3.0 (Orientation and Shaders Aware Optimization)
-- ]]

local mp = require 'mp'
local msg = require 'mp.msg'

local ambient_enabled = false
local APPLY_DELAY = 0.5
local update_timer = nil

local generated_shaders = {}
local active_shader_path = nil

local function apply_calculations()
    if not ambient_enabled then return end

    local osd_w = mp.get_property_number("osd-width", 0)
    local osd_h = mp.get_property_number("osd-height", 0)
    local vid_w = mp.get_property_number("video-params/w", 0)
    local vid_h = mp.get_property_number("video-params/h", 0)
    
    -- === ADDED: Intercept Autocrop boundaries before doing math ===
    local crop = mp.get_property("video-crop", "")
    if crop and crop ~= "" then
        local cw, ch = crop:match("(%d+)x(%d+)")
        if cw and ch then
            vid_w = tonumber(cw)
            vid_h = tonumber(ch)
        end
    end
    -- ==============================================================

    local rot = mp.get_property_number("video-params/rotate", 0)
    local par = mp.get_property_number("video-params/par", 1)

    if osd_w <= 0 or osd_h <= 0 or vid_w <= 0 or vid_h <= 0 then return end

    vid_w = vid_w * par

    if rot == 90 or rot == 270 then
        local temp = vid_w
        vid_w = vid_h
        vid_h = temp
    end

    local res_key = string.format("%dx%d_v%dx%d", osd_w, osd_h, math.floor(vid_w), math.floor(vid_h))
    local new_shader_path = mp.command_native({"expand-path", "~~/shaders/Ambient-" .. res_key .. ".glsl"})

    if not generated_shaders[res_key] then
        local vid_ar = vid_w / vid_h
        local screen_ar = osd_w / osd_h
        local fg_x, fg_y, bg_x, bg_y

        if screen_ar > vid_ar then
            fg_x = screen_ar / vid_ar
            fg_y = 1.0
            bg_x = 1.0
            bg_y = vid_ar / screen_ar
        else
            fg_x = 1.0
            fg_y = vid_ar / screen_ar
            bg_x = screen_ar / vid_ar
            bg_y = 1.0
        end

        local is_screen_portrait = (osd_h > osd_w)
        local is_video_portrait = (vid_h > vid_w)
        local blur_samples, blur_radius
        
        if is_screen_portrait ~= is_video_portrait then
            blur_samples = 8
            blur_radius = 0.12
        else
            blur_samples = 12
            blur_radius = 0.15
        end

        local success, err = pcall(function()
            local file = io.open(new_shader_path, "w")
            if file then
                local shader_code = string.format([[
//!HOOK OUTPUT
//!BIND HOOKED
//!DESC Ambient Blur (%s)

#define BLUR_SAMPLES %d
#define BLUR_RADIUS %.2f
#define CONTRAST 0.85
#define BRIGHTNESS -0.15
#define SATURATION 0.6

const float GOLDEN_ANGLE = 2.39996323;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 hook() {
    vec2 uv = HOOKED_pos;
    
    vec2 fg_scale = vec2(%.4f, %.4f);
    vec2 fg_uv = (uv - 0.5) * fg_scale + 0.5;
    
    if (all(greaterThanEqual(fg_uv, vec2(0.0))) && all(lessThanEqual(fg_uv, vec2(1.0)))) {
        return HOOKED_tex(fg_uv); 
    }
    
    vec2 bg_scale = vec2(%.4f, %.4f);
    vec2 bg_uv = (uv - 0.5) * bg_scale + 0.5;
    
    vec4 bg_color = vec4(0.0);
    float noise = hash(uv) * 6.2831853; 
    float radius_mult = BLUR_RADIUS / sqrt(float(BLUR_SAMPLES));
    vec2 aspect_corr = vec2(HOOKED_size.y / HOOKED_size.x, 1.0);
    
    for (int i = 0; i < BLUR_SAMPLES; i++) {
        float r = sqrt(float(i) + 0.5) * radius_mult;
        float theta = float(i) * GOLDEN_ANGLE + noise;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * aspect_corr;
        
        vec2 sample_uv = clamp(bg_uv + offset, 0.0, 1.0);
        bg_color += HOOKED_tex(sample_uv);
    }
    
    bg_color /= float(BLUR_SAMPLES);
    bg_color.rgb = (bg_color.rgb - 0.5) * CONTRAST + 0.5 + BRIGHTNESS;
    float luma = dot(bg_color.rgb, vec3(0.2126, 0.7152, 0.0722));
    bg_color.rgb = mix(vec3(luma), bg_color.rgb, SATURATION);
    
    return clamp(bg_color, 0.0, 1.0);
}
                ]], res_key, blur_samples, blur_radius, fg_x, fg_y, bg_x, bg_y)
                
                file:write(shader_code)
                file:close()
            end
        end)

        if success then
            generated_shaders[res_key] = new_shader_path
        else
            msg.error("Failed to write shader to " .. new_shader_path)
            return
        end
    end

    if active_shader_path ~= generated_shaders[res_key] then
        mp.set_property_bool("keepaspect", false)
        if active_shader_path then
            mp.commandv("change-list", "glsl-shaders", "remove", active_shader_path)
        end
        active_shader_path = generated_shaders[res_key]
        mp.commandv("change-list", "glsl-shaders", "append", active_shader_path)
    end
end

local function request_update()
    if not ambient_enabled then return end
    if update_timer then update_timer:kill() end
    update_timer = mp.add_timeout(APPLY_DELAY, apply_calculations)
end

local function toggle_ambient()
    ambient_enabled = not ambient_enabled
    -- Tell the HQ script that ambient is running so it can optimize itself
    mp.set_property_bool("user-data/ambient_enabled", ambient_enabled) 
    
    if ambient_enabled then
        request_update()
        mp.osd_message("Ambient Mode: ON")
    else
        if update_timer then update_timer:kill() end
        if active_shader_path then
            mp.commandv("change-list", "glsl-shaders", "remove", active_shader_path)
            active_shader_path = nil
        end
        mp.set_property_bool("keepaspect", true)
        mp.osd_message("Ambient Mode: OFF")
    end
    
    mp.commandv("script-message", "reevaluate-hq-shaders")
end

mp.register_script_message("rehook-ambient", function()
    if ambient_enabled and active_shader_path then
        mp.commandv("change-list", "glsl-shaders", "remove", active_shader_path)
        mp.commandv("change-list", "glsl-shaders", "append", active_shader_path)
    end
end)

mp.register_event("file-loaded", function()
    if ambient_enabled then request_update() end
end)

mp.register_event("end-file", function()
    mp.set_property_bool("keepaspect", true)
end)

mp.observe_property("osd-dimensions", "native", request_update)
mp.observe_property("video-crop", "string", request_update)
mp.register_script_message("toggle-ambient", toggle_ambient)