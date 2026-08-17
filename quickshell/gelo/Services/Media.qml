// Which MPRIS player counts as "my music", and which one is showing.
//
// Two surfaces need this answer — the bar readout and the mini player — and they
// must never disagree: a panel whose transport controls drive a different player
// from the title above them is worse than no panel. So the selection lives here
// once rather than being written twice.

pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Players that are not music, and must never appear.
    //
    // A browser registers an MPRIS player for *any* page with media on it, and
    // reports the PAGE TITLE as the track. That is how the bar ended up scrolling
    //
    //     [Hyprland] Some fun CSS tricks ... : r/unixporn
    //
    // as though it were a song. It is the same information the window title used
    // to show, arriving through a different door.
    //
    // Matched as a substring of desktopEntry + identity + dbusName, lowercased,
    // because which of the three is populated varies by player. `chrom` covers
    // Chrome and Chromium; verified against the live bus, where Chrome appears as
    // `chromium.instance4576` and Spotify as plain `spotify`.
    //
    // The trade is explicit: YouTube Music in a tab will not show up either.
    // Delete the token if you want it back.
    readonly property var ignore: [
        "chrom", "firefox", "librewolf", "brave", "edge", "epiphany"
    ]

    function isMusic(p) {
        if (!p)
            return false;
        const hay = ((p.desktopEntry || "") + " " + (p.identity || "")
                     + " " + (p.dbusName || "")).toLowerCase();
        for (let i = 0; i < ignore.length; i++) {
            if (hay.indexOf(ignore[i]) >= 0)
                return false;
        }
        return true;
    }

    // Whichever player is actually playing wins; otherwise the first one that has
    // a track. Picking `players[0]` unconditionally means a paused player can
    // outrank the thing you are listening to.
    readonly property var player: {
        const list = Mpris.players ? Mpris.players.values : [];
        let fallback = null;
        for (const p of list) {
            if (!p || !p.trackTitle || p.trackTitle.length === 0)
                continue;
            if (!root.isMusic(p))
                continue;
            if (p.isPlaying)
                return p;
            if (!fallback)
                fallback = p;
        }
        return fallback;
    }

    readonly property bool active: player !== null && player !== undefined

    // SECONDS, not microseconds.
    //
    // The MPRIS wire format is microseconds — `busctl` shows Position=69776000
    // and mpris:length=413346000 for a 6:53 track — but Quickshell converts on
    // the way in and hands over seconds. Dividing by a million here produced a
    // confident, wrong `0:00` for both readouts while the progress bar filled
    // correctly, because the bar only ever uses the ratio.
    function clock(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + String(s).padStart(2, "0");
    }
}
