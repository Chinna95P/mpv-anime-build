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

//!DESC Anime4K-Ultra-Thin-AA-DB-Luma-Sharp
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!SAVE LINELUMA_SHARP
//!WIDTH HOOKED.w
//!HEIGHT HOOKED.h
//!COMPONENTS 1

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)
#define LUMA_SHARP_AMOUNT 1.5

vec4 hook() {
    float c = HOOKED_tex(HOOKED_pos).x;
    float blur = (
        HOOKED_texOff(vec2(-D,-D)).x + HOOKED_texOff(vec2( 0.0,-D)).x + HOOKED_texOff(vec2(D,-D)).x +
        HOOKED_texOff(vec2(-D, 0.0)).x + c + HOOKED_texOff(vec2(D, 0.0)).x +
        HOOKED_texOff(vec2(-D, D)).x + HOOKED_texOff(vec2( 0.0, D)).x + HOOKED_texOff(vec2(D, D)).x
    ) / 9.0;
    return vec4(clamp(c + (c - blur) * LUMA_SHARP_AMOUNT, 0.0, 1.0), 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-DB-Sobel-X
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Sobel-Y
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Gaussian-X
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Gaussian-Y
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Kernel-X
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Kernel-Y
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Line-Confidence
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Warp
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND LINESOBEL
//!BIND LINECONF

#define D (0.75 * LINESOBEL_size.y / NATIVE_RES_size.y)
#define THIN_STRENGTH         0.05 // Base displacement step in output pixels per iteration (0.0 to ~0.2)
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

//!DESC Anime4K-Ultra-Thin-AA-DB-PW-Sobel-X
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

//!DESC Anime4K-Ultra-Thin-AA-DB-PW-Sobel-Y
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

//!DESC Anime4K-Ultra-Thin-AA-DB-Dealias-Deblur
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND PWSOBEL
//!BIND LINESOBEL
//!BIND LINECONF

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)
#define DEALIAS_STRENGTH 0.25 // Interpolation strength (0.0 to ~2.0); >1.0 mathematically extrapolates to aggressively force AA
#define DEBLUR_PUSH      0.70 // Strength of luma push toward the detected edge extreme (0.0 to 1.0)
#define DEBLUR_TAPS      3    // Samples along edge normal for min/max luma search (int 1 to ~5)
#define DEBLUR_EDGE_BAND 0.06 // Smoothstep half-width for edge-side classification (0.0 to ~0.2)
#define CONF_LOW         0.02 // Lower bound of the effect mask's smoothstep transition (0.0 to 1.0)
#define CONF_HIGH        0.18 // Upper bound of the effect mask's smoothstep transition (0.0 to 1.0; must be > CONF_LOW)

float get_luma(vec3 rgb) { return dot(vec3(0.299, 0.587, 0.114), rgb); }

vec4 hook() {
    float effect_mask = smoothstep(CONF_LOW, CONF_HIGH, LINECONF_tex(LINECONF_pos).x);
    if (effect_mask < 0.001) return HOOKED_tex(HOOKED_pos);

    vec2 wpos = HOOKED_pos;

    vec4 c = HOOKED_tex(wpos);
    vec2 sd = PWSOBEL_tex(PWSOBEL_pos).xy;
    float mag = length(sd);
    vec2 tang = (mag > 0.01) ? vec2(-sd.y,  sd.x) / mag : vec2(1.0, 0.0); // ⊥ to gradient = along line
    vec2 norm = (mag > 0.01) ? sd / mag : vec2(0.0, 1.0); // ∥ to gradient = across line, pointing toward bright side

    // Blends neighbours along the line. Bilateral weights suppress mixing across
    // luma discontinuities, keeping the blend within the same side of the edge
    vec4 t1 = HOOKED_tex(wpos + tang * HOOKED_pt * D);
    vec4 t2 = HOOKED_tex(wpos - tang * HOOKED_pt * D);
    float lc = get_luma(c.rgb);
    float w1 = exp(-abs(get_luma(t1.rgb) - lc) * 20.0); // 20.0: bilateral sensitivity; large luma diff → weight ≈ 0
    float w2 = exp(-abs(get_luma(t2.rgb) - lc) * 20.0);
    vec4 c_da = mix(c, (c + t1 * w1 + t2 * w2) / (1.0 + w1 + w2),
                     DEALIAS_STRENGTH * effect_mask);

    // Scans DEBLUR_TAPS steps along ±norm to find the luma range bracketing the
    // edge. Since norm points toward the bright side:
    //   -norm taps → ink/dark side  → tracked by darkest
    //   +norm taps → bg/bright side → tracked by brightest
    float darkest = lc, brightest = lc;
    for (int i = 1; i <= DEBLUR_TAPS; i++) {
        float fi = float(i);
        darkest   = min(darkest,   get_luma(HOOKED_tex(wpos - norm * HOOKED_pt * D * fi).rgb));
        brightest = max(brightest, get_luma(HOOKED_tex(wpos + norm * HOOKED_pt * D * fi).rgb));
    }

    float mid = (darkest + brightest) * 0.5;
    float s_lo = max(mid - DEBLUR_EDGE_BAND, darkest);
    float s_hi = min(mid + DEBLUR_EDGE_BAND, brightest);
    float side = (s_hi > s_lo + 1e-5)
        ? smoothstep(s_lo, s_hi, lc)
        : (lc >= mid ? 1.0 : 0.0);

    float target_luma = mix(darkest, brightest, side);

    float lc_da = get_luma(c_da.rgb);
    float luma_scale = (lc_da > 0.001)
        ? mix(lc_da, target_luma, DEBLUR_PUSH * effect_mask) / lc_da
        : 1.0;

    c_da.rgb = clamp(c_da.rgb * luma_scale, 0.0, 1.0);

    return clamp(c_da, 0.0, 1.0);
}

//!DESC Anime4K-Ultra-Thin-AA-DB-Darken
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND PWSOBEL
//!BIND LINECONF

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)
#define DARKEN_STRENGTH         0.60 // Overall darkening scale (0.0 to ~1.0)
#define DARKEN_MAX_FRAC         0.35 // Cap for achromatic (black/gray) ink lines
#define DARKEN_MAX_FRAC_HUE     0.28 // Reduced cap for hue-matched coloured lines (e.g. red lines in red hair)
#define DARKEN_LUMA_FLOOR       0.08 // Luma below which darkening fades out (0.0 to 1.0)
#define DARKEN_LUMA_CEIL        0.88 // Luma above which darkening is fully suppressed (0.0 to 1.0)
#define CONF_LOW                0.02 // Lower bound of the effect mask's smoothstep transition (0.0 to 1.0)
#define CONF_HIGH               0.18 // Upper bound of the effect mask's smoothstep transition (0.0 to 1.0; must be > CONF_LOW)
#define VALLEY_BG_NEAR          1.0  // Near background tap distance in pixels
#define VALLEY_BG_FAR           2.0  // Far background tap distance in pixels
#define VALLEY_WIDTH_GATE       0.06
// Minimum dot product between a tangent tap's gradient direction and the center
// gradient direction for that tap to be allowed to elevate the valley score.
// ~cos(50°) ≈ 0.64. Raise to be stricter about "same line"; lower to tolerate
// more curve/corner variation along the tangent.
#define TANGENT_CONSISTENCY_MIN 0.64
#define HUE_MATCH_SAT_MIN       0.04 // Min chroma vector length to attempt hue comparison (0.0 to ~0.2)
#define HUE_MATCH_DOT_THRESHOLD 0.70 // Chroma dot product above which line is considered hue-matched to bg (~cos(45°))

