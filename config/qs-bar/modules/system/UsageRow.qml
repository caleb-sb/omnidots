import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Icon, label and value over a usage bar. A negative `fraction` hides the
// bar's fill (no reading yet).
ColumnLayout {
    id: root

    required property string icon
    required property string label
    required property string value
    property real fraction: -1
    property color barColor: Theme.c.blue
    property color valueColor: Theme.c.fgDark

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.normal

        MaterialIcon {
            size: 20
            fill: 1
            text: root.icon
            color: root.barColor
        }
        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        StyledText {
            text: root.value
            font.pixelSize: Theme.font.small
            font.features: ({ tnum: 1 })
            color: root.valueColor
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Theme.c.bg

        Rectangle {
            width: root.fraction < 0 ? 0 : Math.max(height, parent.width * Math.min(1, root.fraction))
            height: parent.height
            radius: 3
            color: root.barColor
            visible: root.fraction >= 0

            Behavior on width {
                Anim {}
            }
        }
    }
}
