// The dock.
//
// The pinned launchers used to live in the bar's left cluster, next to the
// workspace indicator. That put five pieces of outside colour — real app logos,
// deliberately untinted — permanently adjacent to the one element allowed to
// carry the accent, and the bar had to stay quiet around them. Moving them out
// gives the launchers room to be recognisable and gives the bar back its left
// edge.
//
// It hides because a dock that is always up is a strip of screen you have
// stopped seeing. The reveal is the whole interaction: `revealStrip` pixels of
// live screen at the bottom edge, and everything else is click-through.
//
// INPUT MASK — READ THIS BEFORE CHANGING THE GEOMETRY:
//
// A layer surface captures the pointer across its entire area regardless of
// what it paints, so an unmasked full-width panel here would eat every click
// along the bottom of the screen. `mask` narrows the input region to the strip
// while hidden and to `hitArea` while open.
//
// `hitArea` deliberately spans from the top of the plate all the way down to
// the screen edge, rather than just the plate: the plate floats above the
// bottom margin, so a mask covering only the plate would exclude the very strip
// the pointer is standing on at the moment of reveal — the hover would drop,
// the dock would hide, and it would oscillate.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/Theme"
import "root:/Components"
import "root:/Services"

PanelWindow {
    id: dock

    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }

    color: "transparent"

    // Reserves no space. The dock overlaps windows rather than shrinking them,
    // which is the whole point of it hiding.
    exclusiveZone: 0

    implicitHeight: plate.height + Tokens.space.sm

    WlrLayershell.namespace: "gelo-dock"

    // Overlay, not Top like the bar. Hyprland renders a fullscreen window
    // *above* the top layer, so on Top the dock would be unreachable in exactly
    // the case where reaching for the bottom edge is most likely — a fullscreen
    // video or a maximised editor. The 6px input mask is what makes this safe:
    // an Overlay surface that swallowed the whole bottom edge would be
    // intolerable, one that swallows 6px is not noticeable.
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property var d: Tokens.material.dock

    // Pinned entries.
    //
    //   icon   desktop-entry icon name, resolved by Components/Icon
    //   exec   what a click runs when nothing is open
    //   match  window-class prefixes that count as "this app is running"
    //
    // `match` exists because the icon name and the window class disagree more
    // often than not — VS Code ships its icon as `vscode` and reports its class
    // as `code`.
    readonly property var apps: [
        { icon: "com.mitchellh.ghostty", exec: "ghostty",              match: ["com.mitchellh.ghostty"] },
        { icon: "vscode",                exec: "code",                 match: ["code", "visual-studio-code"] },
        { icon: "google-chrome",         exec: "google-chrome-stable", match: ["google-chrome", "chromium"] },
        { icon: "obsidian",              exec: "obsidian",             match: ["obsidian"] },
        { icon: "blender",               exec: "blender",              match: ["blender"] }
    ]

    // --- reveal -----------------------------------------------------------

    // Local pointer state. The visible state ORs this with the scripted flag —
    // see Services/DockState.qml for why the IPC handler cannot live here.
    property bool hovering: false

    readonly property bool open: hovering || DockState.forced

    // Leaving is delayed, arriving is not: a dock that waits before opening
    // feels broken, and one that closes the instant the pointer crosses the gap
    // between two icons feels twitchy.
    Timer {
        id: hideTimer
        interval: dock.d.hideDelay
        onTriggered: dock.hovering = false
    }

    function reveal() {
        hideTimer.stop();
        hovering = true;
    }

    function dismiss() {
        hideTimer.restart();
    }

    // Only the strip is live while hidden. `item` is switched rather than the
    // region animated — an input region that followed the slide would let the
    // dock be dismissed by its own animation moving out from under the pointer.
    mask: Region {
        item: dock.open ? hitArea : strip
    }

    // The always-live band. Wider than the plate by one step on each side, so
    // arriving diagonally from above does not require hitting the plate's exact
    // horizontal extent.
    Item {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: plate.width + Tokens.space.xl * 2
        height: dock.d.revealStrip
    }

    Item {
        id: hitArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: plate.width + Tokens.space.xl * 2
        height: dock.height
    }

    HoverHandler {
        // Anchored to the window, but only the masked-in part can ever receive
        // an event — so while hidden this is effectively the strip.
        onHoveredChanged: hovered ? dock.reveal() : dock.dismiss()
    }

    // --- the plate --------------------------------------------------------

    Chrome {
        id: plate

        // Floats over arbitrary windows, so it takes the opaque material for
        // the same reason the dashboard cards do — 96% chrome reads as a ghost
        // over a dark editor.
        opaque: true
        glowEnabled: false

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.space.sm

        width: row.width + dock.d.padding * 2
        height: row.height + dock.d.padding * 2

        // Slides down by its own height plus the margin, which puts it fully
        // off-screen rather than leaving a sliver of chrome showing.
        transform: Translate {
            y: dock.open ? 0 : plate.height + Tokens.space.sm

            Behavior on y {
                NumberAnimation {
                    duration: Tokens.motion.duration.base
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.motion.easeBezier
                }
            }
        }

        opacity: dock.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.base
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.motion.easeBezier
            }
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: dock.d.gap

            Repeater {
                model: dock.apps

                delegate: Item {
                    id: entry
                    required property var modelData

                    // The slot is always the hovered size, so neighbours do not
                    // shuffle sideways when one icon grows. Magnification
                    // happens inside a fixed box.
                    //
                    // The extra height is where the reflection lands. Reflection
                    // draws its mirror *below* its own bounds, so without room
                    // reserved here it would spill past the plate.
                    //
                    // Two thirds of the mirror's nominal height, not all of it:
                    // the gradient mask has taken it to near-zero well before
                    // the end, and reserving the full 55% pushed the running
                    // indicator so far from its icon that it read as belonging
                    // to the plate instead.
                    width: dock.d.iconHover
                    height: dock.d.iconHover
                        + Math.round(dock.d.iconHover * Tokens.material.reflection.heightRatio * 0.66)
                        + dock.d.indicatorSize

                    readonly property var openWindows: Windows.matching(modelData.match)
                    readonly property bool running: openWindows.length > 0

                    // Growing the box rather than scaling the image keeps the
                    // logo on the pixel grid — Icon feeds `size` to IconImage
                    // as a render resolution, so it is re-rasterised rather
                    // than resampled.
                    // Not `readonly` — a Behavior needs somewhere to write the
                    // intermediate values, and QML rejects the animation on a
                    // read-only property rather than ignoring it.
                    property int iconSize: hover.hovered
                        ? dock.d.iconHover
                        : dock.d.iconRest

                    Behavior on iconSize {
                        NumberAnimation {
                            duration: Tokens.motion.duration.fast
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Tokens.motion.easeBezier
                        }
                    }

                    Reflection {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: (dock.d.iconHover - entry.iconSize) / 2

                        width: entry.iconSize
                        height: entry.iconSize

                        Icon {
                            anchors.fill: parent

                            // Real logos, untinted. The dock is the one place
                            // outside colour is allowed — flattening these to
                            // silhouettes would make five blue smudges you
                            // have to read rather than recognise.
                            source: entry.modelData.icon
                            size: entry.iconSize
                            tinted: false
                            opacity: hover.hovered ? 1.0 : dock.d.restOpacity

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Tokens.motion.duration.fast
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Tokens.motion.easeBezier
                                }
                            }
                        }
                    }

                    // Running indicator.
                    //
                    // A dot in text-2, not the accent: the accent is spent on
                    // three things system-wide (design.md §3) and "an app is
                    // open" is not one of them. Same mark the calendar uses for
                    // a day with something on it, for the same reason — it says
                    // "there is something here" without competing.
                    //
                    // It widens into a bar for more than one window rather than
                    // multiplying into a row of dots, which stops being
                    // countable at three and starts being texture.
                    Rectangle {
                        visible: entry.running
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom

                        width: entry.openWindows.length > 1
                            ? dock.d.indicatorSize * 3
                            : dock.d.indicatorSize
                        height: dock.d.indicatorSize
                        radius: dock.d.indicatorSize / 2
                        color: Tokens.color.text2

                        Behavior on width {
                            NumberAnimation {
                                duration: Tokens.motion.duration.fast
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Tokens.motion.easeBezier
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    // Focus what is already open; launch only when nothing is.
                    // Clicking a running app and getting a second copy of it is
                    // the thing an indicator exists to prevent — you can see it
                    // is open, so the click means "show me it".
                    //
                    // Middle-click always launches a new instance.
                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onTapped: (point, button) => {
                            if (button === Qt.MiddleButton || !entry.running)
                                Quickshell.execDetached(["sh", "-c", entry.modelData.exec]);
                            else
                                Windows.activate(entry.openWindows[0]);

                            Ripples.emitFromItem(entry, dock);
                        }
                    }
                }
            }
        }
    }

}
