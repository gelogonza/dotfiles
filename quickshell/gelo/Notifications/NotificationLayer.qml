// Notification stack.
//
// Replaces mako. Only one of these may exist — org.freedesktop.Notifications is
// a single-owner DBus name, so mako has to be stopped for this to bind at all.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import "root:/Theme"
import "root:/Services"

PanelWindow {
    id: layer

    // Follows the focused monitor, like the launcher.
    screen: {
        const fm = Hyprland.focusedMonitor;
        if (fm) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === fm.name)
                    return screens[i];
            }
        }
        return Quickshell.screens[0];
    }

    anchors {
        top: true
        right: true
    }

    margins {
        // Clears the floating bar rather than tucking under it.
        top: Tokens.space.sm + 36 + Tokens.space.sm
        right: Tokens.space.lg
    }

    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)

    color: "transparent"
    visible: server.trackedNotifications.values.length > 0

    // Notifications must never steal space from tiled windows.
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "gelo-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // Cards are click-to-dismiss and drag-to-dismiss, but must not take
    // keyboard focus away from whatever you are typing in.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    NotificationServer {
        id: server

        // Drop anything outstanding when the shell reloads; replaying stale
        // notifications after a config edit is just noise.
        keepOnReload: false

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true

        // Notifications arrive untracked and are discarded unless claimed here.
        // Without this, trackedNotifications stays empty and nothing ever draws.
        onNotification: notification => {
            notification.tracked = true;
            // Record it before the card's expire timer takes it away. This
            // layer is deliberately transient — `keepOnReload: false` above,
            // and cards clear themselves on a timer — so without a store a
            // notification you did not happen to be looking at is gone.
            NotificationHistory.push(notification);
        }
    }

    Column {
        id: stack
        width: parent.width
        spacing: Tokens.space.sm

        Repeater {
            model: server.trackedNotifications

            delegate: NotificationCard {
                required property var modelData
                notif: modelData
                window: layer
                width: stack.width

                // Critical notifications stay until acknowledged; everything
                // else clears itself.
                Timer {
                    running: modelData.urgency !== NotificationUrgency.Critical
                    interval: modelData.expireTimeout > 0 ? modelData.expireTimeout : 5000
                    onTriggered: parent.dismiss()
                }
            }
        }
    }
}
