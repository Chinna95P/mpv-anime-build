/*
 * Anime-Line-Thinner (4K Tier)
 * Part of mpv-anime-build by Chinna95P
 *
 * Copyright (c) 2026 Chinna95P
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

//!HOOK MAIN
//!BIND HOOKED
//!DESC Morphological Line Thinner (4K - 24% Strength)

vec4 hook() {
    // Define the thinning strength (e.g., 0.35 for 35%)
    float blend_factor = 0.24;

    vec4 center = HOOKED_texOff(0.0);
    vec4 n1 = HOOKED_texOff(vec2( 0.0,  1.0));
    vec4 n2 = HOOKED_texOff(vec2( 0.0, -1.0));
    vec4 n3 = HOOKED_texOff(vec2( 1.0,  0.0));
    vec4 n4 = HOOKED_texOff(vec2(-1.0,  0.0));

    float luma_center = dot(center.rgb, vec3(0.299, 0.587, 0.114));
    float luma1 = dot(n1.rgb, vec3(0.299, 0.587, 0.114));
    float luma2 = dot(n2.rgb, vec3(0.299, 0.587, 0.114));
    float luma3 = dot(n3.rgb, vec3(0.299, 0.587, 0.114));
    float luma4 = dot(n4.rgb, vec3(0.299, 0.587, 0.114));

    float max_luma = max(max(max(luma1, luma2), luma3), luma4);
    
    vec4 brightest = center;
    if (max_luma == luma1) brightest = n1;
    else if (max_luma == luma2) brightest = n2;
    else if (max_luma == luma3) brightest = n3;
    else brightest = n4;

    vec4 result = center;
    
    // 4K Math: Extremely strict threshold, barely touches the pixel (20% blend)
    if (max_luma > luma_center + 0.20) {
        result = mix(center, brightest, blend_factor);
    }

    return result;
}
