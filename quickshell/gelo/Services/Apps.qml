// Application index + fuzzy ranking for the command palette.
//
// The index is built by scripts/list-apps.py rather than by Quickshell's
// DesktopEntries singleton, which returns an empty model on this system.
//
// Ranking lives in Fuzzy, shared with the clipboard provider so both search
// modes sort by the same rules.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var apps: []
    property string query: ""

    readonly property bool ready: apps.length > 0

    function reload() {
        if (proc.running)
            return;
        proc.command = ["python3", Quickshell.shellPath("scripts/list-apps.py")];
        proc.running = true;
    }

    Component.onCompleted: reload()

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apps = JSON.parse(text);
                } catch (e) {
                    console.warn("Apps: could not parse index:", e);
                    root.apps = [];
                }
            }
        }
    }

    readonly property var results: {
        const q = query.trim();
        const scored = [];

        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];

            let s = Fuzzy.score(app.name, q);

            // A comment match is real but much weaker than a name match, so it
            // can surface "Files" for "browser" without outranking real hits.
            if (s < 0 && q.length >= 3 && app.comment) {
                const cs = Fuzzy.score(app.comment, q);
                if (cs >= 0)
                    s = cs / 4;
            }

            if (s >= 0)
                scored.push({ app: app, score: s });
        }

        scored.sort((a, b) => b.score !== a.score
            ? b.score - a.score
            : a.app.name.localeCompare(b.app.name));

        return scored.slice(0, 12).map(e => e.app);
    }

    function launch(app) {
        if (!app)
            return;

        if (app.terminal)
            Quickshell.execDetached(["ghostty", "-e", app.exec]);
        else
            Quickshell.execDetached(["sh", "-c", app.exec]);
    }
}
