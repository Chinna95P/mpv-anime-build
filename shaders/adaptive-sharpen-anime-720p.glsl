//!HOOK LUMA
//!BIND HOOKED
//!DESC Adaptive Sharpen Anime (720p)

//--------------------------------------- Anime 720p Settings -------------------------------------
// OPTIMIZED FOR: 720p -> 1440p Upscale
// GOAL: Moderate sharpening to combat the "softness" of 720p content.

#define curve_height    0.70                 // MODERATE (Stronger than 1080p, weaker than SD)
#define overshoot_ctrl  true                 // Anti-Ringing ON

#define curveslope      0.5
#define L_compr_low     0.167                
#define L_compr_high    0.334                
#define D_compr_low     0.250                
#define D_compr_high    0.500                
#define scale_lim       0.1
#define scale_cs        0.056
#define pm_p            1.0

//-------------------------------------------------------------------------------------------------
#define max4(a,b,c,d)  ( max(max(a, b), max(c, d)) )
#define soft_if(a,b,c) ( sat((a + b + c + 0.056/2.5)/(maxedge + 0.03/2.5) - 0.85) )
#define soft_lim(v,s)  ( sat(abs(v/s)*(27.0 + pow(v/s, 2.0))/(27.0 + 9.0*pow(v/s, 2.0)))*s )
#define wpmean(a,b,w)  ( pow(w*pow(abs(a), pm_p) + abs(1.0-w)*pow(abs(b), pm_p), (1.0/pm_p)) )
#define get(x,y)       ( HOOKED_texOff(vec2(x, y)).rgb )
#define sat(x)         ( clamp(x, 0.0, 1.0) )
#define dxdy(val)      ( length(fwidth(val)) ) 

#ifdef LUMA_tex
#define CtL(RGB)       RGB.x
#else
#define CtL(RGB)       ( sqrt(dot(sat(RGB)*sat(RGB), vec3(0.2126, 0.7152, 0.0722))) )
#endif

#define b_diff(pix)    ( (blur-luma[pix])*(blur-luma[pix]) )

