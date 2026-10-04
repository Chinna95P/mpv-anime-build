// Copyright (c) 2015-2021, bacondither
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer
//    in this position and unchanged.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// Adaptive sharpen - version DX11 - 2021-09-10 (quality_mode 1, the HQ original code path)
// Tuned for use post-resize, EXPECTS FULL RANGE GAMMA LIGHT
// mpv / libplacebo user-shader form of bacondither/Miscellaneous-shaders "Adaptive-sharpen - DX11" pass 1 + pass 2
// (repo state 24783895, 2021-10-19), the HLSL math unchanged.

// Settings (sharpening strength curve_height, quality_mode): the "Settings" block at the start of pass 2
// below. mpv compiles each pass on its own, so they live in the pass that uses them.

//!HOOK OUTPUT
//!BIND HOOKED
//!SAVE ASEDGE
//!COMPONENTS 4
//!DESC Adaptive Sharpen Modern (4K) pass 1

#define a_offset     2.0                     // Edge channel offset, MUST BE THE SAME IN ALL PASSES
#define get(x,y)     ( clamp(HOOKED_texOff(vec2(x, y)).rgb, 0.0, 1.0) )
#define b_diff(pix)  ( abs(blur - c[pix]) )

vec4 hook() {
    vec3 cO = HOOKED_texOff(vec2(0.0, 0.0)).rgb;
    // [                c9                ]
    // [           c1,  c2,  c3           ]
    // [      c10, c4,  c0,  c5, c11      ]
    // [           c6,  c7,  c8           ]
    // [                c12               ]
    vec3 c[13] = vec3[](clamp(cO, 0.0, 1.0), get(-1,-1), get( 0,-1), get( 1,-1), get(-1, 0),
                        get( 1, 0), get(-1, 1), get( 0, 1), get( 1, 1), get( 0,-2),
                        get(-2, 0), get( 2, 0), get( 0, 2));
    vec3 blur = (2.0*(c[2]+c[4]+c[5]+c[7]) + (c[1]+c[3]+c[6]+c[8]) + 4.0*c[0])/16.0;
    float c_comp = clamp(4.0/15.0 + 0.9*exp2(dot(blur, vec3(-37.0/15.0))), 0.0, 1.0);
    float edge = length( 1.38*(b_diff(0))
                       + 1.15*(b_diff(2) + b_diff(4)  + b_diff(5)  + b_diff(7))
                       + 0.92*(b_diff(1) + b_diff(3)  + b_diff(6)  + b_diff(8))
                       + 0.23*(b_diff(9) + b_diff(10) + b_diff(11) + b_diff(12)) );
    return vec4(cO, edge*c_comp + a_offset);
}

//!HOOK OUTPUT
//!BIND HOOKED
//!BIND ASEDGE
//!DESC Adaptive Sharpen Modern (4K) pass 2

//--------------------------------------- Settings ------------------------------------------------

#define curve_height    0.45                  // Main control of sharpening strength [>0]
                                             // 0.3 <-> 2.0 is a reasonable range of values

#define quality_mode    1                    // Use HQ original code path (1), faster approximations (0)

// Defined values under this row are "optimal" DO NOT CHANGE IF YOU DO NOT KNOW WHAT YOU ARE DOING!

#define curveslope      0.3                  // Sharpening curve slope, high edge values

#define L_overshoot     0.003                // Max light overshoot before compression [>0.001]
#define L_compr_low     0.101                // Light compression, default (0.167=~6x)
#define L_compr_high    0.268                // Light compression, surrounded by edges (0.334=~3x)

#define D_overshoot     0.009                // Max dark overshoot before compression [>0.001]
#define D_compr_low     0.172                // Dark compression, default (0.250=4x)
#define D_compr_high    0.438                // Dark compression, surrounded by edges (0.500=2x)

#define scale_lim       0.076                  // Abs max change before compression [>0.01]
#define scale_cs        0.031                // Compression slope above scale_lim [0.0-1.0]

#define pm_p            0.91                  // Power mean p-value [>0.0-1.0]
//-------------------------------------------------------------------------------------------------

#define a_offset        2.0                  // Edge channel offset, MUST BE THE SAME IN ALL PASSES

