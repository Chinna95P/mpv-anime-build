// --- adaptive-sharpen-sweetspot.glsl ---
// Optimized for mpv 2025 (gpu-next)
// Tuning: 0.6 Strength - The "Sweet Spot" for 1080p and 4K Content

//!HOOK LUMA
//!BIND HOOKED
//!DESC Adaptive Sharpen (Sweet Spot)

// [ CONFIGURATION ]
#define curve_height    0.60   // The "Sweet Spot": Sharp enough to see detail, soft enough to avoid halos.
#define L_combing       0.20   // Balanced threshold: Sharper than lite, but still ignores minor film grain.
#define video_level_out 1.0    // Keeps output within standard range.
#define max_st_diff     0.85   // Allows slightly more sharpening depth than the lite version.

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
    
    // Adaptive Weighting: Reduces sharpening in flat areas (sky/walls) to prevent grain crawl.
    float weight = clamp(1.0 - (edge * L_combing), 0.0, 1.0);
    
    // High-pass sharpening calculation
    float laplace = (n + s + w + e + nw + ne + sw + se) * 0.125 - c;
    float sharp = laplace * curve_height * weight;
    
    // Soft-clipping to prevent extreme "ringing" artifacts around text.
    sharp = clamp(sharp, -max_st_diff, max_st_diff);

    return vec4(clamp(c - sharp, 0.0, video_level_out), 0.0, 0.0, 1.0);
}
