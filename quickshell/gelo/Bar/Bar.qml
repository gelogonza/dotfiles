// The bar. Three clusters:
//
//   left    workspaces, then pinned application launchers
//   centre  clock and date, with the active window title beneath
//   right   weather, system load, git context, tray, controls
//
// The centre is absolutely centred on the SCREEN rather than laid out between
// the two side clusters. A flow layout would drift the clock sideways every
// time a tray icon appeared or the git module resolved, and a clock that moves
// is worse than a clock that occasionally sits closer to one side.

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

    // Floating rather than edge-to-edge: the chrome has to read as an object
    // sitting above the desktop, which needs a gap on every side.
    margins {
        top: Tokens.space.sm
        left: Tokens.space.lg
        right: Tokens.space.lg
    }

    // 48 rather than 36: the workspace numbers and app icons carry reflections
    // beneath them and those need somewhere to land.
    implicitHeight: 48
    color: "transparent"

    WlrLayershell.namespace: "gelo-bar"
    WlrLayershell.layer: WlrLayer.Top

    Chrome {
        anchors.fill: parent
        glowEnabled: false

        // --- left ---------------------------------------------------------
        Row {
            id: leftCluster

            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -Tokens.space.xs
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.lg
            spacing: Tokens.space.lg

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                window: bar
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Tokens.space.lg
                color: Tokens.color.border
            }

            AppLaunchers {
                anchors.verticalCenter: parent.verticalCenter
                window: bar
            }

            // Only earns its space when something is loaded in a player.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: mediaModule.visible
                width: 1
                height: Tokens.space.lg
                color: Tokens.color.border
            }

            MediaModule {
                id: mediaModule
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // --- centre -------------------------------------------------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Clock {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            WindowTitle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, bar.width * 0.34)
            }
        }

        // --- right --------------------------------------------------------
        Row {
            id: rightCluster

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.lg
            spacing: Tokens.space.md

            WeatherModule {
                id: weatherModule
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: weatherModule.visible
                width: 1
                height: Tokens.space.md
                color: Tokens.color.border
            }

            SysStats {
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Tokens.space.md
                color: Tokens.color.border
            }

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

            Controls {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
