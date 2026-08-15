// gelo-liquid — SDDM login theme.
//
// The one surface in the system that gets a real GLSL shader background. This
// is the right place to spend that budget: it is the first thing seen, it is
// looked at while idle, and unlike the lock screen it is not on the critical
// path back into a running session.
//
// Type is sans here (Inter) and mono everywhere else — the login screen is the
// only place the design system permits it, which is what makes it feel like a
// different surface rather than a big widget.

import QtQuick
import "Components"
import "Theme"

Rectangle {
    id: root

    color: Tokens.color.bg0

    property string currentUser: {
        if (typeof userModel === "undefined" || !userModel)
            return "";
        return userModel.lastUser || "";
    }

    property int sessionIndex: {
        if (typeof sessionModel === "undefined" || !sessionModel)
            return 0;
        return sessionModel.lastIndex || 0;
    }

    property bool busy: false

    // --- shader background ------------------------------------------------
    ShaderEffect {
        id: background
        anchors.fill: parent

        // Baked with design/build-shaders.sh; Qt 6 will not take raw GLSL.
        fragmentShader: Qt.resolvedUrl("Shaders/fluid.frag.qsb")
        blending: false

        property real time: 0
        property vector2d resolution: Qt.vector2d(width, height)

        property vector4d colorBase: toVec(Tokens.color.bg0)
        property vector4d colorMid: toVec(Tokens.color.bg1)
        property vector4d colorHigh: toVec(Tokens.color.bg2)
        property vector4d colorEdge: toVec(Tokens.color.border)
        property vector4d colorAccent: toVec(Tokens.color.accentDim)

        function toVec(c) {
            return Qt.vector4d(c.r, c.g, c.b, c.a);
        }

        // The shader takes `time` pre-scaled, so the rate lives here: 1008 units
        // over an hour is 0.28 units/sec. Slower than this and the motion
        // quantises away against the dark palette (see docs/login-screen.md).
        NumberAnimation on time {
            from: 0
            to: 1008
            duration: 3600000
            loops: Animation.Infinite
            running: true
        }
    }

    // --- clock ------------------------------------------------------------
    Column {
        id: clockBlock

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        spacing: Tokens.space.sm

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.now, "HH:mm")
            font.family: Tokens.typography.sans
            font.pixelSize: 84
            font.weight: Tokens.typography.weight.regular
            // Tight tracking at display size; the default spacing looks loose
            // once type gets this large.
            font.letterSpacing: -2
            color: Tokens.color.text1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.now, "dddd, d MMMM")
            font.family: Tokens.typography.sans
            font.pixelSize: Tokens.typography.size.title
            font.weight: Tokens.typography.weight.regular
            font.letterSpacing: Tokens.typography.letterSpacing.wide
            color: Tokens.color.text2
        }
    }

    QtObject {
        id: clock
        property var now: new Date()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    // --- login ------------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.52
        spacing: Tokens.space.lg

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentUser
            visible: text.length > 0
            font.family: Tokens.typography.sans
            font.pixelSize: Tokens.typography.size.title
            font.weight: Tokens.typography.weight.medium
            color: Tokens.color.text1
        }

        PasswordField {
            id: password
            anchors.horizontalCenter: parent.horizontalCenter
            busy: root.busy

            onAccepted: pw => {
                root.busy = true;
                pulse();
                if (typeof sddm !== "undefined" && sddm)
                    sddm.login(root.currentUser, pw, root.sessionIndex);
            }
        }

        Text {
            id: hint
            anchors.horizontalCenter: parent.horizontalCenter
            text: " "
            font.family: Tokens.typography.mono
            font.pixelSize: Tokens.typography.size.caption
            color: Tokens.color.text2
            opacity: text.trim().length > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.base
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.motion.easeBezier
                }
            }
        }
    }

    Component.onCompleted: password.focusField()

    // --- sddm signals -----------------------------------------------------
    Connections {
        // `sddm` does not exist when the theme is opened outside the greeter
        // (e.g. a plain qml preview), so bind defensively.
        target: typeof sddm !== "undefined" ? sddm : null
        ignoreUnknownSignals: true

        function onLoginSucceeded() {
            root.busy = false;
            hint.text = " ";
        }

        function onLoginFailed() {
            root.busy = false;
            hint.text = "Incorrect password";
            password.fail();
            password.focusField();
        }
    }
}
