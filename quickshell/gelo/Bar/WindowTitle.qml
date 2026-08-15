import Quickshell
import Quickshell.Hyprland
import QtQuick
import "root:/Theme"

Text {
    id: root

    readonly property var toplevel: Hyprland.activeToplevel

    text: toplevel && toplevel.title ? toplevel.title : ""
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter

    font.family: Tokens.typography.mono
    font.pixelSize: Tokens.typography.size.caption
    font.weight: Tokens.typography.weight.regular
    color: Tokens.color.text2

    // The title changes constantly (browser tabs, editor buffers). A hard swap
    // is visually noisy in peripheral vision; a short fade is not.
    Behavior on text {
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0
                duration: Tokens.motion.duration.fast / 2
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
            PropertyAction {}
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: Tokens.motion.duration.fast
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }
    }
}
