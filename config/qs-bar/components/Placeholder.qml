import QtQuick
import QtQuick.Layouts
import qs.config

// Empty-state glyph + line of text, centred across the panel.
Item {
    id: root

    required property string icon
    required property string text

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Theme.spacing.large * 2

    Column {
        id: col

        anchors.centerIn: parent
        spacing: Theme.spacing.small

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 40
            text: root.icon
            color: Theme.c.dark3
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.text
            color: Theme.c.comment
        }
    }
}
