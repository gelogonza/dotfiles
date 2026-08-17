// Shared UI state.
//
// The bar and the overlay panels are separate Wayland surfaces and cannot reach
// into each other, but they are objects in one process — so a button in the bar
// opens a panel by flipping a property here rather than by owning it.

pragma Singleton

import Quickshell
import QtQuick

Singleton {
    property bool powerMenuOpen: false
    property bool dashboardOpen: false
    property bool miniPlayerOpen: false
}
