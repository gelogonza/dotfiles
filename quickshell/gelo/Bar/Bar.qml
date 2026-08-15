import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/Theme"
import "root:/Components"

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    // Floating rather than edge-to-edge: the glass has to read as an object
    // sitting above the desktop, which needs a gap on every side.
    margins {
        top: Tokens.space.sm
        left: Tokens.space.lg
        right: Tokens.space.lg
    }

    implicitHeight: 36
    color: "transparent"

    // Hyprland matches `layerrule { match:namespace = gelo-bar }` against this.
    // That rule is what produces the real backdrop blur — Qt cannot sample
    // behind its own Wayland surface.
    WlrLayershell.namespace: "gelo-bar"
    WlrLayershell.layer: WlrLayer.Top

    Glass {
        anchors.fill: parent

        // --- left ---------------------------------------------------------
        Workspaces {
            id: workspaces
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.md
        }

        // --- centre -------------------------------------------------------
        // Bounded by the two side clusters so a long title never collides with
        // them; it elides instead.
        WindowTitle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, Math.min(implicitWidth,
                parent.width - 2 * Math.max(
                    workspaces.width + Tokens.space.md,
                    rightCluster.width + Tokens.space.md) - Tokens.space.xl))
        }

        // --- right --------------------------------------------------------
        Row {
            id: rightCluster
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.md
            spacing: Tokens.space.md

            GitModule {
                id: gitModule
                anchors.verticalCenter: parent.verticalCenter
            }

            // Only earns its space when there is a repo to separate from.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: gitModule.visible
                width: 1
                height: Tokens.space.md
                color: Tokens.color.border
            }

            TrayRow {
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Tokens.space.md
                color: Tokens.color.border
            }

            Clock {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
