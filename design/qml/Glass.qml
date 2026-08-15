//! SOURCE FILE — edit this one. `design/build-tokens.py` copies it into every
//! QML root that needs it, rewriting the Theme import per destination.
//! Lines starting with //! are stripped from the generated copies.
// Liquid glass — the single material every surface in this system is made of.
//
// Three rules, applied identically to the bar, launcher, notification cards and
// login field:
//
//   1. Depth comes from a soft, large-radius, low-opacity SHADOW. Never from a
//      gradient "shine". That is the difference between Apple and Windows Aero.
//   2. A 1px specular highlight rides the top edge only, brightest at centre and
//      fading toward the corners — light catching a curved edge, not a bevel.
//   3. On interaction the corner radius RELAXES OUTWARD instead of snapping to a
//      hover state. The morph is the affordance.
//
// The actual backdrop blur is NOT done here. Qt cannot sample what is behind a
// Wayland surface. It comes from Hyprland compositing the layer:
//     layerrule = blur, <namespace>
// which is why every window using this material declares a blurred namespace.

import QtQuick
import QtQuick.Effects
import "@THEME@"

Item {
    id: root

    // --- interaction state ------------------------------------------------
    // Set these from the parent, or flip `interactive` to have Glass track them.
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool interactive: false

    // --- material overrides ----------------------------------------------
    property color tint: Tokens.material.glass.background
    property color strokeColor: Tokens.material.glass.stroke
    property bool specularEnabled: true
    property bool shadowEnabled: true

    // Corner radius relaxes outward through the interaction states. The slow
    // duration is what makes it read as liquid rather than as a hover flicker.
    property real cornerRadius: pressed ? Tokens.material.glass.radiusPress
                              : focused ? Tokens.material.glass.radiusPress
                              : hovered ? Tokens.material.glass.radiusHover
                                        : Tokens.material.glass.radiusRest

    Behavior on cornerRadius {
        NumberAnimation {
            duration: Tokens.motion.duration.slow
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    // Anything declared inside a Glass lands here, above the material.
    default property alias content: contentItem.data

    signal clicked()

    // --- the surface itself ----------------------------------------------
    // visible:false because MultiEffect below is what actually rasterises it;
    // drawing both would double the fill and darken the translucency.
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.tint
        visible: false
        layer.enabled: true

        border.width: 1
        border.color: root.strokeColor
    }

    MultiEffect {
        source: surface
        anchors.fill: surface
        // Lets the shadow paint outside the item bounds instead of being clipped.
        autoPaddingEnabled: true

        shadowEnabled: root.shadowEnabled
        shadowBlur: 1.0
        shadowColor: Tokens.material.glass.shadow
        shadowVerticalOffset: Tokens.material.glass.shadowOffsetY
        shadowHorizontalOffset: 0
    }

    // --- specular edge ----------------------------------------------------
    // Inset horizontally by the corner radius so the highlight stops where the
    // curve begins, rather than running flat across a rounded corner.
    Rectangle {
        id: specular
        visible: root.specularEnabled
        height: Tokens.material.glass.specularHeight
        y: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - root.cornerRadius * 2)

        // Held near-full across the span and faded only at the very ends. A
        // centre-peaked gradient works on a small card but disappears on a
        // 2500px-wide bar, where every visible pixel is far from the peak.
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.08; color: Tokens.material.glass.specular }
            GradientStop { position: 0.92; color: Tokens.material.glass.specular }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        visible: root.interactive
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        onCanceled: root.pressed = false
        onClicked: root.clicked()
    }
}
