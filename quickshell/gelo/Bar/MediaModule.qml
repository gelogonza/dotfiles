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

    // Fixed ceiling rather than free growth: a long title would otherwise push
    // the launchers around every time the track changed, which turns a status
    // readout into a layout jitter.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(label.implicitWidth, 220)
        height: label.implicitHeight

        Text {
            id: label
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText

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
