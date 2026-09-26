import QtQuick
import QtQuick.Layouts
import qs.config

// Pill that groups related bar items (same look as the clock).
Rectangle {
    id: root

    default property alias items: row.data
    property int padding: 0

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2
    radius: height / 2
    color: Theme.c.bgHighlight

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 0
    }
}
