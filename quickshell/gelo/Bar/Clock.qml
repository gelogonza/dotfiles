// Centre of the bar: time large, date beside it.
//
// Sits above the active window title, which is the pair the eye actually wants
// in the middle — "when am I" and "what am I looking at".

import Quickshell
import QtQuick
import "root:/Theme"

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
}
