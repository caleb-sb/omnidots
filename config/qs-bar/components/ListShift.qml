import QtQuick
import qs.config

// ListView displaced: slide into the gap.
Transition {
    Anim {
        property: "y"
    }
    // An interrupted enter must still finish fully visible.
    Anim {
        properties: "opacity,scale"
        to: 1
        duration: Theme.anim.effectsDuration
    }
}
