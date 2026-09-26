import QtQuick
import qs.config

// M3 expressive slider: thick active track, a gap, a bar handle, and a thin
// inactive track. Emits moved(value) while dragging/clicking/scrolling; the
// owner writes it back to `value`.
Item {
    id: root

    property real value
    property real from: 0
    property real to: 1
    property real step: 0.05
    property color accent: Theme.c.blue
    property bool dimmed
    signal moved(real value)

    readonly property bool pressed: area.pressed
    readonly property real frac: Math.max(0, Math.min(1, ((pressed ? dragValue : value) - from) / (to - from)))

    property real dragValue
    // Visual position: follows external changes smoothly, the finger exactly.
    property real pos: frac

    Behavior on pos {
        enabled: !area.pressed
        Anim {
            duration: Theme.anim.fastDuration
            easing.bezierCurve: Theme.anim.standard
        }
    }

    readonly property real handleW: pressed ? 2 : 4
    readonly property real gap: 5
    readonly property real handleX: pos * (width - handleW)
    readonly property color tint: dimmed ? Theme.c.dark3 : accent

    implicitWidth: 200
    implicitHeight: 36

    function valueAt(x: real): real {
        const f = Math.max(0, Math.min(1, x / width));
        return from + f * (to - from);
    }

    // Active track.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.handleX - root.gap)
        height: 16
        visible: width > 1
        topLeftRadius: 8
        bottomLeftRadius: 8
        topRightRadius: 2
        bottomRightRadius: 2
        color: root.tint

        Behavior on color {
            CAnim {}
        }
    }

    // Inactive track.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX + root.handleW + root.gap
        width: Math.max(0, root.width - x)
        height: 16
        visible: width > 1
        topLeftRadius: 2
        bottomLeftRadius: 2
        topRightRadius: 8
        bottomRightRadius: 8
        color: Theme.c.bgHighlight

        // End stop dot.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 4
            radius: 2
            color: root.tint
            visible: parent.width > 14
        }
    }

    // Handle.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX
        width: root.handleW
        height: root.pressed ? root.height : root.height - 6
        radius: width / 2
        color: root.tint

        Behavior on width {
            Anim {
                duration: Theme.anim.fastDuration
            }
        }
        Behavior on height {
            Anim {
                duration: Theme.anim.fastDuration
                easing.bezierCurve: Theme.anim.fastSpatial
            }
        }
        Behavior on color {
            CAnim {}
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function drag(x: real): void {
            root.dragValue = root.valueAt(x);
            root.moved(root.dragValue);
        }

        onPressed: e => drag(e.x)
        onPositionChanged: e => {
            if (pressed)
                drag(e.x);
        }
        onWheel: e => {
            const dir = e.angleDelta.y > 0 ? 1 : e.angleDelta.y < 0 ? -1 : 0;
            if (dir !== 0)
                root.moved(Math.max(root.from, Math.min(root.to, root.value + dir * root.step)));
        }
    }
}