float get_luma(vec3 rgb) { return dot(vec3(0.299, 0.587, 0.114), rgb); }

// Returns a [0,1] score indicating how much darker p is than its surroundings on both sides
// High score = confident ink valley; low score = flat region or one-sided edge (shadow, gradient)
float valley_at(vec2 p) {
    vec2 gxy = PWSOBEL_tex(p).xy;
    float mag = length(gxy);
    vec2 norm = (mag > 0.01) ? (gxy / mag) : vec2(1.0, 0.0);
    float lc = get_luma(HOOKED_tex(p).rgb);

    float lpos_near = get_luma(HOOKED_tex(p + norm * HOOKED_pt * D * VALLEY_BG_NEAR).rgb);
    float lneg_near = get_luma(HOOKED_tex(p - norm * HOOKED_pt * D * VALLEY_BG_NEAR).rgb);
    // max(near, far) so a line adjacent to a darker region still detects the brighter background further out
    float lpos = max(lpos_near, get_luma(HOOKED_tex(p + norm * HOOKED_pt * D * VALLEY_BG_FAR).rgb));
    float lneg = max(lneg_near, get_luma(HOOKED_tex(p - norm * HOOKED_pt * D * VALLEY_BG_FAR).rgb));

    // How much darker is the center than the dimmer side, normalized by the brighter side
    float raw_valley = clamp((min(lpos, lneg) - lc) * 8.0 / max(max(lpos, lneg), 0.1), 0.0, 1.0);
    float near_bright = max(lpos_near, lneg_near);
    float width_gate = smoothstep(lc, lc + VALLEY_WIDTH_GATE, near_bright);

    return raw_valley * width_gate;
}

