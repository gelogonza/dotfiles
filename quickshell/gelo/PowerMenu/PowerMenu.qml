// Power menu.
//
// Separate overlay surface rather than a popup inside the bar: the bar is 48px
// tall with an exclusive zone, so anything drawn inside it is clipped to that
// strip. Opened by flipping Ui.powerMenuOpen from the bar's power button.
//
// Every entry here is destructive to some degree, so nothing is a single hover
// away from firing and the two that end the session sit at the bottom.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "root:/Theme"
import "root:/Components"
import "root:/Services"

PanelWindow {
    id: menu

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
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: Ui.powerMenuOpen

    WlrLayershell.namespace: "gelo-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Ui.powerMenuOpen ? WlrKeyboardFocus.OnDemand
                                                  : WlrKeyboardFocus.None

    // Ordered least to most destructive, so the two that end the session sit
    // furthest from the pointer's entry point.
    //
    // Sleep locks on the way down: hypridle's before_sleep_cmd fires
    // loginctl lock-session, so the machine never resumes to an open desktop.
    readonly property var entries: [
        { label: "Lock",      icon: "lock",   cmd: "~/dotfiles/hypr/scripts/lock.sh" },
        { label: "Sleep",     icon: "sleep",  cmd: "systemctl suspend" },
        { label: "Log out",   icon: "logout", cmd: "hyprctl dispatch exit" },
        { label: "Reboot",    icon: "reboot", cmd: "systemctl reboot" },
        { label: "Shut down", icon: "power",  cmd: "systemctl poweroff" }
    ]

    // Scriptable, and the same handle the bar's power button uses:
    //     qs -c gelo ipc call power toggle
    IpcHandler {
        target: "power"

        function toggle(): void {
            Ui.powerMenuOpen = !Ui.powerMenuOpen;
        }
        function open(): void {
            Ui.powerMenuOpen = true;
        }
        function close(): void {
            Ui.powerMenuOpen = false;
        }
    }

    // Click-away.
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.powerMenuOpen = false
    }

    // Escape lives on a focusable Item: `Keys` is an Item attached property and
    // cannot attach to the window itself.
    Item {
        anchors.fill: parent
        focus: Ui.powerMenuOpen
        Keys.onEscapePressed: Ui.powerMenuOpen = false
    }

    Chrome {
        id: panel

        width: 200
        height: column.implicitHeight + Tokens.space.sm * 2

        // Under the power button, which lives at the right end of the bar.
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.lg
        y: Tokens.space.sm + 48 + Tokens.space.sm

        glowEnabled: false

        opacity: Ui.powerMenuOpen ? 1 : 0
        scale: Ui.powerMenuOpen ? 1 : 0.97

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        Column {
            id: column
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width

            Repeater {
                model: menu.entries

                delegate: Item {
                    id: row
                    required property var modelData

                    width: column.width
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space.sm
                        anchors.rightMargin: Tokens.space.sm
                        radius: Tokens.material.chrome.radius
                        color: rowMouse.containsMouse
                            ? Tokens.alpha(Tokens.color.bg2, 0.75)
                            : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.motion.duration.fast
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Tokens.motion.easeBezier
                            }
                        }
                    }

                    Icon {
                        id: rowIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.space.lg
                        size: 15
                        source: row.modelData.icon
                        color: Tokens.color.text2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: rowIcon.right
                        anchors.leftMargin: Tokens.space.md
                        text: row.modelData.label
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.body
                        font.letterSpacing: Tokens.tracking(Tokens.typography.size.body)
                        color: Tokens.color.text1
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Ui.powerMenuOpen = false;
                            Quickshell.execDetached(["sh", "-c", row.modelData.cmd]);
                        }
                    }
                }
            }
        }
    }
}
