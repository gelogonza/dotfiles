//    gelo / quickshell
//
//    Bar, launcher and notifications for Hyprland.
//    Every value comes from design/tokens.json via Theme/Tokens.qml — if you are
//    about to type a colour, a duration or a pixel gap in this tree, stop and add
//    it to the token source instead.

import Quickshell
import "root:/Bar"
import "root:/Launcher"
import "root:/Notifications"
import "root:/Wallpaper"

ShellRoot {
    // One wallpaper per connected screen, on the background layer.
    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }

    // One bar per connected screen.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Single instance, unlike the bar. Two palettes would mean two IPC handlers
    // fighting over one target and two surfaces both claiming exclusive keyboard
    // focus; it follows the focused monitor instead.
    Launcher {}

    // Also single-instance: org.freedesktop.Notifications has one owner.
    NotificationLayer {}
}
