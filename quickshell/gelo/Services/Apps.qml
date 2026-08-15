// Application index + fuzzy ranking for the command palette.
//
// The index is built by scripts/list-apps.py rather than by Quickshell's
// DesktopEntries singleton, which returns an empty model on this system.
//
// Ranking is subsequence-based, the same shape Raycast/Linear/fzf use: every
// query character must appear in order, and the score rewards matches that start
// a word, matches that run contiguously, and short names. That is what makes
// "gimp" beat "GNOME Image Manipulation Program" for the query "gim".

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

    // --- scoring ----------------------------------------------------------
    // Returns -1 for no match, otherwise higher is better.
    function score(haystack, needle) {
        if (needle.length === 0)
            return 0;

        const h = haystack.toLowerCase();
        const n = needle.toLowerCase();

        // Whole-string prefix is the strongest possible signal.
        if (h.startsWith(n))
            return 1000 - h.length;

        let hi = 0;
        let total = 0;
        let run = 0;

        for (let ni = 0; ni < n.length; ni++) {
            const c = n[ni];
            let found = -1;

            while (hi < h.length) {
                if (h[hi] === c) {
                    found = hi;
                    break;
                }
                hi++;
            }

            if (found === -1)
                return -1;

            let points = 1;

            // Word-start match: beginning of the string, or after a separator.
            const prev = found > 0 ? h[found - 1] : " ";
            if (found === 0 || prev === " " || prev === "-" || prev === "_" || prev === ".")
                points += 8;

            // Contiguous run with the previous matched character.
            if (run > 0 && found === hi && ni > 0)
                points += 4 + run;

            run = (ni > 0 && found === hi) ? run + 1 : 1;
            total += points;
            hi = found + 1;
        }

        // Prefer shorter names among otherwise equal matches.
        return total * 10 - h.length;
    }

    readonly property var results: {
        const q = query.trim();
        const scored = [];

        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];

            let s = score(app.name, q);

            // A comment match is real but much weaker than a name match, so it
            // can surface "Files" for "browser" without outranking real hits.
            if (s < 0 && q.length >= 3 && app.comment) {
                const cs = score(app.comment, q);
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
