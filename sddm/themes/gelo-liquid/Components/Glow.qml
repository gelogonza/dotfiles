// GENERATED FILE — DO NOT EDIT. Source: design/qml/Glow.qml (run design/build-tokens.py)
// Glow — selection, the XMB way.
//
// Nothing gets boxed when it is selected. No outline, no filled pill, no
// background swatch. The selected thing BLOOMS: an accent-tinted, blurred,
// enlarged copy of itself sits behind it and fades up.
//
// This is the single most identifiable trait of the reference, and it is also
// why the accent budget survives — a bloom reads as emphasis without the accent
// ever becoming a fill, so the "accent in exactly three places" rule is about
// where light comes from rather than where paint is applied.
//
// Wrap content directly:
//
//     Glow {
//         amount: isActive ? 1 : 0
//         Text { text: "1" }
//     }

import QtQuick
import QtQuick.Effects
import "../Theme"

Item {
    id: root

    // 0 = no bloom, 1 = full. Animate this, not opacity.
    property real amount: 0

    property color tint: Tokens.material.glow.tint
    property real spread: Tokens.material.glow.spread

    default property alias content: holder.data

    Behavior on amount {
        NumberAnimation {
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    // The bloom is declared FIRST so it paints behind the content. It reads a
    // live copy of the content rather than the content itself, because an item
    // cannot be both the source of an effect and drawn normally.
    MultiEffect {
        source: copy
        anchors.fill: holder
        visible: root.amount > 0.001
        opacity: root.amount
        autoPaddingEnabled: true

        // Kill the copy's own colour so only the coloured halo survives;
        // otherwise the glyph would be drawn twice and go muddy.
        brightness: -1.0

        shadowEnabled: true
        shadowColor: root.tint
        shadowBlur: 1.0
        shadowScale: root.spread
        shadowVerticalOffset: 0
        shadowHorizontalOffset: 0
    }

    ShaderEffectSource {
        id: copy
        sourceItem: holder
        anchors.fill: holder
        visible: false
        hideSource: false
        live: true
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
