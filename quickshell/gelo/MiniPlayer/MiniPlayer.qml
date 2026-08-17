// The mini player.
//
// Drops out from under the left bar plate when you click the now-playing
// readout. The bar itself stays exactly as it was — a pause glyph and a
// scrolling title — because the bar is glanceable and this is not: transport
// controls are something you go to deliberately.
//
// Separate overlay surface for the same reason the power menu and dashboard are:
// the bar is 48px with an exclusive zone, so anything drawn inside it is clipped
// to that strip.
//
// THERE IS NO QUEUE, AND THAT IS NOT AN OVERSIGHT:
//
// MPRIS exposes a queue only through the optional
// `org.mpris.MediaPlayer2.TrackList` interface. Verified on the live bus —
// Spotify reports `HasTrackList = false` and does not implement the interface at
// all. Quickshell's Mpris module has no TrackList binding either, so there is
// nothing to read even for a player that does implement it. Spotify's real queue
// is Web-API-only and would need an OAuth app registration, a token refresh and
// a network round-trip, which is a different project from a shell panel.
//
// The panel does not mention it either. A line of apology about somebody else's
// D-Bus interface is not information you need every time you skip a track — the
// constraint belongs here and in the README, not on screen.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "root:/Theme"
import "root:/Components"
import "root:/Services"

