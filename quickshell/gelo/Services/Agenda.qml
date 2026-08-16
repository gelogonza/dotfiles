// Upcoming events, from ICS feeds.
//
// Google and Outlook both publish a private ICS address per calendar, which
// avoids OAuth entirely — no app registration, no token refresh, no browser
// round-trip. scripts/agenda.py does the fetching and parsing; this only holds
// the result.
//
// Those URLs are bearer secrets, so they live in ~/.config/gelo/calendars.json,
// outside this repo — the repo is ~/.config and is pushed to GitHub. Nothing
// here or in the script ever prints one.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool configured: false
    property bool loading: false
    property var events: []
    property var calendars: []
    property var errors: []

    readonly property bool ready: events.length > 0

    // Days that have something on them, for marking the month grid.
    readonly property var busyDays: {
        const set = {};
        for (let i = 0; i < events.length; i++)
            set[events[i].day] = true;
        return set;
    }

    function refresh() {
        if (proc.running)
            return;
        loading = true;
        proc.running = true;
    }

    Process {
        id: proc
        command: ["python3", Quickshell.shellPath("scripts/agenda.py"), "14"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const d = JSON.parse(text);
                    root.configured = d.configured === true;
                    root.events = d.events || [];
                    root.calendars = d.calendars || [];
                    root.errors = d.errors || [];
                } catch (e) {
                    root.configured = false;
                    root.events = [];
                }
            }
        }
    }

    Component.onCompleted: refresh()

    // Calendars change on other devices, not here. Fifteen minutes is often
    // enough to catch an invite before it starts and rare enough that the
    // network barely notices.
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
