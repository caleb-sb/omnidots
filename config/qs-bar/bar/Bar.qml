import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.config
import qs.components
import qs.modules.bluetooth
import qs.modules.audio
import qs.modules.network
import qs.modules.notifications
import qs.modules.clipboard
import qs.modules.display
import qs.modules.clock
import qs.modules.media
import qs.modules.workspaces
import qs.modules.system
import qs.modules.tray

// The bar. The window is taller than the bar so popouts can live in it;
// the input mask limits clicks to the bar strip and the open card.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        // Menu shown by the tray popout (set just before it opens).
        property QsMenuHandle trayMenu
        property string trayTitle

        screen: modelData
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.bar.margin + Theme.bar.height + 720
        exclusiveZone: Theme.bar.margin + Theme.bar.height
        color: "transparent"

        WlrLayershell.namespace: "qs-bar"
        WlrLayershell.keyboardFocus: popout.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            item: barBg

            Region {
                item: popout.card
            }
        }

        // `qs -p <dir> ipc call bluetooth toggle` (bind it to a key if you like).
        IpcHandler {
            target: "bluetooth"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("bluetooth", btIcon, btPanel);
            }
        }

        // `ipc call notifications toggle | dnd | clear`
        IpcHandler {
            target: "notifications"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("notifications", notifIcon, notifPanel);
            }
            function dnd(): void {
                Notifs.dnd = !Notifs.dnd;
            }
            function clear(): void {
                Notifs.clear();
            }
        }

        // Popups stay hidden while the history panel is open.
        Binding {
            target: Notifs
            property: "panelOpen"
            value: true
            when: popout.open && popout.current === "notifications"
            restoreMode: Binding.RestoreValue
        }

        // `ipc call display toggle`: switch between 1.5x and 2x scale.
        IpcHandler {
            target: "display"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                DisplayScale.toggle();
            }
        }

        IpcHandler {
            target: "calendar"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("calendar", clock, calendarPanel);
            }
        }

        IpcHandler {
            target: "clipboard"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("clipboard", clipIcon, clipPanel);
            }
        }

        IpcHandler {
            target: "media"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                if (Media.shown)
                    popout.toggle("media", mediaPill, mediaPanel);
            }
        }

        IpcHandler {
            target: "network"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("network", netIcon, netPanel);
            }
        }

        IpcHandler {
            target: "audio"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("audio", audioIcon, audioPanel);
            }
        }

        // `ipc call power toggle` (Super+X) | gameMode
        IpcHandler {
            target: "power"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("power", powerGroup, powerPanel);
            }
            function gameMode(): void {
                Power.setGameMode(!Power.gameMode);
            }
        }

        IpcHandler {
            target: "system"
            enabled: win.modelData === PrimaryScreen.screen

            function toggle(): void {
                popout.toggle("system", stats, systemPanel);
            }
        }

        HyprlandFocusGrab {
            active: popout.open
            windows: [win]
            onCleared: popout.close()
        }

        Popout {
            id: popout

            anchors.fill: parent
        }

        Rectangle {
            id: barBg

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.bar.margin
            height: Theme.bar.height
            // Drawn by the Popout surface shader so bar and popout are one shape.
            color: "transparent"

            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: Theme.bar.padding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.large

                // Power button (only while the power panel is open, via
                // Super+X) and the device monitor, which opens the system
                // panel. The power popout anchors to the whole pill.
                BarGroup {
                    id: powerGroup

                    readonly property bool open: popout.open && popout.current === "power"

                    PowerIcon {
                        shown: powerGroup.open
                        active: powerGroup.open
                        onClicked: popout.close()
                    }

                    DeviceStats {
                        id: stats

                        active: popout.open && popout.current === "system"
                        onClicked: popout.toggle("system", stats, systemPanel)
                    }
                }

                Workspaces {
                    screen: win.modelData
                }
            }

            ClockText {
                id: clock

                anchors.centerIn: parent
                active: popout.open && popout.current === "calendar"
                onClicked: popout.toggle("calendar", clock, calendarPanel)
            }

            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: Theme.bar.padding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.large

                // Spotify's track and controls (hidden unless a track is loaded).
                MediaPill {
                    id: mediaPill

                    active: popout.open && popout.current === "media"
                    onClicked: popout.toggle("media", mediaPill, mediaPanel)
                }

                // Tray apps (hidden when there are none).
                BarGroup {
                    id: trayGroup

                    // Tray icons for things the bar already has a module for
                    // (Spotify's: the media panel shows and hides its window).
                    readonly property list<string> hidden: ["nm-applet", "blueman", Media.trayId]

                    visible: trayRepeater.count > 0

                    Repeater {
                        id: trayRepeater

                        model: ScriptModel {
                            values: SystemTray.items.values.filter(i => !trayGroup.hidden.includes(i.id))
                        }

                        TrayItem {
                            id: trayItem

                            readonly property string popoutName: "tray:" + modelData.id

                            active: popout.open && popout.current === popoutName
                            onMenuRequested: {
                                win.trayMenu = modelData.menu;
                                win.trayTitle = modelData.tooltipTitle || modelData.title || modelData.id;
                                popout.toggle(popoutName, trayItem, trayMenuPanel);
                            }
                        }
                    }
                }

                // Display tools.
                BarGroup {
                    ScaleIcon {}

                    ClipIcon {
                        id: clipIcon

                        active: popout.open && popout.current === "clipboard"
                        onClicked: popout.toggle("clipboard", clipIcon, clipPanel)
                    }
                }

                // Sound and connectivity.
                BarGroup {
                    AudioIcon {
                        id: audioIcon

                        active: popout.open && popout.current === "audio"
                        onClicked: popout.toggle("audio", audioIcon, audioPanel)
                    }

                    NetworkIcon {
                        id: netIcon

                        active: popout.open && popout.current === "network"
                        onClicked: popout.toggle("network", netIcon, netPanel)
                    }

                    BluetoothIcon {
                        id: btIcon

                        active: popout.open && popout.current === "bluetooth"
                        onClicked: popout.toggle("bluetooth", btIcon, btPanel)
                    }
                }

                BarGroup {
                    NotifIcon {
                        id: notifIcon

                        active: popout.open && popout.current === "notifications"
                        onClicked: popout.toggle("notifications", notifIcon, notifPanel)
                    }
                }
            }
        }

        Component {
            id: trayMenuPanel

            TrayMenuPanel {
                handle: win.trayMenu
                title: win.trayTitle
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: powerPanel

            PowerPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: systemPanel

            SystemPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: calendarPanel

            CalendarPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: clipPanel

            ClipPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: notifPanel

            NotifPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: mediaPanel

            MediaPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: netPanel

            NetworkPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: audioPanel

            AudioPanel {
                onCloseRequested: popout.close()
            }
        }

        Component {
            id: btPanel

            BluetoothPanel {
                onCloseRequested: popout.close()
            }
        }
    }
}
