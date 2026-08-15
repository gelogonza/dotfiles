// Ripple bus — carries interaction points from the UI surfaces down to the
// wallpaper shader.
//
// In the XMB language, motion lives in the wave field BEHIND the interface, not
// in the interface. Elements do not deform, stretch or slide. When you switch a
// workspace or open the launcher, the thing that moves is the background.
//
// The bar, the launcher and the notification layer are separate Wayland
// surfaces and cannot draw into each other — but they are all objects in one
// Quickshell process, so a singleton is enough to get an interaction point from
// the bar into the wallpaper's shader uniforms.
//
// Ripples are held in a fixed-size ring because the shader reads a fixed-size
// uniform array; `maxConcurrent` is the same token on both sides.

pragma Singleton

import Quickshell
import QtQuick
import QtQuick.Window
import "root:/Theme"

Singleton {
    id: root

    readonly property int capacity: Tokens.material.ripple.maxConcurrent

    // Each entry: { x, y, t } — x/y normalised to the screen, t in the same
    // seconds-since-start clock the wallpaper animates on.
    property var slots: []

    // Monotonic seconds. The wallpaper drives this so ripple ages and the wave
    // field share one clock; otherwise ripples would drift out of phase with
    // the background they are supposed to be part of.
    property real now: 0

    Component.onCompleted: {
        const initial = [];
        for (let i = 0; i < capacity; i++)
            initial.push({ x: 0, y: 0, t: -1000 });
        slots = initial;
    }

    property int _next: 0

    // Normalised screen coordinates, 0..1.
    function emit(nx, ny) {
        if (slots.length === 0)
            return;

        const copy = slots.slice();
        copy[_next] = { x: nx, y: ny, t: now };
        slots = copy;
        _next = (_next + 1) % capacity;
    }

    // Resolve an item's centre to normalised screen coordinates and fire.
    //
    // The window must be passed in. Quickshell's PanelWindow is not a plain
    // QQuickWindow, so the `Window` attached property does not resolve from its
    // children — `item.Window.window` is null inside a layer surface.
    //
    // mapToItem(null) then gives coordinates inside the layer surface, and
    // mapToGlobal does NOT account for a layer surface's margins, so the
    // surface's own on-screen origin is derived from its anchors.
    function emitFromItem(item, win) {
        if (!item || !win)
            return;

        const screen = win.screen;
        if (!screen || screen.width <= 0 || screen.height <= 0)
            return;

        const local = item.mapToItem(null, item.width / 2, item.height / 2);

        let ox = 0;
        let oy = 0;

        if (win.anchors.left)
            ox = win.margins.left;
        else if (win.anchors.right)
            ox = screen.width - win.margins.right - win.width;
        else
            ox = (screen.width - win.width) / 2;

        if (win.anchors.top)
            oy = win.margins.top;
        else if (win.anchors.bottom)
            oy = screen.height - win.margins.bottom - win.height;
        else
            oy = (screen.height - win.height) / 2;

        emit((ox + local.x) / screen.width, (oy + local.y) / screen.height);
    }
}
