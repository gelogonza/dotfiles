// Now playing, from MPRIS.
//
// Spotify is essentially always running on this desk, and until now the bar had
// no idea. This is the same judgement as the git module: persistent bar space
// goes to what is actually true about this machine right now, not to a generic
// status strip.
//
// Deliberately no accent. Accent is spent on the workspace indicator, the
// focused window border and the cursor; hierarchy here is title in text-1,
// artist in text-2, exactly like the git module.

import QtQuick
import Quickshell.Services.Mpris
import "root:/Theme"
import "root:/Components"

Row {
    id: root

    spacing: Tokens.space.sm

    // Whichever player is actually playing wins; otherwise the first one that
    // has a track. Picking `players[0]` unconditionally means a paused browser
    // tab can outrank the thing you are listening to.
    readonly property var player: {
        const list = Mpris.players ? Mpris.players.values : [];
        let fallback = null;
        for (const p of list) {
            if (!p || !p.trackTitle || p.trackTitle.length === 0)
                continue;
            if (p.isPlaying)
                return p;
            if (!fallback)
                fallback = p;
        }
        return fallback;
    }

    readonly property bool active: player !== null && player !== undefined

    visible: active
    opacity: active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    Icon {
        id: toggle
        anchors.verticalCenter: parent.verticalCenter
        size: 16
        source: root.player && root.player.isPlaying ? "media-pause" : "media-play"
        // Paused is a quieter state, not a different colour family.
        color: root.player && root.player.isPlaying
            ? Tokens.color.text1
            : Tokens.color.text2

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: root.player && root.player.canTogglePlaying
            onClicked: root.player.togglePlaying()
        }
    }

    // A marquee, not an ellipsis.
    //
    // The width is FIXED rather than fitted to the text. A viewport that resized
    // per track would shove the workspace indicator sideways on every song, and
    // the whole reason the clock is absolutely centred is that things in this bar
    // must not move when their contents change.
    //
    // DEVIATION, on purpose: design.md 5 says motion lives in the wave field
    // behind the interface, not in the interface. A scrolling label breaks that.
    // It is allowed here because a track title is the one label in this system
    // that is routinely longer than the space it has, and the alternative —
    // eliding — hides the artist permanently rather than briefly.
    Item {
        id: viewport

        anchors.verticalCenter: parent.verticalCenter

        // Clipped, so the text is genuinely cut off at the edges instead of
        // being drawn over the workspace numbers and the plate's rounded corner.
        clip: true

        width: Tokens.material.marquee.width
        height: label.implicitHeight

        Text {
            id: label
            textFormat: Text.PlainText

            // No `width` and no `elide`: the Text takes its implicit width so
            // the animation has a real length to travel. Setting either one
            // would clamp it to the viewport and there would be nothing to
            // scroll.
            text: {
                if (!root.player)
                    return "";
                const title = root.player.trackTitle || "";
                const artist = root.player.trackArtist || "";
                return artist.length > 0 ? title + "  ·  " + artist : title;
            }

            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
            color: Tokens.color.text1

            // Parked off the right edge before the animation takes over, so the
            // first frame after a track change is never a flash of text sitting
            // at x=0.
            x: viewport.width
        }

        // Enters at the right edge, exits past the left, repeat. At the moment
        // it wraps the text is immediately off the right edge again, so there is
        // no dead gap where the readout is blank.
        //
        // Duration is derived from `speed` (px/second) rather than fixed, so a
        // long title takes longer instead of scrolling faster.
        NumberAnimation {
            id: scroll

            target: label
            property: "x"
            from: viewport.width
            to: -label.width
            duration: Math.max(Tokens.motion.duration.base,
                               (viewport.width + label.width)
                               / Tokens.material.marquee.speed * 1000)
            loops: Animation.Infinite
            running: root.active && label.text.length > 0
        }

        // `from`/`to` are read when a loop begins, so a new track would finish
        // the previous title's journey at the previous title's length before
        // picking up the new one. Restarting makes the change immediate — and a
        // new song should visibly start over rather than continue mid-scroll.
        Connections {
            target: label
            function onTextChanged() {
                if (scroll.running)
                    scroll.restart();
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: root.player && root.player.canRaise
            // Clicking the title brings the player forward — the thing you
            // want after reading a title is usually the player itself.
            onClicked: root.player.raise()
        }
    }
}
