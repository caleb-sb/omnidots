import QtQuick
import qs.config

Text {
    color: Theme.c.fg
    font.family: Theme.font.sans
    font.pixelSize: Theme.font.normal
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        CAnim {}
    }
}
