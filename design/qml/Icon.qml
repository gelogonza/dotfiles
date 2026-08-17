//! SOURCE FILE — edit this one. `design/build-tokens.py` copies it into every
//! QML root that needs it, rewriting the Theme import per destination.
//! Lines starting with //! are stripped from the generated copies.
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
import "@THEME@"

Item {
    id: root

    // One of three things:
    //   "power"                  -> our own set, icons/power.svg
    //   "vscode"                 -> an application icon from the icon theme
    //   "file:///..." / URL      -> used as-is (this is what SystemTray hands over)
    property string source: ""

    // Where our own icons live, relative to the QML root. The two roots resolve
    // differently, hence the property rather than a constant.
    property string iconRoot: "@ICONROOT@"
    property color color: Tokens.color.text1
    property int size: 16

    // Tray icons are arbitrary third-party artwork. Tinting them flattens real
    // logos into silhouettes, which is right for a monochrome bar but wrong if
    // you would rather see the brand colours — hence the switch.
    property bool tinted: true

    // Names served by design/icons rather than by the system icon theme.
    //! Generated from the contents of design/icons by build-tokens.py — this
    //! used to be a hand-written list sitting next to the directory it was
    //! supposed to mirror, so adding an SVG was not enough to make it render.
    readonly property var ownIcons: [@OWNICONS@]

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

    //! Whether this source is one of ours, which decides how it gets tinted.
    readonly property bool ownSource: ownIcons.indexOf(source) >= 0

    MultiEffect {
        anchors.fill: image
        source: image
        visible: root.tinted && image.status === Image.Ready

        //! `colorization` alone does NOT recolour a black source. It scales
        //! toward `colorizationColor` by the source's own luminance, so black
        //! stays black however hard you colourise it — and every icon in
        //! design/icons is authored black-on-transparent, because that is the
        //! symbolic-icon convention. The whole set was rendering near-black
        //! instead of in the palette ink: measured #0d1b29 against a requested
        //! #1b4c78, with the solid shapes (the play triangle) coming out at
        //! literal #000000. It looked plausible on a light plate, which is why
        //! it survived this long.
        //!
        //! `brightness: 1.0` lifts the source to white first, after which
        //! colourisation lands exactly on the requested colour — measured
        //! #1b4c78 with no error.
        //!
        //! Applied ONLY to our own icons, and that distinction is the point.
        //! Tray icons are arbitrary third-party artwork whose luminance carries
        //! real structure — the Spotify logo's wave bars, for instance. Lifting
        //! those to white first flattens the logo to a featureless disc, which
        //! is recognisable as nothing. They keep plain colourisation, which
        //! already lands correctly for the white icons that made tray tinting
        //! necessary in the first place.
        //!
        //! An earlier comment here warned brightness "blows out any source that
        //! is already bright". That is true of a tray logo and false of a black
        //! symbolic glyph; the warning was right about the case it was written
        //! for and wrong as a blanket rule.
        brightness: root.ownSource ? 1.0 : 0.0
        colorization: 1.0
        colorizationColor: root.color
    }
}
