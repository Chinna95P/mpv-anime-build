//!HOOK LUMA
//!BIND HOOKED
//!DESC AMD CAS Modern (1080p)

//--------------------------------------- Settings ------------------------------------------------

#define CAS_STRENGTH    0.6                  // Balanced "Reference" Strength.
                                             // Enhances texture/pores/grain without causing
                                             // harsh ringing or aliasing on already sharp content.

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