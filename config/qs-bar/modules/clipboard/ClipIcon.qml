import QtQuick
import qs.config
import qs.components

// Bar item: clipboard glyph. Left click opens the history panel (the bar wires
// `clicked` to its popout).
Item {
    id: root

    property bool active
    signal clicked

    implicitWidth: implicitHeight
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

    // Blue while there's history, grey when it's empty.
    MaterialIcon {
        anchors.centerIn: parent
        size: 18
        fill: Clip.count > 0 ? 1 : 0
        text: "assignment"
        color: Clip.count > 0 ? Theme.c.blue : Theme.c.comment
    }
}
