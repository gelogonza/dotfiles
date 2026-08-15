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
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "ddd d MMM")
        font.family: Tokens.typography.mono
        font.pixelSize: Tokens.typography.size.caption
        font.weight: Tokens.typography.weight.regular
        color: Tokens.color.text2
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.family: Tokens.typography.mono
        font.pixelSize: Tokens.typography.size.body
        font.weight: Tokens.typography.weight.medium
        color: Tokens.color.text1
    }
}
