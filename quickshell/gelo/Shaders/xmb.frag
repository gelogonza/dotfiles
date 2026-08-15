#version 440

// XMB wave field.
//
// A FILAMENT field. Two earlier attempts missed the reference in different ways:
//
//   1. Domain-warped fBm — the standard "pretty background" recipe. Reads as
//      smoke or clouds. Nothing like XMB.
//   2. A few wide gaussian bands. Reads as fog: bright in the middle of a smear.
//
// The reference is MANY THIN STRANDS of light — a tight bright core with a much
// wider, much fainter halo — crossing each other over a broad diffuse haze. The
// core-plus-halo split is the whole trick; a single gaussian cannot produce a
// thread that glows, only a band that is brighter in the middle.
//
// Each strand is an explicit sine curve in y as a function of x, summed from two
// sines at a non-integer frequency ratio so it reads as cloth rather than as a
// test pattern, and each drifts at its own rate so they cross and separate.
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

// One filament of light.
//
// The core is what makes this read as XMB. Earlier versions used a single wide
// gaussian, which produces a soft band — fog, not light. A real XMB strand is a
// THIN bright core with a much wider, much fainter halo around it, so the eye
// sees a filament that glows rather than a smear that is bright in the middle.
//
//   yc     centre height, 0..1
//   amp    vertical swing
//   freq   horizontal wavelength
//   speed  drift rate
//   core   half-width of the bright thread (very small)
//   halo   half-width of the surrounding bloom (roughly 15-25x the core)
float filament(vec2 p, float yc, float amp, float freq, float speed,
               float core, float halo, float t) {
    // Two sines at a non-integer ratio. A single sine reads as a test pattern;
    // this reads as cloth.
    float y = yc
            + amp * sin(p.x * freq + t * speed)
            + amp * 0.42 * sin(p.x * freq * 1.73 - t * speed * 0.63);

    float d = p.y - y;
    float d2 = d * d;

    float bright = exp(-d2 / (core * core));
    float bloom = exp(-d2 / (halo * halo));

    return bright + bloom * 0.22;
}

// Broad, very soft mass of light. A handful of these sit behind the filaments
// so the frame is not black between strands — the diffuse field the threads
// are suspended in.
float haze(vec2 p, vec2 c, vec2 radius, float t, float drift) {
    vec2 o = c + vec2(0.09 * sin(t * drift), 0.045 * cos(t * drift * 0.77));
    vec2 d = (p - o) / radius;
    return exp(-dot(d, d));
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

    // --- diffuse haze -----------------------------------------------------
    float hz = 0.0;
    hz += 0.85 * haze(p, vec2(0.42, 0.44), vec2(0.62, 0.20), t, 0.13);
    hz += 0.55 * haze(p, vec2(0.70, 0.55), vec2(0.48, 0.16), t, -0.09);
    hz += 0.40 * haze(p, vec2(0.20, 0.62), vec2(0.40, 0.13), t, 0.11);

    // --- filaments --------------------------------------------------------
    // Many thin strands, not a few thick bands. They are clustered around the
    // middle of the frame and thin out toward the edges, and each drifts at its
    // own rate so they cross and separate instead of moving as a block.
    float f = 0.0;
    f += 1.00 * filament(p, 0.500, 0.060, 4.7,  0.50, 0.0016, 0.030, t);
    f += 0.80 * filament(p, 0.470, 0.075, 3.3, -0.38, 0.0013, 0.026, t);
    f += 0.85 * filament(p, 0.535, 0.068, 6.1,  0.31, 0.0015, 0.028, t);
    f += 0.65 * filament(p, 0.445, 0.090, 2.6, -0.25, 0.0011, 0.034, t);
    f += 0.70 * filament(p, 0.575, 0.082, 5.2,  0.22, 0.0012, 0.024, t);
    f += 0.55 * filament(p, 0.405, 0.105, 3.9,  0.17, 0.0010, 0.038, t);
    f += 0.50 * filament(p, 0.625, 0.098, 4.1, -0.19, 0.0010, 0.030, t);
    f += 0.40 * filament(p, 0.355, 0.120, 5.7,  0.28, 0.0009, 0.042, t);
    f += 0.38 * filament(p, 0.680, 0.115, 3.1,  0.14, 0.0009, 0.034, t);
    f += 0.28 * filament(p, 0.300, 0.135, 4.5, -0.12, 0.0008, 0.046, t);
    f += 0.26 * filament(p, 0.745, 0.128, 5.9,  0.24, 0.0008, 0.038, t);
    f += 0.20 * filament(p, 0.240, 0.150, 3.6,  0.09, 0.0007, 0.050, t);
    f += 0.18 * filament(p, 0.810, 0.142, 4.9, -0.16, 0.0007, 0.042, t);

    // --- tone -------------------------------------------------------------
    // A faint cold vertical gradient underneath, so the frame is not flat where
    // nothing reaches.
    vec3 col = mix(colorBase.rgb, colorMid.rgb, smoothstep(1.0, 0.0, uv.y) * 0.45);

    // The haze lifts the field toward bg-2 / border. Broad and very low
    // contrast — it should never be readable as a shape on its own.
    col = mix(col, colorHigh.rgb, clamp(hz * 0.55, 0.0, 1.0));
    col = mix(col, colorEdge.rgb, clamp((hz - 0.75) * 0.45, 0.0, 1.0));

    // Filaments are light, so they ADD rather than mix — that is what lets a
    // thin core read as brighter than the surface it crosses instead of just
    // being a different colour.
    col += colorEdge.rgb * clamp(f, 0.0, 2.2) * 0.55;
    col += vec3(0.62, 0.72, 0.86) * smoothstep(0.85, 1.9, f) * 0.10;

    // The ripple wavefront carries accent light. This is the only place the
    // accent appears outside its three sanctioned locations, and it is
    // transient — under a second, then gone.
    //
    // Kept low deliberately. At 0.35 the wavefront rendered as a hard cyan ring
    // drawn over the field rather than as light moving through it, which made a
    // transient effect the loudest thing on screen.
    col += colorAccent.rgb * rippleGlow * 0.16;

    // Vignette keeps attention centred.
    float vig = smoothstep(1.35, 0.30, length((uv - 0.5) * vec2(aspect, 1.0)));
    col *= mix(0.80, 1.0, vig);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
