pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.components

// Control-center style Bluetooth panel. Self-contained: give it a host (the
// bar's Popout) and it sizes itself via implicitWidth/implicitHeight.
Item {
    id: root

    signal closeRequested

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false
    readonly property list<BluetoothDevice> devices: adapter?.devices.values ?? []

    // Hide nameless scan results (BlueZ aliases them to the address).
    function hasName(d: BluetoothDevice): bool {
        return d.name.length > 0 && d.name.replace(/-/g, ":") !== d.address;
    }
    function byName(a: BluetoothDevice, b: BluetoothDevice): int {
        return a.name.localeCompare(b.name);
    }

    readonly property var connected: devices.filter(d => d.connected).sort(byName)
    readonly property var paired: devices.filter(d => !d.connected && (d.paired || d.bonded)).sort(byName)
    readonly property var available: devices.filter(d => !d.connected && !d.paired && !d.bonded && hasName(d)).sort((a, b) => (b.pairing - a.pairing) || byName(a, b))

    // Only stop a scan we started, so we don't fight other tools.
    property bool startedScan
    function setScan(on: bool): void {
        if (!adapter || !powered)
            return;
        startedScan = on;
        adapter.discovering = on;
    }
    Component.onDestruction: {
        if (startedScan && adapter)
            adapter.discovering = false;
    }

    implicitWidth: 360
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.normal

        // ── Header ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: root.powered ? Theme.rounding.normal : 22
                color: root.powered ? Theme.c.blue : Theme.c.bgHighlight

                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim {}
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 24
                    fill: root.powered ? 1 : 0
                    text: root.powered ? "bluetooth" : "bluetooth_disabled"
                    color: root.powered ? Theme.c.bgDark : Theme.c.dark5
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Bluetooth"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.small
                    color: Theme.c.comment
                    text: {
                        if (!root.adapter)
                            return "No adapter found";
                        if (!root.powered)
                            return "Off";
                        const n = root.connected.length;
                        return n > 0 ? `${n} device${n === 1 ? "" : "s"} connected` : `On · ${root.adapter.name}`;
                    }
                }
            }

            Switch {
                checked: root.powered
                busy: !root.adapter
                onToggled: root.adapter.enabled = !root.powered
            }
        }

        // ── Quick toggles ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            visible: root.powered

            Tile {
                icon: "radar"
                label: "Scan"
                sublabel: root.scanning ? "Searching…" : "Find devices"
                checked: root.scanning
                spinning: root.scanning
                onClicked: root.setScan(!root.scanning)
            }

            Tile {
                icon: "visibility"
                label: "Visible"
                sublabel: root.adapter?.discoverable ? "Discoverable" : "Hidden"
                checked: root.adapter?.discoverable ?? false
                onClicked: root.adapter.discoverable = !root.adapter.discoverable
            }
        }

        // ── Device lists ──────────────────────────────────────────
        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(lists.implicitHeight, 380)
            visible: root.powered
            contentHeight: lists.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: lists

                width: flick.width
                spacing: 2

                Section {
                    title: "Connected"
                    devices: root.connected
                }
                Section {
                    title: "Paired"
                    devices: root.paired
                }
                Section {
                    title: "Available"
                    devices: root.available
                    trailing: root.scanning
                }

                Placeholder {
                    visible: root.devices.length === 0 || (root.connected.length + root.paired.length + root.available.length === 0)
                    icon: root.scanning ? "bluetooth_searching" : "devices_other"
                    text: root.scanning ? "Looking for devices…" : "No devices. Turn on Scan to find some."
                }
            }
        }

        Placeholder {
            visible: !root.powered
            icon: "bluetooth_disabled"
            text: root.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
        }

        // ── Footer ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            implicitHeight: 40
            radius: Theme.rounding.full
            color: Theme.c.bgHighlight

            StateLayer {
                onClicked: {
                    Quickshell.execDetached(["blueman-manager"]);
                    root.closeRequested();
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacing.small

                MaterialIcon {
                    size: 18
                    text: "settings"
                    color: Theme.c.fgDark
                }
                StyledText {
                    text: "Bluetooth settings"
                    color: Theme.c.fgDark
                }
            }
        }
    }

    component Section: ColumnLayout {
        id: section

        required property string title
        required property var devices
        property bool trailing

        Layout.fillWidth: true
        spacing: 2
        visible: devices.length > 0

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            Layout.leftMargin: 4
            Layout.bottomMargin: 2

            StyledText {
                Layout.fillWidth: true
                text: section.title.toUpperCase()
                font.pixelSize: Theme.font.small - 1
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
                color: Theme.c.comment
            }
            Spinner {
                size: 14
                running: section.trailing
                color: Theme.c.comment
            }
        }

        Repeater {
            model: section.devices

            DeviceRow {}
        }
    }
}
