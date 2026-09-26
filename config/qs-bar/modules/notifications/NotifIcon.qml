import QtQuick
import qs.config
import qs.components

// Bar item: bell with a count badge. Left click opens the panel (the bar
// wires `clicked` to its popout); right click toggles do-not-disturb.
Item {
    id: root

    property bool active
    signal clicked

    readonly property bool any: Notifs.count > 0

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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => {
                if (e.button === Qt.RightButton)
                    Notifs.dnd = !Notifs.dnd;
                else
                    root.clicked();
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: 18
        fill: Notifs.dnd ? 0 : 1
        text: Notifs.dnd ? "notifications_off" : "notifications"
        color: Notifs.dnd ? Theme.c.comment : Theme.c.blue
    }

    // Count badge.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -2
        anchors.topMargin: -1
        implicitWidth: Math.max(14, countText.implicitWidth + 6)
        implicitHeight: 14
        radius: 7
        color: Theme.c.blue
        border.width: 2
        border.color: Theme.c.bgHighlight  // matches the BarGroup pill
        visible: scale > 0
        scale: root.any && !Notifs.dnd ? 1 : 0

        Behavior on scale {
            Anim {
                duration: Theme.anim.fastDuration
                easing.bezierCurve: Theme.anim.fastSpatial
            }
        }

        Text {
            id: countText

            anchors.centerIn: parent
            text: Notifs.count > 99 ? "99+" : Notifs.count
            color: Theme.c.bgDark
            font.family: Theme.font.sans
            font.pixelSize: 8
            font.weight: Font.Bold
        }
    }
}
