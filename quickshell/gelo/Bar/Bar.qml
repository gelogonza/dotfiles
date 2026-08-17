// The bar — three separate panels, not one strip.
//
//   left    workspaces, then whatever is playing
//   centre  clock and date, with the active window title beneath
//   right   weather, tray, volume/bluetooth/keep-awake/power
//
// One full-width plate with three clusters inside it was the old build, and it
// was wrong for this material. Chrome is an object sitting above the desktop, and
// a plate spanning the whole screen stops reading as an object and starts reading
// as a frame — the wave field only touched it along one edge. Three plates put
// the field back between them, which is where the motion in this system lives.
//
// WHY THIS IS STILL ONE SURFACE — READ BEFORE SPLITTING IT:
//
// The obvious build is three PanelWindows. It does not work, because Hyprland
// only honours a layer surface's exclusive zone if that surface SPANS its
// anchored edge. Measured against a clean baseline, with the property read back
// to confirm it really was set:
//
//   anchored top+left+right, Normal, zone 56  ->  reserved [0,56,0,0]
//   anchored top+left,       Normal, zone 56  ->  reserved [0,0,0,0]
//
// So three side-by-side surfaces cannot reserve space however they ask for it,
// and every window ends up underneath the bar. One spanning surface keeps the
// exclusive zone, and `mask` narrows the *input* region to the three plates so
// the gaps between them stay click-through — the wallpaper there is not merely
// visible, it is reachable.
//
// `exclusionMode` is set explicitly because it defaults to Auto, which derives
// the zone from the anchors and discards `exclusiveZone` entirely.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/Theme"
import "root:/Components"

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    readonly property var b: Tokens.material.bar

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: Tokens.space.sm
        left: Tokens.space.lg
        right: Tokens.space.lg
    }

    implicitHeight: bar.b.height
    color: "transparent"

    exclusionMode: ExclusionMode.Normal

    // Height only. Hyprland adds `margins.top` on top of whatever is requested,
    // so asking for height + margin reserves the margin twice — measured
    // reserved=[0,64,0,0] instead of the [0,56,0,0] the old bar had.
    exclusiveZone: bar.b.height

    WlrLayershell.namespace: "gelo-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Only the plates take input. Everything between them belongs to whatever
    // window is underneath.
    mask: Region {
        Region { item: leftPlate; intersection: Intersection.Combine }
        Region { item: centrePlate; intersection: Intersection.Combine }
        Region { item: rightPlate; intersection: Intersection.Combine }
    }

    // --- left: workspaces, now playing ------------------------------------

    Chrome {
        id: leftPlate

        glowEnabled: false
        cornerRadius: bar.b.radius

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: leftCluster.implicitWidth + bar.b.padding * 2
        height: parent.height

        Row {
            id: leftCluster

            anchors.centerIn: parent

            // The reflections under the workspace numbers hang below the glyphs,
            // so the row sits slightly high of centre to give them somewhere to
            // land.
            anchors.verticalCenterOffset: -Tokens.space.xs
            spacing: Tokens.space.lg

            Workspaces {
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
    }

    // --- centre: clock, date, window title --------------------------------

    Chrome {
        id: centrePlate

        glowEnabled: false
        cornerRadius: bar.b.radius

        // Centred on the SCREEN, not between the two side plates. A flow layout
        // would drift the clock sideways every time a tray icon appeared or the
        // weather resolved, and a clock that moves is worse than a clock that
        // occasionally sits closer to one side.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        width: Math.min(
            Math.max(clock.implicitWidth, title.implicitWidth) + bar.b.padding * 2,
            bar.width * 0.42)
        height: parent.height

        Column {
            anchors.centerIn: parent
            spacing: 0

            Clock {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
            }

            WindowTitle {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter

                // Bounded by the plate rather than by its own content, so a long
                // browser-tab title elides instead of widening the plate and
                // pushing its own edges out from under the clock.
                width: Math.min(implicitWidth, centrePlate.width - bar.b.padding * 2)
            }
        }
    }

    // --- right: status ----------------------------------------------------

    Chrome {
        id: rightPlate

        glowEnabled: false
        cornerRadius: bar.b.radius

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        width: rightCluster.implicitWidth + bar.b.padding * 2
        height: parent.height

        Row {
            id: rightCluster

            anchors.centerIn: parent
            spacing: Tokens.space.md

            WeatherModule {
                id: weatherModule
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: weatherModule.visible && trayRow.implicitWidth > 0
                width: 1
                height: Tokens.space.md
                color: Tokens.color.border
            }

            TrayRow {
                id: trayRow
                anchors.verticalCenter: parent.verticalCenter
            }

            // Only earns its space when there is a tray icon to separate. With
            // Claude and NordVPN filtered out this row is often empty, and a
            // divider with nothing on one side of it is a stray line.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: trayRow.implicitWidth > 0
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
