// GENERATED FILE — DO NOT EDIT. Source: design/tokens.json (run design/build-tokens.py)
pragma Singleton

import QtQuick

QtObject {
    id: root

    // Returns `c` at alpha `a`. Materials are defined as a base colour plus an
    // opacity, so nearly every surface in the system goes through here.
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property QtObject color: QtObject {
        readonly property color bg0: "#05070c"
        readonly property color bg1: "#0b0f18"
        readonly property color bg2: "#131a28"
        readonly property color border: "#1c2536"
        readonly property color text1: "#eef2f7"
        readonly property color text2: "#6b7686"
        readonly property color accent: "#4fc8ff"
        readonly property color accentDim: "#2a7fa8"
        readonly property color glow: "#334fc8ff"
    }

    readonly property QtObject space: QtObject {
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
        readonly property int xxl: 32
    }

    readonly property QtObject radius: QtObject {
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
        readonly property int full: 999
    }

    // Open tracking is part of the XMB feel. QML letterSpacing is in
    // pixels, so it has to be derived from the size it is applied at.
    function tracking(pixelSize) {
        return pixelSize * root.typography.trackingEm;
    }

    readonly property QtObject typography: QtObject {
        readonly property string display: "Michroma"

        // QML's font value type exposes `family` (one string) and has no
        // `families` list, so per-glyph fallback is fontconfig's job, not
        // ours. This list is here for the CSS tier, which can express it.
        readonly property var families: ["Michroma", "Inter Display"]

        readonly property real trackingEm: 0.02

        readonly property QtObject size: QtObject {
            readonly property int caption: 11
            readonly property int body: 13
            readonly property int title: 15
        }

        readonly property QtObject weight: QtObject {
            readonly property int light: 300
            readonly property int regular: 400
        }
    }

    readonly property QtObject motion: QtObject {
        // Feed straight into `easing.bezierCurve`. QML wants six values:
        // the two control points plus the fixed (1,1) endpoint.
        readonly property var easeBezier: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]

        readonly property QtObject duration: QtObject {
            readonly property int fast: 150
            readonly property int base: 250
            readonly property int slow: 400
        }

        readonly property int stagger: 24
    }

    readonly property QtObject material: QtObject {
        readonly property QtObject chrome: QtObject {
            readonly property real surfaceOpacity: 0.96
            readonly property real gradientDarken: 0.06
            readonly property real strokeOpacity: 0.9
            readonly property int radius: 8
            readonly property int shadowRadius: 32
            readonly property real shadowOpacity: 0.5
            readonly property int shadowOffsetY: 6
            // The brushed-metal gradient stops, and the hairline/shadow that frame them.
            readonly property color surfaceTop: root.alpha(root.color.bg1, surfaceOpacity)
            readonly property color surfaceBottom: root.alpha(Qt.darker(root.color.bg1, 1.0 + gradientDarken), surfaceOpacity)
            readonly property color stroke: root.alpha(root.color.border, strokeOpacity)
            readonly property color shadow: root.alpha(root.color.bg0, shadowOpacity)
        }

        readonly property QtObject glow: QtObject {
            readonly property int radius: 20
            readonly property real spread: 1.7
            readonly property real restOpacity: 0.0
            readonly property real hoverOpacity: 0.3
            readonly property real activeOpacity: 1.0
            readonly property color tint: root.color.accent
        }

        readonly property QtObject reflection: QtObject {
            readonly property real opacity: 0.16
            readonly property real heightRatio: 0.55
            readonly property int gap: 1
        }

        readonly property QtObject blob: QtObject {
            readonly property real squashX: 1.08
            readonly property real squashY: 0.92
            readonly property int morphDuration: 400
        }

        readonly property QtObject ripple: QtObject {
            readonly property real speed: 0.55
            readonly property real width: 0.05
            readonly property real amplitude: 0.55
            readonly property int maxConcurrent: 4
        }

    }
}
