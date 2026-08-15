// GENERATED FILE — DO NOT EDIT. Source: design/qml/Chrome.qml (run design/build-tokens.py)
// Chrome — the single material every surface in this system is made of.
//
// PS3 XMB material language: brushed metal, glow, reflection. Explicitly NOT
// frosted glass. There is no backdrop blur anywhere in this system and the
// compositor layerrules that used to produce it have been removed.
//
// Three rules:
//
//   1. A subtle vertical gradient, bg-1 at the top fading a few percent darker
//      at the bottom. Enough to read as material, not enough to read as a
//      gradient. That is the whole trick — a flat fill reads as paint, and an
//      obvious gradient reads as 2000s web design.
//   2. Selection is GLOW, not outline and not fill. Nothing gets boxed when it
//      is focused; it blooms. The bloom is a blurred, scaled, accent-tinted
//      copy of the surface sitting behind it.
//   3. Depth from a soft shadow underneath.
//
// The corner radius does NOT change on interaction. That was the glass
// affordance; here the affordance is the glow, and the ripple it fires into the
// wallpaper behind it.

import QtQuick
import QtQuick.Effects
import "../Theme"

Item {
    id: root

    // --- interaction state ------------------------------------------------
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool interactive: false

    // --- material overrides ----------------------------------------------
    property bool glowEnabled: true
    property bool shadowEnabled: true
    property real cornerRadius: Tokens.material.chrome.radius

    // Glow rides interaction state. Rest is fully transparent — an always-on
    // bloom stops meaning "this one".
    property real glowOpacity: focused || pressed ? Tokens.material.glow.activeOpacity
                             : hovered ? Tokens.material.glow.hoverOpacity
                                       : Tokens.material.glow.restOpacity

    // No Behavior here: Glow animates `amount` internally, and easing the same
    // transition twice makes focus feel laggy.

    default property alias content: contentItem.data

    signal clicked()

    // --- the surface ------------------------------------------------------
    // Rendered by the effects below rather than directly; drawing it here too
    // would double the fill.
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.cornerRadius
        visible: false
        layer.enabled: true

        border.width: 1
        border.color: Tokens.material.chrome.stroke

        // Brushed metal. Two stops only — a three-stop gradient starts to read
        // as a highlight, which is a different material.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Tokens.material.chrome.surfaceTop }
            GradientStop { position: 1.0; color: Tokens.material.chrome.surfaceBottom }
        }
    }

    // --- glow -------------------------------------------------------------
    // Delegated to Glow rather than reimplemented. Same directory, so no import
    // is needed, and it means a focused Chrome surface and a selected launcher
    // row bloom identically.
    //
    // This used to be a colourised MultiEffect blur, which samples the
    // transparent-black surround and fringed the halo grey on a light
    // background — the same failure documented in Glow.qml.
    Glow {
        anchors.fill: parent
        visible: root.glowEnabled
        amount: root.glowEnabled ? root.glowOpacity : 0
        cornerRadius: root.cornerRadius
    }

    // --- surface + depth shadow -------------------------------------------
    MultiEffect {
        source: surface
        anchors.fill: surface
        autoPaddingEnabled: true

        shadowEnabled: root.shadowEnabled
        shadowColor: Tokens.material.chrome.shadow
        shadowBlur: 1.0
        shadowVerticalOffset: Tokens.material.chrome.shadowOffsetY
        shadowHorizontalOffset: 0
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
