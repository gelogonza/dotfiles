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
    readonly property var ownIcons: ["bluetooth-off", "bluetooth-on", "clipboard", "image", "lock", "logout", "media-next", "media-pause", "media-play", "media-previous", "media-shuffle", "power", "reboot", "sleep", "sleep-off", "volume-high", "volume-low", "volume-medium", "volume-muted", "weather-clear", "weather-clouds", "weather-fog", "weather-overcast", "weather-showers", "weather-snow", "weather-storm"]

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: image
        anchors.fill: parent
        implicitSize: root.size
        source: {
            if (root.source.length === 0)
                return "";
            // Already a URL — SystemTray items arrive like this.
            if (root.source.indexOf(":") >= 0)
                return root.source;

            // An absolute path needs the file: scheme. Without it IconImage
            // resolves it against qrc: and silently renders nothing — which is
            // how desktop entries that use a full icon path (gpsd, some
            // bundled apps) came out blank.
            if (root.source.startsWith("/"))
                return "file://" + root.source;

            if (root.source.indexOf("/") >= 0)
                return root.source;
            // Our own set takes precedence over the icon theme.
            if (root.ownIcons.indexOf(root.source) >= 0)
                return root.iconRoot + root.source + ".svg";
            return Quickshell.iconPath(root.source, true);
        }
        visible: !root.tinted
        smooth: true
    }

    readonly property bool ownSource: ownIcons.indexOf(source) >= 0

    MultiEffect {
        anchors.fill: image
        source: image
        visible: root.tinted && image.status === Image.Ready

        brightness: root.ownSource ? 1.0 : 0.0
        colorization: 1.0
        colorizationColor: root.color
    }
}
