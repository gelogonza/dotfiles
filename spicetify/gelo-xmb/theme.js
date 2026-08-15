// GENERATED FILE — DO NOT EDIT. Source: design/tokens.json (run design/build-tokens.py)
//
// The XMB wave field, behind Spotify, rippling on the beat.
// Settings live in the profile menu ("XMB field"), or Ctrl+Alt+X.
// Not Ctrl+Shift+X: that is Spotify's Connect panel, and binding it
// opened both at once.
// Delete this file and re-apply to drop back to the static theme.

(function () {
  "use strict";

  var FIELD = {
    colorBase: [0.0431, 0.0902, 0.1373, 1.0],
    colorMid: [0.0784, 0.1608, 0.2471, 1.0],
    colorHigh: [0.1333, 0.2118, 0.2941, 1.0],
    colorEdge: [0.1804, 0.2549, 0.3294, 1.0],
    colorLine: [0.2706, 0.4000, 0.5098, 1.0],
    colorAccent: [0.3765, 0.6275, 0.6980, 1.0]
  };
  var SURF = {
    main: [0.0784, 0.1608, 0.2471, 1.0],
    deep: [0.0510, 0.1059, 0.1608, 1.0],
    raised: [0.1333, 0.2118, 0.2941, 1.0]
  };
  var RIPPLE = { speed: 0.55, width: 0.05, amplitude: 0.55, slots: 4 };

  // The palette's own hue, measured off ANSI bright blue. "Cool lock" pulls any
  // album hue back toward this, which is what keeps an album-tinted field
  // inside the system instead of turning it into whatever the cover art is.
  var PALETTE_HUE = 207.5;

  var BASE_RATE = 0.16;
  var FPS_CAP = 60;              // the surge waits up to a frame to render
  var KEY = "gelo-xmb-field";

  // Every default is the value the token source produces. Reset returns here.
  var DEFAULTS = {
    fieldGain: 1, sat: 1, tint: 0.65,
    scrim: 0.68, panel: 0.88, ui: 1,
    reactivity: 1, rate: 1, spin: 14, lead: 0.12,
    enabled: true, coolLock: true, turntable: true, waveform: true,
    // Colour SOURCE, not a colour. "tokens" is design/tokens.json and is the
    // default, so the system's palette is what you get until you ask for
    // something else. "custom" uses customColor; "album" follows the cover.
    colorMode: "tokens",
    customColor: "#8cc6f7",
    // What the chrome does with the chosen colour. "tinted" recolours the
    // surfaces and accents through the same pipeline as the field; "neutral"
    // drops them to plain black at the UI alpha, so the album shows through
    // without colouring the furniture.
    surface: "tinted"
  };
  var CFG = load();
  var ALBUM = null;            // {h, s, hex} from the current cover, or null

  function load() {
    var out = {};
    for (var k in DEFAULTS) out[k] = DEFAULTS[k];
    try {
      var raw = window.Spicetify && Spicetify.LocalStorage
        ? Spicetify.LocalStorage.get(KEY) : localStorage.getItem(KEY);
      if (raw) {
        var got = JSON.parse(raw);
        for (var j in DEFAULTS) if (typeof got[j] === typeof DEFAULTS[j]) out[j] = got[j];
      }
    } catch (e) { /* corrupt or absent: defaults are correct */ }
    return out;
  }

  function save() {
    try {
      var raw = JSON.stringify(CFG);
      if (window.Spicetify && Spicetify.LocalStorage) Spicetify.LocalStorage.set(KEY, raw);
      else localStorage.setItem(KEY, raw);
    } catch (e) { /* non-fatal: settings simply do not persist */ }
  }

  var gl = null, U = null, canvas = null, frame = 0;

  // ------------------------------------------------------------------
  // Colour.
  //
  // Everything here rotates HUE and scales SATURATION, then restores the
  // original WCAG relative luminance. That is load-bearing rather than tidy:
  // the field's contrast against text was measured once (design.md 8d), and
  // those numbers stay valid only if recolouring cannot change how bright the
  // field is. Tint the hue, hold the luminance, and no album and no slider
  // position can push secondary text under AA.
  // ------------------------------------------------------------------
  function rgb2hsl(r, g, b) {
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
    var h = 0, s = 0, l = (mx + mn) / 2;
    if (d) {
      s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
      if (mx === r) h = ((g - b) / d + (g < b ? 6 : 0));
      else if (mx === g) h = (b - r) / d + 2;
      else h = (r - g) / d + 4;
      h *= 60;
    }
    return [h, s, l];
  }

  function hue2rgb(p, q, t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  function hsl2rgb(h, s, l) {
    h = ((h % 360) + 360) % 360 / 360;
    if (!s) return [l, l, l];
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    var p = 2 * l - q;
    return [hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3)];
  }

  function shortest(a, b) {          // signed smallest angle from a to b
    return ((((b - a) % 360) + 540) % 360) - 180;
  }

  function lin(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }
  function relY(c) {                 // WCAG relative luminance
    return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
  }

  // Solve for the HSL lightness that reproduces a target relative luminance at
  // a given hue and saturation.
  //
  // Holding HSL *lightness* constant is not enough, and the gap is not small:
  // at constant L, rotating this field's brightest colour through the hue
  // circle swings its relative luminance by 1.70x (0.12 at 240deg to 0.39 at
  // 60deg) — and still 1.46x inside the cool-lock band. HSL lightness is not
  // perceptual brightness; green at L=0.76 is far brighter than blue at
  // L=0.76. Left alone, a yellow album would have quietly undone the contrast
  // work in design.md 8d.
  //
  // Relative luminance is monotonic in L at fixed H/S, so a short bisection is
  // exact enough and costs nothing — this runs on slider moves, not per frame.
  function solveL(h, s, targetY) {
    var lo = 0, hi = 1, mid, c;
    for (var i = 0; i < 24; i++) {
      mid = (lo + hi) / 2;
      c = hsl2rgb(h, s, mid);
      if (relY(c) < targetY) lo = mid; else hi = mid;
    }
    return (lo + hi) / 2;
  }

  function hexToHS(hex) {
    var m = String(hex || "").replace("#", "");
    if (m.length !== 6 || /[^0-9a-f]/i.test(m)) return null;
    var c = rgb2hsl(parseInt(m.slice(0, 2), 16) / 255,
                    parseInt(m.slice(2, 4), 16) / 255,
                    parseInt(m.slice(4, 6), 16) / 255);
    return { h: c[0], s: c[1] };
  }

  function rgbToHex(c) {
    return "#" + [0, 1, 2].map(function (i) {
      var v = Math.round(Math.max(0, Math.min(1, c[i])) * 255).toString(16);
      return v.length < 2 ? "0" + v : v;
    }).join("");
  }

  // One field colour, recoloured by the current settings.
  function tint(rgba) {
    var hsl = rgb2hsl(rgba[0], rgba[1], rgba[2]);
    var h = hsl[0], s = hsl[1], l = hsl[2];

    var src = null;
    if (CFG.colorMode === "album" && ALBUM) src = ALBUM;
    else if (CFG.colorMode === "custom") src = hexToHS(CFG.customColor);

    if (src) {
      h = h + shortest(h, src.h) * CFG.tint;
      s = s + (src.s - s) * CFG.tint * 0.6;
    }
    if (CFG.coolLock) {
      // Compress toward the palette hue rather than clamping, so a red album
      // still reads as "warmer" without ever actually being warm.
      h = PALETTE_HUE + shortest(PALETTE_HUE, h) * 0.14;
      s = Math.min(s, 0.9);
    }
    s = Math.max(0, Math.min(1, s * CFG.sat));
    // Recolour the hue, then put the luminance back exactly where it was.
    var out = hsl2rgb(h, s, solveL(h, s, relY(rgba)));
    return [out[0], out[1], out[2], rgba[3]];
  }

  // "R, G, B" for a surface, recoloured to match the field.
  function surfRGB(key) {
    if (CFG.surface === "neutral") return "0, 0, 0";
    var c = tint(SURF[key]);
    return [0, 1, 2].map(function (i) {
      return Math.round(Math.max(0, Math.min(1, c[i])) * 255);
    }).join(", ");
  }

  function applyCss() {
    var r = document.documentElement.style;
    r.setProperty("--gelo-surf-main", surfRGB("main"));
    r.setProperty("--gelo-surf-deep", surfRGB("deep"));
    r.setProperty("--gelo-surf-raised", surfRGB("raised"));
    // Accents ride the same tint(), which preserves luminance — so however far
    // the album drags the hue, dark ink on a button keeps the contrast it was
    // measured at. Album-coloured buttons cannot become unreadable buttons.
    // The field keeps the album's colour; the CHROME does not. Once colour
    // stops coming from tokens.json, a tinted button competes with a tinted
    // surface behind it and both lose. White reads on any hue, so buttons,
    // inputs and the waveform go neutral and the colour stays where it is
    // doing work. In tokens mode nothing changes.
    var native = CFG.colorMode === "tokens";
    var acc = native ? tint(FIELD.colorLine) : [1, 1, 1, 1];
    var hot = native ? tint(FIELD.colorAccent) : [0.88, 0.92, 0.96, 1];
    r.setProperty("--gelo-accent", rgbToHex(acc));
    r.setProperty("--gelo-accent-hot", rgbToHex(hot));
    r.setProperty("--gelo-accent-rgb", [0, 1, 2].map(function (i) {
      return Math.round(Math.max(0, Math.min(1, acc[i])) * 255);
    }).join(", "));
    r.setProperty("--gelo-scrim", String(CFG.scrim));
    r.setProperty("--gelo-panel", String(CFG.panel));
    r.setProperty("--gelo-spin", CFG.spin + "s");
    r.setProperty("--gelo-ui", String(CFG.ui));
    document.documentElement.classList.toggle("gelo-turntable", !!CFG.turntable);
    document.documentElement.classList.toggle("gelo-waveform", !!CFG.waveform);
    if (canvas) canvas.style.display = CFG.enabled ? "block" : "none";
  }

  function rate() { return BASE_RATE * Math.max(CFG.rate, 0.05); }

  function applyGl() {
    if (!gl || !U) return;
    ["colorBase", "colorMid", "colorHigh", "colorEdge", "colorAccent"].forEach(function (k) {
      gl.uniform4fv(U[k], tint(FIELD[k]));
    });
    var line = tint(FIELD.colorLine).map(function (v, i) {
      return i < 3 ? Math.min(v * CFG.fieldGain, 1) : v;
    });
    gl.uniform4fv(U.colorLine, line);
    gl.uniform1f(U.rippleAmplitude, 0);
    // Inert while the ripple slots are parked (see boot), but kept correct so
    // re-enabling wavefronts does not silently reintroduce the bug below.
    //
    // `material.ripple.speed` is units per REAL second, but the shader derives
    // a wavefront's radius as `age * rippleSpeed` on the same clock it uses for
    // drift — and that clock is pre-scaled. Passing the token value straight
    // through made the wavefront expand `rate` times too slowly: at 0.16 a
    // ripple took about eleven seconds to cross the window, which measured as
    // zero frame-to-frame change and read as "ripples are broken" when they
    // were merely crawling. Divide it back out, and re-divide on every change.
    gl.uniform1f(U.rippleSpeed, RIPPLE.speed / rate());
  }

  function boot() {
    if (document.getElementById("gelo-xmb-field")) return;
    if (!document.body) return setTimeout(boot, 200);

    // Transparency lives here, not in user.css, so that deleting this file
    // removes the hole and the thing filling it in one step.
    var style = document.createElement("style");
    style.id = "gelo-xmb-field-style";
    style.textContent = [
      "html:root {",
      "  --gelo-scrim: 0.68; --gelo-panel: 0.88; --gelo-spin: 14s; --gelo-ui: 1;",
      "  --gelo-surf-main: 20, 41, 63; --gelo-surf-deep: 20, 41, 63;",
      "  --gelo-surf-raised: 20, 41, 63;",
      "  --gelo-accent: #8cc6f7; --gelo-accent-hot: #85dbef;",
      "  --gelo-accent-rgb: 140, 198, 247;",
      "  --gelo-wave-hot: none; --gelo-wave-dim: none;",
      "}",
      // The rest of the UI — sidebar, top bar, player bar, cards — rebuilt
      // from the `--spice-rgb-*` triplets spicetify already emits, so one
      // alpha opens every opaque surface onto the field at once. The main
      // view has its own scrim and the right panel its own alpha; this is
      // everything else.
      "html:root {",
      "  --spice-sidebar: rgba(var(--gelo-surf-deep), var(--gelo-ui));",
      "  --spice-player: rgba(var(--gelo-surf-deep), var(--gelo-ui));",
      "  --spice-card: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --spice-main-elevated: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --spice-highlight: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      // Buttons, selection and notifications follow the colour source too.
      "  --spice-button: var(--gelo-accent);",
      "  --spice-button-active: var(--gelo-accent-hot);",
      "  --spice-selected-row: var(--gelo-accent);",
      "  --spice-notification: var(--gelo-accent);",
      "  --spice-rgb-button: var(--gelo-accent-rgb);",
      // The triplets themselves, and `--spice-main`, which nothing above
      // touched. Anything painting `var(--spice-main)` or rebuilding a colour
      // from `rgba(var(--spice-rgb-*), a)` kept the token navy — which is why
      // the Related-music-videos box stayed blue while the panel around it
      // went red.
      "  --spice-main: rgba(var(--gelo-surf-main), var(--gelo-ui));",
      "  --spice-rgb-main: var(--gelo-surf-main);",
      "  --spice-rgb-sidebar: var(--gelo-surf-deep);",
      "  --spice-rgb-player: var(--gelo-surf-deep);",
      "  --spice-rgb-card: var(--gelo-surf-raised);",
      "  --spice-rgb-main-elevated: var(--gelo-surf-raised);",
      "  --spice-rgb-highlight: var(--gelo-surf-raised);",
      // The home shortcuts strip — the row with All / Music / Podcasts /
      // Audiobooks and the playlist tiles under it — paints an art-derived
      // gradient through `--background-image`, on a hashed styled-components
      // class. That is what stayed indigo while everything around it followed
      // the palette, and what shifted hue when a tile was hovered.
      //
      // Neutralise the variable rather than chase the class. `!important`
      // because Spotify sets this one INLINE per hovered item, and inline
      // beats a stylesheet without it. What remains underneath is a gradient
      // to `--spice-main`, which now follows the colour source like the rest.
      "  --background-image: none !important;",
      // Half the chrome does not read `--spice-*` at all. The left panel and
      // the home interior paint Encore's `--background-base`, and the top bar
      // `--background-elevated-base`, which is why the first UI-opacity pass
      // left them stubbornly solid while everything else opened up. Alpha
      // those too and the whole shell goes translucent together.
      //
      // This also permanently kills Spotify's album-art tint, which arrived
      // through this same variable.",
      "  --background-base: rgba(var(--gelo-surf-main), var(--gelo-ui));",
      "  --background-elevated-base: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --background-elevated-highlight: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --background-tinted-base: rgba(var(--gelo-surf-main), calc(var(--gelo-ui) * 0.10));",
      "}",
      // :root is not enough. A custom property resolves to the nearest
      // ancestor that declares it, and `.encore-dark-theme` re-declares these
      // (`--background-elevated-base: #1f1f1f`) much closer to the element —
      // which is why the now-playing panel's inner boxes stayed solid while
      // the panel around them went translucent. Override at the theme class
      // so the whole subtree inherits the alpha.
      //
      // Only the neutral surface values are touched. Encore also declares
      // these inside narrower selectors for alerts and inverted controls, and
      // those are more specific, so they still win — which is correct.
      ".encore-dark-theme, .encore-light-theme {",
      "  --background-base: rgba(var(--gelo-surf-main), var(--gelo-ui));",
      "  --background-elevated-base: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --background-elevated-highlight: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --section-background-base: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "}",
      // The panel's own boxes — cover art, About the artist, Credits, queue —
      // painted directly, so they follow UI opacity whatever Spotify decides
      // to resolve those variables to next release.
      ".main-nowPlayingView-section {",
      "  background-color: rgba(var(--gelo-surf-raised),",
      "    calc(var(--gelo-ui) * var(--gelo-panel) * 0.92)) !important;",
      "}",
      // This wrapper lays a near-opaque black gradient over the panel, which
      // reads as a dark slab once anything behind it is meant to show.
      ".main-nowPlayingView-mainWrapper {",
      "  background: rgba(var(--gelo-surf-main),",
      "    calc(var(--gelo-ui) * var(--gelo-panel) * 0.35)) !important;",
      "}",
      // Belt and braces on the semantic home classes, so this does not rely on
      // the hashed element keeping its shape.
      ".main-home-homeHeader,",
      ".main-home-filterChipsContainer,",
      ".main-home-filterChipsSection,",
      ".main-home-filterChipsSectionActive {",
      "  background-image: none !important;",
      "  background-color: transparent !important;",
      "}",
      ".main-nowPlayingView-coverArtContainer,",
      ".main-nowPlayingView-aboutArtist,",
      ".main-nowPlayingView-credits {",
      "  background-color: transparent !important;",
      "}",
      "body, .Root__top-container { background: transparent !important; }",
      // A scrim, not full transparency. Text sits on this surface, and the
      // field's bright end is filament cores — measured by isolating the
      // pixels that move between two frames, the top 5% put secondary text at
      // 4.17:1, under AA and a regression on the flat 5.78:1.
      ".Root__main-view, .Root__main-view .os-content {",
      "  background-color: rgba(var(--gelo-surf-main), calc(var(--gelo-ui) * var(--gelo-scrim))) !important;",
      "}",
      // A brighter secondary ink, scoped to the surface that now has a field
      // under it — the same move `hint` makes for inputs in the editor theme.
      ".Root__main-view { --spice-subtext: #a5b7cc; }",
      // Spotify tints the main view from the current album art, and making
      // that surface translucent is what exposed it: a maroon cover turned the
      // whole middle panel warm red, straight through the one rule the palette
      // does not bend. The tint arrives as `--background-base`, painted by the
      // action-bar gradient. Kill that layer and neutralise the tinted set.
      ".Root__main-view .main-actionBarBackground-background {",
      "  background-image: none !important;",
      "}",
      ".Root__main-view {",
      "  --background-tinted-base: rgba(var(--gelo-surf-main), 0.06);",
      "  --background-tinted-highlight: rgba(var(--gelo-surf-main), 0.10);",
      "  --background-tinted-press: rgba(var(--gelo-surf-main), 0.14);",
      "}",
      // The right panel. Its sections paint --section-background-base rather
      // than a background of their own, so the variable is the lever.
      ".Root__right-sidebar {",
      "  background-color: rgba(var(--gelo-surf-main), calc(var(--gelo-ui) * var(--gelo-panel))) !important;",
      "  --section-background-base: rgba(var(--gelo-surf-raised), calc(var(--gelo-ui) * var(--gelo-panel) * 0.92));",
      "}",
      ".Root__right-sidebar .main-nowPlayingView-section {",
      "  background-color: rgba(var(--gelo-surf-raised), calc(var(--gelo-ui) * var(--gelo-panel) * 0.92)) !important;",
      "}",
      "#gelo-xmb-field {",
      "  position: fixed; inset: 0; width: 100%; height: 100%;",
      "  z-index: -1; pointer-events: none; display: block;",
      "}",

      // ---- turntable ------------------------------------------------
      // `position: relative` is the one layout property this stylesheet sets,
      // and only because ::after needs a containing block. It does not move
      // anything.
      // The waveform IS the playback bar — the track's loudness envelope in
      // place of the flat progress strip, filling as it plays.
      //
      // Height comes from `--progress-bar-height`, which Spotify already
      // drives the bar from, so this asks for room through the app's own
      // variable rather than editing a box model. Same lesson as the Encore
      // colour sets and the turntable: set the variable, do not fight the
      // layout.
      //
      // Both layers are painted on the *background* element, which is static
      // and full width. `.x-progressBar-fillColor` cannot carry the played
      // half: it is a full-width element moved with `transform: translateX`,
      // so a background on it would slide across rather than be revealed. The
      // hot layer is instead pre-clipped to the playhead when generated —
      // CSS cannot clip a background, and scaling one would squash the
      // waveform rather than uncover it.
      // `--progress-bar-height` is declared on `.progress-bar` itself, so that
      // is what has to be overridden — setting it on an ancestor does nothing.
      "html.gelo-waveform.gelo-has-wave .progress-bar {",
      "  --progress-bar-height: 26px;",
      "  --progress-bar-radius: 3px;",
      "}",
      "html.gelo-waveform.gelo-has-wave .x-progressBar-progressBarBg {",
      "  background-color: transparent !important;",
      "  background-image: var(--gelo-wave-hot), var(--gelo-wave-dim) !important;",
      "  background-size: 100% 100%, 100% 100% !important;",
      "  background-repeat: no-repeat, no-repeat !important;",
      "  background-position: center, center !important;",
      "}",
      // The solid fill would sit on top of the waveform, so it steps aside.
      "html.gelo-waveform.gelo-has-wave .x-progressBar-fillColor {",
      "  background-color: transparent !important;",
      "  box-shadow: none !important;",
      "}",
      "@keyframes gelo-spin { to { transform: rotate(360deg); } }",
      // Styled on the IMAGE, never the container.
      //
      // The first attempt put `position/overflow/border-radius` and an ::after
      // on `.main-nowPlayingView-coverArt` and the artwork vanished entirely —
      // the slot measured as panel background with none of the cover in it.
      // Spotify sizes that container itself, so touching its box model is a
      // way to lose the contents. The image cannot affect layout, so this
      // cannot.
      //
      // Grooves are a stack of inset ring shadows rather than a pseudo-element,
      // because an <img> has none.
      "html.gelo-turntable .main-nowPlayingView-coverArt img,",
      "html.gelo-turntable .main-nowPlayingView-coverArt .main-image-image {",
      "  border-radius: 50%;",
      "  animation: gelo-spin var(--gelo-spin) linear infinite;",
      "  animation-play-state: paused;",
      "  box-shadow:",
      "    inset 0 0 0 2px rgba(0,0,0,0.30),",
      "    inset 0 0 0 14px rgba(255,255,255,0.045),",
      "    inset 0 0 0 15px rgba(0,0,0,0.22),",
      "    inset 0 0 0 30px rgba(255,255,255,0.04),",
      "    inset 0 0 0 31px rgba(0,0,0,0.20),",
      "    inset 0 0 0 48px rgba(255,255,255,0.035),",
      "    inset 0 0 0 49px rgba(0,0,0,0.18),",
      "    0 0 0 1px rgba(var(--spice-rgb-button), 0.18),",
      "    0 10px 36px rgba(var(--spice-rgb-shadow), 0.55);",
      "}",
      "html.gelo-turntable.gelo-playing .main-nowPlayingView-coverArt img,",
      "html.gelo-turntable.gelo-playing .main-nowPlayingView-coverArt .main-image-image {",
      "  animation-play-state: running;",
      "}",
    ].join("\n");
    document.head.appendChild(style);

    canvas = document.createElement("canvas");
    canvas.id = "gelo-xmb-field";
    document.body.insertBefore(canvas, document.body.firstChild);

    gl = canvas.getContext("webgl2", { antialias: false, alpha: true });
    if (!gl) { teardown(style); return; }

    function compile(type, src) {
      var s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        console.error("[gelo-xmb]", gl.getShaderInfoLog(s));
        return null;
      }
      return s;
    }

    var vs = compile(gl.VERTEX_SHADER, VERT);
    var fs = compile(gl.FRAGMENT_SHADER, FRAG);
    if (!vs || !fs) { teardown(style); return; }

    var prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      console.error("[gelo-xmb]", gl.getProgramInfoLog(prog));
      teardown(style); return;
    }
    gl.useProgram(prog);

    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(prog, "pos");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    U = {};
    ["time", "resolution", "colorBase", "colorMid", "colorHigh", "colorEdge",
     "colorLine", "colorAccent", "rippleSpeed", "rippleWidth",
     "rippleAmplitude", "rippleA", "rippleB", "rippleC", "rippleD"
    ].forEach(function (n) { U[n] = gl.getUniformLocation(prog, n); });

    gl.uniform1f(U.rippleWidth, RIPPLE.width);
    applyGl();
    applyCss();

    // The ripple slots are parked permanently out of range.
    //
    // The wavefronts read as concentric rings drawn *over* the field rather
    // than as the field moving, which is the opposite of the reference: XMB's
    // motion is in the ribbons themselves. Beats now surge the band drift
    // instead — same input, and it moves the thing that is supposed to move.
    //
    // The uniforms are set explicitly rather than left at their defaults,
    // because an unset vec4 is all zeroes, and a birth time of 0 would render
    // one real ripple during the first 2.5 units of the clock.
    ["rippleA", "rippleB", "rippleC", "rippleD"].forEach(function (n) {
      gl.uniform4fv(U[n], [0, 0, -999, 0]);
    });
    gl.uniform1f(U.rippleAmplitude, 0);

    function resize() {
      var d = Math.min(window.devicePixelRatio || 1, 1.5);
      var w = Math.max(1, Math.round(canvas.clientWidth * d));
      var h = Math.max(1, Math.round(canvas.clientHeight * d));
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w; canvas.height = h;
        gl.viewport(0, 0, w, h);
        gl.uniform2f(U.resolution, w, h);
      }
    }

    // Time is ACCUMULATED rather than derived from elapsed*rate, so moving the
    // rate slider changes the speed from now on instead of jumping the clock
    // and teleporting every live ripple.
    var tAcc = 0, tPrev = performance.now(), kick = 0;
    function clock() { return tAcc; }

    // A beat adds to the drift rate and decays back, so the ribbons lurch and
    // settle. Reactivity scales the surge; at 0 the field just drifts.
    function ripple() {
      if (!CFG.enabled) return;
      kick = Math.min(kick + 0.55 * CFG.reactivity, 3.0);
    }

    var last = 0;
    function draw(now) {
      frame = requestAnimationFrame(draw);
      var dt = Math.min((now - tPrev) / 1000, 0.1);
      tAcc += dt * (rate() + kick);
      kick *= Math.pow(0.02, dt / 0.30);      // ~0.3s to settle
      tPrev = now;
      if (now - last < 1000 / FPS_CAP) return;
      last = now;
      if (!CFG.enabled) return;
      resize();
      gl.uniform1f(U.time, clock());
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    frame = requestAnimationFrame(draw);

    // The desktop wallpaper keeps rendering behind maximised windows because
    // wlr-layer-shell exposes no occlusion signal. A web page does, so use it.
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) {
        cancelAnimationFrame(frame);
      } else {
        last = 0; tPrev = performance.now();
        frame = requestAnimationFrame(draw);
      }
    });

    startBeats(ripple);
    installPanel();
  }

  function teardown(style) {
    if (style) style.remove();
    if (canvas) canvas.remove();
    canvas = null; gl = null; U = null;
  }

  // ------------------------------------------------------------------
  // Waveform.
  //
  // `segments[].loudness_max` is dB, roughly -60..0. Normalised and drawn as
  // a mirrored bar envelope. Two images: a dim one for the whole track and a
  // hot one clipped to the playhead, regenerated a few times a second rather
  // than per frame — half a second of playhead precision is invisible, and
  // toDataURL is far too expensive to run at 60Hz.
  // ------------------------------------------------------------------
  var WAVE = { segs: null, dur: 0, lastPct: -1, lastAt: 0 };
  var WAVE_W = 900, WAVE_H = 64;

  function drawWave(fraction, colour, alpha) {
    var cv = document.createElement("canvas");
    cv.width = WAVE_W; cv.height = WAVE_H;
    var ctx = cv.getContext("2d");
    if (!ctx || !WAVE.segs || !WAVE.dur) return "none";
    ctx.fillStyle = colour;
    ctx.globalAlpha = alpha;
    var bars = 220, bw = WAVE_W / bars, si = 0;
    for (var i = 0; i < bars; i++) {
      var t = (i / bars) * WAVE.dur;
      if ((i / bars) > fraction) break;
      while (si < WAVE.segs.length - 1 && WAVE.segs[si + 1].start <= t) si++;
      var db = WAVE.segs[si].loudness_max;
      if (typeof db !== "number") db = -30;
      var amp = Math.max(0, Math.min(1, (db + 46) / 46));
      amp = Math.pow(amp, 1.4);
      var hgt = Math.max(1.5, amp * WAVE_H * 0.72);
      ctx.fillRect(i * bw + bw * 0.18, (WAVE_H - hgt) / 2, bw * 0.64, hgt);
    }
    try { return 'url("' + cv.toDataURL("image/png") + '")'; }
    catch (e) { return "none"; }
  }

  function accentHex() {
    return CFG.colorMode === "tokens" ? rgbToHex(tint(FIELD.colorLine)) : "#ffffff";
  }

  function refreshWave(pct, force) {
    if (!CFG.waveform || !WAVE.segs) return;
    var now = Date.now();
    if (!force && (now - WAVE.lastAt < 450 || Math.abs(pct - WAVE.lastPct) < 0.004)) return;
    WAVE.lastAt = now; WAVE.lastPct = pct;
    document.documentElement.classList.add("gelo-has-wave");
    var r = document.documentElement.style;
    r.setProperty("--gelo-wave-hot", drawWave(pct, accentHex(), 0.85));
    if (force) r.setProperty("--gelo-wave-dim", drawWave(1, accentHex(), 0.18));
  }

  function clearWave() {
    WAVE.segs = null; WAVE.lastPct = -1;
    document.documentElement.classList.remove("gelo-has-wave");
    var r = document.documentElement.style;
    r.setProperty("--gelo-wave-hot", "none");
    r.setProperty("--gelo-wave-dim", "none");
  }

  // ------------------------------------------------------------------
  // Album colour. Best-effort in every direction: two different Spicetify
  // APIs, either of which may be absent or reject, and a null result simply
  // means the field keeps its token colours.
  // ------------------------------------------------------------------
  function readAlbumColour(uri) {
    var S = window.Spicetify;
    if (!S) return;

    function accept(hex) {
      if (!hex || typeof hex !== "string") return false;
      var m = hex.replace("#", "");
      if (m.length !== 6 || /[^0-9a-f]/i.test(m)) return false;
      var r = parseInt(m.slice(0, 2), 16) / 255,
          g = parseInt(m.slice(2, 4), 16) / 255,
          b = parseInt(m.slice(4, 6), 16) / 255;
      var hsl = rgb2hsl(r, g, b);
      if (hsl[1] < 0.08) return false;     // a grey cover carries no hue
      ALBUM = { h: hsl[0], s: hsl[1], hex: "#" + m.toLowerCase() };
      applyGl(); applyCss();
      refreshWave(WAVE.lastPct < 0 ? 0 : WAVE.lastPct, true);
      var sw = document.getElementById("gelo-album-swatch");
      if (sw) paintSwatch(sw);
      return true;
    }

    try {
      if (S.colorExtractor) {
        S.colorExtractor(uri).then(function (c) {
          if (!accept(c && (c.VIBRANT || c.PROMINENT || c.DESATURATED))) fromPixels();
        }).catch(fromPixels);
        return;
      }
      if (S.extractColorPreset) {
        S.extractColorPreset(uri).then(function (p) {
          var first = p && p[0];
          if (!accept(first && first.colorRaw && first.colorRaw.hex)) fromPixels();
        }).catch(fromPixels);
        return;
      }
    } catch (e) { /* fall through */ }
    fromPixels();
  }

  // Reading the cover art directly.
  //
  // This is the path that has to work, so it does not lean on Spotify
  // internals: Spotify's image CDN answers with `access-control-allow-origin:
  // *` (verified against image-cdn-fa.spotifycdn.com), which means an
  // anonymous <img> can be drawn to a canvas and sampled. The extractor APIs
  // above are a nicety; this is the guarantee.
  //
  // The artwork element is found rather than assumed — the first version
  // queried one selector and came back empty, and an empty read is
  // indistinguishable from "this cover has no colour" unless you look. It also
  // retries, because the DOM art swaps in a beat or two after the track does.
  function coverUrl() {
    var sels = [
      ".main-nowPlayingView-coverArt img",
      ".main-nowPlayingView-coverArt .main-image-image",
      ".main-nowPlayingWidget-coverArt img",
      "[data-testid=\"cover-art-image\"] img",
      "[data-testid=\"cover-art-image\"]",
      ".main-coverSlotCollapsed-container img"
    ];
    for (var i = 0; i < sels.length; i++) {
      var el = document.querySelector(sels[i]);
      if (!el) continue;
      var u = el.currentSrc || el.src || el.getAttribute("src");
      if (!u) {
        try {
          var m = /url\(["\']?(.*?)["\']?\)/.exec(
            getComputedStyle(el).backgroundImage || "");
          if (m) u = m[1];
        } catch (e) { /* ignore */ }
      }
      if (u && /^https?:/.test(u)) return u;
    }
    return null;
  }

  function fromPixels(attempt) {
    attempt = attempt || 0;
    if (attempt > 5) return;
    var src = coverUrl();
    if (!src) { setTimeout(function () { fromPixels(attempt + 1); }, 700); return; }

    var probe = new Image();
    probe.crossOrigin = "anonymous";
    probe.onerror = function () {
      setTimeout(function () { fromPixels(attempt + 1); }, 700);
    };
    probe.onload = function () {
      try {
        var n = 48, cv = document.createElement("canvas");
        cv.width = n; cv.height = n;
        var ctx = cv.getContext("2d");
        ctx.drawImage(probe, 0, 0, n, n);
        var d = ctx.getImageData(0, 0, n, n).data;
        // Average hue as a unit vector, weighted by saturation squared, so a
        // mostly-grey cover with one saturated element still resolves and hues
        // near 0/360 do not average to the opposite side of the circle.
        var x = 0, y = 0, sw = 0, ss = 0;
        for (var i = 0; i < d.length; i += 4) {
          if (d[i + 3] < 128) continue;
          var hsl = rgb2hsl(d[i] / 255, d[i + 1] / 255, d[i + 2] / 255);
          if (hsl[2] < 0.08 || hsl[2] > 0.96) continue;   // near-black / blown out
          var w = hsl[1] * hsl[1];
          var rad = hsl[0] * Math.PI / 180;
          x += Math.cos(rad) * w; y += Math.sin(rad) * w;
          ss += hsl[1] * w; sw += w;
        }
        if (sw <= 0) { setTimeout(function () { fromPixels(attempt + 1); }, 700); return; }
        var h = ((Math.atan2(y, x) * 180 / Math.PI) % 360 + 360) % 360;
        var sat = Math.max(0, Math.min(1, ss / sw));
        if (sat < 0.06) return;                 // genuinely a greyscale cover
        ALBUM = { h: h, s: sat, hex: rgbToHex(hsl2rgb(h, sat, 0.55)) };
        applyGl(); applyCss();
        refreshWave(WAVE.lastPct < 0 ? 0 : WAVE.lastPct, true);
        var sw2 = document.getElementById("gelo-album-swatch");
        if (sw2) paintSwatch(sw2);
      } catch (e) {
        // Tainted canvas: the CDN stopped sending CORS. Keep token colours.
      }
    };
    probe.src = src;
  }

  // ------------------------------------------------------------------
  // Beats -> ripples, and playback state -> the turntable.
  //
  // Spotify's audio analysis is best-effort: it is missing for local files
  // and most podcasts, and the call can simply fail. Every path here
  // degrades to fewer ripples, never to a broken field.
  // ------------------------------------------------------------------
  function startBeats(ripple) {
    var beats = [], idx = 0, uri = null, lastFallback = 0;

    function reload(u) {
      beats = []; idx = 0;
      var S = window.Spicetify;
      if (!S || !S.getAudioData) return;
      ripple();                             // a track change is itself an event
      readAlbumColour(u);
      clearWave();
      S.getAudioData().then(function (d) {
        beats = (d && d.beats) ? d.beats : [];
        idx = 0;
        if (d && d.segments && d.segments.length) {
          WAVE.segs = d.segments;
          WAVE.dur = (d.track && d.track.duration)
            || d.segments[d.segments.length - 1].start
               + d.segments[d.segments.length - 1].duration;
          refreshWave(0, true);
        }
      }).catch(function () { beats = []; });
    }

    // Watch the ARTWORK, not the track change.
    //
    // Extraction used to fire on track change and retry on a fixed schedule,
    // which is a race: the DOM swaps the cover a beat or two later, and if the
    // retries ran out first the read silently produced nothing. The symptom
    // was the panel disagreeing with itself — the colour swatch showing a
    // magenta taken from the *previous* cover while "Detected" correctly said
    // nothing had been read for this one.
    //
    // The artwork URL is the actual signal, so poll that. It self-heals for
    // late loads, video mode, and covers that arrive out of order.
    var lastCover = null;
    setInterval(function () {
      if (!CFG.enabled) return;
      var u = coverUrl();
      if (u && u !== lastCover) { lastCover = u; fromPixels(0); }
    }, 600);

    setInterval(function () {
      var S = window.Spicetify;
      if (!S || !S.Player || !S.Player.data) return;

      var playing = !!(S.Player.isPlaying && S.Player.isPlaying());
      document.documentElement.classList.toggle("gelo-playing", playing);

      if (!CFG.enabled) return;
      var now = S.Player.data.item && S.Player.data.item.uri;
      if (now !== uri) { uri = now; reload(now); return; }
      if (!playing) return;

      // More reactivity also means a lower bar for what counts as a beat.
      var floor = Math.max(0.05, 0.55 - 0.3 * CFG.reactivity);

      if (!beats.length) {
        if (WAVE.dur) {
          var p0 = S.Player.getProgress() / 1000;
          refreshWave(Math.max(0, Math.min(1, p0 / WAVE.dur)), false);
        }
        var t = Date.now();
        if (t - lastFallback > 2400 / Math.max(CFG.reactivity, 0.2)) {
          lastFallback = t;
          ripple();
        }
        return;
      }

      var pos = S.Player.getProgress() / 1000;
      if (WAVE.dur) refreshWave(Math.max(0, Math.min(1, pos / WAVE.dur)), false);

      // Fire AHEAD of the timestamp. The analysis timeline is where the beat
      // is in the file, not where it is in the air — Spotify's output
      // buffering puts the two apart, and the poll and frame cap add their own
      // delay on top. Anticipating by `lead` cancels the lot. The right value
      // depends on the output path, hence a slider rather than a constant.
      var p = pos + CFG.lead;
      if (idx > 0 && beats[idx - 1] && p < beats[idx - 1].start - 1) idx = 0;

      while (idx < beats.length && beats[idx].start <= p) {
        if (p - beats[idx].start < 0.25 && beats[idx].confidence > floor) {
          // Off-centre and low, so the field answers the music rather than
          // pulsing at it from the middle of the screen.
          ripple();
        }
        idx++;
      }
    }, 20);
  }

  // ------------------------------------------------------------------
  // The control panel.
  //
  // Built as plain DOM rather than through PopupModal, so it depends on as
  // little of Spicetify's API surface as possible — the whole layer has to
  // survive Spotify updates, and every API touched is a way to not.
  // ------------------------------------------------------------------
  var SLIDERS = [
    ["tint", "Tint strength", 0, 1, 0.05],
    ["fieldGain", "Field brightness", 0, 2, 0.05],
    ["sat", "Field saturation", 0, 2, 0.05],
    ["scrim", "Main view scrim", 0.2, 0.95, 0.01],
    ["ui", "UI opacity", 0.3, 1, 0.01],
    ["panel", "Right panel", 0.3, 1, 0.01],
    ["reactivity", "Beat reactivity", 0, 2, 0.05],
    ["lead", "Beat lead", 0, 0.4, 0.01],
    ["rate", "Drift rate", 0, 2, 0.05],
    ["spin", "Spin period (s)", 3, 40, 1]
  ];
  var TOGGLES = [
    ["enabled", "Field"],
    ["coolLock", "Cool lock"],
    ["turntable", "Turntable"],
    ["waveform", "Waveform bar"]
  ];

  function paintSwatch(el) {
    var src = CFG.colorMode === "album" ? (ALBUM && ALBUM.hex)
            : CFG.colorMode === "custom" ? CFG.customColor
            : null;
    el.style.background = src || "transparent";
    el.style.borderStyle = src ? "solid" : "dashed";
    el.title = src || "using tokens.json";
    var lbl = document.getElementById("gelo-album-label");
    if (lbl) {
      lbl.textContent = CFG.colorMode === "album"
        ? (ALBUM && ALBUM.hex ? ALBUM.hex : "reading cover…")
        : CFG.colorMode === "custom" ? CFG.customColor : "tokens.json";
    }
  }

  function installPanel() {
    // `Spicetify.Menu` is not populated yet when this file first runs, so a
    // single attempt registers nothing and — because the failure is caught —
    // does it silently. The item was simply absent from the profile menu while
    // every other spicetify entry showed up. Retry until it takes.
    var tries = 0;
    (function register() {
      if (++tries > 100) return;                 // ~30s, then give up quietly
      try {
        if (window.Spicetify && Spicetify.Menu && Spicetify.Menu.Item) {
          new Spicetify.Menu.Item("XMB field", false, function (self) {
            toggle(); if (self && self.setState) self.setState(false);
          }).register();
          return;
        }
      } catch (e) { /* not ready yet */ }
      setTimeout(register, 300);
    })();

    document.addEventListener("keydown", function (ev) {
      if (ev.ctrlKey && ev.altKey && (ev.key === "X" || ev.key === "x")) {
        ev.preventDefault(); toggle();
      }
    });
  }

  function toggle() {
    var open = document.getElementById("gelo-xmb-panel");
    if (open) { open.remove(); return; }
    document.body.appendChild(buildPanel());
  }

  function buildPanel() {
    var wrap = document.createElement("div");
    wrap.id = "gelo-xmb-panel";
    wrap.style.cssText = [
      "position:fixed", "right:24px", "bottom:112px", "z-index:9999",
      "width:300px", "max-height:74vh", "overflow-y:auto", "padding:16px",
      "border-radius:8px",
      // Opaque on purpose. The panel reads `--gelo-surf-*` so it follows the
      // palette, but NOT `--gelo-ui` — a settings panel you cannot read at low
      // UI opacity is a settings panel you cannot use to raise UI opacity.
      "background:linear-gradient(180deg," +
        "rgba(var(--gelo-surf-raised),0.97) 0%," +
        "rgba(var(--gelo-surf-deep),0.97) 100%)",
      "border:1px solid rgba(var(--spice-rgb-button),0.20)",
      "box-shadow:0 6px 32px rgba(var(--spice-rgb-shadow),0.5)," +
        "0 0 14px rgba(var(--spice-rgb-button),0.15)",
      "color:var(--spice-text)",
      "font-size:12px", "letter-spacing:0.02em"
    ].join(";");

    var head = document.createElement("div");
    head.style.cssText = "display:flex;justify-content:space-between;align-items:center;margin-bottom:12px";
    var title = document.createElement("div");
    title.textContent = "XMB field";
    title.style.cssText = "font-size:13px";
    var close = document.createElement("button");
    close.textContent = "×";
    close.style.cssText = "background:none;border:0;color:var(--spice-subtext);cursor:pointer;font-size:16px;line-height:1";
    close.onclick = function () { wrap.remove(); };
    head.appendChild(title); head.appendChild(close);
    wrap.appendChild(head);

    // ---- colour source -------------------------------------------------
    var srcRow = row("Colour source");
    var sel = document.createElement("select");
    sel.style.cssText = "background:var(--spice-player);color:var(--spice-text);"
      + "border:1px solid rgba(var(--spice-rgb-button),0.25);border-radius:4px;"
      + "padding:2px 6px;font-size:12px;cursor:pointer";
    [["tokens", "tokens.json"], ["custom", "Custom"], ["album", "Album art"]]
      .forEach(function (o) {
        var op = document.createElement("option");
        op.value = o[0]; op.textContent = o[1];
        if (CFG.colorMode === o[0]) op.selected = true;
        sel.appendChild(op);
      });
    srcRow.appendChild(sel);
    wrap.appendChild(srcRow);

    var pickRow = row("Colour");
    var swatch = document.createElement("span");
    swatch.id = "gelo-album-swatch";
    swatch.style.cssText = "width:18px;height:18px;border-radius:4px;display:inline-block;"
      + "border:1px solid rgba(var(--spice-rgb-button),0.35);margin-left:auto";
    var label = document.createElement("span");
    label.id = "gelo-album-label";
    label.style.cssText = "color:var(--spice-subtext);font-variant-numeric:tabular-nums;"
      + "margin:0 8px 0 8px";
    var picker = document.createElement("input");
    picker.type = "color"; picker.value = CFG.customColor;
    picker.style.cssText = "width:24px;height:20px;padding:0;border:0;background:none;cursor:pointer";
    var hex = document.createElement("input");
    hex.type = "text"; hex.value = CFG.customColor; hex.spellcheck = false;
    hex.style.cssText = "width:74px;background:var(--spice-player);color:var(--spice-text);"
      + "border:1px solid rgba(var(--spice-rgb-button),0.25);border-radius:4px;"
      + "padding:2px 6px;font-size:12px;margin-left:8px";

    function setCustom(v, from) {
      if (!hexToHS(v)) return;
      CFG.customColor = v.toLowerCase();
      if (from !== "picker") picker.value = CFG.customColor;
      if (from !== "hex") hex.value = CFG.customColor;
      paintSwatch(swatch); applyGl(); applyCss();
      refreshWave(WAVE.lastPct, true); save();
    }
    picker.oninput = function () { setCustom(picker.value, "picker"); };
    hex.onchange = function () { setCustom(hex.value.trim(), "hex"); };

    function syncMode() {
      var custom = CFG.colorMode === "custom";
      picker.style.display = custom ? "" : "none";
      hex.style.display = custom ? "" : "none";
      label.style.display = custom ? "none" : "";
      paintSwatch(swatch);
    }
    sel.onchange = function () {
      CFG.colorMode = sel.value;
      syncMode(); applyGl(); applyCss(); refreshWave(WAVE.lastPct, true); save();
    };

    pickRow.appendChild(label);
    pickRow.appendChild(picker);
    pickRow.appendChild(hex);
    pickRow.appendChild(swatch);
    wrap.appendChild(pickRow);

    // Always show what was read off the current cover, whatever mode is
    // selected. It is the honest answer to "is it actually reading the album
    // art" — a hex here means yes, "—" means the extractors and the pixel
    // fallback both came back empty and the field is on token colours.
    var detRow = row("Detected");
    var detSw = document.createElement("span");
    detSw.style.cssText = "width:18px;height:18px;border-radius:4px;display:inline-block;"
      + "border:1px solid rgba(var(--spice-rgb-button),0.35);margin-left:8px";
    var detTxt = document.createElement("span");
    detTxt.style.cssText = "color:var(--spice-subtext);font-variant-numeric:tabular-nums;margin-left:auto";
    detRow.appendChild(detTxt); detRow.appendChild(detSw);
    wrap.appendChild(detRow);
    // Deferred, not immediate. buildPanel() runs BEFORE the node is appended,
    // so an immediate first tick fails its own `contains(wrap)` guard and never
    // reschedules — the readout then sits empty forever while the swatch beside
    // it updates fine, which reads exactly like broken colour extraction and is
    // not.
    setTimeout(function poll() {
      if (!document.body.contains(wrap)) return;
      detTxt.textContent = ALBUM && ALBUM.hex ? ALBUM.hex : "—";
      detSw.style.background = ALBUM && ALBUM.hex ? ALBUM.hex : "transparent";
      setTimeout(poll, 500);
    }, 0);

    syncMode();

    var surfRow = row("Surface style");
    var surfSel = document.createElement("select");
    surfSel.style.cssText = sel.style.cssText;
    [["tinted", "Tinted"], ["neutral", "Neutral black"]].forEach(function (o) {
      var op = document.createElement("option");
      op.value = o[0]; op.textContent = o[1];
      if (CFG.surface === o[0]) op.selected = true;
      surfSel.appendChild(op);
    });
    surfSel.onchange = function () {
      CFG.surface = surfSel.value; applyCss(); save();
    };
    surfRow.appendChild(surfSel);
    wrap.appendChild(surfRow);

    TOGGLES.forEach(function (t) {
      var r = row(t[1]);
      var chk = document.createElement("input");
      chk.type = "checkbox"; chk.checked = !!CFG[t[0]];
      chk.style.cssText = "accent-color:var(--spice-button);cursor:pointer";
      chk.onchange = function () {
        CFG[t[0]] = chk.checked; applyCss(); applyGl(); save();
      };
      r.appendChild(chk);
      wrap.appendChild(r);
    });

    SLIDERS.forEach(function (s) {
      var key = s[0], min = s[2], max = s[3], step = s[4];
      var r = row(s[1]);
      var val = document.createElement("span");
      val.textContent = fmt(key, CFG[key]);
      val.style.cssText = "color:var(--spice-subtext);font-variant-numeric:tabular-nums";
      r.appendChild(val);
      wrap.appendChild(r);

      var input = document.createElement("input");
      input.type = "range";
      input.min = min; input.max = max; input.step = step; input.value = CFG[key];
      input.style.cssText = "width:100%;margin:0 0 10px;accent-color:var(--spice-button);cursor:pointer";
      input.oninput = function () {
        CFG[key] = parseFloat(input.value);
        val.textContent = fmt(key, CFG[key]);
        applyCss(); applyGl();
      };
      input.onchange = save;
      wrap.appendChild(input);
    });

    var foot = document.createElement("div");
    foot.style.cssText = "display:flex;gap:8px;margin-top:4px";
    foot.appendChild(button("Reset", function () {
      for (var k in DEFAULTS) CFG[k] = DEFAULTS[k];
      applyCss(); applyGl(); save();
      wrap.remove(); document.body.appendChild(buildPanel());
    }));
    // The panel is a place to FIND a value, not to keep it. tokens.json is
    // still the source of truth, so make moving a setting back there one click.
    foot.appendChild(button("Copy", function (b) {
      var out = {};
      for (var k in DEFAULTS) out[k] = CFG[k];
      var text = JSON.stringify(out, null, 2);
      try {
        navigator.clipboard.writeText(text);
        b.textContent = "Copied";
        setTimeout(function () { b.textContent = "Copy"; }, 1200);
      } catch (e) { console.log("[gelo-xmb]", text); }
    }));
    wrap.appendChild(foot);

    var note = document.createElement("div");
    note.textContent = "Colour source defaults to tokens.json. Cool lock keeps "
      + "custom and album hues inside the palette. Copy a value you like back "
      + "into the token source.";
    note.style.cssText = "margin-top:10px;color:var(--spice-subtext);font-size:11px;line-height:1.4";
    wrap.appendChild(note);

    return wrap;
  }

  function fmt(key, v) {
    if (key === "hue") return Math.round(v) + "°";
    if (key === "spin") return Math.round(v) + "s";
    if (key === "lead") return Math.round(v * 1000) + "ms";
    return Number(v).toFixed(2);
  }

  function row(label) {
    var r = document.createElement("div");
    r.style.cssText = "display:flex;justify-content:space-between;align-items:center;margin-bottom:6px";
    var l = document.createElement("span");
    l.textContent = label;
    r.appendChild(l);
    return r;
  }

  function button(text, fn) {
    var b = document.createElement("button");
    b.textContent = text;
    b.style.cssText = [
      "flex:1", "padding:6px 10px", "cursor:pointer",
      "border-radius:8px",
      "border:1px solid rgba(var(--spice-rgb-button),0.25)",
      "background:transparent", "color:var(--spice-text)",
      "font-size:12px",
      "transition:box-shadow 150ms cubic-bezier(0.22, 1.0, 0.36, 1.0), border-color 150ms cubic-bezier(0.22, 1.0, 0.36, 1.0)"
    ].join(";");
    b.onmouseenter = function () {
      b.style.boxShadow = "0 0 14px rgba(var(--spice-rgb-button),0.28)";
      b.style.borderColor = "rgba(var(--spice-rgb-button),0.5)";
    };
    b.onmouseleave = function () {
      b.style.boxShadow = "none";
      b.style.borderColor = "rgba(var(--spice-rgb-button),0.25)";
    };
    b.onclick = function () { fn(b); };
    return b;
  }

  var VERT = [
    "#version 300 es",
    "in vec2 pos;",
    "out vec2 qt_TexCoord0;",
    "void main() {",
    "  qt_TexCoord0 = pos * 0.5 + 0.5;",
    "  gl_Position = vec4(pos, 0.0, 1.0);",
    "}"
  ].join("\n");

  var FRAG = "#version 300 es\nprecision highp float;\n\n// Retargeted from design/shaders/xmb.frag by design/build-tokens.py.\n// Edit the .frag, never this string.\n\nin vec2 qt_TexCoord0;\nout vec4 fragColor;\n\nuniform float time;\nuniform vec2 resolution;\nuniform vec4 colorBase;\nuniform vec4 colorMid;\nuniform vec4 colorHigh;\nuniform vec4 colorEdge;\nuniform vec4 colorLine;\nuniform vec4 colorAccent;\nuniform float rippleSpeed;\nuniform float rippleWidth;\nuniform float rippleAmplitude;\nuniform vec4 rippleA;\nuniform vec4 rippleB;\nuniform vec4 rippleC;\nuniform vec4 rippleD;\n\nconst float qt_Opacity = 1.0;\n\n\n// One filament of light.\n//\n// The core is what makes this read as XMB. Earlier versions used a single wide\n// gaussian, which produces a soft band \u2014 fog, not light. A real XMB strand is a\n// THIN bright core with a much wider, much fainter halo around it, so the eye\n// sees a filament that glows rather than a smear that is bright in the middle.\n//\n//   yc     centre height, 0..1\n//   amp    vertical swing\n//   freq   horizontal wavelength\n//   speed  drift rate\n//   core   half-width of the bright thread (very small)\n//   halo   half-width of the surrounding bloom (roughly 15-25x the core)\nfloat filament(vec2 p, float yc, float amp, float freq, float speed,\n               float core, float halo, float t) {\n    // Two sines at a non-integer ratio. A single sine reads as a test pattern;\n    // this reads as cloth.\n    float y = yc\n            + amp * sin(p.x * freq + t * speed)\n            + amp * 0.42 * sin(p.x * freq * 1.73 - t * speed * 0.63);\n\n    float d = p.y - y;\n    float d2 = d * d;\n\n    float bright = exp(-d2 / (core * core));\n    float bloom = exp(-d2 / (halo * halo));\n\n    return bright + bloom * 0.22;\n}\n\n// Broad, very soft mass of light. A handful of these sit behind the filaments\n// so the frame is not black between strands \u2014 the diffuse field the threads\n// are suspended in.\nfloat haze(vec2 p, vec2 c, vec2 radius, float t, float drift) {\n    vec2 o = c + vec2(0.09 * sin(t * drift), 0.045 * cos(t * drift * 0.77));\n    vec2 d = (p - o) / radius;\n    return exp(-dot(d, d));\n}\n\n// xy = origin (normalised screen), z = birth time on the same clock as `time`.\nvoid accumulateRipple(vec4 r, vec2 uv, float aspect, float t,\n                      inout vec2 warp, inout float glow) {\n    float age = t - r.z;\n    if (age < 0.0 || age > 2.5)\n        return;\n\n    vec2 d = (uv - r.xy) * vec2(aspect, 1.0);\n    float dist = length(d);\n    float radius = age * rippleSpeed;\n\n    // Annulus: strongest at the wavefront, nothing inside or outside it.\n    float band = exp(-pow((dist - radius) / rippleWidth, 2.0));\n    float decay = exp(-age * 1.6);\n\n    warp += normalize(d + 1e-6) * band * decay * rippleAmplitude * 0.05;\n    glow += band * decay;\n}\n\nvoid main() {\n    vec2 uv = qt_TexCoord0;\n    float aspect = resolution.x / max(resolution.y, 1.0);\n    float t = time;\n\n    // --- ripple displacement ---------------------------------------------\n    // Accumulated BEFORE the ribbons are evaluated, so a ripple bends the bands\n    // it crosses instead of being drawn on top of them.\n    vec2 warp = vec2(0.0);\n    float rippleGlow = 0.0;\n\n    accumulateRipple(rippleA, uv, aspect, t, warp, rippleGlow);\n    accumulateRipple(rippleB, uv, aspect, t, warp, rippleGlow);\n    accumulateRipple(rippleC, uv, aspect, t, warp, rippleGlow);\n    accumulateRipple(rippleD, uv, aspect, t, warp, rippleGlow);\n\n    vec2 p = uv + warp;\n\n    // --- diffuse haze -----------------------------------------------------\n    float hz = 0.0;\n    hz += 0.85 * haze(p, vec2(0.42, 0.44), vec2(0.62, 0.20), t, 0.13);\n    hz += 0.55 * haze(p, vec2(0.70, 0.55), vec2(0.48, 0.16), t, -0.09);\n    hz += 0.40 * haze(p, vec2(0.20, 0.62), vec2(0.40, 0.13), t, 0.11);\n\n    // --- filaments --------------------------------------------------------\n    // Ordered top of frame to bottom, and thickness TAPERS as they descend:\n    // the upper strands are broad ribbons, the lower ones are fine threads.\n    // A uniform thickness reads as a pattern; the taper gives the field a\n    // near edge and a far edge, so it has depth rather than repetition.\n    //\n    // Eleven strands, down from thirteen \u2014 the lower band was dense enough that\n    // individual threads stopped being legible as threads. Drift rates are also\n    // ~1.35x the original: enough that the field is perceptibly alive at a\n    // glance, still slow enough to ignore while working.\n    float f = 0.0;\n    //                      yc     amp    freq  speed    core    halo\n    f += 0.55 * filament(p, 0.185, 0.075, 2.4,  0.18,  0.0090, 0.075, t);\n    f += 0.70 * filament(p, 0.255, 0.068, 3.1, -0.22,  0.0075, 0.068, t);\n    f += 0.85 * filament(p, 0.325, 0.082, 2.8,  0.29,  0.0060, 0.060, t);\n    f += 1.00 * filament(p, 0.395, 0.070, 3.6, -0.34,  0.0048, 0.052, t);\n    f += 0.95 * filament(p, 0.455, 0.060, 4.7,  0.68,  0.0036, 0.044, t);\n    f += 0.90 * filament(p, 0.515, 0.075, 3.3, -0.52,  0.0028, 0.038, t);\n    f += 0.78 * filament(p, 0.575, 0.068, 6.1,  0.42,  0.0020, 0.032, t);\n    f += 0.62 * filament(p, 0.640, 0.090, 2.6, -0.30,  0.0016, 0.030, t);\n    f += 0.48 * filament(p, 0.710, 0.098, 4.1,  0.26,  0.0013, 0.026, t);\n    f += 0.32 * filament(p, 0.785, 0.120, 5.7, -0.19,  0.0009, 0.023, t);\n    f += 0.22 * filament(p, 0.860, 0.112, 3.4,  0.15,  0.0007, 0.020, t);\n\n    // --- tone -------------------------------------------------------------\n    // A faint cold vertical gradient underneath, so the frame is not flat where\n    // nothing reaches.\n    vec3 col = mix(colorBase.rgb, colorMid.rgb, smoothstep(1.0, 0.0, uv.y) * 0.45);\n\n    // The haze lifts the field toward bg-2 / border. Broad and very low\n    // contrast \u2014 it should never be readable as a shape on its own.\n    col = mix(col, colorHigh.rgb, clamp(hz * 0.40, 0.0, 1.0));\n    col = mix(col, colorEdge.rgb, clamp((hz - 0.75) * 0.45, 0.0, 1.0));\n\n    // Filaments are light, so they ADD rather than mix \u2014 that is what lets a\n    // strand read as brighter than the surface it crosses instead of just\n    // being a different colour. On the light palette the field is already near\n    // silver, so the strands have to reach past it toward white to register.\n    //\n    // Measured tuning: at 0.30 / 0.16 the overlapping strands summed into a\n    // white wash \u2014 10% of the frame clipped at 250+ and the whole middle read\n    // as blown out rather than as light. Additive terms have to be far gentler\n    // on a light field than on a dark one, because the surface is already most\n    // of the way to white before anything is added.\n    col += colorLine.rgb * clamp(f, 0.0, 2.2) * 0.15;\n    col += vec3(1.0) * smoothstep(1.10, 2.2, f) * 0.07;\n\n    // The ripple wavefront carries accent light. This is the only place the\n    // accent appears outside its three sanctioned locations, and it is\n    // transient \u2014 under a second, then gone.\n    //\n    // Kept low deliberately. At 0.35 the wavefront rendered as a hard cyan ring\n    // drawn over the field rather than as light moving through it, which made a\n    // transient effect the loudest thing on screen.\n    col += colorAccent.rgb * rippleGlow * 0.16;\n\n    // Vignette keeps attention centred.\n    float vig = smoothstep(1.35, 0.30, length((uv - 0.5) * vec2(aspect, 1.0)));\n    col *= mix(0.80, 1.0, vig);\n\n    fragColor = vec4(col, 1.0) * qt_Opacity;\n}\n";

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
