import QtQuick
import qs.config

// Round icon-only button.
Rectangle {
    id: root

    property alias icon: glyph.text
    property alias iconColor: glyph.color
    property alias fill: glyph.fill
    property int size: 32
    property bool disabled
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: "transparent"

    Behavior on color {
        CAnim {}
    }

    StateLayer {
        color: glyph.color
        disabled: root.disabled
        onClicked: root.clicked()
    }

    MaterialIcon {
        id: glyph

        anchors.centerIn: parent
        size: Math.round(root.size * 0.58)
    }
}