PanelWindow {
    id: mini

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

    anchors { top: true; bottom: true; left: true; right: true }

    color: "transparent"
    visible: Ui.miniPlayerOpen

    WlrLayershell.namespace: "gelo-miniplayer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Ui.miniPlayerOpen ? WlrKeyboardFocus.OnDemand
                                                   : WlrKeyboardFocus.None

    readonly property var m: Tokens.material.miniPlayer

    // The same selection the bar makes, from the same service — including the
    // browser filter, so this panel cannot end up controlling a Reddit tab.
    readonly property var player: Media.player

    readonly property bool has: Media.active

    // Closes itself if the music stops existing, rather than sitting there with
    // dead controls.
    onHasChanged: if (!has) Ui.miniPlayerOpen = false

    IpcHandler {
        target: "player"

        function toggle(): void { Ui.miniPlayerOpen = !Ui.miniPlayerOpen; }
        function open(): void { Ui.miniPlayerOpen = true; }
        function close(): void { Ui.miniPlayerOpen = false; }
    }

    // Click-away.
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.miniPlayerOpen = false
    }

    // Escape lives on a focusable Item: `Keys` is an Item attached property and
    // does not resolve on the window itself.
    Item {
        anchors.fill: parent
        focus: mini.visible
        Keys.onEscapePressed: Ui.miniPlayerOpen = false
    }

    Chrome {
        id: panel

        // Floats over arbitrary windows, so it takes the opaque material for the
        // same reason the dashboard cards do.
        opaque: true
        glowEnabled: false
        cornerRadius: Tokens.material.bar.radius

        width: mini.m.width
        height: content.implicitHeight + Tokens.space.lg * 2

        // Under the left plate, whose left edge is the bar's own left margin.
        //
        // `y` is one gap, NOT bar height + gaps. This surface respects the bar's
        // exclusive zone, so the compositor has already placed its origin below
        // the bar — measured at y=56 on a 48px bar with an 8px top margin. Adding
        // the bar's height again put the panel 64px adrift, floating in the middle
        // of nothing. One gap here means the same 8px below the bar that the bar
        // has above itself, and it stays correct if the bar height changes.
        anchors.left: parent.left
        anchors.leftMargin: Tokens.space.lg
        y: Tokens.space.sm

        opacity: Ui.miniPlayerOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        // Swallow clicks so they do not reach the dismiss layer underneath.
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.space.lg
            anchors.rightMargin: Tokens.space.lg
            spacing: Tokens.space.md

            // --- art, title, artist, album --------------------------------

            Row {
                width: parent.width
                spacing: Tokens.space.md

                Rectangle {
                    width: mini.m.artSize
                    height: mini.m.artSize
                    radius: Tokens.radius.sm
                    color: Tokens.color.bg2
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: mini.player ? (mini.player.trackArtUrl || "") : ""

                        // PreserveAspectFit, not Crop. Album art is the one image
                        // in this system that is somebody else's composition, and
                        // cropping it to a square is editing it.
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true

                        // Spotify serves cover art from its own CDN, so this is a
                        // network request — to the vendor whose audio is already
                        // streaming, which is why it does not get the opt-in the
                        // weather module has.
                        visible: status === Image.Ready
                    }
                }

                Column {
                    width: parent.width - mini.m.artSize - Tokens.space.md
                    spacing: 2

                    Text {
                        width: parent.width
                        text: mini.player ? (mini.player.trackTitle || "") : ""
                        elide: Text.ElideRight
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.body
                        color: Tokens.color.text1
                    }

                    Text {
                        width: parent.width
                        text: mini.player ? (mini.player.trackArtist || "") : ""
                        elide: Text.ElideRight
                        visible: text.length > 0
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.caption
                        color: Tokens.color.text2
                    }

                    Text {
                        width: parent.width
                        text: mini.player ? (mini.player.trackAlbum || "") : ""
                        elide: Text.ElideRight
                        visible: text.length > 0
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.caption
                        font.weight: Tokens.typography.weight.light
                        color: Tokens.color.text2
                    }
                }
            }

            // --- playback -------------------------------------------------

            Item {
                width: parent.width
                height: elapsed.implicitHeight + Tokens.space.sm + mini.m.trackHeight
                visible: mini.player && mini.player.lengthSupported

                // Position does not tick on its own — the player publishes it on
                // change, not on a clock. Polling it is the supported way to get
                // a moving progress bar, and 500ms is under the eye's threshold
                // for a 3px track while staying cheap.
                Timer {
                    interval: 500
                    repeat: true
                    running: mini.visible && mini.player && mini.player.isPlaying
                    onTriggered: if (mini.player) mini.player.positionChanged()
                }

                Rectangle {
                    id: track
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: mini.m.trackHeight
                    radius: height / 2
                    color: Tokens.alpha(Tokens.color.text2, 0.35)

                    Rectangle {
                        width: {
                            const len = mini.player ? mini.player.length : 0;
                            if (!len || len <= 0)
                                return 0;
                            const f = Math.max(0, Math.min(1, mini.player.position / len));
                            return parent.width * f;
                        }
                        height: parent.height
                        radius: height / 2

                        // Elevation and ink, not accent — the accent is spent
                        // (design.md 3) and a progress bar is not one of the
                        // three places.
                        color: Tokens.color.text1
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -Tokens.space.sm
                        anchors.bottomMargin: -Tokens.space.sm
                        enabled: mini.player && mini.player.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        function seekTo(mx) {
                            if (!mini.player || !mini.player.length)
                                return;
                            const f = Math.max(0, Math.min(1, mx / width));
                            mini.player.position = f * mini.player.length;
                        }

                        onPressed: mouse => seekTo(mouse.x)
                        onPositionChanged: mouse => { if (pressed) seekTo(mouse.x); }
                    }
                }

                Text {
                    id: elapsed
                    anchors.top: parent.top
                    anchors.left: parent.left
                    text: Media.clock(mini.player ? mini.player.position : 0)
                    font.family: Tokens.typography.display
                    font.pixelSize: Tokens.typography.size.caption
                    color: Tokens.color.text2
                }

                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    text: Media.clock(mini.player ? mini.player.length : 0)
                    font.family: Tokens.typography.display
                    font.pixelSize: Tokens.typography.size.caption
                    color: Tokens.color.text2
                }
            }

            // --- transport ------------------------------------------------

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.space.lg

                Repeater {
                    model: [
                        { icon: "media-previous", act: "previous" },
                        { icon: "",               act: "toggle" },
                        { icon: "media-next",     act: "next" },
                        { icon: "media-shuffle",  act: "shuffle" }
                    ]

                    delegate: Item {
                        id: btn
                        required property var modelData

                        width: mini.m.controlSize
                        height: mini.m.controlSize

                        readonly property bool enabled: mini.controlEnabled(modelData.act)

                        // Shuffle is a *state*, not an action, so it reads as on
                        // or off rather than only responding to being pressed.
                        readonly property bool engaged: modelData.act === "shuffle"
                            && mini.player && mini.player.shuffle

                        Icon {
                            anchors.fill: parent
                            size: mini.m.controlSize

                            source: btn.modelData.act === "toggle"
                                ? (mini.player && mini.player.isPlaying
                                   ? "media-pause" : "media-play")
                                : btn.modelData.icon

                            color: !btn.enabled ? Tokens.alpha(Tokens.color.text2, 0.4)
                                 : (hover.hovered || btn.engaged) ? Tokens.color.text1
                                                                  : Tokens.color.text2

                            Behavior on color {
                                ColorAnimation {
                                    duration: Tokens.motion.duration.fast
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Tokens.motion.easeBezier
                                }
                            }
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: btn.enabled ? Qt.PointingHandCursor
                                                     : Qt.ArrowCursor
                        }

                        TapHandler {
                            enabled: btn.enabled
                            onTapped: mini.act(btn.modelData.act)
                        }
                    }
                }
            }
        }
    }

    // --- helpers ----------------------------------------------------------

    function controlEnabled(act) {
        const p = player;
        if (!p)
            return false;
        switch (act) {
        case "previous": return p.canGoPrevious;
        case "next":     return p.canGoNext;
        case "toggle":   return p.canTogglePlaying;
        case "shuffle":  return p.shuffleSupported;
        }
        return false;
    }

    function act(a) {
        const p = player;
        if (!p)
            return;
        switch (a) {
        case "previous": p.previous(); break;
        case "next":     p.next(); break;
        case "toggle":   p.togglePlaying(); break;
        case "shuffle":  p.shuffle = !p.shuffle; break;
        }
    }
}
