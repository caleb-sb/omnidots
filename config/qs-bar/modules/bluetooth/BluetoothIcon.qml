import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.components

// Bar item: Bluetooth status glyph. Left click opens the panel (the bar wires
// `clicked` to its popout); right click toggles the adapter.
Item {
    id: root

    property bool active
    signal clicked

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property int connectedCount: Bluetooth.devices.values.filter(d => d.connected).length

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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => {
                if (e.button === Qt.RightButton) {
                    if (root.adapter)
                        root.adapter.enabled = !root.powered;
                } else {
                    root.clicked();
                }
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: 18
        fill: root.powered ? 1 : 0
        text: {
            if (!root.powered)
                return "bluetooth_disabled";
            if (root.connectedCount > 0)
                return "bluetooth_connected";
            if (root.adapter?.discovering)
                return "bluetooth_searching";
            return "bluetooth";
        }
        // Blue while the adapter is on, grey when it's off.
        color: root.powered ? Theme.c.blue : Theme.c.comment
    }
}
