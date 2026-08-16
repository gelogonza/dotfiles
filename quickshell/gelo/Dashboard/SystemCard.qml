// CPU / memory / GPU, with the bar the number never had.
//
// A percentage on its own is a number you read; a bar is a shape you glance
// at. That distinction is why these were not worth permanent bar space and
// are worth a card here.

import QtQuick
import "root:/Theme"
import "root:/Components"
import "root:/Services"

Chrome {
    // Floats over whatever window happens to be underneath.
    opaque: true
    id: card
    width: 260
    height: content.implicitHeight + Tokens.space.lg * 2

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.space.lg
        anchors.rightMargin: Tokens.space.lg
        spacing: Tokens.space.sm

        Text {
            text: "system"
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
            color: Tokens.color.text2
        }

        Repeater {
            model: [
                { label: "CPU", value: SysStats.cpu, show: true },
                { label: "MEM", value: SysStats.memory, show: true },
                { label: "GPU", value: SysStats.gpu, show: SysStats.hasGpu }
            ]

            delegate: Item {
                required property var modelData
                width: content.width
                height: modelData.show ? 26 : 0
                visible: modelData.show

                Text {
                    id: lbl
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    font.family: Tokens.typography.display
                    font.pixelSize: Tokens.typography.size.caption
                    color: Tokens.color.text2
                }

                Text {
                    id: pct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.value + "%"
                    font.family: Tokens.typography.display
                    font.pixelSize: Tokens.typography.size.caption
                    font.weight: Tokens.typography.weight.regular
                    color: Tokens.color.text1
                }

                // The track is the hairline; the fill is ink, not accent —
                // accent is spent elsewhere (design.md 3).
                Rectangle {
                    anchors.left: lbl.right
                    anchors.right: pct.left
                    anchors.leftMargin: Tokens.space.sm
                    anchors.rightMargin: Tokens.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Tokens.color.bg2

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, card.valueOf_(parent))) / 100
                        height: parent.height
                        radius: parent.radius
                        color: Tokens.color.text2

                        Behavior on width {
                            NumberAnimation {
                                duration: Tokens.motion.duration.base
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Tokens.motion.easeBezier
                            }
                        }
                    }
                }
            }
        }
    }

    // Reaching the delegate's modelData from a nested Rectangle is noisy; this
    // keeps the binding readable.
    function valueOf_(track) {
        const row = track.parent;
        return row && row.modelData ? row.modelData.value : 0;
    }
}
