import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.config
import qs.components

// One device. Click = primary action (connect / disconnect / pair / cancel).
Rectangle {
    id: root

    required property BluetoothDevice modelData
    readonly property BluetoothDevice device: modelData
    readonly property bool known: device.paired || device.bonded
    readonly property bool transitioning: device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting
    readonly property bool busy: transitioning || device.pairing
    // Set when we pair a new device so we connect it once pairing lands.
    property bool connectAfterPair

    function primaryAction(): void {
        if (device.pairing) {
            connectAfterPair = false;
            device.cancelPair();
        } else if (transitioning) {
            return;
        } else if (!known) {
            connectAfterPair = true;
            device.trusted = true;
            device.pair();
        } else {
            device.connected = !device.connected;
        }
    }

    function glyph(icon: string): string {
        if (icon.includes("headset") || icon.includes("headphones"))
            return "headphones";
        if (icon.includes("audio"))
            return "speaker";
        if (icon.includes("phone"))
            return "smartphone";
        if (icon.includes("mouse"))
            return "mouse";
        if (icon.includes("keyboard"))
            return "keyboard";
        if (icon.includes("gaming") || icon.includes("joystick"))
            return "sports_esports";
        if (icon.includes("computer"))
            return "computer";
        if (icon.includes("watch"))
            return "watch";
        return "bluetooth";
    }

    function statusText(): string {
        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        }
        if (device.pairing)
            return "Pairing… (click to cancel)";
        if (device.connected)
            return device.batteryAvailable ? `Connected · ${Math.round(device.battery * 100)}%` : "Connected";
        return known ? "Paired" : "Click to pair";
    }

    Connections {
        target: root.device

        function onPairedChanged(): void {
            if (root.device.paired && root.connectAfterPair) {
                root.connectAfterPair = false;
                root.device.connect();
            }
        }
    }

    Layout.fillWidth: true
    implicitHeight: 56
    radius: Theme.rounding.normal
    color: device.connected ? Qt.alpha(Theme.c.blue, 0.1) : "transparent"

    // Entry animation, like caelestia's list items.
    opacity: 0
    scale: 0.85
    Component.onCompleted: {
        opacity = 1;
        scale = 1;
    }
    Behavior on opacity {
        Anim {
            duration: Theme.anim.effectsDuration
            easing.bezierCurve: Theme.anim.effects
        }
    }
    Behavior on scale {
        Anim {}
    }
    Behavior on color {
        CAnim {}
    }

    HoverHandler {
        id: hover
    }

    StateLayer {
        radius: root.radius
        disabled: root.transitioning
        onClicked: root.primaryAction()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: Theme.spacing.normal

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: root.device.connected ? Theme.rounding.normal : 18
            color: root.device.connected ? Theme.c.blue : Theme.c.bgHighlight

            Behavior on color {
                CAnim {}
            }
            Behavior on radius {
                Anim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                size: 20
                text: root.glyph(root.device.icon)
                fill: root.device.connected ? 1 : 0
                color: root.device.connected ? Theme.c.bgDark : Theme.c.fgDark
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.device.name || root.device.address
                elide: Text.ElideRight
                font.weight: root.device.connected ? Font.DemiBold : Font.Normal
            }

            StyledText {
                Layout.fillWidth: true
                text: root.statusText()
                elide: Text.ElideRight
                font.pixelSize: Theme.font.small
                color: root.device.connected ? Theme.c.blue : Theme.c.comment
            }
        }

        Spinner {
            size: 18
            running: root.busy
            color: Theme.c.blue
        }

        IconButton {
            visible: root.known && !root.busy
            opacity: hover.hovered ? 1 : 0
            disabled: !hover.hovered
            size: 30
            icon: "delete"
            iconColor: Theme.c.red

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.effectsDuration
                }
            }

            onClicked: root.device.forget()
        }

        IconButton {
            visible: !root.busy
            size: 30
            icon: root.device.connected ? "link_off" : root.known ? "link" : "add_link"
            iconColor: root.device.connected ? Theme.c.blue : Theme.c.fgDark
            onClicked: root.primaryAction()
        }
    }
}
