// --- adaptive-sharpen-lite.glsl ---
// Optimized for mpv 2025 (gpu-next)
// Tuning: Subtle/Natural Sharpness for GTX 1060 & RTX 2060

//!HOOK LUMA
//!BIND HOOKED
//!DESC Adaptive Sharpen (Lite)

// [ CONFIGURATION ]
#define curve_height    0.40   // Strength of sharpening (Default was 1.0, 0.4 is Lite)
#define L_combing       0.25   // Threshold to ignore noise/grain (Higher = Cleaner)
#define video_level_out 1.0    // Output clipping
#define max_st_diff     0.7    // Max sharpening per pixel

vec4 hook() {
    vec2 pos = HOOKED_pos;
    
    // Get center pixel
    float c = HOOKED_tex(pos).x;
    
    // Get 4-neighbor average
    float n = HOOKED_texOff(vec2( 0, -1)).x;
    float s = HOOKED_texOff(vec2( 0,  1)).x;
    float w = HOOKED_texOff(vec2(-1,  0)).x;
    float e = HOOKED_texOff(vec2( 1,  0)).x;
    
    // Get diagonal-neighbor average
    float nw = HOOKED_texOff(vec2(-1, -1)).x;
    float ne = HOOKED_texOff(vec2( 1, -1)).x;
    float sw = HOOKED_texOff(vec2(-1,  1)).x;
    float se = HOOKED_texOff(vec2( 1,  1)).x;

    // Edge detection logic
    float edge = abs(n + s + w + e - 4.0 * c);
    
    // Weighting to avoid sharpening compression artifacts and flat grain
    float weight = clamp(1.0 - (edge * L_combing), 0.0, 1.0);
    
    // Simple high-pass sharpening calculation
    float laplace = (n + s + w + e + nw + ne + sw + se) * 0.125 - c;
    float sharp = laplace * curve_height * weight;
    
    // Soft-clipping to prevent extreme ringing
    sharp = clamp(sharp, -max_st_diff, max_st_diff);

    return vec4(clamp(c - sharp, 0.0, video_level_out), 0.0, 0.0, 1.0);
}
