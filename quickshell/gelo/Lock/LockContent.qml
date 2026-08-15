// The lock screen's visuals and input, extracted from the lock itself.
//
// Used in two places:
//   - inside WlSessionLockSurface, where it is the real lock
//   - inside a normal overlay window, so the appearance can be checked without
//     engaging the compositor's session lock
//
// That split exists specifically so nobody has to lock a live session to find
// out whether the layout is right. `controller` is the Lock root: it owns the
// password buffer, the status text and the PAM transaction.

import Quickshell
import QtQuick
import "root:/Theme"
import "root:/Components"

Item {
    id: content

    required property var controller

    // True in preview, so the field does not fight the real desktop for focus.
    property bool preview: false

    // --- shader background ------------------------------------------------
    ShaderEffect {
        id: field

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("root:/Shaders/xmb.frag.qsb")
        blending: false

        property real time: 0
        property vector2d resolution: Qt.vector2d(width, height)

        property vector4d colorBase: toVec(Tokens.color.fieldBase)
        property vector4d colorMid: toVec(Tokens.color.fieldMid)
        property vector4d colorHigh: toVec(Tokens.color.fieldHigh)
        property vector4d colorEdge: toVec(Tokens.color.fieldEdge)
        property vector4d colorLine: toVec(Tokens.color.fieldLine)
        property vector4d colorAccent: toVec(Tokens.color.accent)

        property real rippleSpeed: Tokens.material.ripple.speed
        property real rippleWidth: Tokens.material.ripple.width
        property real rippleAmplitude: Tokens.material.ripple.amplitude

        // A rejected password ripples the field from behind the input. The
        // element itself only shakes — motion belongs to the field.
        property vector4d rippleA: Qt.vector4d(0.5, 0.58, -1000, 0)
        property vector4d rippleB: Qt.vector4d(0, 0, -1000, 0)
        property vector4d rippleC: Qt.vector4d(0, 0, -1000, 0)
        property vector4d rippleD: Qt.vector4d(0, 0, -1000, 0)

        function toVec(c) {
            return Qt.vector4d(c.r, c.g, c.b, c.a);
        }

        function ripple() {
            rippleA = Qt.vector4d(0.5, 0.58, time, 0);
        }

        // 0.28 units/sec, same as the login screen. The lock is looked at while
        // typing, so it runs at the greeter's rate rather than the slower
        // desktop wallpaper.
        NumberAnimation on time {
            from: 0
            to: 1008
            duration: 3600000
            loops: Animation.Infinite
            running: true
        }
    }

    Connections {
        target: content.controller
        function onFailedChanged() {
            if (content.controller.failed) {
                field.ripple();
                shake.restart();
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // --- clock ------------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.24
        spacing: Tokens.space.sm

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Tokens.typography.display
            font.pixelSize: 84
            font.weight: Tokens.typography.weight.light
            font.letterSpacing: -2
            color: Tokens.color.text1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.title
            font.weight: Tokens.typography.weight.light
            font.letterSpacing: Tokens.tracking(Tokens.typography.size.title)
            color: Tokens.color.text2
        }
    }

    // --- password ---------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.54
        spacing: Tokens.space.lg

        Item {
            id: fieldWrap
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 48

            transform: Translate { id: nudge }

            // Decaying shake. Constant amplitude reads as a broken widget; the
            // decay reads as a rejection.
            SequentialAnimation {
                id: shake
                NumberAnimation { target: nudge; property: "x"; to: 9; duration: 45 }
                NumberAnimation { target: nudge; property: "x"; to: -8; duration: 60 }
                NumberAnimation { target: nudge; property: "x"; to: 5; duration: 60 }
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

            Chrome {
                anchors.fill: parent

                // In preview the field must not steal keyboard focus from the
                // desktop, but focused is the state the real lock is always in
                // — so show that appearance regardless, or the preview is not
                // showing you what you are actually going to look at.
                focused: content.preview || input.activeFocus

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
                    enabled: !content.controller.busy

                    font.family: Tokens.typography.display
                    font.pixelSize: Tokens.typography.size.title
                    color: Tokens.color.text1

                    // The buffer lives on the controller, so every screen's
                    // surface shares one password regardless of which display
                    // was typed into.
                    text: content.controller.password
                    onTextChanged: content.controller.password = text

                    onAccepted: content.controller.authenticate()

                    // The real lock owns all input; the preview must not steal
                    // focus from the desktop.
                    focus: !content.preview

                    Text {
                        anchors.centerIn: parent
                        visible: input.text.length === 0 && !content.controller.busy
                        text: content.preview ? "Password (preview)" : "Password"
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.body
                        color: Tokens.color.text2
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: content.controller.busy ? "Checking…" : content.controller.status
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
            color: Tokens.color.text2
            opacity: text.length > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.base
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.motion.easeBezier
                }
            }
        }
    }

    function focusInput() {
        input.forceActiveFocus();
    }
}
