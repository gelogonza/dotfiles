// Month grid, and what is actually on.
//
// The grid answers "what is the date"; the list answers "what am I doing".
// Both matter and neither replaces the other — a month with dots on it tells
// you next Thursday is busy without telling you why.

import QtQuick
import "root:/Theme"
import "root:/Components"
import "root:/Services"

Chrome {
    // Floats over whatever window happens to be underneath.
    opaque: true
    id: card

    width: 320
    height: content.implicitHeight + Tokens.space.lg * 2

    // Recomputed whenever the panel opens, so the grid cannot be a day stale.
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    onVisibleChanged: if (visible) today = new Date()

    // Monday-first, which is what a week looks like when you have classes.
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1);
        const lead = (first.getDay() + 6) % 7;
        const days = new Date(viewYear, viewMonth + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++)
            out.push(null);
        for (let d = 1; d <= days; d++)
            out.push(d);
        return out;
    }

    function iso(d) {
        const m = String(viewMonth + 1).padStart(2, "0");
        return viewYear + "-" + m + "-" + String(d).padStart(2, "0");
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.space.lg
        anchors.rightMargin: Tokens.space.lg
        spacing: Tokens.space.sm

        Text {
            text: card.monthNames[card.viewMonth] + " " + card.viewYear
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.title
            color: Tokens.color.text1
        }

        Grid {
            columns: 7
            spacing: 0

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                delegate: Item {
                    required property var modelData
                    width: (content.width) / 7
                    height: 20
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.caption
                        color: Tokens.color.text2
                    }
                }
            }

            Repeater {
                model: card.cells
                delegate: Item {
                    id: cell
                    required property var modelData
                    width: content.width / 7
                    height: 30

                    readonly property bool isToday: modelData !== null
                        && modelData === card.today.getDate()
                        && card.viewMonth === card.today.getMonth()
                        && card.viewYear === card.today.getFullYear()
                    readonly property bool busy: modelData !== null
                        && Agenda.busyDays[card.iso(modelData)] === true

                    // Today blooms rather than getting a filled pill — the
                    // same selection language as everything else (design.md 5).
                    Glow {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        cornerRadius: 13
                        amount: cell.isToday ? 1 : 0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData === null ? "" : cell.modelData
                        font.family: Tokens.typography.display
                        font.pixelSize: Tokens.typography.size.caption
                        font.weight: cell.isToday
                            ? Tokens.typography.weight.regular
                            : Tokens.typography.weight.light
                        color: cell.isToday ? Tokens.color.text1 : Tokens.color.text2
                    }

                    // A day with something on it gets a mark, not a colour:
                    // colour would have to come from somewhere, and the accent
                    // is spent.
                    Rectangle {
                        visible: cell.busy && !cell.isToday
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Tokens.color.text2
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Tokens.color.border
        }

        Text {
            text: Agenda.configured ? "next up" : "calendar"
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            font.letterSpacing: Tokens.tracking(Tokens.typography.size.caption)
            color: Tokens.color.text2
        }

        // Not configured is the normal first-run state, so it explains itself
        // rather than showing an empty box.
        Text {
            width: parent.width
            visible: !Agenda.configured
            wrapMode: Text.WordWrap
            text: "Add ~/.config/gelo/calendars.json with the secret ICS address "
                + "of each Google or Outlook calendar. Kept outside this repo — "
                + "those links read your calendar to anyone who has them."
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            color: Tokens.color.text2
        }

        Text {
            width: parent.width
            visible: Agenda.configured && Agenda.events.length === 0
            text: Agenda.loading ? "Loading…" : "Nothing in the next fortnight."
            font.family: Tokens.typography.display
            font.pixelSize: Tokens.typography.size.caption
            color: Tokens.color.text2
        }

        Repeater {
            model: Agenda.events.slice(0, 6)

            delegate: Row {
                required property var modelData
                width: content.width
                spacing: Tokens.space.sm

                Text {
                    width: 52
                    text: modelData.time.length > 0 ? modelData.time : "all day"
                    font.family: Tokens.typography.display
                    font.pixelSize: Tokens.typography.size.caption
                    color: Tokens.color.text2
                }

                Text {
                    width: parent.width - 52 - Tokens.space.sm
                    text: modelData.summary
                    elide: Text.ElideRight
                    font.family: Tokens.typography.display
                    font.pixelSize: Tokens.typography.size.caption
                    color: Tokens.color.text1
                }
            }
        }
    }
}
