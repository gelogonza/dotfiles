// Open windows, as a launcher provider.
//
// There is no Alt+Tab here, and that is deliberate. Hold-and-cycle is a good
// interaction for four windows and a bad one for fifteen — you end up tabbing
// past the thing you wanted and going round again. Searching by name is O(1)
// however many are open, and this desk routinely has a browser, an editor, a
// terminal grid and a music player spread over five workspaces.
//
// Same shape as Apps, Clipboard and NotificationHistory so the launcher can
// swap between them without caring which is active: `query`, `results`,
// `activate()`, `reload()`.

pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property string query: ""

    // Hyprland hands over the toplevel list; the class lives in the raw IPC
    // object rather than on the typed handle.
    readonly property var entries: {
        const out = [];
        const list = Hyprland.toplevels ? Hyprland.toplevels.values : [];

        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t || !t.title || t.title.length === 0)
                continue;

            const raw = t.lastIpcObject || {};
            out.push({
                address: t.address,
                title: t.title,
                appClass: raw["class"] || raw.initialClass || "",
                // The typed handle is preferred, but the raw IPC object
                // always carries the workspace even before a refresh lands.
                workspace: t.workspace ? t.workspace.id
                    : (raw.workspace ? raw.workspace.id : -1),
                active: t.activated === true
            });
        }

        // The focused window first would be useless — it is the one you are
        // already looking at. Sort by workspace so the list reads like the
        // desktop is laid out, and drop the active window to the end.
        out.sort((a, b) => {
            if (a.active !== b.active)
                return a.active ? 1 : -1;
            if (a.workspace !== b.workspace)
                return a.workspace - b.workspace;
            return a.title.localeCompare(b.title);
        });
        return out;
    }

    readonly property bool ready: entries.length > 0

    // Hyprland pushes toplevel changes over its event socket, but the detail
    // arrives on an async refresh. Both calls are needed:
    //
    //   toplevels  — titles are empty until this lands, and a window opened
    //                moments ago would be filtered out above
    //   workspaces — a toplevel's `workspace` handle stays null for workspaces
    //                the shell has not seen, which showed as "workspace -1"
    //                against every window that was not on the active one
    function reload() {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    function activate(entry) {
        if (!entry || !entry.address)
            return;
        // `address:0x...` is the only stable handle. Matching on title races
        // with anything that renames itself, which browsers and editors do on
        // every tab change.
        Hyprland.dispatch("focuswindow address:" + entry.address);
    }

    readonly property var results: {
        const q = query.trim();
        const scored = [];

        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            // Match on both, so "chrome" finds it by class and "roadmap" finds
            // the same window by document title.
            const s = Fuzzy.score(e.title + " " + e.appClass, q);
            if (s >= 0)
                scored.push({ entry: e, score: s, order: i });
        }

        scored.sort((a, b) => q.length === 0
            ? a.order - b.order
            : (b.score !== a.score ? b.score - a.score : a.order - b.order));

        return scored.slice(0, 12).map(e => e.entry);
    }
}
