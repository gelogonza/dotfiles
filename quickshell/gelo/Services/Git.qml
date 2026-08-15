// Git context for whatever window is focused right now.
//
// Re-resolved on focus change (debounced) and polled slowly while focus is
// unchanged, so the dirty-file count stays live while you work without running
// `git status` on a hot loop.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property string repo: ""
    property string branch: ""
    property string commit: ""
    property string subject: ""
    property int dirty: 0

    readonly property bool valid: branch.length > 0

    // Used only as a change signal. The pid itself is resolved by the script,
    // which asks the compositor directly — activeToplevel carries the title
    // immediately but only exposes a pid after an async refreshToplevels().
    readonly property var activeToplevel: Hyprland.activeToplevel

    function _clear() {
        repo = "";
        branch = "";
        commit = "";
        subject = "";
        dirty = 0;
    }

    function refresh() {
        if (proc.running)
            return;
        proc.command = ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/git-context.sh"];
        proc.running = true;
    }

    onActiveToplevelChanged: debounce.restart()
    Component.onCompleted: refresh()

    // Focus can change several times in a few milliseconds while cycling
    // windows; only the window you land on is worth a subprocess.
    Timer {
        id: debounce
        interval: 150
        onTriggered: root.refresh()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                let data = {};
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    root._clear();
                    return;
                }

                if (!data || !data.branch) {
                    root._clear();
                    return;
                }

                root.repo = data.repo || "";
                root.branch = data.branch || "";
                root.commit = data.commit || "";
                root.subject = data.subject || "";
                root.dirty = data.dirty || 0;
            }
        }
    }
}
