// Command palette.
//
// Reference is Raycast / Linear, not dmenu: one chrome slab floating in dimmed
// space, a search field that glows on focus, and result rows that arrive
// staggered rather than all at once. Opening it ripples the wallpaper.
//
// Opened over IPC so a Hyprland keybind can drive it:
//     qs -c gelo ipc call launcher toggle

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/Theme"
import "root:/Components"
import "root:/Services"

PanelWindow {
    id: launcher

    // Follows the focused monitor. Falls back to the first screen if Hyprland
    // has not reported a focused monitor yet, so the palette is never unopenable.
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

    property bool open: false

    // Stagger is an entrance flourish, not a per-keystroke effect. It plays when
    // the palette opens; while typing, rows swap in immediately.
    property bool staggering: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: open

    WlrLayershell.namespace: "gelo-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive
                                      : WlrKeyboardFocus.None

    function show() {
        // Clear the field, not Apps.query directly: the field is the source of
        // truth and its onTextChanged is what pushes the query down. Resetting
        // the query alone leaves stale text visible above unfiltered results.
        field.text = "";
        list.currentIndex = 0;
        open = true;
        staggering = true;
        staggerWindow.restart();
        field.forceActiveFocus();

        // Opening the palette is an interaction like any other: the motion
        // belongs in the field behind it.
        Ripples.emitFromItem(panel, launcher);
    }

    function hide() {
        open = false;
        field.text = "";
    }

    function toggle() {
        if (open)
            hide();
        else
            show();
    }

    Timer {
        id: staggerWindow
        interval: Tokens.motion.duration.slow
        onTriggered: launcher.staggering = false
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.toggle();
        }
        function open(): void {
            launcher.show();
        }
        function close(): void {
            launcher.hide();
        }

        // Open pre-filled, e.g. `qs -c gelo ipc call launcher search fire`.
        function search(query: string): void {
            launcher.show();
            field.text = query;
        }
    }

    // --- scrim ------------------------------------------------------------
    // Dimming the desktop is what makes the palette read as a modal surface
    // rather than as another panel. Built from `shade`: on the light palette
    // bg-0 is the lightest surface and would brighten rather than dim.
    Rectangle {
        anchors.fill: parent
        color: Tokens.alpha(Tokens.color.shade, 0.38)
        opacity: launcher.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.hide()
        }
    }

    // --- palette ----------------------------------------------------------
    Chrome {
        id: panel

        width: 640
        height: header.height + (list.count > 0 ? list.height + Tokens.space.sm : 0)

        anchors.horizontalCenter: parent.horizontalCenter
        // Sits above centre — a centred modal reads as heavier and slower.
        y: parent.height * 0.28

        // Deliberately NOT glowing. Glow means "this is the selected thing";
        // blooming the whole panel makes the container compete with its own
        // contents and turns the accent into decoration.
        glowEnabled: false

        opacity: launcher.open ? 1 : 0
        scale: launcher.open ? 1 : 0.97

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
        Behavior on height {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        // --- search field -------------------------------------------------
        Item {
            id: header
            width: parent.width
            height: 56

            Text {
                id: prompt
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Tokens.space.lg
                text: "›"
                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.title
                color: Tokens.color.text2
            }

            TextInput {
                id: field

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: prompt.right
                anchors.leftMargin: Tokens.space.md
                anchors.right: parent.right
                anchors.rightMargin: Tokens.space.lg

                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.title
                font.weight: Tokens.typography.weight.light
                color: Tokens.color.text1
                selectionColor: Tokens.alpha(Tokens.color.text1, 0.2)
                selectedTextColor: Tokens.color.text1

                onTextChanged: {
                    Apps.query = text;
                    list.currentIndex = 0;
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: field.text.length === 0
                    text: "Search applications"
                    font: field.font
                    color: Tokens.color.text2
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        launcher.hide();
                        event.accepted = true;
                        break;
                    case Qt.Key_Down:
                        list.incrementCurrentIndex();
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        list.decrementCurrentIndex();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (list.currentItem) {
                            Apps.launch(Apps.results[list.currentIndex]);
                            launcher.hide();
                        }
                        event.accepted = true;
                        break;
                    }
                }
            }

            // Hairline between field and results, inset so it does not touch
            // the glass edge where the corner curve begins.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Tokens.space.lg * 2
                height: 1
                color: Tokens.color.border
                visible: list.count > 0
            }
        }

        // --- results ------------------------------------------------------
        ListView {
            id: list

            anchors.top: header.bottom
            anchors.topMargin: Tokens.space.sm
            width: parent.width
            height: Math.min(contentHeight, 8 * 40)

            model: Apps.results
            currentIndex: 0
            clip: true
            interactive: contentHeight > height

            delegate: ResultRow {
                required property var modelData
                required property int index

                app: modelData
                rowIndex: index
                width: list.width
                selected: index === list.currentIndex
                staggered: launcher.staggering

                onActivated: {
                    Apps.launch(app);
                    launcher.hide();
                }
                onHovered: list.currentIndex = index
            }
        }
    }
}
