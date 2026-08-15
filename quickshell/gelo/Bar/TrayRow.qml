import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "root:/Theme"
import "root:/Components"

Row {
    id: root

    spacing: Tokens.space.md

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry
            required property var modelData

            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            // TINTED, unlike the app launchers. Tray icons are supplied by
            // whatever application happens to be running and are frequently
            // white — which on this light bar renders them completely
            // invisible. Flattening them to the ink colour costs their brand
            // colour and guarantees they can be seen, which for a status tray
            // is the right trade.
            Icon {
                anchors.fill: parent
                source: entry.modelData.icon
                size: 16
                tinted: true
                color: mouse.containsMouse ? Tokens.color.text1 : Tokens.color.text2

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.motion.duration.fast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.motion.easeBezier
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.RightButton)
                        entry.modelData.secondaryActivate();
                    else
                        entry.modelData.activate();
                }
            }
        }
    }
}
