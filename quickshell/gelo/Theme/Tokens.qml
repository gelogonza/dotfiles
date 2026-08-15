// GENERATED FILE — DO NOT EDIT. Source: design/tokens.json (run design/build-tokens.py)
pragma Singleton

import QtQuick

QtObject {
    id: root

    // Returns `c` at alpha `a`. The glass material is defined as a base colour
    // plus an opacity, so nearly every surface in the system goes through here.
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property QtObject color: QtObject {
        readonly property color bg0: "#0d0e12"
        readonly property color bg1: "#16181d"
        readonly property color bg2: "#1f222a"
        readonly property color border: "#2a2d36"
        readonly property color text1: "#e8e6e0"
        readonly property color text2: "#8f8d87"
        readonly property color accent: "#d97757"
        readonly property color accentDim: "#a85f45"
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

    readonly property QtObject typography: QtObject {
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property string sans: "Inter"

        readonly property QtObject size: QtObject {
            readonly property int caption: 11
            readonly property int body: 13
            readonly property int title: 15
        }

        readonly property QtObject weight: QtObject {
            readonly property int regular: 400
            readonly property int medium: 500
        }

        readonly property QtObject letterSpacing: QtObject {
            readonly property real tight: -0.2
            readonly property real normal: 0
            readonly property real wide: 0.4
        }
    }

    readonly property QtObject motion: QtObject {
        // Feed straight into `easing.bezierCurve`. QML wants six values:
        // the two control points plus the fixed (1,1) endpoint.
        readonly property var easeBezier: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]

        readonly property QtObject duration: QtObject {
            readonly property int fast: 120
            readonly property int base: 200
            readonly property int slow: 400
        }

        readonly property int stagger: 24
    }

    readonly property QtObject material: QtObject {
        readonly property QtObject glass: QtObject {
            readonly property int blurRadius: 24
            readonly property real backgroundOpacity: 0.68
            readonly property real borderOpacity: 0.55
            readonly property real specularOpacity: 0.09
            readonly property int specularHeight: 1
            readonly property int shadowRadius: 32
            readonly property real shadowOpacity: 0.45
            readonly property int shadowOffsetY: 8
            readonly property int radiusRest: 12
            readonly property int radiusHover: 16
            readonly property int radiusPress: 24

            // Derived surfaces — the actual paintable values components bind to.
            readonly property color background: root.alpha(root.color.bg1, backgroundOpacity)
            readonly property color stroke: root.alpha(root.color.border, borderOpacity)
            readonly property color specular: root.alpha(root.color.text1, specularOpacity)
            readonly property color shadow: root.alpha(root.color.bg0, shadowOpacity)
        }

        readonly property QtObject blob: QtObject {
            readonly property real overshoot: 1.06
            readonly property real squashX: 1.08
            readonly property real squashY: 0.92
            readonly property int morphDuration: 400
        }
    }
}
