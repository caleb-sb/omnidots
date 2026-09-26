import QtQuick
import qs.config
import qs.components

// Bar item: connection glyph. Left click opens the panel (the bar wires
// `clicked` to its popout); right click toggles Wi-Fi.
Item {
    id: root

    property bool active
    signal clicked

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
                if (e.button === Qt.RightButton)
                    Net.setWifi(!Net.wifiEnabled);
                else
                    root.clicked();
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: 18
        fill: Net.online ? 1 : 0
        text: {
            if (Net.ethernet)
                return "lan";
            if (!Net.wifiEnabled)
                return "signal_wifi_off";
            if (Net.active)
                return Net.limited ? "signal_wifi_bad" : Net.signalIcon(Net.active.signalStrength);
            if (Net.connecting)
                return "wifi_find";
            return "wifi";
        }
        color: {
            if (Net.limited)
                return Theme.c.yellow;
            if (Net.online)
                return Theme.c.blue;
            return Net.wifiEnabled ? Theme.c.fg : Theme.c.comment;
        }
    }
}
