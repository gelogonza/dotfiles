// Default audio sink.
//
// Pipewire node properties are only live while something is tracking the node —
// without PwObjectTracker the volume reads once and then never updates, which
// looks like a broken widget rather than a missing subscription.

pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null

    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : true

    // 0-100 for display.
    readonly property int percent: Math.round(volume * 100)

    function setVolume(v) {
        if (!ready)
            return;
        // Clamp: Pipewire will happily accept >1.0 (software boost), which is a
        // good way to destroy your ears via a stray scroll event.
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function adjust(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    readonly property string icon: {
        if (!ready || muted)
            return "volume-muted";
        if (percent < 34)
            return "volume-low";
        if (percent < 67)
            return "volume-medium";
        return "volume-high";
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
