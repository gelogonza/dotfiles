import Quickshell
import Quickshell.Widgets
import QtQuick
import "root:/Theme"

Item {
    id: root

    property var app: null
    property int rowIndex: 0
    property bool selected: false
    property bool staggered: false

    signal activated()
    signal hovered()

    height: 40

    // Entrance: fade up from slightly below, offset by row position so the list
    // arrives as a cascade rather than a block. Runs once, on creation.
    opacity: 0
    transform: Translate { id: lift; y: 8 }

    Component.onCompleted: entrance.start()

    SequentialAnimation {
        id: entrance

        PauseAnimation {
            duration: root.staggered ? root.rowIndex * Tokens.motion.stagger : 0
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
            NumberAnimation {
                target: lift
                property: "y"
                to: 0
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }
    }

    // Selection is carried by a raised surface, not by accent — accent is spent
    // on the workspace indicator, the window border and the cursor.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.sm
        anchors.rightMargin: Tokens.space.sm
        radius: root.selected ? Tokens.material.glass.radiusHover
                              : Tokens.material.glass.radiusRest
        color: root.selected ? Tokens.alpha(Tokens.color.bg2, 0.9) : "transparent"

        Behavior on radius {
            NumberAnimation {
                duration: Tokens.motion.duration.slow
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.fast
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }
    }

    IconImage {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Tokens.space.lg
        implicitSize: 20
        source: root.app && root.app.icon
            ? Quickshell.iconPath(root.app.icon, true)
            : ""
        opacity: root.selected ? 1.0 : 0.8
    }

    Text {
        id: name
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: icon.right
        anchors.leftMargin: Tokens.space.md
        width: Math.max(0, comment.x - x - Tokens.space.md)

        text: root.app ? root.app.name : ""
        elide: Text.ElideRight
        font.family: Tokens.typography.mono
        font.pixelSize: Tokens.typography.size.body
        font.weight: root.selected ? Tokens.typography.weight.medium
                                   : Tokens.typography.weight.regular
        color: Tokens.color.text1
    }

    Text {
        id: comment
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.lg
        width: Math.min(implicitWidth, root.width * 0.4)

        text: root.app && root.app.comment ? root.app.comment : ""
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        font.family: Tokens.typography.mono
        font.pixelSize: Tokens.typography.size.caption
        color: Tokens.color.text2
        opacity: root.selected ? 1.0 : 0.7
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.activated()
    }
}
