#version 440

// XMB wave field.
//
// This is a RIBBON field, not a noise field. The first version of this shader
// used domain-warped fBm, which is the standard "pretty background" recipe and
// reads as smoke or clouds — nothing like the reference. The PS3 XMB background
// is a small number of smooth, wide, horizontal bands of light that undulate
// like silk and cross the screen, concentrated around the middle of the frame.
//
// So: each ribbon is an explicit sine curve in y as a function of x, with a
// gaussian falloff perpendicular to it. Two summed sines per ribbon (at
// non-integer frequency ratios) keep them from looking like a plain wave, and
// each ribbon drifts at its own speed so they cross and separate over time.
//
// The field carries NO accent colour. It is built from bg-1 / bg-2 / border
// only, so it reads as cold light rather than as a fourth accent location. The
// single exception is the transient ripple wavefront below.
//
// `time` arrives pre-scaled; the caller sets the rate through its
// NumberAnimation, so the login screen and the desktop can run this at
// different speeds.
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
    float rippleSpeed;
    float rippleWidth;
    float rippleAmplitude;

    // Four discrete slots rather than `vec4 ripples[4]`. Qt 6's ShaderEffect
    // binds uniform-block members to QML properties BY NAME, and an array
    // member has no name a QML property can match — so an array here would
    // silently never receive data. Count must match
    // material.ripple.maxConcurrent in design/tokens.json.
    vec4 rippleA;
    vec4 rippleB;
    vec4 rippleC;
    vec4 rippleD;
};

// One ribbon of light.
//   yc     centre height, 0..1
//   amp    how far it swings vertically
//   freq   horizontal wavelength
//   speed  drift rate
//   thick  gaussian half-width — this is what makes it a soft band, not a line
float ribbon(vec2 p, float yc, float amp, float freq, float speed, float thick, float t) {
    // Two sines at a non-integer ratio. A single sine reads as a test pattern;
    // this reads as cloth.
    float y = yc
            + amp * sin(p.x * freq + t * speed)
            + amp * 0.42 * sin(p.x * freq * 1.73 - t * speed * 0.63);

    float d = p.y - y;
    return exp(-(d * d) / (thick * thick));
}

// xy = origin (normalised screen), z = birth time on the same clock as `time`.
void accumulateRipple(vec4 r, vec2 uv, float aspect, float t,
                      inout vec2 warp, inout float glow) {
    float age = t - r.z;
    if (age < 0.0 || age > 2.5)
        return;

    vec2 d = (uv - r.xy) * vec2(aspect, 1.0);
    float dist = length(d);
    float radius = age * rippleSpeed;

    // Annulus: strongest at the wavefront, nothing inside or outside it.
    float band = exp(-pow((dist - radius) / rippleWidth, 2.0));
    float decay = exp(-age * 1.6);

    warp += normalize(d + 1e-6) * band * decay * rippleAmplitude * 0.05;
    glow += band * decay;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);
    float t = time;

    // --- ripple displacement ---------------------------------------------
    // Accumulated BEFORE the ribbons are evaluated, so a ripple bends the bands
    // it crosses instead of being drawn on top of them.
    vec2 warp = vec2(0.0);
    float rippleGlow = 0.0;

    accumulateRipple(rippleA, uv, aspect, t, warp, rippleGlow);
    accumulateRipple(rippleB, uv, aspect, t, warp, rippleGlow);
    accumulateRipple(rippleC, uv, aspect, t, warp, rippleGlow);
    accumulateRipple(rippleD, uv, aspect, t, warp, rippleGlow);

    vec2 p = uv + warp;

    // --- ribbons ----------------------------------------------------------
    // Clustered around the middle of the frame, widest and brightest there,
    // thinning toward the top and bottom edges.
    float i = 0.0;
    i += 1.00 * ribbon(p, 0.50, 0.070, 5.1, 0.55, 0.055, t);
    i += 0.75 * ribbon(p, 0.44, 0.095, 3.7, -0.41, 0.075, t);
    i += 0.60 * ribbon(p, 0.57, 0.085, 6.4, 0.33, 0.048, t);
    i += 0.45 * ribbon(p, 0.36, 0.110, 2.9, -0.27, 0.095, t);
    i += 0.35 * ribbon(p, 0.66, 0.120, 4.3, 0.21, 0.085, t);
    i += 0.25 * ribbon(p, 0.24, 0.140, 3.3, 0.17, 0.110, t);

    i = clamp(i, 0.0, 1.6);

    // --- tone -------------------------------------------------------------
    // A faint cold vertical gradient underneath, so the frame is not flat where
    // no ribbon reaches.
    vec3 col = mix(colorBase.rgb, colorMid.rgb, smoothstep(1.0, 0.0, uv.y) * 0.5);

    col = mix(col, colorHigh.rgb, clamp(i * 0.85, 0.0, 1.0));
    col = mix(col, colorEdge.rgb, clamp((i - 0.55) * 1.1, 0.0, 1.0));

    // The very cores of the brightest ribbons lift slightly past --border
    // toward steel, which is what gives the bands an edge rather than a plateau.
    col += (colorEdge.rgb * 0.55) * smoothstep(1.05, 1.55, i);

    // The ripple wavefront carries accent light. This is the only place the
    // accent appears outside its three sanctioned locations, and it is
    // transient — under a second, then gone.
    col += colorAccent.rgb * rippleGlow * 0.35;

    // Vignette keeps attention centred.
    float vig = smoothstep(1.35, 0.30, length((uv - 0.5) * vec2(aspect, 1.0)));
    col *= mix(0.80, 1.0, vig);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
