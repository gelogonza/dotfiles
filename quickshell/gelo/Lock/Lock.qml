// Lock screen.
//
// A real ext-session-lock client (WlSessionLock), not a fullscreen window — the
// compositor keeps the session locked even if this process dies, which is what
// makes it a lock rather than a decoration.
//
// THAT PROPERTY CUTS BOTH WAYS. If the shell crashes while locked there is no
// UI left to unlock with: recovery is a TTY (Ctrl+Alt+F2), log in, and
// `loginctl unlock-session`. hyprlock stays installed as a fallback. Read
// docs/lock-screen.md before making this your only lock.
//
// Authentication is PAM via /etc/pam.d/hyprlock, which is `auth include login`.
// That file ships with the hyprlock package, so uninstalling hyprlock could
// take it with it and leave this unable to start a transaction. A dedicated
// /etc/pam.d/gelo-lock is more robust but needs root; see the doc.
//
// The password is held in one place, handed to PamContext, and cleared on every
// terminal outcome. It is never logged, never written to disk, and never
// interpolated into a shell command.
//
// IPC:
//   qs -c gelo ipc call lock lock      engage the real lock
//   qs -c gelo ipc call lock preview   show the UI WITHOUT locking
//
// There is deliberately no `unlock` verb. Anything that releases the lock
// without PAM would make the lock bypassable by any process running as you.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import "root:/Theme"

Scope {
    id: root

    property bool locked: false
    property bool previewing: false

    // Shared across every screen's surface.
    property string password: ""
    property string status: ""
    property bool busy: false
    property bool failed: false

    function authenticate() {
        if (busy || password.length === 0)
            return;
        busy = true;
        failed = false;
        status = "";
        pam.start();
    }

    function reset() {
        password = "";
        busy = false;
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.status = "";
            root.failed = false;
            root.password = "";
            root.locked = true;
        }

        // Appearance check that does not touch the session lock.
        function preview(): void {
            root.password = "";
            root.status = "";
            root.failed = false;
            root.previewing = !root.previewing;
        }
    }

    PamContext {
        id: pam

        config: "hyprlock"

        onPamMessage: {
            // PAM asks; we answer. The password is never pushed unprompted.
            if (pam.responseRequired)
                pam.respond(root.password);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.reset();
                root.status = "";
                root.previewing = false;
                root.locked = false;          // releases the compositor lock
                return;
            }

            root.reset();
            root.failed = true;
            root.status = result === PamResult.MaxTries ? "Too many attempts"
                                                        : "Incorrect password";
        }

        onError: err => {
            root.reset();
            root.failed = true;
            // Distinguish "wrong password" from "auth is broken": if PAM cannot
            // start, retyping will never help and the user needs to know to
            // reach for a TTY.
            root.status = err === PamError.StartFailed
                ? "PAM failed to start — use a TTY"
                : "Authentication error";
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: root.locked

        surface: WlSessionLockSurface {
            color: Tokens.color.fieldBase

            LockContent {
                anchors.fill: parent
                controller: root
            }
        }
    }

    // --- preview ----------------------------------------------------------
    // A normal overlay window showing the same content. Engages nothing, grabs
    // no input, and can be dismissed by clicking or by calling preview again.
    Variants {
        model: root.previewing ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            WlrLayershell.namespace: "gelo-lock-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            LockContent {
                anchors.fill: parent
                controller: root
                preview: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.previewing = false
            }
        }
    }
}
