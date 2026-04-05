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
    
    vec2 inv_scale = vec2(1, 1);
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
            