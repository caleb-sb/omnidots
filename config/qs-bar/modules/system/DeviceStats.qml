import QtQuick
import qs.config
import qs.components

// Bar item: RAM used, disk used on /, and battery when there is one. A
// gamepad glyph shows while game mode is on. Clicking opens the system panel.
Item {
    id: root

    property bool active
    signal clicked

    implicitWidth: row.implicitWidth + 28
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Theme.c.blue7 : "transparent"

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
        spacing: 14

        Stat {
            icon: "memory_alt"
            text: SysStats.gb(SysStats.memUsed)
        }
        Stat {
            icon: "hard_drive"
            text: SysStats.gb(SysStats.diskUsed)
        }
        Stat {
            visible: SysStats.hasBattery
            icon: SysStats.batteryIcon()
            iconColor: SysStats.batteryPercent <= 15 && !SysStats.charging ? Theme.c.red : Theme.c.blue
            text: `${SysStats.batteryPercent}%`
        }
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Power.gameMode
            size: 18
            fill: 1
            text: "sports_esports"
            color: Theme.c.blue
        }
    }

    component Stat: Row {
        property alias icon: glyph.text
        property alias iconColor: glyph.color
        property alias text: label.text

        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        MaterialIcon {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter
            size: 18
            fill: 1
            color: Theme.c.blue
        }
        StyledText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.font.bar
            font.features: ({ tnum: 1 })
            color: Theme.c.fg
        }
    }
}
