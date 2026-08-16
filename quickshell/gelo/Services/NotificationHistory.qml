// Notifications, kept.
//
// The notification layer deliberately drops everything on reload and clears
// non-critical cards on a timer — which is right for the transient surface and
// means a notification you were not looking at is gone for good. This is the
// record behind it.
//
// Same shape as Apps and Clipboard so the launcher can swap between them
// without caring which is active: `query`, `results`, `activate()`, `reload()`.
//
// Persisted rather than in-memory: the point is surviving the thing that lost
// the notification in the first place, which is usually a shell restart.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string query: ""

    // Enough to answer "what did I miss" without the file becoming a log.
    readonly property int cap: 200

    readonly property var entries: store.adapter && store.adapter.items
        ? store.adapter.items
        : []

    readonly property bool ready: entries.length > 0

    FileView {
        id: store
        path: Quickshell.statePath("notification-history.json")
        // Written from here only; nothing else edits it, so watching for
        // external changes would just re-read our own writes.
        watchChanges: false
        // The file is rewritten on every notification. A torn write here would
        // lose the whole history, so it is swapped into place instead.
        atomicWrites: true

        adapter: JsonAdapter {
            property var items: []
        }
    }

    // The launcher calls this on open; there is nothing to fetch, the store is
    // already live. Present so the provider contract holds.
    function reload() {}

    function push(n) {
        if (!n)
            return;

        const summary = n.summary || "";
        const body = n.body || "";
        if (summary.length === 0 && body.length === 0)
            return;

        const list = (store.adapter.items || []).slice();

        // Applications that update a notification in place (progress bars,
        // "now playing") would otherwise fill the history with near-duplicates
        // of one event.
        if (list.length > 0
            && list[0].appName === (n.appName || "")
            && list[0].summary === summary
            && list[0].body === body)
            return;

        list.unshift({
            appName: n.appName || "",
            summary: summary,
            body: body,
            image: n.image || "",
            urgency: String(n.urgency),
            time: Date.now()
        });

        store.adapter.items = list.slice(0, root.cap);
        store.writeAdapter();
    }

    function clear() {
        store.adapter.items = [];
        store.writeAdapter();
        query = "";
    }

    // Copying is the useful verb here. The thing you go back to a notification
    // for is almost always a code, a link or a name you now want to paste.
    function activate(entry) {
        if (!entry || copyProc.running)
            return;
        const text = entry.body && entry.body.length > 0
            ? entry.summary + "\n" + entry.body
            : entry.summary;
        // Array form, never a shell string: notification bodies are arbitrary
        // remote text and must not be able to become a command.
        copyProc.command = ["wl-copy", "--", text];
        copyProc.running = true;
    }

    Process { id: copyProc }

    function ageLabel(ms) {
        const secs = Math.max(0, Math.floor((Date.now() - ms) / 1000));
        if (secs < 60) return "just now";
        if (secs < 3600) return Math.floor(secs / 60) + "m ago";
        if (secs < 86400) return Math.floor(secs / 3600) + "h ago";
        return Math.floor(secs / 86400) + "d ago";
    }

    readonly property var results: {
        const q = query.trim();
        const scored = [];

        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            // Match across everything shown, so "firefox" finds it by app and
            // "build failed" finds it by body.
            const hay = [e.summary, e.body, e.appName].join(" ");
            const s = Fuzzy.score(hay, q);
            if (s >= 0)
                scored.push({ entry: e, score: s, order: i });
        }

        // Unqueried, newest first — the same reasoning as the clipboard: a
        // history re-sorted by score is no longer a history.
        scored.sort((a, b) => q.length === 0
            ? a.order - b.order
            : (b.score !== a.score ? b.score - a.score : a.order - b.order));

        return scored.slice(0, 12).map(e => e.entry);
    }
}
