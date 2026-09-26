import QtQuick
import qs.config

// ListView remove: fade and shrink out.
Transition {
    ParallelAnimation {
        Anim {
            property: "opacity"
            to: 0
            duration: Theme.anim.closeDuration
            easing.bezierCurve: Theme.anim.standardAccel
        }
        Anim {
            property: "scale"
            to: 0.9
            duration: Theme.anim.closeDuration
            easing.bezierCurve: Theme.anim.standardAccel
        }
    }
}
