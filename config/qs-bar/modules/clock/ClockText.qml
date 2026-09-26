import QtQuick
import qs.config
import qs.components

// Bar item: time and date. Left click opens the calendar (the bar wires
// `clicked` to its popout).
Item {
    id: root

    property bool active
    signal clicked

    implicitWidth: row.implicitWidth + 32
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        // Always a pill; a touch bluer while the calendar is open.
        color: root.active ? Theme.c.blue7 : Theme.c.bgHighlight

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            radius: parent.radius
            onClicked: root.clicked()
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 10

        StyledText {
            text: Time.format("h:mm AP")
            font.pixelSize: Theme.font.bar
            font.weight: Font.DemiBold
            font.features: ({ tnum: 1 })
            color: Theme.c.blue
        }
        StyledText {
            text: Time.format("ddd, MMM d")
            font.pixelSize: Theme.font.bar
            color: Theme.c.fgDark
        }
    }
}
