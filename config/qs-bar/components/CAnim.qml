import QtQuick
import qs.config

ColorAnimation {
    duration: Theme.anim.effectsDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.anim.effects
}
