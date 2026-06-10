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

//!DESC Anime4K-Ultra-Thin-AA-Luma
//!HOOK MAIN
//!BIND HOOKED
//!SAVE LINELUMA
//!COMPONENTS 1

float get_luma(vec4 rgba) {
    return dot(vec3(0.299, 0.587, 0.114), rgba.rgb);
}

vec4 hook() {
    return vec4(get_luma(HOOKED_tex(HOOKED_pos)), 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-Sobel-X
//!HOOK MAIN
//!BIND LINELUMA
//!SAVE LINESOBEL
//!COMPONENTS 2

vec4 hook() {
    float l = LINELUMA_texOff(vec2(-1.0, 0.0)).x;
    float c = LINELUMA_tex(LINELUMA_pos).x;
    float r = LINELUMA_texOff(vec2(1.0, 0.0)).x;
    return vec4(-l + r, l + c + c + r, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-Sobel-Y
//!HOOK MAIN
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!COMPONENTS 1

vec4 hook() {
    float tx = LINESOBEL_texOff(vec2(0.0, -1.0)).x;
    float cx = LINESOBEL_tex(LINESOBEL_pos).x;
    float bx = LINESOBEL_texOff(vec2(0.0, 1.0)).x;
    float ty = LINESOBEL_texOff(vec2(0.0, -1.0)).y;
    float by = LINESOBEL_texOff(vec2(0.0, 1.0)).y;
    float xgrad = (tx + cx + cx + bx) / 8.0;
    float ygrad = (-ty + by) / 8.0;
    return vec4(pow(sqrt(xgrad * xgrad + ygrad * ygrad), 0.7));
}

//!DESC Anime4K-Ultra-Thin-AA-Gaussian-X
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!COMPONENTS 1

#define SPATIAL_SIGMA (1.5 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.
#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1) //Kernel size, must be an positive odd integer.

float gaussian(float x, float s) {
    return exp(-0.5 * (x/s) * (x/s));
}

vec4 hook() {
    float g = 0.0;
    float gn = 0.0;
    for (int i=0; i<KERNELSIZE; i++) {
        float di = float(i - int(KERNELSIZE/2));
        float gf = gaussian(di, SPATIAL_SIGMA);
        g += LINESOBEL_texOff(vec2(di, 0.0)).x * gf;
        gn += gf;
    }
    return vec4(g / gn, 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-Gaussian-Y
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!COMPONENTS 1

#define SPATIAL_SIGMA (1.5 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.
#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1) //Kernel size, must be an positive odd integer

float gaussian(float x, float s) {
    return exp(-0.5 * (x/s) * (x/s));
}

vec4 hook() {
    float g = 0.0;
    float gn = 0.0;
    for (int i=0; i<KERNELSIZE; i++) {
        float di = float(i - int(KERNELSIZE/2));
        float gf = gaussian(di, SPATIAL_SIGMA);
        g += LINESOBEL_texOff(vec2(0.0, di)).x * gf;
        gn += gf;
    }
    return vec4(g / gn, 0.0, 0.0, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-Kernel-X
//!HOOK MAIN
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!COMPONENTS 3

vec4 hook() {
    float l = LINESOBEL_texOff(vec2(-1.0, 0.0)).x;
    float c = LINESOBEL_tex(LINESOBEL_pos).x;
    float r = LINESOBEL_texOff(vec2(1.0, 0.0)).x;
    return vec4(-l + r, l + c + c + r, c, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-Kernel-Y
//!HOOK MAIN
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!COMPONENTS 3

vec4 hook() {
    float tx = LINESOBEL_texOff(vec2(0.0, -1.0)).x;
    float cx = LINESOBEL_tex(LINESOBEL_pos).x;
    float bx = LINESOBEL_texOff(vec2(0.0, 1.0)).x;
    float ty = LINESOBEL_texOff(vec2(0.0, -1.0)).y;
    float by = LINESOBEL_texOff(vec2(0.0, 1.0)).y;
    float line_mask = LINESOBEL_tex(LINESOBEL_pos).z;
    return vec4((tx + cx + cx + bx) / 8.0, (-ty + by) / 8.0, line_mask, 0.0);
}

//!DESC Anime4K-Ultra-Thin-AA-Warp-Final
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINESOBEL

#define THIN_STRENGTH 0.12 // Strength of warping for each iteration
#define ITERATIONS 3       // Number of iterations for the forwards solver, decreasing strength and increasing iterations improves quality at the cost of speed
#define DARKEN_STRENGTH 0.7    // [0.0 to 1.0]
#define DEALIAS_STRENGTH 0.5   // [0.0 to 2.0]
#define MIN_EDGE_STRENGTH 0.01 // [0.0 to 1.0] Higher = protects glows more, but might miss very faint lines

vec4 hook() {
    vec2 d = HOOKED_pt;
    float relstr = HOOKED_size.y / 1080.0 * THIN_STRENGTH;
    vec2 pos = HOOKED_pos;
    
    // Thinning / Warping
    for (int i=0; i<ITERATIONS; i++) {
        vec2 dn = LINESOBEL_tex(pos).xy;
        float mag = length(dn);
        if (mag > MIN_EDGE_STRENGTH) {
            vec2 dd = (dn / (mag + 0.01)) * d * relstr;
            pos -= dd;
        } else {
            break;
        }
    }

    vec4 c_final = HOOKED_tex(pos);

    // Dark line detection (5-tap average)
    vec2 d_aa = d * 0.5;
    vec4 c_l = HOOKED_tex(pos - vec2(d_aa.x, 0.0));
    vec4 c_r = HOOKED_tex(pos + vec2(d_aa.x, 0.0));
    vec4 c_t = HOOKED_tex(pos - vec2(0.0, d_aa.y));
    vec4 c_b = HOOKED_tex(pos + vec2(0.0, d_aa.y));
    vec4 c_avg = (c_final + c_l + c_r + c_t + c_b) / 5.0;

    // Inline Luma Calculation (Standard Rec.601)
    float l_center = dot(vec3(0.299, 0.587, 0.114), c_final.rgb);
    float l_avg    = dot(vec3(0.299, 0.587, 0.114), c_avg.rgb);
    float valley_depth = clamp((l_avg - l_center) * 10.0, 0.0, 1.0); // Positive if center is darker than neighbors
    
    float structure = LINESOBEL_tex(pos).z;
    float structure_mask = smoothstep(0.05, 0.15, structure);

    float darken_mask = valley_depth * structure_mask;

    // Apply
    c_final = mix(c_final, c_avg, darken_mask * DEALIAS_STRENGTH);
    c_final.rgb -= c_final.rgb * darken_mask * (1.0 - l_center) * DARKEN_STRENGTH;

    return c_final;
}