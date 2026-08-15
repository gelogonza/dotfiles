// CPU, memory and GPU load.
//
// CPU and memory come from /proc, which is free. GPU comes from nvidia-smi,
// which is a process spawn and is NOT free, so it polls on a slower timer and
// is skipped entirely when the machine has no NVIDIA GPU.
//
// Everything here is a percentage 0-100 so the bar module can treat the three
// identically.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int cpu: 0
    property int memory: 0
    property int gpu: -1          // -1 = no GPU / unavailable, so the module hides
    property int gpuMemory: -1

    readonly property bool hasGpu: gpu >= 0

    // --- CPU -------------------------------------------------------------
    // /proc/stat is cumulative since boot, so load is the DELTA between two
    // samples. A single reading tells you the average since power-on, which is
    // a number that barely moves and looks broken.
    property var _prev: null

    FileView {
        id: stat
        path: "/proc/stat"
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            root._sampleCpu();
            root._sampleMemory();
        }
    }

    function _sampleCpu() {
        const text = stat.text();
        if (!text)
            return;

        const line = text.split("\n")[0];          // aggregate "cpu" row
        const f = line.trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 4)
            return;

        const idle = f[3] + (f[4] || 0);           // idle + iowait
        const total = f.reduce((a, b) => a + b, 0);

        if (_prev) {
            const dt = total - _prev.total;
            const di = idle - _prev.idle;
            if (dt > 0)
                cpu = Math.max(0, Math.min(100, Math.round((1 - di / dt) * 100)));
        }
        _prev = { idle: idle, total: total };
    }

    function _sampleMemory() {
        const text = meminfo.text();
        if (!text)
            return;

        let total = 0;
        let available = 0;
        for (const line of text.split("\n")) {
            if (line.startsWith("MemTotal:"))
                total = Number(line.split(/\s+/)[1]);
            else if (line.startsWith("MemAvailable:"))
                available = Number(line.split(/\s+/)[1]);
            if (total && available)
                break;
        }

        // MemAvailable, not MemFree: free excludes cache and reclaimable slab,
        // so it reports a machine with a warm page cache as nearly full.
        if (total > 0)
            memory = Math.round((1 - available / total) * 100);
    }

    // --- GPU -------------------------------------------------------------
    Process {
        id: gpuProc
        command: ["nvidia-smi",
                  "--query-gpu=utilization.gpu,memory.used,memory.total",
                  "--format=csv,noheader,nounits"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",").map(s => Number(s.trim()));
                if (parts.length < 3 || isNaN(parts[0])) {
                    root.gpu = -1;
                    return;
                }
                root.gpu = Math.round(parts[0]);
                root.gpuMemory = parts[2] > 0
                    ? Math.round(parts[1] / parts[2] * 100)
                    : -1;
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.gpu = -1;
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!gpuProc.running)
                gpuProc.running = true;
        }
    }
}
