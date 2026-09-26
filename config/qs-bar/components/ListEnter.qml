import QtQuick
import qs.config

// ListView add/populate: fade and grow in (caelestia-style).
Transition {
    ParallelAnimation {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.anim.effectsDuration
            easing.bezierCurve: Theme.anim.effects
        }
        Anim {
            property: "scale"
            from: 0.9
            to: 1
        }
    }
}
