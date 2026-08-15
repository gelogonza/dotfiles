// Volume, Bluetooth and power.
//
// The volume slider is always visible rather than hidden behind a popup. It is
// the one control here that gets adjusted rather than merely toggled, and a
// 56px track costs less bar space than the interaction of opening something.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "root:/Theme"
import "root:/Components"
import "root:/Services"

Row {
    id: root

    spacing: Tokens.space.md

    // --- volume -----------------------------------------------------------
    Row {
        spacing: Tokens.space.sm
        anchors.verticalCenter: parent.verticalCenter

        Icon {
            id: volIcon
            anchors.verticalCenter: parent.verticalCenter
            source: Audio.icon
            size: 16
            color: Audio.muted ? Tokens.color.text2 : Tokens.color.text1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: Audio.toggleMute()
                onWheel: wheel => Audio.adjust(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }

        Item {
            id: slider
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 16

            readonly property real fraction: Audio.muted ? 0 : Audio.volume

            // Track
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 3
                radius: 1.5
                color: Tokens.alpha(Tokens.color.text2, 0.35)
            }

            // Fill — accent is NOT permitted here, so level is carried by the
            // ink colour instead.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * slider.fraction
                height: 3
                radius: 1.5
                color: Tokens.color.text1

                Behavior on width {
                    NumberAnimation {
                        duration: Tokens.motion.duration.fast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.motion.easeBezier
                    }
                }
            }

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Tokens.color.text1
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width,
                                        parent.width * slider.fraction - width / 2))
                visible: !Audio.muted

                Behavior on x {
                    NumberAnimation {
                        duration: Tokens.motion.duration.fast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.motion.easeBezier
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => Audio.setVolume(mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        Audio.setVolume(mouse.x / width);
                }
                onWheel: wheel => Audio.adjust(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }
    }

    // --- bluetooth --------------------------------------------------------
    Icon {
        id: bt
        anchors.verticalCenter: parent.verticalCenter
        size: 16

        // defaultAdapter can be null briefly at startup and permanently on a
        // machine with no radio, so fall back to the first adapter and hide the
        // control entirely when there is none.
        readonly property var adapter: Bluetooth.defaultAdapter
            || (Bluetooth.adapters && Bluetooth.adapters.values.length > 0
                ? Bluetooth.adapters.values[0]
                : null)

        readonly property bool on: adapter ? adapter.enabled : false

        visible: adapter !== null
        source: on ? "bluetooth-on" : "bluetooth-off"
        color: on ? Tokens.color.text1 : Tokens.color.text2

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (bt.adapter)
                    bt.adapter.enabled = !bt.adapter.enabled;
            }
        }
    }

    // --- power ------------------------------------------------------------
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        size: 16
        source: "power"
        color: Ui.powerMenuOpen ? Tokens.color.text1 : Tokens.color.text2

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Ui.powerMenuOpen = !Ui.powerMenuOpen
        }
    }
}
