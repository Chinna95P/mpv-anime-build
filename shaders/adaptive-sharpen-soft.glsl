//!HOOK LUMA
//!BIND HOOKED
//!DESC Adaptive Sharpen (480p Safe)

#define STRENGTH 0.35      // Very low strength (HD is ~0.6–0.8)
#define EDGE_THRESHOLD 0.035
#define DETAIL_THRESHOLD 0.012
#define CLAMP_LOW -0.02
#define CLAMP_HIGH 0.02

vec4 hook() {
    vec2 px = vec2(1.0) / vec2(textureSize(HOOKED, 0));

    float c  = texture(HOOKED, HOOKED_pos).x;
    float l  = texture(HOOKED, HOOKED_pos + vec2(-px.x, 0)).x;
    float r  = texture(HOOKED, HOOKED_pos + vec2(px.x, 0)).x;
    float u  = texture(HOOKED, HOOKED_pos + vec2(0, -px.y)).x;
    float d  = texture(HOOKED, HOOKED_pos + vec2(0, px.y)).x;

    float edge = abs(l - r) + abs(u - d);

    // Avoid sharpening noise & blocks
    if (edge < EDGE_THRESHOLD || edge > 0.25)
        return vec4(c);

    float blur = (l + r + u + d) * 0.25;
    float diff = c - blur;

    // Ignore micro-noise
    if (abs(diff) < DETAIL_THRESHOLD)
        return vec4(c);

    float sharpen = clamp(diff * STRENGTH, CLAMP_LOW, CLAMP_HIGH);
    return vec4(c + sharpen);
}
