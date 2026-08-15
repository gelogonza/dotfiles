// Password field for the login screen.
//
// Interaction budget, in order of importance:
//   focus    -> the glass corner radius relaxes outward (the standard morph)
//   submit   -> one blob pulse radiating from the field
//   failure  -> shake, plus a pulse tinted with the existing accent
//
// Nothing pulses per keystroke. A ripple on every character is the kind of
// effect that demos well once and is intolerable by the third password.
//
// The failure state introduces NO new hue. It reuses --accent at low opacity,
// which keeps the palette closed; a red would be a fourth colour and a fourth
// accent location.

import QtQuick
import "../Theme"

Item {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder: "Password"
    property bool busy: false

    signal accepted(string password)

    implicitWidth: 320
    implicitHeight: 48

    function pulse() {
        ring.tinted = false;
        ringAnim.restart();
    }

    function fail() {
        input.text = "";
        ring.tinted = true;
        ringAnim.restart();
        shake.restart();
    }

    function focusField() {
        input.forceActiveFocus();
    }

    transform: Translate { id: nudge }

    // --- failure shake ----------------------------------------------------
    // Decaying amplitude. A constant-amplitude shake reads as a broken widget;
    // the decay is what makes it read as a rejection.
    SequentialAnimation {
        id: shake

        NumberAnimation { target: nudge; property: "x"; to:  9; duration: 45 }
        NumberAnimation { target: nudge; property: "x"; to: -8; duration: 60 }
        NumberAnimation { target: nudge; property: "x"; to:  5; duration: 60 }
        NumberAnimation { target: nudge; property: "x"; to: -3; duration: 60 }
        NumberAnimation {
            target: nudge
            property: "x"
            to: 0
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    // --- blob pulse -------------------------------------------------------
    // Expands past the field and fades. Radius is driven independently of scale
    // so the shape stays a soft blob rather than a scaling rectangle.
    Rectangle {
        id: ring

        property bool tinted: false

        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: Tokens.material.glass.radiusPress
        color: "transparent"
        border.width: 1
        border.color: tinted ? Tokens.alpha(Tokens.color.accent, 0.55)
                             : Tokens.alpha(Tokens.color.text1, 0.35)
        opacity: 0
        scale: 1
    }

    ParallelAnimation {
        id: ringAnim

        NumberAnimation {
            target: ring
            property: "scale"
            from: 1.0
            to: 1.12
            duration: Tokens.motion.duration.slow
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
        NumberAnimation {
            target: ring
            property: "radius"
            from: Tokens.material.glass.radiusPress
            to: root.height / 2
            duration: Tokens.motion.duration.slow
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
        SequentialAnimation {
            NumberAnimation {
                target: ring
                property: "opacity"
                from: 0
                to: 1
                duration: Tokens.motion.duration.fast
            }
            NumberAnimation {
                target: ring
                property: "opacity"
                to: 0
                duration: Tokens.motion.duration.slow
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }
    }

    // --- the field --------------------------------------------------------
    Glass {
        id: glass
        anchors.fill: parent
        focused: input.activeFocus

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Tokens.space.lg
            anchors.rightMargin: Tokens.space.lg
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter

            echoMode: TextInput.Password
            passwordCharacter: "•"
            passwordMaskDelay: 0
            enabled: !root.busy

            font.family: Tokens.typography.mono
            font.pixelSize: Tokens.typography.size.title
            color: Tokens.color.text1
            selectionColor: Tokens.alpha(Tokens.color.text1, 0.2)
            selectedTextColor: Tokens.color.text1

            onAccepted: {
                if (text.length > 0)
                    root.accepted(text);
            }

            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0 && !input.activeFocus
                text: root.placeholder
                font.family: Tokens.typography.mono
                font.pixelSize: Tokens.typography.size.body
                color: Tokens.color.text2
            }
        }
    }
}
