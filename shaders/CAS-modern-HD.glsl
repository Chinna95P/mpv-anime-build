//!HOOK LUMA
//!BIND HOOKED
//!DESC AMD CAS Modern HD (720p)

//--------------------------------------- Settings ------------------------------------------------

#define CAS_STRENGTH    0.9                  // High Strength for 720p.
                                             // "Super-Resolution" mode.
                                             // Aggressively restores texture pop to make 720p look like FHD.

//-------------------------------------------------------------------------------------------------

#define Get(x,y) (HOOKED_texOff(vec2(x,y)).x)

vec4 hook() {
    float a = Get(-1, -1);
    float b = Get( 0, -1);
    float c = Get( 1, -1);
    float d = Get(-1,  0);
    float e = Get( 0,  0);
    float f = Get( 1,  0);
    float g = Get(-1,  1);
    float h = Get( 0,  1);
    float i = Get( 1,  1);

    float mnR = min(min(min(d, e), min(f, b)), h);
    float mnG = min(mnR, min(min(a, c), min(g, i)));
    mnR += mnG;

    float mxR = max(max(max(d, e), max(f, b)), h);
    float mxG = max(mxR, max(max(a, c), max(g, i)));
    mxR += mxG;

    float ampR = clamp(min(mnR, 2.0 - mxR) / mxR, 0.0, 1.0);

    // Shaping amount of sharpening.
    float peak = -1.0 / mix(8.0, 5.0, CAS_STRENGTH);
    
    float wR = ampR * peak;
    float rcpWeightR = 1.0 / (1.0 + 4.0 * wR);

    float outColor = (b * wR + d * wR + f * wR + h * wR + e) * rcpWeightR;

    return vec4(outColor, 0.0, 0.0, 1.0);
}