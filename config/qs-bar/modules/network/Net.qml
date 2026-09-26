pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Wi-Fi/Ethernet state shared by the bar icon and panel (NetworkManager via
// Quickshell.Networking).
Singleton {
    id: root

    readonly property list<NetworkDevice> devices: Networking.devices.values
    readonly property WifiDevice wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WiredDevice wired: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiAvailable: !!wifi && Networking.wifiHardwareEnabled

    // One entry per SSID (APs on several bands show up more than once).
    readonly property var networks: {
        const best = {};
        for (const n of wifi?.networks.values ?? []) {
            if (!n.name)
                continue;
            const cur = best[n.name];
            if (!cur || rank(n) > rank(cur))
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => b.signalStrength - a.signalStrength);
    }
    readonly property WifiNetwork active: networks.find(n => n.connected) ?? null
    readonly property WifiNetwork connecting: networks.find(n => n.state === ConnectionState.Connecting) ?? null

    // SSID whose inline password field is open in the panel.
    property string passwordFor

    readonly property bool ethernet: wired?.connected ?? false
    readonly property bool online: ethernet || !!active
    // Connected, but NetworkManager can't reach the internet.
    readonly property bool limited: online && (Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.Portal)

    function rank(n: WifiNetwork): real {
        return (n.connected ? 10 : 0) + (n.stateChanging ? 5 : 0) + n.signalStrength;
    }

    function setWifi(on: bool): void {
        Networking.wifiEnabled = on;
    }

    function isOpen(n: WifiNetwork): bool {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe;
    }

    // 802.1X networks need more than a password; hand those to the settings app.
    function isEnterprise(n: WifiNetwork): bool {
        return [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.Leap, WifiSecurityType.DynamicWep].includes(n.security);
    }

    function securityText(n: WifiNetwork): string {
        return isOpen(n) ? "Open" : WifiSecurityType.toString(n.security);
    }

    function signalIcon(strength: real): string {
        const s = Math.round(strength * 100);
        if (s >= 80)
            return "signal_wifi_4_bar";
        if (s >= 60)
            return "network_wifi_3_bar";
        if (s >= 40)
            return "network_wifi_2_bar";
        if (s >= 20)
            return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    function openSettings(): void {
        Quickshell.execDetached(["nm-connection-editor"]);
    }
}
