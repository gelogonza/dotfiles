// Scripted open/close for the dock.
//
// The dock is per-screen (one PanelWindow per monitor, like the bar), and an
// IpcHandler is a process-wide registration — two instances declaring
// `target: "dock"` means the second one is dropped with a warning and
// `ipc call dock show` silently only ever reaches one monitor. Same constraint
// that makes the launcher single-instance.
//
// So the handler lives here, once, and sets a flag that every dock observes.
// A scripted reveal opens the dock on all screens, which is the right answer
// for a call that cannot name a monitor: the alternative is guessing, and
// guessing wrong means the caller sees nothing happen.
//
// Hover is unaffected and stays per-screen — `forced` is OR'd with the local
// pointer state, not a replacement for it.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool forced: false

    IpcHandler {
        target: "dock"

        // `open`/`close`, not `show`/`hide`: `quickshell ipc show` is the
        // CLI's own subcommand for listing targets, so `ipc call dock show`
        // never reaches the handler — it prints the target listing and exits 0,
        // which looks exactly like a call that worked.
        function open(): void { root.forced = true; }
        function close(): void { root.forced = false; }
        function toggle(): void { root.forced = !root.forced; }
        function status(): string { return root.forced ? "pinned open" : "hover"; }
    }
}
