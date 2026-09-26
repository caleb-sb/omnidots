import QtQuick
import qs.config

NumberAnimation {
    duration: Theme.anim.spatialDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.anim.spatial
}
