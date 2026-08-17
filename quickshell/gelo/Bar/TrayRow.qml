import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "root:/Theme"
import "root:/Components"

Row {
    id: root

    spacing: Tokens.space.md

    // Tray items to leave out, matched case-insensitively against the item's
    // `id` and `title`.
    //
    // A tray icon is a claim on permanent screen space, and these two do not
    // earn it: neither Claude nor NordVPN has anything to *report* — they are
    // launchers wearing a status icon, and both apps are one click away in the
    // dock. The tray is for state you would otherwise have to go and look up.
    //
    // Matched on substring because the ids are not stable: Claude registers as
    // `Claude_status_icon_1`, and that trailing counter goes up if the app is
    // restarted while the shell is running. Read the live values with
    // `id`/`title` from SystemTray.items — `title` is empty for Claude, so
    // matching on title alone would silently never fire.
    readonly property var ignore: ["claude", "nordvpn"]

    function ignored(item) {
        if (!item)
            return false;
        const hay = ((item.id || "") + " " + (item.title || "")).toLowerCase();
        for (let i = 0; i < ignore.length; i++) {
            if (hay.indexOf(ignore[i]) >= 0)
                return true;
        }
        return false;
    }

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry
            required property var modelData

            // Filtered here rather than by wrapping the model: SystemTray.items
            // is an ObjectModel with no filtering view, and QtQuick positioners
            // skip invisible children entirely — so this leaves no gap where the
            // icon would have been.
            visible: !root.ignored(modelData)

            width: visible ? 16 : 0
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            // TINTED, unlike the app launchers. Tray icons are supplied by
            // whatever application happens to be running and are frequently
            // white — which on this light bar renders them completely
            // invisible. Flattening them to the ink colour costs their brand
            // colour and guarantees they can be seen, which for a status tray
            // is the right trade.
            Icon {
                anchors.fill: parent
                source: entry.modelData.icon
                size: 16
                tinted: true
                color: mouse.containsMouse ? Tokens.color.text1 : Tokens.color.text2

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.motion.duration.fast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.motion.easeBezier
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.RightButton)
                        entry.modelData.secondaryActivate();
                    else
                        entry.modelData.activate();
                }
            }
        }
    }
}
