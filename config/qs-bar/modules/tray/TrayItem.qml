pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

// One tray app. Left click activates it (e.g. shows Steam's window), right
// click opens its menu in a popout, middle click is the app's secondary
// action. The app's icon is tinted blue to match the other bar icons.
Item {
    id: root

    required property SystemTrayItem modelData
    property bool active
    signal menuRequested

    implicitWidth: implicitHeight
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Theme.c.blue7 : "transparent"

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            radius: parent.radius
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                const item = root.modelData;
                if (e.button === Qt.MiddleButton)
                    item.secondaryActivate();
                else if (e.button === Qt.RightButton || item.onlyMenu) {
                    if (item.hasMenu)
                        root.menuRequested();
                } else
                    item.activate();
            }
        }
    }

    // Tinted blue like the Material bar icons. Brightened first, since
    // colorizing keeps each pixel's lightness and dark icons would stay dark.
    IconImage {
        id: icon

        anchors.centerIn: parent
        implicitSize: 18
        source: root.modelData.icon
        visible: false
    }

    MultiEffect {
        anchors.fill: icon
        source: icon
        brightness: 0.5
        colorization: 1
        colorizationColor: Theme.c.blue
    }
}