#define soft_if(a,b,c) ( clamp((a + b + c - 3.0*a_offset + 0.056)/(abs(maxedge) + 0.03) - 0.85, 0.0, 1.0) )
#if (quality_mode == 0) // Tanh approx
    #define soft_lim(v,s)  ( clamp(abs(v/s)*(27.0 + sqr(v/s))/(27.0 + 9.0*sqr(v/s)), 0.0, 1.0)*s )
#else
    #define soft_lim(v,s)  ( (exp(2.0*min(abs(v), s*24.0)/s) - 1.0)/(exp(2.0*min(abs(v), s*24.0)/s) + 1.0)*s )
#endif
#define wpmean(a,b,w)  ( pow(w*pow(abs(a), pm_p) + abs(1.0-w)*pow(abs(b), pm_p), (1.0/pm_p)) )
#define get(x,y)       ( ASEDGE_texOff(vec2(x, y)) )
#define satc(var)      ( vec4(clamp((var).rgb, 0.0, 1.0), (var).a) )
#define max4(a,b,c,d)  ( max(max(a, b), max(c, d)) )
#define max3(a,b,c)    ( max(max(a, b), c) )
#define sqr(a)         ( (a)*(a) )
#define CtL(var)       ( sqrt(dot(vec3(0.2558, 0.6511, 0.0931), clamp(((var)*abs(var)).rgb, 0.0, 1.0))) )
#define mdiff(a,b,c,d,e,f,g) ( abs(luma[g] - luma[a]) + abs(luma[g] - luma[b])       \
                             + abs(luma[g] - luma[c]) + abs(luma[g] - luma[d])       \
                             + 0.5*(abs(luma[g] - luma[e]) + abs(luma[g] - luma[f])) )

