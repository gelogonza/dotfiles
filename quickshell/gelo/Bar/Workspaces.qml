// Workspace indicator. One of the three places accent is permitted to appear.
//
// The travelling blob. Its two edges animate at different durations — leading
// fast, trailing slow — so it stretches across the gap and settles rather than
// sliding, and it squashes vertically while in motion.
//
// This coexists with the XMB language rather than contradicting it: the blob is
// the indicator moving, and the same switch ALSO fires a ripple into the wave
// field behind the bar. The element travels; the field responds.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/Components"
import "root:/Services"
import "root:/Theme"

Item {
    id: root

    // The PanelWindow this lives in. Needed to resolve screen coordinates for
    // ripples; Quickshell layer surfaces do not expose the Window attached
    // property to their children.
    property var window: null

    readonly property int cell: Tokens.space.xl // 24 — one grid step
    readonly property int gap: Tokens.space.sm // 8

    readonly property var wsList: {
        const v = Hyprland.workspaces.values.slice();
        // Sort by the NAME parsed as a number, not by id. Hyprland reports
        // id = -1 for workspaces it has not fully populated yet, which sorts
        // them to the front and visibly reorders the bar on startup.
        const key = ws => {
            const n = parseInt(ws.name, 10);
            return isNaN(n) ? ws.id : n;
        };
        v.sort((a, b) => key(a) - key(b));
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

    implicitWidth: Math.max(0, wsList.length * (cell + gap) - gap)
    implicitHeight: cell

    // Hyprland's workspace model starts empty; it only populates after an
    // explicit refresh. Without this the bar renders no workspaces until the
    // first workspace-change event happens to arrive.
    Component.onCompleted: Hyprland.refreshWorkspaces()

    // The blob travels; the field behind the bar responds.
    onFocusedIndexChanged: {
        if (focusedIndex < 0)
            return ;

        const item = repeater.itemAt(focusedIndex);
        if (item)
            Ripples.emitFromItem(item, root.window);

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
            id: repeater

            model: root.wsList

            delegate: Item {
                id: cellItem

                required property var modelData
                required property int index
                readonly property bool isFocused: index === root.focusedIndex
                readonly property bool isOccupied: modelData.toplevels && modelData.toplevels.values.length > 0

                width: root.cell
                height: root.cell

                Reflection {
                    anchors.fill: parent

                    Text {
                        anchors.centerIn: parent
                        text: cellItem.modelData.name
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.caption
                        font.weight: Tokens.typography.weight.light
                        font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
                        // On the blob, `accent-ink` reads out of the accent.
                        // Off it, occupied workspaces sit stronger than empty
                        // ones.
                        color: cellItem.isFocused ? Tokens.color.accentInk : cellItem.isOccupied ? Tokens.color.text1 : Tokens.color.text2

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.motion.duration.base
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Tokens.motion.easeBezier
                            }
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
