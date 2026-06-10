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
    float blur = (
        get_luma(HOOKED_texOff(vec2(-D,-D))) + get_luma(HOOKED_texOff(vec2(0.0,-D))) + get_luma(HOOKED_texOff(vec2(D,-D))) +
        get_luma(HOOKED_texOff(vec2(-D, 0.0))) + c + get_luma(HOOKED_texOff(vec2(D, 0.0))) +
        get_luma(HOOKED_texOff(vec2(-D, D))) + get_luma(HOOKED_texOff(vec2(0.0, D))) + get_luma(HOOKED_texOff(vec2(D, D)))
    ) / 9.0;
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
    float gx = (tx + cx + cx + bx) / 8.0;
    float gy = (-ty + by) / 8.0;
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

#define SPATIAL_SIGMA (1.5 * LINESOBEL_size.y / NATIVE_RES_size.y) // Base blur radius for edge detection (~0.5 to 3.0 by modifying the '1.5' multiplier)
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

#define SPATIAL_SIGMA (1.5 * LINESOBEL_size.y / NATIVE_RES_size.y) // Base blur radius for edge detection (~0.5 to 3.0 by modifying the '1.5' multiplier)
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
    vec2 tang = (mag > 0.001) ? vec2(-sd.y, sd.x) / mag : vec2(1.0, 0.0);

    float csum = sd.z, cwsum = 1.0;
    for (int i = 1; i <= TANGENT_TAPS; i++) {
        float fi = float(i);
        float w = gaussian(fi, TANGENT_SIGMA);
        csum += (LINESOBEL_texOff( tang * (fi * D)).z + LINESOBEL_texOff(-tang * (fi * D)).z) * w;
        cwsum += 2.0 * w;
    }
    return vec4(csum / cwsum, 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Warp
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND LINESOBEL
//!BIND LINECONF

#define THIN_STRENGTH         0.06 // Base displacement step in output pixels per iteration (0.0 to ~0.2)
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

    float relstr = (LINESOBEL_size.y / NATIVE_RES_size.y) * THIN_STRENGTH;
    vec2 d = LINESOBEL_pt;
    vec2 offset = vec2(0.0);
    for (int i = 0; i < ITERATIONS; i++) {
        vec2 dn = LINESOBEL_tex(LINESOBEL_pos + offset).xy;
        float mag = length(dn);
        if (mag > MIN_EDGE_STRENGTH)
            offset -= (dn / (mag + 0.01)) * d * relstr;
        else break;
    }

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
    return vec4(gx, gy, sqrt(gx * gx + gy * gy), 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-SH-Dealias-USM
//!HOOK MAIN
//!BIND NATIVE_RES
//!BIND HOOKED
//!BIND PWSOBEL
//!BIND LINECONF

#define D (0.75 * HOOKED_size.y / NATIVE_RES_size.y)
#define DEALIAS_STRENGTH 1.25 // Interpolation strength (0.0 to ~2.0); >1.0 mathematically extrapolates to aggressively force AA
#define USM_AMOUNT       0.5  // Unsharp mask strength specifically over dealiased lines (0.0 to ~2.0)
#define CONF_LOW         0.05 // Lower bound of the effect mask's smoothstep transition (0.0 to 1.0)
#define CONF_HIGH        0.18 // Upper bound of the effect mask's smoothstep transition (0.0 to 1.0; must be > CONF_LOW)

float get_luma(vec3 rgb) { return dot(vec3(0.299, 0.587, 0.114), rgb); }

vec4 hook() {
    float effect_mask = smoothstep(CONF_LOW, CONF_HIGH, LINECONF_tex(LINECONF_pos).x);
    if (effect_mask < 0.001) return HOOKED_tex(HOOKED_pos);

    vec4 c = HOOKED_tex(HOOKED_pos);
    vec2 sd = PWSOBEL_tex(PWSOBEL_pos).xy;
    float mag = length(sd);
    vec2 tang = (mag > 0.01) ? vec2(-sd.y, sd.x) / mag : vec2(1.0, 0.0);

    vec4 t1 = HOOKED_tex(HOOKED_pos + tang * HOOKED_pt * D);
    vec4 t2 = HOOKED_tex(HOOKED_pos - tang * HOOKED_pt * D);
    float lc = get_luma(c.rgb);
    float w1 = exp(-abs(get_luma(t1.rgb) - lc) * 20.0);
    float w2 = exp(-abs(get_luma(t2.rgb) - lc) * 20.0);
    vec4 c_da = mix(c, (c + t1 * w1 + t2 * w2) / (1.0 + w1 + w2), DEALIAS_STRENGTH * effect_mask);

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
#define DARKEN_STRENGTH 0.23 // Base multiplier for line darkening via local luma valleys (0.0 to ~1.0)
#define DARKEN_MAX_FRAC 0.25 // Max fraction of luma to SUBTRACT (0.0 to 1.0); 0.25 means keeping at least 75% of original brightness
#define CONF_LOW        0.02 // Lower bound of the effect mask's smoothstep transition (0.0 to 1.0)
#define CONF_HIGH       0.18 // Upper bound of the effect mask's smoothstep transition (0.0 to 1.0; must be > CONF_LOW)

float get_luma(vec3 rgb) { return dot(vec3(0.299, 0.587, 0.114), rgb); }

float valley_at(vec2 p) {
    vec2 gxy = PWSOBEL_tex(p).xy;
    float mag = length(gxy);
    vec2 norm = (mag > 0.01) ? (gxy / mag) : vec2(1.0, 0.0);
    float lc = get_luma(HOOKED_tex(p).rgb);
    float lpos = max(get_luma(HOOKED_tex(p + norm * HOOKED_pt * D).rgb),
                     get_luma(HOOKED_tex(p + norm * HOOKED_pt * (D * 2.0)).rgb));
    float lneg = max(get_luma(HOOKED_tex(p - norm * HOOKED_pt * D).rgb),
                     get_luma(HOOKED_tex(p - norm * HOOKED_pt * (D * 2.0)).rgb));
    return clamp((min(lpos, lneg) - lc) * 8.0 / max(max(lpos, lneg), 0.1), 0.0, 1.0);
}

vec4 hook() {
    float effect_mask = smoothstep(CONF_LOW, CONF_HIGH, LINECONF_tex(LINECONF_pos).x);
    if (effect_mask < 0.001) return HOOKED_tex(HOOKED_pos);

    vec2 gxy = PWSOBEL_tex(PWSOBEL_pos).xy;
    float mag = length(gxy);
    vec2 tang = (mag > 0.01) ? vec2(-gxy.y, gxy.x) / mag : vec2(1.0, 0.0);

    float valley = max(valley_at(HOOKED_pos),
                   max(valley_at(HOOKED_pos + tang * HOOKED_pt * D),
                       valley_at(HOOKED_pos - tang * HOOKED_pt * D)));

    vec4 c = HOOKED_tex(HOOKED_pos);
    float l = get_luma(c.rgb);
    float delta = min(effect_mask * valley * DARKEN_STRENGTH * l, l * DARKEN_MAX_FRAC);
    c.rgb *= clamp((l - delta) / max(l, 0.001), 0.0, 1.0);
    return c;
}
