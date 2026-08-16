// The dashboard.
//
// The bar used to carry CPU/MEM/GPU and a git context permanently. Both were
// glanceable in the sense that they were always visible, and neither was
// something you actually looked at — a number you never read is just texture.
// They moved here, behind a deliberate gesture, and the bar got quieter.
//
// Separate overlay surface for the same reason the power menu is one: the bar
// is 48px with an exclusive zone, so anything drawn inside it is clipped to
// that strip.
//
// Opened by clicking the clock, SUPER+SHIFT+D, or `ipc call dashboard toggle`.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "root:/Theme"
import "root:/Components"
import "root:/Services"

PanelWindow {
    id: dash

    screen: {
        const fm = Hyprland.focusedMonitor;
        if (fm) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === fm.name)
                    return screens[i];
            }
        }
        return Quickshell.screens[0];
    }

    anchors { top: true; bottom: true; left: true; right: true }

    color: "transparent"
    visible: Ui.dashboardOpen

    WlrLayershell.namespace: "gelo-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Ui.dashboardOpen ? WlrKeyboardFocus.OnDemand
                                                  : WlrKeyboardFocus.None

    // Refresh on open rather than on a timer: nothing here is worth a poll
    // while the panel is closed, and stale numbers on open are worse than a
    // half-second wait.
    onVisibleChanged: {
        if (visible) {
            Weather.refresh();
            Agenda.refresh();
        }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { Ui.dashboardOpen = !Ui.dashboardOpen; }
        function open(): void { Ui.dashboardOpen = true; }
        function close(): void { Ui.dashboardOpen = false; }
    }

    // A scrim, built from `shade` like every other scrim in the system.
    //
    // Chrome is 96% opaque by design, which reads as solid over the wallpaper
    // and as a faint ghost over a dark editor — measured #e4e9f0 against a
    // nominal #f8fbff with VS Code behind it. Rather than make this one
    // surface denser than the rest of the material, put something between the
    // panel and whatever happens to be underneath. It also says the panel is
    // modal, which it is.
    Rectangle {
        anchors.fill: parent
        color: Tokens.alpha(Tokens.color.shade, 0.28)
        opacity: Ui.dashboardOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        // Click-away and Escape both close. A panel you can only dismiss by
        // finding the same 40px of clock again is a panel you resent.
        MouseArea {
            anchors.fill: parent
            onClicked: Ui.dashboardOpen = false
        }
    }

    Item {
        anchors.fill: parent
        focus: dash.visible
        Keys.onEscapePressed: Ui.dashboardOpen = false
    }

    Row {
        id: panel

        anchors.top: parent.top
        anchors.topMargin: Tokens.space.sm + 36 + Tokens.space.sm
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.space.md

        opacity: Ui.dashboardOpen ? 1 : 0
        y: Ui.dashboardOpen ? 0 : -Tokens.space.md

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        // Swallow clicks inside the panel so they do not reach the dismiss
        // layer underneath.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {}
        }

        CalendarCard {}

        Column {
            spacing: Tokens.space.md
            WeatherCard {}
            SystemCard {}
        }
    }
}
