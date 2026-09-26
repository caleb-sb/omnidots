pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components

// Control-center style network panel: Wi-Fi toggle, Ethernet status, and
// connected / saved / available Wi-Fi networks.
Item {
    id: root

    signal closeRequested

    readonly property var connected: Net.networks.filter(n => n.connected || n.state === ConnectionState.Connecting)
    readonly property var saved: Net.networks.filter(n => n.known && !connected.includes(n))
    readonly property var available: Net.networks.filter(n => !n.known && !connected.includes(n))

    // Scan while the panel is open; only stop a scanner we started.
    property bool startedScan
    function setScan(on: bool): void {
        if (!Net.wifi || (on && !Net.wifiEnabled))
            return;
        if (on && Net.wifi.scannerEnabled)
            return;
        startedScan = on;
        Net.wifi.scannerEnabled = on;
    }
    Component.onCompleted: setScan(true)
    Component.onDestruction: {
        Net.passwordFor = "";
        if (startedScan && Net.wifi)
            Net.wifi.scannerEnabled = false;
    }
    Connections {
        target: Networking

        function onWifiEnabledChanged(): void {
            if (Networking.wifiEnabled)
                root.setScan(true);
        }
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
                radius: Net.online ? Theme.rounding.normal : 22
                color: Net.online ? Theme.c.blue : Theme.c.bgHighlight

                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim {}
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 24
                    fill: Net.online ? 1 : 0
                    text: Net.ethernet ? "lan" : Net.wifiEnabled ? "wifi" : "wifi_off"
                    color: Net.online ? Theme.c.bgDark : Theme.c.dark5
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Network"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.small
                    color: Net.limited ? Theme.c.yellow : Theme.c.comment
                    text: {
                        const via = Net.ethernet ? "Ethernet" : Net.active?.name;
                        if (via)
                            return Net.limited ? `${via} · no internet` : `Connected · ${via}`;
                        if (Net.connecting)
                            return `Connecting to ${Net.connecting.name}…`;
                        if (!Net.wifiAvailable)
                            return "No Wi-Fi adapter";
                        return Net.wifiEnabled ? "Not connected" : "Wi-Fi off";
                    }
                }
            }

            Switch {
                checked: Net.wifiEnabled
                busy: !Net.wifiAvailable
                onToggled: Net.setWifi(!Net.wifiEnabled)
            }
        }

        // ── Ethernet ──────────────────────────────────────────────
        Rectangle {
            id: eth

            readonly property WiredDevice dev: Net.wired
            readonly property bool busy: dev?.state === ConnectionState.Connecting || dev?.state === ConnectionState.Disconnecting

            Layout.fillWidth: true
            visible: !!dev
            implicitHeight: 56
            radius: Theme.rounding.normal
            color: Net.ethernet ? Qt.alpha(Theme.c.blue, 0.1) : Theme.c.bgHighlight

            Behavior on color {
                CAnim {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: Theme.spacing.normal

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: Net.ethernet ? Theme.rounding.normal : 18
                    color: Net.ethernet ? Theme.c.blue : Theme.c.bg

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on radius {
                        Anim {}
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 20
                        text: "lan"
                        fill: Net.ethernet ? 1 : 0
                        color: Net.ethernet ? Theme.c.bgDark : eth.dev?.hasLink ? Theme.c.fgDark : Theme.c.dark3
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: "Ethernet"
                        font.weight: Net.ethernet ? Font.DemiBold : Font.Normal
                        color: eth.dev?.hasLink || Net.ethernet ? Theme.c.fg : Theme.c.comment
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.font.small
                        color: Net.ethernet ? Theme.c.blue : Theme.c.comment
                        text: {
                            const d = eth.dev;
                            if (!d)
                                return "";
                            if (d.state === ConnectionState.Connecting)
                                return "Connecting…";
                            if (d.state === ConnectionState.Disconnecting)
                                return "Disconnecting…";
                            if (d.connected)
                                return d.linkSpeed > 0 ? `Connected · ${d.linkSpeed >= 1000 ? `${d.linkSpeed / 1000} Gb/s` : `${d.linkSpeed} Mb/s`}` : "Connected";
                            return d.hasLink ? "Cable connected" : "Cable unplugged";
                        }
                    }
                }

                Spinner {
                    size: 18
                    running: eth.busy
                    color: Theme.c.blue
                }

                IconButton {
                    visible: !eth.busy && (Net.ethernet || (!!eth.dev?.hasLink && !!eth.dev?.network))
                    size: 30
                    icon: Net.ethernet ? "link_off" : "link"
                    iconColor: Net.ethernet ? Theme.c.blue : Theme.c.fgDark
                    onClicked: Net.ethernet ? eth.dev.disconnect() : eth.dev.network.connect()
                }
            }
        }

        // ── Wi-Fi networks ────────────────────────────────────────
        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(lists.implicitHeight, 380)
            visible: Net.wifiEnabled
            contentHeight: lists.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: lists

                width: flick.width
                spacing: 2

                Section {
                    title: "Connected"
                    networks: root.connected
                }
                Section {
                    title: "Saved"
                    networks: root.saved
                }
                Section {
                    title: "Available"
                    networks: root.available
                    trailing: root.available.length === 0 || !!Net.connecting
                }

                Placeholder {
                    visible: Net.networks.length === 0
                    icon: "wifi_find"
                    text: "Looking for networks…"
                }
            }
        }

        Placeholder {
            visible: !Net.wifiEnabled
            icon: "wifi_off"
            text: Net.wifiAvailable ? "Wi-Fi is off" : "No Wi-Fi adapter"
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
                    Net.openSettings();
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
                    text: "Network settings"
                    color: Theme.c.fgDark
                }
            }
        }
    }

    component Section: ColumnLayout {
        id: section

        required property string title
        required property var networks
        property bool trailing

        Layout.fillWidth: true
        spacing: 2
        visible: networks.length > 0 || trailing

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
            // ScriptModel diffs by object, so rows (and a half-typed
            // password) survive signal-strength re-sorts.
            model: ScriptModel {
                values: section.networks
            }

            NetworkRow {}
        }
    }
}
