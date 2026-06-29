-- [[ 
--    PC AMBIENT MANAGER (THE DEFINITIVE FIX)
--    Bypasses mpv's shader cache, locale bugs, and autocrop race conditions.
-- ]]

local mp = require 'mp'

local SHADER_BASE = mp.command_native({"expand-path", "~~/shaders/ambient_baked_"})
local active = false
local last_scale_x, last_scale_y = -1.0, -1.0
local shader_idx = 0

-- Prevents Windows region settings from breaking GLSL compiler with commas
local function format_float(num)
    return tostring(num):gsub(",", ".")
end

-- Alternates between two file names to physically bypass mpv's aggressive shader cache
local function inject_ambient(path)
    mp.commandv("change-list", "glsl-shaders", "remove", SHADER_BASE .. "0.glsl")
    mp.commandv("change-list", "glsl-shaders", "remove", SHADER_BASE .. "1.glsl")
    if active and path then
        mp.commandv("change-list", "glsl-shaders", "append", path)
    end
end

local function update_aspect()
    if not active then return end

    local osd_w = mp.get_property_number("osd-width")
    local osd_h = mp.get_property_number("osd-height")
    local vid_w = mp.get_property_number("video-params/w")
    local vid_h = mp.get_property_number("video-params/h")
    
    if not osd_w or not osd_h or not vid_w or not vid_h or osd_h == 0 then return end

    local crop = mp.get_property("video-crop", "")
    if crop ~= "" then
        local cw, ch = crop:match("(%d+)x(%d+)")
        if cw and ch then
            vid_w = tonumber(cw)
            vid_h = tonumber(ch)
        end
    end

    local screen_ar = osd_w / osd_h
    local vid_ar = vid_w / vid_h

    local scale_x = 1.0
    local scale_y = 1.0

    if screen_ar > vid_ar then
        scale_x = screen_ar / vid_ar
    else
        scale_y = vid_ar / screen_ar
    end

    if math.abs(scale_x - last_scale_x) > 0.001 or math.abs(scale_y - last_scale_y) > 0.001 then
        last_scale_x = scale_x
        last_scale_y = scale_y

        shader_idx = 1 - shader_idx
        local current_path = SHADER_BASE .. tostring(shader_idx) .. ".glsl"

        local file = io.open(current_path, "w")
        if file then
            local shader_code = string.format([[
//!HOOK OUTPUT
//!BIND HOOKED
//!DESC Ambient Blur (PC Auto-Synced)

#define BLUR_SAMPLES 32      
#define BLUR_RADIUS 0.12     
#define CONTRAST 0.85
#define BRIGHTNESS -0.15
#define SATURATION 0.6

const float GOLDEN_ANGLE = 2.39996323;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 hook() {
    vec2 uv = HOOKED_pos;
    
    vec2 inv_scale = vec2(%s, %s);
    vec2 center_uv = (uv - 0.5) * inv_scale + 0.5;
    
    if (all(greaterThanEqual(center_uv, vec2(0.0))) && all(lessThanEqual(center_uv, vec2(1.0)))) {
        return HOOKED_tex(center_uv); 
    }
    
    vec4 bg_color = vec4(0.0);
    float noise = hash(uv) * 6.2831853; 
    
    float radius_mult = BLUR_RADIUS / sqrt(float(BLUR_SAMPLES));
    vec2 aspect_corr = vec2(HOOKED_size.y / HOOKED_size.x, 1.0);
    
    for (int i = 0; i < BLUR_SAMPLES; i++) {
        float r = sqrt(float(i) + 0.5) * radius_mult;
        float theta = float(i) * GOLDEN_ANGLE + noise;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * aspect_corr;
        
        vec2 sample_uv = clamp(center_uv + offset, 0.0, 1.0);
        bg_color += HOOKED_tex(sample_uv);
    }
    
    bg_color /= float(BLUR_SAMPLES);
    
    bg_color.rgb = (bg_color.rgb - 0.5) * CONTRAST + 0.5 + BRIGHTNESS;
    float luma = dot(bg_color.rgb, vec3(0.2126, 0.7152, 0.0722));
    bg_color.rgb = mix(vec3(luma), bg_color.rgb, SATURATION);
    
    return clamp(bg_color, 0.0, 1.0);
}
            ]], format_float(scale_x), format_float(scale_y))
            
            file:write(shader_code)
            file:close()
        end
        
        mp.set_property_number("video-scale-x", scale_x)
        mp.set_property_number("video-scale-y", scale_y)
        inject_ambient(current_path)
    end
end

local function toggle_ambient()
    active = not active
    if active then
        last_scale_x, last_scale_y = -1.0, -1.0 
        update_aspect()
        mp.osd_message("✨ Ambient Mode: ON")
    else
        inject_ambient(nil) 
        mp.set_property_number("video-scale-x", 1.0)
        mp.set_property_number("video-scale-y", 1.0)
        mp.osd_message("✨ Ambient Mode: OFF")
    end
end

-- The Unified UOSC Bridge
mp.register_script_message("toggle-crop-ambient", function()
    mp.command("script-binding toggle_crop") 
    -- 1.5s allows autocrop (which takes 1.0s) to completely finish without a race condition
    mp.add_timeout(1.5, toggle_ambient)      
end)

mp.observe_property("osd-dimensions", "native", update_aspect)
mp.observe_property("video-crop", "string", update_aspect)
mp.observe_property("video-params", "native", update_aspect)

mp.register_event("file-loaded", function()
    if active then
        last_scale_x, last_scale_y = -1.0, -1.0 
        mp.add_timeout(0.5, update_aspect)
    end
end)

mp.register_event("end-file", function()
    mp.set_property_number("video-scale-x", 1.0)
    mp.set_property_number("video-scale-y", 1.0)
end)

-- Reset Ambient Mode when a new file starts
mp.register_event("start-file", function()
    if active then
        active = false
        inject_ambient(nil) 
        mp.set_property_number("video-scale-x", 1.0)
        mp.set_property_number("video-scale-y", 1.0)
        -- Optional: mp.osd_message("Ambient Mode Reset")
    end
end)