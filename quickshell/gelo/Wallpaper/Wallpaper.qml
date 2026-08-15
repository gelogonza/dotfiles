// Desktop wallpaper — the XMB wave field, and the surface every interaction
// ripple propagates through.
//
// This is not decoration. In this design language the UI elements never deform;
// all interaction motion lives here, behind them. Switching a workspace or
// opening the launcher fires a ripple into this shader.
//
// It runs all day, so it is slower than the login variant.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/Theme"
import "root:/Services"

PanelWindow {
    id: wallpaper

    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: Tokens.color.bg0

    WlrLayershell.namespace: "gelo-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    ShaderEffect {
        id: field

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("root:/Shaders/xmb.frag.qsb")
        blending: false

        // NOTE: this only tracks whether the surface exists, NOT whether it is
        // occluded — wlr-layer-shell exposes no occlusion signal, so a maximised
        // window on top does not stop the shader. If that ever matters (laptop
        // battery, thermals), swap this file for a static image rather than
        // micro-optimising the GLSL.
        visible: wallpaper.visible

        property real time: 0
        property vector2d resolution: Qt.vector2d(width, height)

        // The wave field has its own ramp, separate from the UI surface
        // tokens, so it can stay more saturated than the chrome on top of it.
        property vector4d colorBase: toVec(Tokens.color.fieldBase)
        property vector4d colorMid: toVec(Tokens.color.fieldMid)
        property vector4d colorHigh: toVec(Tokens.color.fieldHigh)
        property vector4d colorEdge: toVec(Tokens.color.fieldEdge)
        property vector4d colorLine: toVec(Tokens.color.fieldLine)
        property vector4d colorAccent: toVec(Tokens.color.accent)

        property real rippleSpeed: Tokens.material.ripple.speed
        property real rippleWidth: Tokens.material.ripple.width
        property real rippleAmplitude: Tokens.material.ripple.amplitude

        // One property per shader uniform, matched by name. xy = origin,
        // z = birth time on the same clock as `time`.
        property vector4d rippleA: slot(0)
        property vector4d rippleB: slot(1)
        property vector4d rippleC: slot(2)
        property vector4d rippleD: slot(3)

        function slot(i) {
            const s = Ripples.slots;
            if (!s || i >= s.length)
                return Qt.vector4d(0, 0, -1000, 0);
            return Qt.vector4d(s[i].x, s[i].y, s[i].t, 0);
        }

        function toVec(c) {
            return Qt.vector4d(c.r, c.g, c.b, c.a);
        }

        // 900 units/hour = 0.25 units/sec, still under the login screen's 0.28.
        // This is ambient behind real work rather than something you sit and
        // look at, but at 0.16 it read as a still image unless you stared.
        NumberAnimation on time {
            from: 0
            to: 900
            duration: 3600000
            loops: Animation.Infinite
            running: field.visible
        }

        // Ripple ages are measured against this same clock, so a ripple stays
        // in phase with the field it is bending.
        onTimeChanged: Ripples.now = time
    }
}
