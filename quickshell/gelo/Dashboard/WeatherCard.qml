// Weather, when it is enabled.
//
// Off by default in the token source, because turning it on means talking to a
// third party about where you are. The card says so rather than rendering an
// empty box.

import QtQuick
import "root:/Theme"
import "root:/Components"
import "root:/Services"

Chrome {
    // Floats over whatever window happens to be underneath.
    opaque: true
    width: 260
    height: content.implicitHeight + Tokens.space.lg * 2

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.space.lg
        anchors.rightMargin: Tokens.space.lg
        spacing: Tokens.space.sm

        Text {
            text: "weather"
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
            color: Tokens.color.text2
        }

        Row {
            spacing: Tokens.space.md
            visible: Weather.valid

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                source: Weather.icon
                size: 24
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.temperature + "°"
                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.title
                color: Tokens.color.text1
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.condition
                font.family: Tokens.typography.display
                font.pixelSize: Tokens.typography.size.caption
                color: Tokens.color.text2
            }
        }

        Text {
            width: parent.width
            visible: !Weather.valid
            wrapMode: Text.WordWrap
            text: Weather.enabled
                ? "No reading yet."
                : "Off. Set weather.enabled in design/tokens.json — it sends a request to a third party, and without a location that server geolocates you by IP."
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            color: Tokens.color.text2
        }
    }
}