vec4 hook() {
    vec4 cO = get(0, 0);
    float c_edge = cO.a - a_offset;
    if (c_edge > 16.0 || c_edge < -0.5) { return vec4(0.0, 1.0, 0.0, 1.0); }  // bounds_check: green = bad edge data

    // [                c22               ]
    // [           c24, c9,  c23          ]
    // [      c21, c1,  c2,  c3, c18      ]
    // [ c19, c10, c4,  c0,  c5, c11, c16 ]
    // [      c20, c6,  c7,  c8, c17      ]
    // [           c15, c12, c14          ]
    // [                c13               ]
    vec4 c[25] = vec4[](satc( cO ), get(-1,-1), get( 0,-1), get( 1,-1), get(-1, 0),
                        get( 1, 0), get(-1, 1), get( 0, 1), get( 1, 1), get( 0,-2),
                        get(-2, 0), get( 2, 0), get( 0, 2), get( 0, 3), get( 1, 2),
                        get(-1, 2), get( 3, 0), get( 2, 1), get( 2,-1), get(-3, 0),
                        get(-2, 1), get(-2,-1), get( 0,-3), get( 1,-2), get(-1,-2));

    float maxedge = max4( max4(c[1].a,c[2].a,c[3].a,c[4].a), max4(c[5].a,c[6].a,c[7].a,c[8].a),
                          max4(c[9].a,c[10].a,c[11].a,c[12].a), c[0].a ) - a_offset;

    float sbe = soft_if(c[2].a,c[9].a, c[22].a)*soft_if(c[7].a,c[12].a,c[13].a)  // x dir
              + soft_if(c[4].a,c[10].a,c[19].a)*soft_if(c[5].a,c[11].a,c[16].a)  // y dir
              + soft_if(c[1].a,c[24].a,c[21].a)*soft_if(c[8].a,c[14].a,c[17].a)  // z dir
              + soft_if(c[3].a,c[23].a,c[18].a)*soft_if(c[6].a,c[20].a,c[15].a); // w dir

#if (quality_mode == 0)
    vec2 cs = mix( vec2(L_compr_low,  D_compr_low),
                   vec2(L_compr_high, D_compr_high), clamp(1.091*sbe - 2.282, 0.0, 1.0) );
#else
    vec2 cs = mix( vec2(L_compr_low,  D_compr_low),
                   vec2(L_compr_high, D_compr_high), smoothstep(2.0, 3.1, sbe) );
#endif

    float c0_Y = CtL(c[0]);
    float luma[25] = float[](c0_Y, CtL(c[1]), CtL(c[2]), CtL(c[3]), CtL(c[4]), CtL(c[5]), CtL(c[6]),
                             CtL(c[7]),  CtL(c[8]),  CtL(c[9]),  CtL(c[10]), CtL(c[11]), CtL(c[12]),
                             CtL(c[13]), CtL(c[14]), CtL(c[15]), CtL(c[16]), CtL(c[17]), CtL(c[18]),
                             CtL(c[19]), CtL(c[20]), CtL(c[21]), CtL(c[22]), CtL(c[23]), CtL(c[24]));

    const vec3 W1 = vec3(0.5,           1.0, 1.41421356237); // 0.25, 1.0, 2.0
    const vec3 W2 = vec3(0.86602540378, 1.0, 0.54772255751); // 0.75, 1.0, 0.3
#if (quality_mode == 0)
    vec3 dW = sqr(mix( W1, W2, clamp(2.4*c_edge - 0.82, 0.0, 1.0) ));
#else
    vec3 dW = sqr(mix( W1, W2, smoothstep(0.3, 0.8, c_edge) ));
#endif

    float mdiff_c0 = 0.02 + 3.0*( abs(luma[0]-luma[2]) + abs(luma[0]-luma[4])
                                + abs(luma[0]-luma[5]) + abs(luma[0]-luma[7])
                                + 0.25*(abs(luma[0]-luma[1]) + abs(luma[0]-luma[3])
                                       +abs(luma[0]-luma[6]) + abs(luma[0]-luma[8])) );

    float weights[12] = float[]( ( min(mdiff_c0/mdiff(24, 21, 2,  4,  9,  10, 1),  dW.y) ),   // c1
                                 ( dW.x ),                                                    // c2
                                 ( min(mdiff_c0/mdiff(23, 18, 5,  2,  9,  11, 3),  dW.y) ),   // c3
                                 ( dW.x ),                                                    // c4
                                 ( dW.x ),                                                    // c5
                                 ( min(mdiff_c0/mdiff(4,  20, 15, 7,  10, 12, 6),  dW.y) ),   // c6
                                 ( dW.x ),                                                    // c7
                                 ( min(mdiff_c0/mdiff(5,  7,  17, 14, 12, 11, 8),  dW.y) ),   // c8
                                 ( min(mdiff_c0/mdiff(2,  24, 23, 22, 1,  3,  9),  dW.z) ),   // c9
                                 ( min(mdiff_c0/mdiff(20, 19, 21, 4,  1,  6,  10), dW.z) ),   // c10
                                 ( min(mdiff_c0/mdiff(17, 5,  18, 16, 3,  8,  11), dW.z) ),   // c11
                                 ( min(mdiff_c0/mdiff(13, 15, 7,  14, 6,  8,  12), dW.z) ) ); // c12

    weights[0] = (max3((weights[8]  + weights[9])/4.0,  weights[0], 0.25) + weights[0])/2.0;
    weights[2] = (max3((weights[8]  + weights[10])/4.0, weights[2], 0.25) + weights[2])/2.0;
    weights[5] = (max3((weights[9]  + weights[11])/4.0, weights[5], 0.25) + weights[5])/2.0;
    weights[7] = (max3((weights[10] + weights[11])/4.0, weights[7], 0.25) + weights[7])/2.0;

    float lowthrsum   = 0.0;
    float weightsum   = 0.0;
    float neg_laplace = 0.0;
    for (int pix = 0; pix < 12; ++pix)
    {
#if (quality_mode == 0)
        // as in the HLSL: the a_offset sits outside the 13.2 factor here
        float lowthr = clamp((13.2*c[pix + 1].a - a_offset - 0.221), 0.01, 1.0);
        neg_laplace += sqr(luma[pix + 1])*(abs(weights[pix])*lowthr);
#else
        float t = clamp((c[pix + 1].a - a_offset - 0.01)/0.09, 0.0, 1.0);
        float lowthr = t*t*(2.97 - 1.98*t) + 0.01;
        neg_laplace += pow(abs(luma[pix + 1]) + 0.06, 2.4)*(abs(weights[pix])*lowthr);
#endif
        weightsum   += abs(weights[pix])*lowthr;
        lowthrsum   += lowthr/12.0;
    }
#if (quality_mode == 0)
    neg_laplace = sqrt(neg_laplace/weightsum);
#else
    neg_laplace = clamp(pow(neg_laplace/weightsum, (1.0/2.4)) - 0.06, 0.0, 1.0);
#endif

    float sharpen_val = curve_height/(curve_height*curveslope*pow(abs(c_edge), 3.5) + 0.625);
    float sharpdiff = (c0_Y - neg_laplace)*(lowthrsum*sharpen_val + 0.01);

    // Calculate local near min & max, partial sort (3 iterations)
    float temp; int i; int ii;
    for (i = 0; i < 24; i += 2) { temp = luma[i]; luma[i] = min(luma[i], luma[i+1]); luma[i+1] = max(temp, luma[i+1]); }
    for (ii = 24; ii > 0; ii -= 2)
    {
        temp = luma[0];  luma[0]  = min(luma[0], luma[ii]);    luma[ii]   = max(temp, luma[ii]);
        temp = luma[24]; luma[24] = max(luma[24], luma[ii-1]); luma[ii-1] = min(temp, luma[ii-1]);
    }
    for (i = 1; i < 23; i += 2) { temp = luma[i]; luma[i] = min(luma[i], luma[i+1]); luma[i+1] = max(temp, luma[i+1]); }
    for (ii = 23; ii > 1; ii -= 2)
    {
        temp = luma[1];  luma[1]  = min(luma[1], luma[ii]);    luma[ii]   = max(temp, luma[ii]);
        temp = luma[23]; luma[23] = max(luma[23], luma[ii-1]); luma[ii-1] = min(temp, luma[ii-1]);
    }
#if (quality_mode != 0) // 3rd iteration
    for (i = 2; i < 22; i += 2) { temp = luma[i]; luma[i] = min(luma[i], luma[i+1]); luma[i+1] = max(temp, luma[i+1]); }
    for (ii = 22; ii > 2; ii -= 2)
    {
        temp = luma[2];  luma[2]  = min(luma[2], luma[ii]);    luma[ii]   = max(temp, luma[ii]);
        temp = luma[22]; luma[22] = max(luma[22], luma[ii-1]); luma[ii-1] = min(temp, luma[ii-1]);
    }
#endif

#if (quality_mode == 0)
    float nmax = (max(luma[23], c0_Y)*2.0 + luma[24])/3.0;
    float nmin = (min(luma[1],  c0_Y)*2.0 + luma[0])/3.0;
    float min_dist  = min(abs(nmax - c0_Y), abs(c0_Y - nmin));
    vec2 pn_scale = min_dist + vec2(L_overshoot, D_overshoot);
#else
    float nmax = (max(luma[22] + luma[23]*2.0, c0_Y*3.0) + luma[24])/4.0;
    float nmin = (min(luma[2]  + luma[1]*2.0,  c0_Y*3.0) + luma[0])/4.0;
    float min_dist  = min(abs(nmax - c0_Y), abs(c0_Y - nmin));
    vec2 pn_scale = vec2( min(L_overshoot + min_dist, 1.0001 - c0_Y),
                          min(D_overshoot + min_dist, 0.0001 + c0_Y) );
#endif
    pn_scale = min(pn_scale, scale_lim*(1.0 - scale_cs) + pn_scale*scale_cs);

    sharpdiff = wpmean( max(sharpdiff, 0.0), soft_lim( max(sharpdiff, 0.0), pn_scale.x ), cs.x )
              - wpmean( min(sharpdiff, 0.0), soft_lim( min(sharpdiff, 0.0), pn_scale.y ), cs.y );

    // Compensate for saturation loss/gain while making pixels brighter/darker
    float sharpdiff_lim = clamp(c0_Y + sharpdiff, 0.0, 1.0) - c0_Y;
    float satmul = (c0_Y + max(sharpdiff_lim*0.9, sharpdiff_lim)*1.03 + 0.03)/(c0_Y + 0.03);
    vec3 res = c0_Y + (sharpdiff_lim*3.0 + sharpdiff)/4.0 + (c[0].rgb - c0_Y)*satmul;
    return vec4(res, 1.0);
}
