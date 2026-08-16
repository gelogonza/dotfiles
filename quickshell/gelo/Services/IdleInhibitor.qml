// Keep the screen awake on demand.
//
// hypridle locks at 5 minutes, which is right for a desk you walk away from and
// wrong for one you are watching something on. Browsers do take an idle
// inhibitor for fullscreen video, but not reliably across every player and
// never for a PDF you are reading slowly — so this is the manual override.
//
// Implemented as a logind inhibitor rather than by signalling hypridle:
// `ignore_dbus_inhibit = false` in hypridle.conf means it already honours them,
// so this is the supported mechanism rather than a side channel. It also means
// anything else that respects logind — a screensaver, a future lock daemon —
// gets the same answer.
//
// Verified against logind: holding one sets BlockInhibited to "idle", and
// releasing it clears the property.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool inhibited: hold.running

    function toggle() {
        hold.running = !hold.running;
    }

    function set(on) {
        hold.running = on === true;
    }

    // Scriptable, so it can be bound to a key or driven by a wrapper — start a
    // long render with it on, turn it off when the render finishes.
    IpcHandler {
        target: "idle"

        function toggle(): void { root.toggle(); }
        function on(): void { root.set(true); }
        function off(): void { root.set(false); }
        function status(): string { return root.inhibited ? "inhibited" : "idle allowed"; }
    }

    // The inhibitor is the *lifetime of this process*: logind releases it when
    // the process goes away. That is a useful property rather than an
    // implementation detail — if the shell dies, the machine goes back to
    // locking on schedule instead of staying awake forever with nothing left
    // to turn it off.
    Process {
        id: hold
        running: false
        command: [
            "systemd-inhibit",
            "--what=idle",
            "--mode=block",
            "--who=gelo shell",
            "--why=Idle inhibited from the bar",
            "sleep", "infinity"
        ]
    }
}
