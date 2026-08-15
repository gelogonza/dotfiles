// Desktop wallpaper — the same fluid field as the login screen, on the
// background layer.
//
// Two reasons this is worth running instead of a static image:
//
//   1. The bar and launcher get their frost from the compositor blurring
//      whatever is behind them. Against a near-black PNG there is nothing to
//      refract and the glass material reads as flat paint. A moving field gives
//      every glass surface in the system something to be glass *about*.
//   2. It is the same shader as the login screen, so the desktop is visibly
//      continuous with the thing you just logged in through.
//
// It runs all day, so it is deliberately slower and dimmer than the login
// variant, and it stops entirely when it cannot be seen.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/Theme"

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
        fragmentShader: Qt.resolvedUrl("root:/Shaders/fluid.frag.qsb")
        blending: false

        // NOTE: this only tracks whether the surface exists, NOT whether it is
        // occluded — wlr-layer-shell exposes no occlusion signal, so a maximised
        // window on top does not stop the shader. A fullscreen fragment shader
        // per monitor running behind opaque windows is the real cost of this
        // component; if that ever matters (laptop battery, thermals), the fix is
        // to swap this file for a static image, not to micro-optimise the GLSL.
        visible: wallpaper.visible

        property real time: 0
        property vector2d resolution: Qt.vector2d(width, height)

        property vector4d colorBase: toVec(Tokens.color.bg0)
        property vector4d colorMid: toVec(Tokens.color.bg1)
        property vector4d colorHigh: toVec(Tokens.color.bg2)
        property vector4d colorEdge: toVec(Tokens.color.border)
        property vector4d colorAccent: toVec(Tokens.color.accentDim)

        function toVec(c) {
            return Qt.vector4d(c.r, c.g, c.b, c.a);
        }

        // 576 units/hour = 0.16 units/sec — slower than the login screen's 0.28.
        // This one is ambient behind real work rather than something you sit and
        // look at, so it should stay under the threshold of noticing.
        NumberAnimation on time {
            from: 0
            to: 576
            duration: 3600000
            loops: Animation.Infinite
            running: field.visible
        }
    }
}
