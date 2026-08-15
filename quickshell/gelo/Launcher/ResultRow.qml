import Quickshell
import Quickshell.Widgets
import QtQuick
import "root:/Theme"
import "root:/Components"

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

    // Selection is a bloom, not a filled row. A very low-opacity plate stays
    // underneath purely to keep long text legible where it crosses a bright
    // band in the wallpaper — it is a legibility floor, not the selection cue.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.sm
        anchors.rightMargin: Tokens.space.sm
        radius: Tokens.material.chrome.radius
        color: root.selected ? Tokens.alpha(Tokens.color.bg2, 0.35) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.fast
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }
    }

    // The bloom sits behind the icon rather than wrapping it: Glow takes the
    // bounding shape of whatever it contains, and an empty Glow sized to the
    // icon gives a clean disc of light under it.
    Glow {
        anchors.centerIn: icon
        width: icon.width
        height: icon.height
        amount: root.selected ? 1 : 0
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
        font.family: Tokens.typography.display
        font.pixelSize: Tokens.typography.size.body
        font.weight: root.selected ? Tokens.typography.weight.regular
                                   : Tokens.typography.weight.light
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
        font.family: Tokens.typography.display
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
