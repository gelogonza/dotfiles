// Pinned application launchers.
//
// Real app icons, deliberately NOT tinted: these are logos, and flattening them
// to silhouettes would make five blue smudges you have to read rather than
// recognise. They are the one place in the bar where outside colour is allowed,
// which is also why they sit at 78% opacity until hovered — recognisable, but
// not competing with the workspace indicator next to them.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Components"
import "root:/Services"

Row {
    id: root

    spacing: Tokens.space.md

    // desktop-entry icon name + the command to run.
    readonly property var apps: [
        { icon: "com.mitchellh.ghostty", exec: "ghostty" },
        { icon: "vscode",                exec: "code" },
        { icon: "google-chrome",         exec: "google-chrome-stable" },
        { icon: "obsidian",              exec: "obsidian" },
        { icon: "blender",               exec: "blender" }
    ]

    Repeater {
        model: root.apps

        delegate: Item {
            id: entry
            required property var modelData

            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            Reflection {
                anchors.fill: parent

                Icon {
                    anchors.fill: parent
                    source: entry.modelData.icon
                    size: 18
                    tinted: false
                    opacity: mouse.containsMouse ? 1.0 : 0.78

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Tokens.motion.duration.fast
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Tokens.motion.easeBezier
                        }
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", entry.modelData.exec]);
                    Ripples.emitFromItem(entry, root.window);
                }
            }
        }
    }

    property var window: null
}
