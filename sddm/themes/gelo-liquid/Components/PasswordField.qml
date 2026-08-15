// Password field for the login screen.
//
// Interaction budget, in order of importance:
//   focus    -> the field glows (Chrome handles it)
//   submit   -> a ripple propagates outward through the background shader
//   failure  -> shake, plus another ripple
//
// The element itself never deforms — no pulse ring, no morphing border. Motion
// belongs to the field behind the UI. Main.qml owns the ripple because it owns
// the shader; this component only reports what happened.
//
// Nothing fires per keystroke. A ripple on every character is the kind of
// effect that demos well once and is intolerable by the third password.
//
// The palette contains no warm hue at all, so failure is conveyed by the shake
// and by the accent at low opacity — never by a red.

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

    function fail() {
        input.text = "";
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

    // --- the field --------------------------------------------------------
    Chrome {
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

            font.family: Tokens.typography.display
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
                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.body
                color: Tokens.color.text2
            }
        }
    }
}
