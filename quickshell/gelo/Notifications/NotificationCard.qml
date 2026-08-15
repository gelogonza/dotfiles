import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "root:/Theme"
import "root:/Components"
import "root:/Services"

Item {
    id: root

    required property var notif
    property var window: null

    // Horizontal travel past which a release dismisses instead of springing back.
    readonly property int dismissThreshold: 96

    signal dismissed()

    width: 380
    height: content.implicitHeight + Tokens.space.lg * 2

    // Entrance/exit progress, kept separate from `opacity` so the drag fade can
    // multiply into it without the two forming a binding loop.
    property real revealed: 0

    // --- entrance ---------------------------------------------------------
    // Slides in from the right edge it is anchored to, so it reads as arriving
    // from off-screen rather than materialising in place.
    x: width

    // Drag feedback is continuous rather than binary at the threshold.
    opacity: revealed * Math.max(0.25, 1 - Math.abs(x) / (dismissThreshold * 2))

    Component.onCompleted: {
        enter.start();
        Ripples.emitFromItem(root, root.window);
    }

    ParallelAnimation {
        id: enter
        NumberAnimation {
            target: root; property: "x"; to: 0
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
        NumberAnimation {
            target: root; property: "revealed"; to: 1
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    // --- dismissal --------------------------------------------------------
    // Slides out and fades. No squash: in this language elements do not deform
    // — the card fires a ripple into the wallpaper behind it instead, and that
    // is where the physicality lives.
    SequentialAnimation {
        id: exit

        ParallelAnimation {
            NumberAnimation {
                target: root; property: "x"; to: root.width + Tokens.space.xxl
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
            NumberAnimation {
                target: root; property: "revealed"; to: 0
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
            NumberAnimation {
                target: root; property: "height"; to: 0
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        ScriptAction {
            script: {
                Ripples.emitFromItem(root, root.window);
                if (root.notif)
                    root.notif.dismiss();
                root.dismissed();
            }
        }
    }

    function dismiss() {
        if (!exit.running)
            exit.start();
    }

    // Spring back when a drag is released short of the threshold.
    SpringAnimation {
        id: springBack
        target: root
        property: "x"
        to: 0
        spring: 3.5
        damping: 0.35
        epsilon: 0.5
    }

    Chrome {
        anchors.fill: parent
        // Urgent notifications sit slightly proud of the others.
        cornerRadius: root.notif && root.notif.urgency === NotificationUrgency.Critical
            ? Tokens.material.chrome.radius
            : Tokens.material.chrome.radius

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.space.lg
            anchors.rightMargin: Tokens.space.lg
            spacing: Tokens.space.xs

            Text {
                width: parent.width
                text: root.notif ? root.notif.appName : ""
                visible: text.length > 0
                elide: Text.ElideRight
                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.caption
                font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
                color: Tokens.color.text2
            }

            Text {
                width: parent.width
                text: root.notif ? root.notif.summary : ""
                visible: text.length > 0
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.body
                font.weight: Tokens.typography.weight.regular
                color: Tokens.color.text1
            }

            Text {
                width: parent.width
                text: root.notif ? root.notif.body : ""
                visible: text.length > 0
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                textFormat: Text.PlainText
                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.caption
                color: Tokens.color.text2
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        drag.target: root
        drag.axis: Drag.XAxis
        drag.minimumX: -root.width
        drag.maximumX: root.width

        onReleased: {
            if (Math.abs(root.x) > root.dismissThreshold)
                root.dismiss();
            else
                springBack.restart();
        }

        onClicked: root.dismiss()
    }
}
