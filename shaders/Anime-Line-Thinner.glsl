//!HOOK MAIN
//!BIND HOOKED
//!DESC Morphological Line Thinner

// These values are injected/updated by your Lua controller script
// before applying the shader.
#define BLEND_FACTOR 0.20
#define THRESHOLD_VAL 0.08

vec4 hook() {
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
    if (max_luma > luma_center + THRESHOLD_VAL) {
        result = mix(center, brightest, BLEND_FACTOR);
    }
    return result;
}
