import QtQuick
import qs.config

// Material Symbols Rounded glyph. `fill` animates between outlined (0) and filled (1).
Text {
    id: root

    property real fill: 0
    property int grade: 0
    property int size: 20

    color: Theme.c.fg
    font.family: Theme.font.icons
    font.pixelSize: size
    font.variableAxes: ({
            FILL: fill.toFixed(1),
            GRAD: grade,
            opsz: size,
            wght: 400
        })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    Behavior on fill {
        Anim {
            duration: Theme.anim.effectsDuration
        }
    }
    Behavior on color {
        CAnim {}
    }
}
