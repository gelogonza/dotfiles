// Git context of the focused window.
//
// This is the module that makes the bar specific to the person using it rather
// than a generic clock-and-battery strip. It answers "what am I actually working
// on right now", which for this desk is the only status worth persistent space.
//
// Deliberately no accent colour: accent is spent on the workspace indicator,
// the focused window border and the cursor. Hierarchy here is carried by
// text-1 vs text-2 and by weight alone.

import QtQuick
import "root:/Theme"
import "root:/Services"

Row {
    id: root

    spacing: Tokens.space.sm
    visible: Git.valid
    opacity: Git.valid ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        // U+E0A0 — the powerline branch glyph, present in JetBrains Mono Nerd Font.
        text: " " + Git.branch
        font.family: Tokens.typography.mono
        font.pixelSize: Tokens.typography.size.caption
        font.weight: Tokens.typography.weight.medium
        color: Tokens.color.text1
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: Git.dirty > 0
        text: "+" + Git.dirty
        font.family: Tokens.typography.mono
        font.pixelSize: Tokens.typography.size.caption
        color: Tokens.color.text2
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Git.commit
        font.family: Tokens.typography.mono
        font.pixelSize: Tokens.typography.size.caption
        color: Tokens.color.text2
    }
}
