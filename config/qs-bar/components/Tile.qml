import QtQuick
import QtQuick.Layouts
import qs.config

// Quick-toggle tile (icon, label, sublabel). Filled blue while `checked`.
Rectangle {
    id: tile

    required property string icon
    required property string label
    property string sublabel
    property bool checked
    property bool spinning
    property bool disabled
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 60
    radius: checked ? Theme.rounding.large : Theme.rounding.normal
    color: checked ? Theme.c.blue : Theme.c.bgHighlight

    Behavior on color {
        CAnim {}
    }
    Behavior on radius {
        Anim {}
    }

    opacity: disabled ? 0.5 : 1

    StateLayer {
        color: tile.checked ? Theme.c.bgDark : Theme.c.fg
        disabled: tile.disabled
        onClicked: tile.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: Theme.spacing.normal

        MaterialIcon {
            id: tileIcon

            size: 22
            text: tile.icon
            fill: tile.checked ? 1 : 0
            color: tile.checked ? Theme.c.bgDark : Theme.c.fgDark

            RotationAnimation on rotation {
                running: tile.spinning
                from: 0
                to: 360
                duration: 1800
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    tileIcon.rotation = 0
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: tile.label
                font.weight: Font.DemiBold
                color: tile.checked ? Theme.c.bgDark : Theme.c.fg
            }
            StyledText {
                Layout.fillWidth: true
                text: tile.sublabel
                elide: Text.ElideRight
                font.pixelSize: Theme.font.small
                color: tile.checked ? Qt.alpha(Theme.c.bgDark, 0.75) : Theme.c.comment
            }
        }
    }
}
