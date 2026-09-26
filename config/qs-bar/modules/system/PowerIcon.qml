import QtQuick
import qs.config
import qs.components

// Bar item: power button, the leftmost thing on the bar. Hidden (zero
// width) unless `shown`; the bar shows it while the power panel is open.
Item {
    id: root

    property bool active
    property bool shown
    signal clicked

    implicitWidth: shown ? implicitHeight : 0
    clip: true
    opacity: shown ? 1 : 0
    visible: implicitWidth > 0

    Behavior on implicitWidth {
        Anim {
            easing.bezierCurve: Theme.anim.standard
        }
    }
    Behavior on opacity {
        Anim {
            duration: Theme.anim.effectsDuration
            easing.bezierCurve: Theme.anim.effects
        }
    }
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2

    Rectangle {
        width: parent.implicitHeight
        height: parent.height
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

    MaterialIcon {
        x: (parent.implicitHeight - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        size: 18
        fill: 1
        text: "power_settings_new"
        color: Theme.c.blue
    }
}
