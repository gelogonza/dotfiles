// CPU / MEM / GPU readout.
//
// Label + value rather than a bar or a dial: at 11px a graph is decoration, and
// the only question this answers in passing is "is something eating the
// machine". The value goes accent-adjacent only when it crosses a threshold
// worth looking at, so a healthy system is quiet.

import QtQuick
import "root:/Theme"
import "root:/Services"

Row {
    id: root

    spacing: Tokens.space.md

    component Stat: Row {
        required property string label
        required property int value

        spacing: Tokens.space.xs
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
            color: Tokens.color.text2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Fixed width so the row does not jitter as digits change.
            width: 26
            horizontalAlignment: Text.AlignRight
            text: parent.value + "%"
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            color: parent.value >= 85 ? Tokens.color.accentDim : Tokens.color.text1

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.duration.base
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.motion.easeBezier
                }
            }
        }
    }

    Stat {
        label: "CPU"
        value: SysStats.cpu
    }

    Stat {
        label: "MEM"
        value: SysStats.memory
    }

    Stat {
        label: "GPU"
        value: SysStats.gpu
        visible: SysStats.hasGpu
    }
}
