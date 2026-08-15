// Clipboard history, backed by cliphist.
//
// Same shape as Apps so the launcher can swap between them without caring which
// is active: `query`, `results`, `activate()`, `reload()`.
//
// Entries are addressed by ID throughout. The decoded content never enters this
// process — scripts/clipboard.sh pipes cliphist straight into wl-copy — so
// passwords and tokens that pass through the clipboard are not held in QML
// properties, logged, or interpolated into a command line.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var entries: []
    property string query: ""

    readonly property bool ready: entries.length > 0

    function reload() {
        if (listProc.running)
            return;
        listProc.command = ["bash", Quickshell.shellPath("scripts/clipboard.sh"), "list"];
        listProc.running = true;
    }

    function activate(entry) {
        if (!entry || copyProc.running)
            return;
        copyProc.command = ["bash", Quickshell.shellPath("scripts/clipboard.sh"),
                            "copy", String(entry.id)];
        copyProc.running = true;
    }

    readonly property var results: {
        const q = query.trim();
        const scored = [];

        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const s = Fuzzy.score(e.preview, q);
            if (s >= 0)
                scored.push({ entry: e, score: s, order: i });
        }

        // With no query, preserve cliphist's order — most recent first. That is
        // the whole point of a clipboard history and it must not be re-sorted
        // into alphabetical or score order.
        scored.sort((a, b) => q.length === 0
            ? a.order - b.order
            : (b.score !== a.score ? b.score - a.score : a.order - b.order));

        return scored.slice(0, 12).map(e => e.entry);
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.entries = JSON.parse(text);
                } catch (e) {
                    root.entries = [];
                }
            }
        }
    }

    Process {
        id: copyProc
    }
}
