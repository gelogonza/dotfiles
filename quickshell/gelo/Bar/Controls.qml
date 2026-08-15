// Volume, Bluetooth and power.
//
// The volume slider is always visible rather than hidden behind a popup. It is
// the one control here that gets adjusted rather than merely toggled, and a
// 56px track costs less bar space than the interaction of opening something.
//
// Volume interaction, in full:
//   click        -> open pavucontrol (per-app volumes, device switching)
//   drag         -> set the level directly
//   scroll       -> nudge the level
//   right click  -> mute
//
// Click and drag share the same mouse area, so they are told apart by movement:
// a press and release that never moved more than a few pixels is a click, and
// anything further is a drag. Without that, every drag would also fire the
// click handler on release and open a window you did not ask for.

import QtQuick
import Quickshell
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
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.RightButton)
                        Audio.toggleMute();
                    else
                        Audio.openMixer();
                }

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
                id: sliderMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                // Movement past this many pixels turns a press into a drag.
                readonly property int dragThreshold: 3
                property real pressX: 0
                property bool dragging: false

                onPressed: mouseEvent => {
                    pressX = mouseEvent.x;
                    dragging = false;
                }

                onPositionChanged: mouseEvent => {
                    if (!pressed)
                        return;
                    if (!dragging && Math.abs(mouseEvent.x - pressX) > dragThreshold)
                        dragging = true;
                    if (dragging)
                        Audio.setVolume(mouseEvent.x / width);
                }

                onReleased: mouseEvent => {
                    if (dragging)
                        return;                       // it was a drag; already applied
                    if (mouseEvent.button === Qt.RightButton)
                        Audio.toggleMute();
                    else
                        Audio.openMixer();
                }

                onWheel: wheel => Audio.adjust(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }
    }

    // --- bluetooth --------------------------------------------------------
    //   click        -> open blueman
    //   right click  -> disconnect every connected device
    //
    // Hidden entirely when the machine has no controller, rather than shown as
    // a dead icon.
    Icon {
        id: bt
        anchors.verticalCenter: parent.verticalCenter
        size: 16

        visible: Bluetooth.present
        source: Bluetooth.icon

        // Three states, and only two colours: something is connected (full
        // ink), the radio is on but idle, or it is off (receded). Accent is not
        // available here — it is spent elsewhere.
        color: Bluetooth.connected > 0 ? Tokens.color.text1
             : Bluetooth.powered ? Tokens.color.text2
                                 : Tokens.alpha(Tokens.color.text2, 0.5)

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.fast
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouseEvent => {
                if (mouseEvent.button === Qt.RightButton)
                    Bluetooth.disconnectAll();
                else
                    Bluetooth.openManager();
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
