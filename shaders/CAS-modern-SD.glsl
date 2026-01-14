//!HOOK LUMA
//!BIND HOOKED
//!DESC AMD CAS Modern SD (480p)

//--------------------------------------- Settings ------------------------------------------------

#define CAS_STRENGTH    0.4                  // Moderate Strength for SD.
                                             // Enough to define edges, but low enough to avoid
                                             // sharpening compression artifacts and blocks.

//-------------------------------------------------------------------------------------------------

// The CAS algorithm requires fetching the immediate neighbors.
// [ a b c ]
// [ d e f ]
// [ g h i ]

#define Get(x,y) (HOOKED_texOff(vec2(x,y)).x)

vec4 hook() {
    // Fetch 3x3 neighborhood around the pixel 'e'
    float a = Get(-1, -1);
    float b = Get( 0, -1);
    float c = Get( 1, -1);
    float d = Get(-1,  0);
    float e = Get( 0,  0);
    float f = Get( 1,  0);
    float g = Get(-1,  1);
    float h = Get( 0,  1);
    float i = Get( 1,  1);

    // Soft min and max.
    //  a b c             b
    //  d e f * 0.5  +  d e f * 0.5
    //  g h i             h
    // These are 2.0x bigger (factored out the extra multiply).

    float mnR = min(min(min(d, e), min(f, b)), h);
    float mnG = min(mnR, min(min(a, c), min(g, i)));
    mnR += mnG; // Soft min

    float mxR = max(max(max(d, e), max(f, b)), h);
    float mxG = max(mxR, max(max(a, c), max(g, i)));
    mxR += mxG; // Soft max

    // Smooth minimum distance to signal limit (0 or 1).
    float ampR = clamp(min(mnR, 2.0 - mxR) / mxR, 0.0, 1.0);

    // Shaping amount of sharpening.
    float peak = -1.0 / mix(8.0, 5.0, CAS_STRENGTH);
    
    float wR = ampR * peak;
    float rcpWeightR = 1.0 / (1.0 + 4.0 * wR);

    //                  0 w 0
    //  Filter shape:   w 1 w
    //                  0 w 0

    float outColor = (b * wR + d * wR + f * wR + h * wR + e) * rcpWeightR;

    return vec4(outColor, 0.0, 0.0, 1.0);
}