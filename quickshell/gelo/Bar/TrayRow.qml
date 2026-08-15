import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import "root:/Theme"

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

            IconImage {
                id: icon
                anchors.fill: parent
                source: entry.modelData.icon
                // Tray icons are third-party artwork and the only place in the
                // system with colour outside the palette. Desaturating toward
                // the text tone keeps them from fighting the accent.
                opacity: mouse.containsMouse ? 1.0 : 0.75

                Behavior on opacity {
                    NumberAnimation {
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
