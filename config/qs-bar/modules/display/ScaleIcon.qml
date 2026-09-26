import QtQuick
import qs.config
import qs.components

// Bar item: toggles the monitor scale between 1.5x and 2.5x.
// Blue (filled) while enlarged, grey at the normal scale.
Item {
    id: root

    implicitWidth: implicitHeight
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"

        StateLayer {
            radius: parent.radius
            onClicked: DisplayScale.toggle()
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: 18
        fill: DisplayScale.enlarged ? 1 : 0
        text: "fit_screen"
        color: DisplayScale.enlarged ? Theme.c.blue : Theme.c.comment
    }
}
