import QtQuick
import "root:/Theme"
import "root:/Components"
import "root:/Services"

Row {
    id: root

    spacing: Tokens.space.xs
    visible: Weather.valid

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        source: Weather.icon
        size: 15
        color: Tokens.color.text2
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Weather.temperature + "°"
        font.family: Tokens.typography.display
        font.pixelSize: Tokens.typography.size.caption
        color: Tokens.color.text1
    }

    // Only shown when there is actually precipitation — a permanent "0mm" is
    // noise, and this row is glanced at rather than read.
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: Weather.precipitation > 0
        text: Weather.precipitation + "mm"
        font.family: Tokens.typography.display
        font.pixelSize: Tokens.typography.size.caption
        color: Tokens.color.text2
    }
}
