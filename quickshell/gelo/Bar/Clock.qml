// Centre of the bar: time large, date beside it.
//
// Sits above the active window title, which is the pair the eye actually wants
// in the middle — "when am I" and "what am I looking at".

import Quickshell
import QtQuick
import "root:/Theme"
import "root:/Services"

Row {
    id: root

    spacing: Tokens.space.sm

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.baseline: time.baseline
        text: Qt.formatDateTime(clock.date, "ddd d MMM")
        font.family: Tokens.typography.display
        font.pixelSize: Tokens.typography.size.caption
        font.weight: Tokens.typography.weight.light
        font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
        color: Tokens.color.text2
    }

    Text {
        id: time
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.family: Tokens.typography.display
        font.pixelSize: Tokens.typography.size.title
        font.weight: Tokens.typography.weight.regular
        color: Tokens.color.text1
    }

    // The date is the natural handle for a panel about dates.
    //
    // Handlers rather than a MouseArea: this root is a Row, so a MouseArea
    // child would both take a slot in the layout and trip "cannot specify
    // fill anchors for items inside Row". Pointer handlers do not participate
    // in positioner layout at all.
    TapHandler {
        onTapped: Ui.dashboardOpen = !Ui.dashboardOpen
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
