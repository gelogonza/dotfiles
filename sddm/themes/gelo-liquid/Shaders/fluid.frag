#version 440

// Fluid field background for the login screen.
//
// Domain-warped fBm: the noise field is sampled through a displacement that is
// itself made of noise, twice over. That recursion is what makes it read as a
// slow liquid rather than as drifting clouds — straight fBm always looks like
// weather.
//
// Palette is passed in from the design tokens rather than hardcoded, so the
// login screen cannot drift away from the rest of the system.
//
// Compile with:  design/build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec4 colorBase;
    vec4 colorMid;
    vec4 colorHigh;
    vec4 colorEdge;
    vec4 colorAccent;
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);

    // `time` arrives pre-scaled: the caller sets the rate through its
    // NumberAnimation, so the login screen and the desktop wallpaper can move at
    // different speeds without recompiling this shader.
    //
    // Be careful going slow here. The first version ran at 0.06 units/sec and
    // measured as literally zero changed pixels over 30 seconds — on a palette
    // this dark (bg-0..border spans only 13..42 in 8-bit) the motion quantised
    // away entirely and the shader rendered a still image. ~0.28/sec is about
    // the floor for perceptible drift.
    float t = time;

    vec2 q = vec2(fbm(p * 1.6 + vec2(0.0, t)),
                  fbm(p * 1.6 + vec2(3.7, -t)));

    vec2 r = vec2(fbm(p * 1.8 + 2.2 * q + vec2(1.7, 9.2) + 0.9 * t),
                  fbm(p * 1.8 + 2.2 * q + vec2(8.3, 2.8) - 0.7 * t));

    float f = clamp(fbm(p * 1.4 + 2.6 * r) * 1.25 - 0.1, 0.0, 1.0);

    // Four stops rather than three. --border is the brightest tone the palette
    // allows, and reaching for it widens the usable range by ~60%, which is the
    // difference between motion you can perceive and motion that rounds away.
    vec3 col = mix(colorBase.rgb, colorMid.rgb, smoothstep(0.10, 0.50, f));
    col = mix(col, colorHigh.rgb, smoothstep(0.45, 0.78, f));
    col = mix(col, colorEdge.rgb, smoothstep(0.72, 0.96, f));

    // One faint warm bloom, kept well below the level where it would register
    // as a second accent. It drifts, so the warm region is never pinned to one
    // spot, and stays off-centre so it never sits behind the password field.
    vec2 bloomCentre = vec2(aspect * (0.68 + 0.06 * sin(t * 0.35)),
                            0.34 + 0.05 * cos(t * 0.27));
    float bloom = smoothstep(0.80, 0.0, length(p - bloomCentre));
    col += colorAccent.rgb * bloom * 0.10 * (0.55 + 0.45 * r.x);

    // Vignette pulls the eye to the centre where the controls live.
    float vig = smoothstep(1.25, 0.25, length((uv - 0.5) * vec2(aspect, 1.0)));
    col *= mix(0.72, 1.0, vig);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