vec4 hook() {
    vec3 c[25] = vec3[](get( 0, 0), get(-1,-1), get( 0,-1), get( 1,-1), get(-1, 0),
                        get( 1, 0), get(-1, 1), get( 0, 1), get( 1, 1), get( 0,-2),
                        get(-2, 0), get( 2, 0), get( 0, 2), get( 0, 3), get( 1, 2),
                        get(-1, 2), get( 3, 0), get( 2, 1), get( 2,-1), get(-3, 0),
                        get(-2, 1), get(-2,-1), get( 0,-3), get( 1,-2), get(-1,-2));
    
    float e[13] = float[](dxdy(c[0]),  dxdy(c[1]),  dxdy(c[2]),  dxdy(c[3]),  dxdy(c[4]),
                          dxdy(c[5]),  dxdy(c[6]),  dxdy(c[7]),  dxdy(c[8]),  dxdy(c[9]),
                          dxdy(c[10]), dxdy(c[11]), dxdy(c[12]));
    
    float luma[25] = float[](CtL(c[0]), CtL(c[1]), CtL(c[2]), CtL(c[3]), CtL(c[4]), CtL(c[5]), CtL(c[6]),
                             CtL(c[7]),  CtL(c[8]),  CtL(c[9]),  CtL(c[10]), CtL(c[11]), CtL(c[12]),
                             CtL(c[13]), CtL(c[14]), CtL(c[15]), CtL(c[16]), CtL(c[17]), CtL(c[18]),
                             CtL(c[19]), CtL(c[20]), CtL(c[21]), CtL(c[22]), CtL(c[23]), CtL(c[24]));
    float c0_Y = luma[0];

    float  blur   = (2.0 * (luma[2]+luma[4]+luma[5]+luma[7]) + (luma[1]+luma[3]+luma[6]+luma[8]) + 4.0 * luma[0]) / 16.0;
    float c_comp = sat(0.266666681f + 0.9*exp2(blur * blur * -7.4));
    float edge = ( 1.38*b_diff(0) + 1.15*(b_diff(2) + b_diff(4) + b_diff(5) + b_diff(7))
                 + 0.92*(b_diff(1) + b_diff(3) + b_diff(6) + b_diff(8))
                 + 0.23*(b_diff(9) + b_diff(10) + b_diff(11) + b_diff(12)) ) * c_comp;

    vec2 cs = vec2(L_compr_low,  D_compr_low);

    if (overshoot_ctrl) {
        float maxedge = max4( max4(e[1],e[2],e[3],e[4]), max4(e[5],e[6],e[7],e[8]),
                              max4(e[9],e[10],e[11],e[12]), e[0] );
        float sbe = soft_if(e[2],e[9], dxdy(c[22]))*soft_if(e[7],e[12],dxdy(c[13]))
                  + soft_if(e[4],e[10],dxdy(c[19]))*soft_if(e[5],e[11],dxdy(c[16])) 
                  + soft_if(e[1],dxdy(c[24]),dxdy(c[21]))*soft_if(e[8],dxdy(c[14]),dxdy(c[17])) 
                  + soft_if(e[3],dxdy(c[23]),dxdy(c[18]))*soft_if(e[6],dxdy(c[20]),dxdy(c[15]));
        cs = mix(cs, vec2(L_compr_high, D_compr_high), sat(2.4002*sbe - 2.282));
    }

    const vec3 w1 = vec3(0.5,           1.0, 1.41421356237);
    const vec3 w2 = vec3(0.86602540378, 1.0, 0.54772255751);
    vec3 dW = pow(mix( w1, w2, sat(2.4*edge - 0.82)), vec3(2.0));
    float modif_e0 = 3.0 * e[0] + 0.02/2.5;
    float weights[12]  = float[](( min(modif_e0/e[1],  dW.y) ), ( dW.x ), ( min(modif_e0/e[3],  dW.y) ),
                                 ( dW.x ), ( dW.x ), ( min(modif_e0/e[6],  dW.y) ),
                                 ( dW.x ), ( min(modif_e0/e[8],  dW.y) ), ( min(modif_e0/e[9],  dW.z) ),
                                 ( min(modif_e0/e[10], dW.z) ), ( min(modif_e0/e[11], dW.z) ), ( min(modif_e0/e[12], dW.z) ));

    weights[0] = (max(max((weights[8]  + weights[9])/4.0,  weights[0]), 0.25) + weights[0])/2.0;
    weights[2] = (max(max((weights[8]  + weights[10])/4.0, weights[2]), 0.25) + weights[2])/2.0;
    weights[5] = (max(max((weights[9]  + weights[11])/4.0, weights[5]), 0.25) + weights[5])/2.0;
    weights[7] = (max(max((weights[10] + weights[11])/4.0, weights[7]), 0.25) + weights[7])/2.0;

    float lowthrsum = 0.0; float weightsum = 0.0; float neg_laplace = 0.0;
    for (int pix = 0; pix < 12; ++pix) {
        float lowthr = sat((20.*4.5*c_comp*e[pix + 1] - 0.221));
        neg_laplace += luma[pix+1] * luma[pix+1] * weights[pix] * lowthr;
        weightsum   += weights[pix] * lowthr;
        lowthrsum   += lowthr / 12.0;
    }

    neg_laplace = sqrt(neg_laplace / weightsum);
    float sharpen_val = curve_height/(curve_height*curveslope*edge + 0.625);
    float sharpdiff = (c0_Y - neg_laplace)*(lowthrsum*sharpen_val + 0.01);
    
    float temp;
    for (int i1 = 0; i1 < 24; i1 += 2) { temp = luma[i1]; luma[i1] = min(luma[i1], luma[i1+1]); luma[i1+1] = max(temp, luma[i1+1]); }
    for (int i2 = 24; i2 > 0; i2 -= 2) { temp = luma[0]; luma[0] = min(luma[0], luma[i2]); luma[i2] = max(temp, luma[i2]); temp = luma[24]; luma[24] = max(luma[24], luma[i2-1]); luma[i2-1] = min(temp, luma[i2-1]); }

    float min_dist  = min(abs(luma[24] - c0_Y), abs(c0_Y - luma[0]));
    min_dist = min(min_dist, scale_lim*(1.0 - scale_cs) + min_dist*scale_cs);
    sharpdiff = wpmean(max(sharpdiff, 0.0), soft_lim( max(sharpdiff, 0.0), min_dist ), cs.x )
              - wpmean(min(sharpdiff, 0.0), soft_lim( min(sharpdiff, 0.0), min_dist ), cs.y );
    float sharpdiff_lim = sat(c0_Y + sharpdiff) - c0_Y;
    return vec4(sharpdiff_lim + c[0], HOOKED_texOff(0).a);
}