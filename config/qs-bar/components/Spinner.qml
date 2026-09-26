import QtQuick
import qs.config

// Indeterminate progress: a rotating arc glyph.
MaterialIcon {
    id: root

    property bool running: true

    text: "progress_activity"
    visible: opacity > 0
    opacity: running ? 1 : 0

    Behavior on opacity {
        Anim {
            duration: Theme.anim.effectsDuration
        }
    }

    RotationAnimation on rotation {
        running: root.visible
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
