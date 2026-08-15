// GENERATED FILE — DO NOT EDIT. Source: design/qml/Glow.qml (run design/build-tokens.py)
// Glow — selection, the XMB way.
//
// Nothing gets boxed when it is selected. No outline, no filled pill, no
// background swatch. The selected thing BLOOMS.
//
// This is the single most identifiable trait of the reference, and it is also
// why the accent budget survives: a bloom reads as emphasis without the accent
// ever becoming a fill, so "accent in exactly three places" stays a rule about
// where light comes from rather than where paint is applied.
//
// IMPLEMENTATION NOTE — why this is stacked rings rather than a blur.
//
// The obvious build is MultiEffect over a ShaderEffectSource copy. Two ways
// that went wrong, both found on the light palette:
//
//   1. As a coloured drop shadow it needs `brightness: -1` to suppress the
//      copy's own colour, and MultiEffect still paints that blackened copy over
//      the halo — invisible on a dark surface, a hard black box on a light one.
//   2. As a colourised blur it samples the transparent-black surround, so the
//      halo picks up dark fringing. Measured: the ring came out (107,128,151)
//      grey-blue instead of the accent (52,120,196).
//
// Concentric rounded rects at falling opacity have neither problem, cost no
// render target, and land identically on light or dark. The trade is that the
// bloom takes the content's bounding shape rather than its silhouette — which
// is exactly right for everything this wraps.

import QtQuick
import "root:/Theme"

Item {
    id: root

    // 0 = no bloom, 1 = full. Animate this, not opacity.
    property real amount: 0

    property color tint: Tokens.material.glow.tint
    property real spread: Tokens.material.glow.spread

    // Corner radius of the halo rings. Defaults to a pill/disc.
    property real cornerRadius: Math.min(width, height) / 2

    default property alias content: holder.data

    Behavior on amount {
        NumberAnimation {
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    // Halo rings, outermost and faintest first so they stack outward-in and the
    // content lands on top.
    Repeater {
        model: 5

        delegate: Rectangle {
            required property int index

            // k = 1 at the outermost ring, approaching 0 at the innermost.
            readonly property real k: (5 - index) / 5

            anchors.centerIn: parent
            width: root.width * (1 + (root.spread - 1) * k)
            height: root.height * (1 + (root.spread - 1) * k)
            radius: root.cornerRadius * (1 + (root.spread - 1) * k)

            color: root.tint
            // Quadratic falloff approximates a gaussian closely enough at this
            // size, and keeps the innermost ring from reading as a solid fill.
            opacity: root.amount * 0.34 * (1.0 - k) * (1.0 - k)
            visible: root.amount > 0.001
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
