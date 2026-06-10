// MIT License

// Copyright (c) 2019-2021 bloc97
// Copyright (c) 2026 Th-Underscore
// All rights reserved.

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

//!DESC Save-Native-Resolution
//!HOOK LUMA
//!BIND HOOKED
//!SAVE NATIVE_RES
//!WHEN OUTPUT.w LUMA.w >
//!COMPONENTS 1
vec4 hook() {
    return HOOKED_tex(HOOKED_pos);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Luma-Sharp
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!SAVE LINELUMA_SHARP
//!COMPONENTS 1

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y) // Dynamically scales sampling radius based on upscale factor
#define LUMA_SHARP_AMOUNT 1.5

float get_luma(vec4 rgba) { return dot(vec3(0.299, 0.587, 0.114), rgba.rgb); }

vec4 hook() {
    float c = get_luma(HOOKED_tex(HOOKED_pos));
    // Box blur (9-tap): used as the low-frequency reference for unsharp masking
    // Pre-sharpening luma before edge detection improves gradient signal quality on soft upscaled sources, making subsequent Sobel passes more responsive to true lines vs. interpolation blur
    float blur = (
        get_luma(HOOKED_texOff(vec2(-D,-D))) + get_luma(HOOKED_texOff(vec2(0.0,-D))) + get_luma(HOOKED_texOff(vec2(D,-D))) +
        get_luma(HOOKED_texOff(vec2(-D, 0.0))) + c + get_luma(HOOKED_texOff(vec2(D, 0.0))) +
        get_luma(HOOKED_texOff(vec2(-D, D))) + get_luma(HOOKED_texOff(vec2(0.0, D))) + get_luma(HOOKED_texOff(vec2(D, D)))
    ) / 9.0;
    // sharpened = c + (c - blur) * amount
    return vec4(clamp(c + (c - blur) * LUMA_SHARP_AMOUNT, 0.0, 1.0), 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Luma-Sharp
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND EASUTEX
//!SAVE LINELUMA_SHARP
//!WIDTH EASUTEX.w
//!HEIGHT EASUTEX.h
//!COMPONENTS 1
//!WHEN OUTPUT.w MAIN.w >

// Upscaling path: operates on the FSR-upscaled texture instead of HOOKED
#define D (0.75 * EASUTEX_size.y / NATIVE_RES_size.y)
#define LUMA_SHARP_AMOUNT 1.5

vec4 hook() {
    float c = EASUTEX_tex(EASUTEX_pos).x;
    float blur = (
        EASUTEX_texOff(vec2(-D,-D)).x + EASUTEX_texOff(vec2(0.0,-D)).x + EASUTEX_texOff(vec2(D,-D)).x +
        EASUTEX_texOff(vec2(-D, 0.0)).x + c + EASUTEX_texOff(vec2(D, 0.0)).x +
        EASUTEX_texOff(vec2(-D, D)).x + EASUTEX_texOff(vec2(0.0, D)).x + EASUTEX_texOff(vec2(D, D)).x
    ) / 9.0;
    return vec4(clamp(c + (c - blur) * LUMA_SHARP_AMOUNT, 0.0, 1.0), 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Sobel-X
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND LINELUMA_SHARP
//!SAVE LINESOBEL
//!WIDTH NATIVE_RES.w
//!HEIGHT NATIVE_RES.h
//!COMPONENTS 2

#define D (0.75 * LINELUMA_SHARP_size.y / NATIVE_RES_size.y)

vec4 hook() {
    float l = LINELUMA_SHARP_texOff(vec2(-D, 0.0)).x;
    float c = LINELUMA_SHARP_tex(LINELUMA_SHARP_pos).x;
    float r = LINELUMA_SHARP_texOff(vec2( D, 0.0)).x;
    // Horizontal pass of a separable Sobel operator. Stores partial row products so Sobel-Y can complete both axes without re-fetching this row:
    //   .x = gx_partial = -l + r       (horizontal difference)
    //   .y = row_sum    =  l + 2c + r  (row weight for gy completion)
    return vec4(-l + r, l + c + c + r, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Sobel-Y
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH NATIVE_RES.w
//!HEIGHT NATIVE_RES.h
//!COMPONENTS 1

#define D (0.75 * LINESOBEL_size.y / NATIVE_RES_size.y)

vec4 hook() {
    float tx = LINESOBEL_texOff(vec2(0.0,-D)).x;
    float cx = LINESOBEL_tex(LINESOBEL_pos).x;
    float bx = LINESOBEL_texOff(vec2(0.0, D)).x;
    float ty = LINESOBEL_texOff(vec2(0.0,-D)).y;
    float by = LINESOBEL_texOff(vec2(0.0, D)).y;
    // Vertical pass completing the separable 3x3 Sobel:
    //   Gx kernel          Gy kernel
    //   -1  0  +1          -1  -2  -1
    //   -2  0  +2           0   0   0
    //   -1  0  +1          +1  +2  +1
    //
    //   gx = (top.y + 2·mid.y + bot.y) / 8  (completes column weighting)
    //   gy = (-top.x + bot.x) / 8           (vertical difference of row sums)
    float gx = (tx + cx + cx + bx) / 8.0;
    float gy = (-ty + by) / 8.0;
    // Magnitude raised to 0.7 to compress dynamic range: weaker edges get
    // a stronger mask presence without blowing out strong ones
    return vec4(pow(sqrt(gx * gx + gy * gy), 0.7));
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Gaussian-X
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH NATIVE_RES.w
//!HEIGHT NATIVE_RES.h
//!COMPONENTS 1

// Separable Gaussian smoothing of the Sobel magnitude map. Blurring before the second gradient pass (Kernel-X/Y) suppresses isolated noise spikes so the direction vectors used for warping reflect true edge orientation
#define SPATIAL_SIGMA (1.5 * LINESOBEL_size.y / NATIVE_RES_size.y)  // Base blur radius for edge detection (~0.5 to 3.0 by modifying the '1.5' multiplier)
#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1) // Auto-calculates kernel footprint size; do not modify manually

float gaussian(float x, float s) { return exp(-0.5 * (x/s) * (x/s)); }

vec4 hook() {
    float g = 0.0, gn = 0.0;
    for (int i = 0; i < KERNELSIZE; i++) {
        float di = float(i - KERNELSIZE / 2);
        float gf = gaussian(di, SPATIAL_SIGMA);
        g += LINESOBEL_texOff(vec2(di, 0.0)).x * gf;
        gn += gf;
    }
    return vec4(g / gn, 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Gaussian-Y
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH NATIVE_RES.w
//!HEIGHT NATIVE_RES.h
//!COMPONENTS 1

#define SPATIAL_SIGMA (1.5 * LINESOBEL_size.y / NATIVE_RES_size.y)  // Base blur radius for edge detection (~0.5 to 3.0 by modifying the '1.5' multiplier)
#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1) // Auto-calculates kernel footprint size; do not modify manually

float gaussian(float x, float s) { return exp(-0.5 * (x/s) * (x/s)); }

vec4 hook() {
    float g = 0.0, gn = 0.0;
    for (int i = 0; i < KERNELSIZE; i++) {
        float di = float(i - KERNELSIZE / 2);
        float gf = gaussian(di, SPATIAL_SIGMA);
        g += LINESOBEL_texOff(vec2(0.0, di)).x * gf;
        gn += gf;
    }
    return vec4(g / gn, 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Kernel-X
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH NATIVE_RES.w
//!HEIGHT NATIVE_RES.h
//!COMPONENTS 3

#define D (0.75 * LINESOBEL_size.y / NATIVE_RES_size.y)

vec4 hook() {
    float l = LINESOBEL_texOff(vec2(-D, 0.0)).x;
    float c = LINESOBEL_tex(LINESOBEL_pos).x;
    float r = LINESOBEL_texOff(vec2( D, 0.0)).x;
    // Second separable Sobel, horizontal pass, on the Gaussian-smoothed
    // magnitude map. Packs partial products alongside M for Kernel-Y:
    //   .x = gx_partial  =  -l + r
    //   .y = row_sum     =   l + 2c + r
    //   .z = M           =  smoothed Sobel magnitude (passed through)
    return vec4(-l + r, l + c + c + r, c, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Kernel-Y
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH NATIVE_RES.w
//!HEIGHT NATIVE_RES.h
//!COMPONENTS 3

#define D (0.75 * LINESOBEL_size.y / NATIVE_RES_size.y)

vec4 hook() {
    float tx = LINESOBEL_texOff(vec2(0.0,-D)).x;
    float cx = LINESOBEL_tex(LINESOBEL_pos).x;
    float bx = LINESOBEL_texOff(vec2(0.0, D)).x;
    float ty = LINESOBEL_texOff(vec2(0.0,-D)).y;
    float by = LINESOBEL_texOff(vec2(0.0, D)).y;
    float mask = LINESOBEL_tex(LINESOBEL_pos).z;
    // Completes the second Sobel pass. Final LINESOBEL layout:
    //   .x = gx   gradient x-component  (Sobel of smoothed M, /8)
    //   .y = gy   gradient y-component  (Sobel of smoothed M, /8)
    //   .z = M    Gaussian-smoothed Sobel magnitude (from Kernel-X .z)
    return vec4((tx + cx + cx + bx) / 8.0, (-ty + by) / 8.0, mask, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Line-Confidence
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND LINESOBEL
//!SAVE LINECONF
//!WIDTH NATIVE_RES.w
//!HEIGHT NATIVE_RES.h
//!COMPONENTS 1

#define D (0.75 * LINESOBEL_size.y / NATIVE_RES_size.y)
#define TANGENT_TAPS  5   // Samples along line tangent (int 1 to 10); higher bridges wider gaps but costs performance
#define TANGENT_SIGMA 2.0 // Gaussian falloff for tangent tap weights (0.1 to ~5.0)

float gaussian(float x, float s) { return exp(-0.5 * (x/s) * (x/s)); }

vec4 hook() {
    vec3 sd = LINESOBEL_tex(LINESOBEL_pos).xyz;
    float mag = length(sd.xy);
    // Tangent direction: perpendicular to ∇M, so we walk along the line rather than across it
    vec2 tang = (mag > 0.001) ? vec2(-sd.y, sd.x) / mag : vec2(1.0, 0.0);

    // Accumulate smoothed magnitude (.z) along the tangent. Isolated noise spikes
    // score low; connected line segments score high
    //   <---[-N]-···-[-1]-[c]-[+1]-···-[+N]--->
    //          \___________TANGENT_TAPS_________/
    // Gaussian-weighted so central taps matter more than distant ones
    float csum = sd.z, cwsum = 1.0;
    for (int i = 1; i <= TANGENT_TAPS; i++) {
        float fi = float(i);
        float w = gaussian(fi, TANGENT_SIGMA);
        csum += (LINESOBEL_texOff( tang * (fi * D)).z + LINESOBEL_texOff(-tang * (fi * D)).z) * w;
        cwsum += 2.0 * w;
    }
    return vec4(csum / cwsum, 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Line-Absorb
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND LINESOBEL
//!BIND LINECONF

#define ABSORB_STRENGTH 0.70  // Blend weight toward the line for halo pixels (0.0-1.0)
#define ABSORB_CONF_LOW 0.05  // Match CONF_LOW in the Warp pass
#define MAG_SENSITIVITY 1.3   // Raise for low-contrast lines (e.g. 0xbbb0bb / 0xf5f5f5)

// Degree-5 polynomial - same as before, peaks near M ≈ 0.45
#define P5 ( 11.68129591)
#define P4 (-42.46906057)
#define P3 ( 60.28286266)
#define P2 (-41.84451327)
#define P1 ( 14.05517353)
#define P0 ( -1.08152193)

float refine_curve(float x) {
    float x2 = x*x, x3 = x2*x, x4 = x2*x2, x5 = x2*x3;
    return P5*x5 + P4*x4 + P3*x3 + P2*x2 + P1*x + P0;
}

float get_luma(vec4 c) { return dot(vec3(0.299, 0.587, 0.114), c.rgb); }

vec4 hook() {
    float conf = LINECONF_tex(LINECONF_pos).x;
    if (conf < ABSORB_CONF_LOW)
        return HOOKED_tex(HOOKED_pos);

    // LINESOBEL.xy = ∇M (gradient of blurred Sobel magnitude, /8)
    // LINESOBEL.z  = M  (Gaussian-blurred Sobel magnitude)
    vec3 sd   = LINESOBEL_tex(LINESOBEL_pos).xyz;
    float mag = clamp(sd.z * MAG_SENSITIVITY, 0.0, 1.0);
    float dval = clamp(refine_curve(mag) * ABSORB_STRENGTH, 0.0, 1.0);
    if (dval < 0.001) return HOOKED_tex(HOOKED_pos);

    vec2 dc = sd.xy;
    float dclen = length(dc);
    if (dclen <= 0.001) return HOOKED_tex(HOOKED_pos);
    dc /= dclen;

    vec2 d   = HOOKED_pt;
    vec4 c   = HOOKED_tex(HOOKED_pos);
    float lc = get_luma(c);

    // +∇M = toward increasing edge magnitude = toward the line for halo/bg pixels.
    // Cardinal sampling weighted by edge angle, same pattern as before.
    vec4 xval = HOOKED_tex(HOOKED_pos + vec2(d.x *  sign(dc.x), 0.0));
    vec4 yval = HOOKED_tex(HOOKED_pos + vec2(0.0,  d.y *  sign(dc.y)));
    float xyratio = abs(dc.x) / (abs(dc.x) + abs(dc.y) + 0.0001);
    vec4 line_sample = xyratio * xval + (1.0 - xyratio) * yval;

    // Gate: only absorb when the line-direction sample is darker than the current pixel.
    //   - Halo/background pixel looking toward line:  l_toward < lc  → mask > 0  ✓
    //   - Line-interior pixel (+∇M overshoots to bg): l_toward ≥ lc  → mask = 0  ✓
    // The *8 factor gives a soft but steep ramp over ~0.125 luma units of contrast.
    float absorb_mask = clamp((lc - get_luma(line_sample)) * 8.0, 0.0, 1.0);

    return mix(c, line_sample, dval * absorb_mask);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Warp
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND LINESOBEL
//!BIND LINECONF

#define D (0.75 * LINESOBEL_size.y / NATIVE_RES_size.y)
#define THIN_STRENGTH         0.08 // Base displacement step in output pixels per iteration (0.0 to ~0.2)
#define ITERATIONS            3    // Number of coordinate warping passes to thin lines (int 0 to ~10)
#define MIN_EDGE_STRENGTH     0.01 // Gradient magnitude threshold to abort warping early (0.0 to 1.0)
#define CONF_LOW              0.05 // Minimum line confidence required to trigger any warping (0.0 to 1.0)
#define BLURRY_DISP_THRESHOLD 0.4  // Max displacement (pixels) before triggering secondary blurry warp passes (0.0 to ~2.0)
#define BLURRY_RELSTR_MULT    1.5  // Multiplier for THIN_STRENGTH during extra blurry iterations (1.0 to ~3.0)
#define BLURRY_EDGE_MULT      0.4  // Multiplier for MIN_EDGE_STRENGTH during extra iterations (0.0 to 1.0)
#define BLURRY_EXTRA_ITERS    2    // Extra loop iterations if blurry threshold is met (int 0 to ~5)

vec4 hook() {
    if (LINECONF_tex(LINECONF_pos).x < CONF_LOW)
        return HOOKED_tex(HOOKED_pos);

    float relstr = D * 1.33 * THIN_STRENGTH;
    vec2 d = LINESOBEL_pt;
    vec2 offset = vec2(0.0);
    // Each iteration nudges the sampling UV toward the edge's luminance peak:
    // offset -= normalize(∇M) · pixel_step · relstr
    // Breaks early once |∇M| < MIN_EDGE_STRENGTH to prevent drift on flat regions
    for (int i = 0; i < ITERATIONS; i++) {
        vec2 dn = LINESOBEL_tex(LINESOBEL_pos + offset).xy;
        float mag = length(dn);
        if (mag > MIN_EDGE_STRENGTH)
            offset -= (dn / (mag + 0.01)) * d * relstr;
        else break;
    }

    // A small primary displacement means the gradient was real but weak (blurry line), not noise. A secondary pass with relaxed thresholds handles these cases
    if (length(offset / HOOKED_pt) < BLURRY_DISP_THRESHOLD) {
        float weak_relstr = relstr * BLURRY_RELSTR_MULT;
        float weak_threshold = MIN_EDGE_STRENGTH * BLURRY_EDGE_MULT;
        for (int i = 0; i < BLURRY_EXTRA_ITERS; i++) {
            vec2 dn = LINESOBEL_tex(LINESOBEL_pos + offset).xy;
            float mag = length(dn);
            if (mag > weak_threshold)
                offset -= (dn / (mag + 0.01)) * d * weak_relstr;
            else break;
        }
    }
    return HOOKED_tex(HOOKED_pos + offset);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-PW-Sobel-X
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!SAVE PWSOBEL
//!COMPONENTS 2

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)

float pw_luma(vec4 c) { return dot(vec3(0.299, 0.587, 0.114), c.rgb); }

vec4 hook() {
    float l = pw_luma(HOOKED_texOff(vec2(-D, 0.0)));
    float c = pw_luma(HOOKED_tex(HOOKED_pos));
    float r = pw_luma(HOOKED_texOff(vec2( D, 0.0)));
    // Post-warp Sobel, horizontal pass. Operates on the warped HOOKED so that Dealias/Darken/ChromaDeblur have gradient vectors aligned to thinned lines
    // Same packing layout as the first Sobel-X:
    //   .x = gx_partial  =  -l + r
    //   .y = row_sum     =   l + 2c + r
    return vec4(-l + r, l + c + c + r, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-PW-Sobel-Y
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND PWSOBEL
//!SAVE PWSOBEL
//!COMPONENTS 3

#define D (0.75 * PWSOBEL_size.y / NATIVE_RES_size.y)

vec4 hook() {
    float tx = PWSOBEL_texOff(vec2(0.0,-D)).x;
    float cx = PWSOBEL_tex(PWSOBEL_pos).x;
    float bx = PWSOBEL_texOff(vec2(0.0, D)).x;
    float ty = PWSOBEL_texOff(vec2(0.0,-D)).y;
    float by = PWSOBEL_texOff(vec2(0.0, D)).y;
    float gx = (tx + cx + cx + bx) / 8.0;
    float gy = (-ty + by) / 8.0;
    // Completes the post-warp Sobel. Final PWSOBEL layout:
    //   .x = gx    gradient x-component (/8)
    //   .y = gy    gradient y-component (/8)
    //   .z = |∇|   gradient magnitude  (linear, not gamma-compressed)
    return vec4(gx, gy, sqrt(gx * gx + gy * gy), 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Dealias-USM
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND PWSOBEL
//!BIND LINECONF

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)
#define DEALIAS_STRENGTH 0.25 // Interpolation strength (0.0 to ~2.0); >1.0 mathematically extrapolates to aggressively force AA
#define USM_AMOUNT       0.5  // Unsharp mask strength specifically over dealiased lines (0.0 to ~2.0)
#define CONF_LOW         0.02 // Lower bound of the effect mask's smoothstep transition (0.0 to 1.0)
#define CONF_HIGH        0.18 // Upper bound of the effect mask's smoothstep transition (0.0 to 1.0; must be > CONF_LOW)

float get_luma(vec3 rgb) { return dot(vec3(0.299, 0.587, 0.114), rgb); }

vec4 hook() {
    float effect_mask = smoothstep(CONF_LOW, CONF_HIGH, LINECONF_tex(LINECONF_pos).x);
    if (effect_mask < 0.001) return HOOKED_tex(HOOKED_pos);

    vec4 c = HOOKED_tex(HOOKED_pos);
    vec2 sd = PWSOBEL_tex(PWSOBEL_pos).xy;
    float mag = length(sd);
    vec2 tang = (mag > 0.01) ? vec2(-sd.y, sd.x) / mag : vec2(1.0, 0.0);

    // Bilateral average of two tangent taps. The high luma-proximity decay (x20) makes weights collapse to ~0 across even modest luma differences, so colour cannot bleed across the edge while the staircase along its length is smoothed:
    //   w = exp(-|luma(tap) - luma(centre)| · 20)
    vec4 t1 = HOOKED_tex(HOOKED_pos + tang * HOOKED_pt * D);
    vec4 t2 = HOOKED_tex(HOOKED_pos - tang * HOOKED_pt * D);
    float lc = get_luma(c.rgb);
    float w1 = exp(-abs(get_luma(t1.rgb) - lc) * 20.0);
    float w2 = exp(-abs(get_luma(t2.rgb) - lc) * 20.0);
    vec4 c_da = mix(c, (c + t1 * w1 + t2 * w2) / (1.0 + w1 + w2), DEALIAS_STRENGTH * effect_mask);

    // Unsharp mask applied to the dealiased result, gated by effect_mask so flat regions receive no sharpening
    vec4 blur = (
        HOOKED_texOff(vec2(-D,-D)) + HOOKED_texOff(vec2(0.0,-D)) + HOOKED_texOff(vec2(D,-D)) +
        HOOKED_texOff(vec2(-D, 0.0)) + c + HOOKED_texOff(vec2(D, 0.0)) +
        HOOKED_texOff(vec2(-D, D)) + HOOKED_texOff(vec2(0.0, D)) + HOOKED_texOff(vec2(D, D))
    ) / 9.0;
    return clamp(c_da + (c - blur) * USM_AMOUNT * effect_mask, 0.0, 1.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Darken
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND PWSOBEL
//!BIND LINECONF

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)
#define DARKEN_STRENGTH   0.30 // Base multiplier for line darkening via local luma valleys (0.0 to ~1.0)
#define DARKEN_MAX_FRAC   0.25 // Max fraction of luma to SUBTRACT (0.0 to 1.0)
#define DARKEN_LUMA_FLOOR 0.08 // Below this luma, full darkening is applied (canonical dark ink lines)
#define DARKEN_LUMA_CEIL  0.82 // Above this luma, darkening is fully suppressed (coloured lines / highlights)
#define CONF_LOW          0.02 // Lower bound of the effect mask's smoothstep transition (0.0 to 1.0)
#define CONF_HIGH         0.18 // Upper bound of the effect mask's smoothstep transition (0.0 to 1.0; must be > CONF_LOW)

float get_luma(vec3 rgb) { return dot(vec3(0.299, 0.587, 0.114), rgb); }

float valley_at(vec2 p) {
    vec2 gxy = PWSOBEL_tex(p).xy;
    float mag = length(gxy);
    vec2 norm = (mag > 0.01) ? (gxy / mag) : vec2(1.0, 0.0);
    float lc = get_luma(HOOKED_tex(p).rgb);
    // Check two steps outward in each direction to handle lines thicker than one pixel, then take the brighter of the two as the background reference:
    //   lpos = max(luma at +D, luma at +2D)  along ∇M
    //   lneg = max(luma at -D, luma at -2D)  along ∇M
    float lpos = max(get_luma(HOOKED_tex(p + norm * HOOKED_pt * D).rgb),
                     get_luma(HOOKED_tex(p + norm * HOOKED_pt * (D * 2.0)).rgb));
    float lneg = max(get_luma(HOOKED_tex(p - norm * HOOKED_pt * D).rgb),
                     get_luma(HOOKED_tex(p - norm * HOOKED_pt * (D * 2.0)).rgb));
    // x8 scaling + normalisation:
    // score -> 1.0 when centre is a clear local minimum (ink line), -> 0 on shallow gradients (shading, textures)
    return clamp((min(lpos, lneg) - lc) * 8.0 / max(max(lpos, lneg), 0.1), 0.0, 1.0);
}

vec4 hook() {
    float effect_mask = smoothstep(CONF_LOW, CONF_HIGH, LINECONF_tex(LINECONF_pos).x);
    if (effect_mask < 0.001) return HOOKED_tex(HOOKED_pos);

    vec2 gxy = PWSOBEL_tex(PWSOBEL_pos).xy;
    float mag = length(gxy);
    vec2 tang = (mag > 0.01) ? vec2(-gxy.y, gxy.x) / mag : vec2(1.0, 0.0);

    // Max-pool valley score across three tangent positions so narrow lines that sit between output pixels still register
    float valley = max(valley_at(HOOKED_pos),
                   max(valley_at(HOOKED_pos + tang * HOOKED_pt * D),
                       valley_at(HOOKED_pos - tang * HOOKED_pt * D)));

    vec4 c = HOOKED_tex(HOOKED_pos);
    float l = get_luma(c.rgb);

    // Suppress darkening on saturated pixels (coloured lines / highlights)
    // luma_gate and sat_suppress are multiplied so either condition alone can fully suppress the effect
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float luma_gate = 1.0 - smoothstep(DARKEN_LUMA_FLOOR, DARKEN_LUMA_CEIL, l);
	float sat_suppress = smoothstep(0.08, 0.25, sat);
	float darken_gate = luma_gate * (1.0 - sat_suppress);

	float delta = min(effect_mask * valley * DARKEN_STRENGTH * l * darken_gate, l * DARKEN_MAX_FRAC);
    // Scale RGB uniformly so hue is preserved while luma drops by delta
    c.rgb *= clamp((l - delta) / max(l, 0.001), 0.0, 1.0);
    return c;
}

//!DESC Anime4K-Ultra-Thin-AA-SH-ChromaDeblur
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND PWSOBEL
//!BIND LINECONF

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)
#define CHROMA_DEBLUR_AMOUNT 2.2   // (0.0 to ~3.0)
#define DARKEN_LUMA_FLOOR    0.08  // Match above
#define DARKEN_LUMA_CEIL     0.72  // Match above
#define CONF_LOW             0.02
#define CONF_HIGH            0.18
#define TANGENT_TAPS         2     // ±N taps along tangent (1 = 3-tap, 2 = 5-tap)
#define TANGENT_SIGMA        1.0   // Gaussian sigma for tangent weights

float get_luma(vec3 rgb) { return dot(vec3(0.299, 0.587, 0.114), rgb); }
float gaussian(float x, float s) { return exp(-0.5 * (x/s) * (x/s)); }

vec4 hook() {
    float effect_mask = smoothstep(CONF_LOW, CONF_HIGH, LINECONF_tex(LINECONF_pos).x);
    if (effect_mask < 0.001) return HOOKED_tex(HOOKED_pos);

    vec4 c = HOOKED_tex(HOOKED_pos);
    float l = get_luma(c.rgb);

    // Inverse of Darken's luma_gate: restricts sharpening to coloured/bright pixels, avoiding double-processing of dark ink lines
    float color_gate = smoothstep(DARKEN_LUMA_FLOOR, DARKEN_LUMA_CEIL, l);
    if (color_gate < 0.001) return c;

    vec2 sd = PWSOBEL_tex(PWSOBEL_pos).xy;
    float mag = length(sd);
    vec2 tang = (mag > 0.01) ? vec2(-sd.y, sd.x) / mag : vec2(1.0, 0.0);

    // Gaussian-weighted blur along the edge tangent, used as the low-frequency reference for the unsharp mask. Tangent-aligned blur avoids softening across the edge while still averaging chroma fringing along its length
    vec4 blur = vec4(0.0);
    float wsum = 0.0;
    for (int i = -TANGENT_TAPS; i <= TANGENT_TAPS; i++) {
        float fi = float(i);
        float w = gaussian(fi, TANGENT_SIGMA);
        blur += HOOKED_texOff(tang * fi * D) * w;
        wsum += w;
    }
    blur /= wsum;

    // sharpened = c + (c - tangent_blur) · strength
    float strength = CHROMA_DEBLUR_AMOUNT * effect_mask * color_gate;
    vec3 sharpened = c.rgb + (c.rgb - blur.rgb) * strength;

    // Clamp to the min/max of the two nearest tangent neighbours to prevent residual overshoot from propagating into flat colour areas
    vec4 t1 = HOOKED_texOff( tang * D);
    vec4 t2 = HOOKED_texOff(-tang * D);
    vec3 mn = min(min(t1.rgb, t2.rgb), c.rgb);
    vec3 mx = max(max(t1.rgb, t2.rgb), c.rgb);
    sharpened = clamp(sharpened, mn, mx);

    return clamp(vec4(sharpened, c.a), 0.0, 1.0);
}
