// GENERATED FILE — DO NOT EDIT. Source: design/qml/Icon.qml (run design/build-tokens.py)
// Icon — a symbolic icon rendered in a palette colour.
//
// Symbolic icons (Adwaita's `*-symbolic` set) are single-colour glyphs designed
// to be recoloured by the consumer. They ship black, which on this light bar is
// legible but wrong, and third-party tray icons ship whatever they like — often
// white, which on a light bar is invisible.
//
// Colourising a blur was the wrong tool for the selection bloom (see Glow.qml)
// but it is exactly right here: these are flat monochrome shapes with no
// internal colour to preserve, so a full colourisation just restates the
// silhouette in the tint.
//
//     Icon { source: "audio-volume-high-symbolic"; color: Tokens.color.text1 }

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../Theme"

Item {
    id: root

    // One of three things:
    //   "power"                  -> our own set, icons/power.svg
    //   "vscode"                 -> an application icon from the icon theme
    //   "file:///..." / URL      -> used as-is (this is what SystemTray hands over)
    property string source: ""

    // Where our own icons live, relative to the QML root. The two roots resolve
    // differently, hence the property rather than a constant.
    property string iconRoot: "../icons/"
    property color color: Tokens.color.text1
    property int size: 16

    // Tray icons are arbitrary third-party artwork. Tinting them flattens real
    // logos into silhouettes, which is right for a monochrome bar but wrong if
    // you would rather see the brand colours — hence the switch.
    property bool tinted: true

    // Names served by design/icons rather than by the system icon theme.
    readonly property var ownIcons: [
        "volume-high", "volume-medium", "volume-low", "volume-muted",
        "bluetooth-on", "bluetooth-off",
        "power", "lock", "logout", "reboot",
        "weather-clear", "weather-clouds", "weather-overcast",
        "weather-showers", "weather-snow", "weather-storm", "weather-fog"
    ]

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: image
        anchors.fill: parent
        implicitSize: root.size
        source: {
            if (root.source.length === 0)
                return "";
            // Already a path or URL — SystemTray items arrive like this.
            if (root.source.indexOf("/") >= 0 || root.source.indexOf(":") >= 0)
                return root.source;
            // Our own set takes precedence over the icon theme.
            if (root.ownIcons.indexOf(root.source) >= 0)
                return root.iconRoot + root.source + ".svg";
            return Quickshell.iconPath(root.source, true);
        }
        visible: !root.tinted
        smooth: true
    }

    MultiEffect {
        anchors.fill: image
        source: image
        visible: root.tinted && image.status === Image.Ready

        // Full colourisation replaces hue outright while keeping the alpha
        // silhouette, which is the whole point here.
        //
        // Do NOT add `brightness` to this. Lifting it fixes nothing and blows
        // out any source that is already bright — tray icons are frequently
        // white, and at brightness 1.0 they came back as pale washes rather
        // than the ink colour they were asked for.
        colorization: 1.0
        colorizationColor: root.color
    }
}
