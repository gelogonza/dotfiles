// Bluetooth state and actions.
//
// Backed by scripts/bluetooth.sh (bluetoothctl) rather than by Quickshell's
// Bluetooth service. That service reports a null adapter and an empty device
// list on this machine while bluetoothctl sees a controller and two paired
// devices, so a control bound to it would either never appear or never update.
//
// This is the same pattern the launcher uses for its application index and the
// bar uses for git context: when the built-in service does not work here, drive
// the underlying tool directly and keep the shape of the API.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool present: false
    property bool powered: false
    property int connected: 0
    property string deviceName: ""

    readonly property string icon: powered ? "bluetooth-on" : "bluetooth-off"

    function refresh() {
        if (statusProc.running)
            return;
        statusProc.command = ["bash", Quickshell.shellPath("scripts/bluetooth.sh"), "status"];
        statusProc.running = true;
    }

    function disconnectAll() {
        if (disconnectProc.running)
            return;
        disconnectProc.command = ["bash", Quickshell.shellPath("scripts/bluetooth.sh"), "disconnect"];
        disconnectProc.running = true;
    }

    // Opens blueman. Focuses an existing window instead of spawning another —
    // blueman-manager is not single-instance.
    function openManager() {
        Quickshell.execDetached(["sh", "-c",
            "pgrep -x blueman-manager >/dev/null 2>&1 "
            + "&& hyprctl dispatch focuswindow class:blueman-manager "
            + "|| blueman-manager"]);
    }

    Component.onCompleted: refresh()

    Timer {
        // Each poll is two bluetoothctl invocations, so this is deliberately
        // slower than the /proc-backed stats.
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    root.present = false;
                    return;
                }
                root.present = d.present === true;
                root.powered = d.powered === true;
                root.connected = d.connected || 0;
                root.deviceName = d.name || "";
            }
        }
    }

    Process {
        id: disconnectProc
        // Re-read state as soon as the disconnect lands rather than waiting out
        // the poll interval, so the icon responds to the click that caused it.
        onExited: root.refresh()
    }
}
