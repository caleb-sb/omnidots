import QtQuick
import qs.config

// Hover/press overlay + click handling. Fill the parent you want to make clickable.
MouseArea {
    id: root

    property color color: Theme.c.fg
    property real radius: parent?.radius ?? 0
    property bool disabled: false

    anchors.fill: parent
    hoverEnabled: true
    enabled: !disabled
    cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.color
        opacity: root.disabled ? 0 : root.pressed ? 0.14 : root.containsMouse ? 0.08 : 0

        Behavior on opacity {
            Anim {
                duration: Theme.anim.effectsDuration
                easing.bezierCurve: Theme.anim.effects
            }
        }
    }
}