vec4 hook() {
    float effect_mask = smoothstep(CONF_LOW, CONF_HIGH, LINECONF_tex(LINECONF_pos).x);
    if (effect_mask < 0.001) return HOOKED_tex(HOOKED_pos);

    vec2 gxy = PWSOBEL_tex(PWSOBEL_pos).xy;
    float mag = length(gxy);
    vec2 norm = (mag > 0.01) ?  gxy / mag                  : vec2(1.0, 0.0);
    vec2 tang = (mag > 0.01) ?  vec2(-gxy.y, gxy.x) / mag  : vec2(1.0, 0.0);

    // Gradient-direction-consistent max pooling
    float v0 = valley_at(HOOKED_pos);
    vec2 p1 = HOOKED_pos + tang * HOOKED_pt * D;
    vec2 p2 = HOOKED_pos - tang * HOOKED_pt * D;

    vec2 g1 = PWSOBEL_tex(p1).xy;
    vec2 g2 = PWSOBEL_tex(p2).xy;
    float m1 = length(g1), m2 = length(g2);

    // abs(dot) measures alignment between the tangent tap's gradient and the center normal
    // High value = tap is on the same line; abs() handles opposite-sign gradients across the line
    float c1 = (m1 > 0.01) ? abs(dot(g1 / m1, norm)) : 0.0;
    float c2 = (m2 > 0.01) ? abs(dot(g2 / m2, norm)) : 0.0;
    float gate1 = smoothstep(TANGENT_CONSISTENCY_MIN, 1.0, c1);
    float gate2 = smoothstep(TANGENT_CONSISTENCY_MIN, 1.0, c2);

    // Only allow tangent taps to raise the score if their gradient direction is consistent with the center (same line, not a crossing edge)
    float valley = max(v0, max(valley_at(p1) * gate1, valley_at(p2) * gate2));

    vec4 c = HOOKED_tex(HOOKED_pos);
    float l = get_luma(c.rgb);

    // Picks the brighter background side to compare against the line's chroma
    vec3 bg_pos = HOOKED_tex(HOOKED_pos + norm * HOOKED_pt * D * VALLEY_BG_FAR).rgb;
    vec3 bg_neg = HOOKED_tex(HOOKED_pos - norm * HOOKED_pt * D * VALLEY_BG_FAR).rgb;
    vec3 bg_rgb = (get_luma(bg_pos) >= get_luma(bg_neg)) ? bg_pos : bg_neg;

    // Chroma vectors: colour minus its own grey (i.e. subtract luma component)
    vec3 line_chroma = c.rgb  - vec3(l);
    vec3 bg_chroma = bg_rgb - vec3(get_luma(bg_rgb));
    float line_clen = length(line_chroma);
    float bg_clen = length(bg_chroma);
    // Dot product of unit chroma vectors: 1 = same hue, 0 = orthogonal, guarded by saturation floor
    float hue_dot = (line_clen > HUE_MATCH_SAT_MIN && bg_clen > HUE_MATCH_SAT_MIN)
                    ? clamp(dot(line_chroma / line_clen, bg_chroma / bg_clen), 0.0, 1.0)
                    : 0.0;
    float hue_match = smoothstep(HUE_MATCH_DOT_THRESHOLD, 1.0, hue_dot);

    float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    float is_saturated = smoothstep(0.08, 0.25, sat);
    float luma_gate = 1.0 - smoothstep(DARKEN_LUMA_FLOOR, DARKEN_LUMA_CEIL, l);
    float sat_suppress = is_saturated * (1.0 - hue_match);
    float darken_gate = luma_gate * (1.0 - sat_suppress);

    float effective_max_frac = mix(DARKEN_MAX_FRAC, DARKEN_MAX_FRAC_HUE, hue_match * is_saturated);
    // Multiplying by l makes the raw delta proportional to current brightness,
    // preventing over-darkening of pixels that are already dim
    float delta = min(effect_mask * valley * DARKEN_STRENGTH * l * darken_gate,
                      l * effective_max_frac);
    c.rgb *= clamp((l - delta) / max(l, 0.001), 0.0, 1.0); // uniform RGB scale preserves hue
    return c;
}
