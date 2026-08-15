// Workspace indicator. One of the three places accent is permitted to appear.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "root:/Theme"
import "root:/Components"

Item {
    id: root

    readonly property int cell: Tokens.space.xl          // 24 — one grid step
    readonly property int gap: Tokens.space.xs           // 4

    implicitWidth: Math.max(0, wsList.length * (cell + gap) - gap)
    implicitHeight: cell

    // Hyprland's workspace model starts empty; it only populates after an
    // explicit refresh. Without this the bar renders no workspaces until the
    // first workspace-change event happens to arrive.
    Component.onCompleted: Hyprland.refreshWorkspaces()

    readonly property var wsList: {
        const v = Hyprland.workspaces.values.slice();
        v.sort((a, b) => a.id - b.id);
        return v;
    }

    readonly property int focusedIndex: {
        const fw = Hyprland.focusedWorkspace;
        for (let i = 0; i < wsList.length; i++) {
            if (wsList[i].focused)
                return i;
            if (fw && wsList[i].id === fw.id)
                return i;
        }
        return -1;
    }

    BlobIndicator {
        anchors.fill: parent
        visible: root.focusedIndex >= 0
        targetX: root.focusedIndex * (root.cell + root.gap)
        targetWidth: root.cell
    }

    Row {
        spacing: root.gap

        Repeater {
            model: root.wsList

            delegate: Item {
                id: cellItem
                required property var modelData
                required property int index

                width: root.cell
                height: root.cell

                readonly property bool isFocused: index === root.focusedIndex

                Text {
                    anchors.centerIn: parent
                    text: cellItem.modelData.name
                    font.family: Tokens.typography.mono
                    font.pixelSize: Tokens.typography.size.caption
                    // On the accent blob, use the darkest background for contrast.
                    // Off it, occupied workspaces read brighter than empty ones.
                    color: cellItem.isFocused ? Tokens.color.bg0
                         : cellItem.modelData.toplevels
                           && cellItem.modelData.toplevels.values.length > 0
                             ? Tokens.color.text1
                             : Tokens.color.text2

                    font.weight: cellItem.isFocused ? Tokens.typography.weight.medium
                                                    : Tokens.typography.weight.regular

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.motion.duration.base
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Tokens.motion.easeBezier
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + cellItem.modelData.id)
                }
            }
        }
    }
}
