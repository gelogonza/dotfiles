//! SOURCE FILE — edit this one. `design/build-tokens.py` copies it into every
//! QML root that needs it, rewriting the Theme import per destination.
//! Lines starting with //! are stripped from the generated copies.
// Reflection — the XMB "icons floating over water" effect.
//
// A flipped, heavily faded copy of the content sits directly beneath it and
// falls off to nothing. It is not a real reflection and does not need to be:
// vertical mirror, low opacity, gradient mask, done.
//
// The mask is the important part. Without it the mirrored copy ends in a hard
// horizontal edge, which reads as a rendering bug rather than as a surface.
//
// Wrap content directly:
//
//     Reflection {
//         Text { text: "1" }
//     }

import QtQuick
import QtQuick.Effects
import "@THEME@"

Item {
    id: root

    property real reflectionOpacity: Tokens.material.reflection.opacity
    property real heightRatio: Tokens.material.reflection.heightRatio
    property int gap: Tokens.material.reflection.gap

    default property alias content: holder.data

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Item {
        id: holder
        anchors.fill: parent
    }

    // A live copy of the content, drawn upside down beneath it.
    ShaderEffectSource {
        id: mirror

        sourceItem: holder
        hideSource: false
        live: true

        width: holder.width
        height: holder.height * root.heightRatio

        anchors.top: holder.bottom
        anchors.topMargin: root.gap
        anchors.horizontalCenter: holder.horizontalCenter

        // Sample the BOTTOM slice of the source — the part sitting at the
        // waterline. Sampling from the top instead reflects whatever empty
        // space is above the glyph, which produces a disconnected fragment
        // floating below the item.
        sourceRect: Qt.rect(0,
                            holder.height * (1.0 - root.heightRatio),
                            holder.width,
                            holder.height * root.heightRatio)

        transform: Scale {
            origin.x: mirror.width / 2
            origin.y: mirror.height / 2
            yScale: -1
        }

        opacity: root.reflectionOpacity
        layer.enabled: true
        layer.effect: MultiEffect {
            // Fade to nothing with distance from the waterline.
            maskEnabled: true
            maskSource: fade
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }
    }

    // Mask gradient. White at the waterline (which, after the flip, is the
    // bottom edge of this rectangle) fading to transparent away from it.
    Item {
        id: fade
        width: mirror.width
        height: mirror.height
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: "white" }
            }
        }
    }
}
