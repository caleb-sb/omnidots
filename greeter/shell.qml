//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Greetd
import qs.config
import qs.components

// The login screen, run by greetd inside a minimal Hyprland session (see
// hyprland.lua and installer/greeter/omnidots-greeter.sh). Every screen gets
// the Tokyo Night background and the clock; the login card goes on the screen
// Hyprland focused first. Theme and components are qs-bar's.
ShellRoot {
    id: shell

    // The screen with the login card, fixed once known so typing never moves.
    property string cardScreen: ""
    readonly property string focused: Hyprland.focusedMonitor?.name ?? ""
    onFocusedChanged: {
        if (!cardScreen || !Quickshell.screens.some(s => s.name === cardScreen))
            cardScreen = focused;
    }

    Auth {
        id: authFlow
    }

    // Without greetd there's nothing to log in to: exit with an error, so
    // omnidots-greeter falls back to tuigreet. From a timer, since Quickshell
    // only handles Qt.exit() once the shell has loaded.
    Timer {
        running: !Greetd.available
        interval: 1
        onTriggered: {
            console.error("greetd isn't available (GREETD_SOCK is unset)");
            Qt.exit(1);
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            readonly property bool hasCard: modelData.name === shell.cardScreen || (!shell.cardScreen && modelData === Quickshell.screens[0])

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.c.bg

            WlrLayershell.namespace: "omnidots-greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: hasCard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // A faint glow from the top, in the bar's blue.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.c.blue7, 0.35)
                    }
                    GradientStop {
                        position: 0.6
                        color: "transparent"
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: card.visible ? card.top : parent.verticalCenter
                anchors.bottomMargin: 48
                spacing: 4

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.pixelSize: 96
                    font.weight: Font.Bold
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Theme.c.fgDark
                    font.pixelSize: Theme.font.title
                }
            }

            LoginCard {
                id: card

                auth: authFlow
                visible: win.hasCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 60
                width: implicitWidth

                onVisibleChanged: if (visible)
                    focusField()
                Component.onCompleted: if (visible)
                    focusField()
            }

            // The way out if this screen misbehaves (see hyprland.lua).
            StyledText {
                visible: win.hasCard
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 24
                text: "Ctrl+Alt+Backspace: text login"
                color: Theme.c.comment
                font.pixelSize: Theme.font.small
            }

            // Power off and restart, bottom right.
            Row {
                visible: win.hasCard
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24
                spacing: Theme.spacing.small

                IconButton {
                    size: 44
                    icon: "restart_alt"
                    iconColor: Theme.c.dark5
                    onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                }
                IconButton {
                    size: 44
                    icon: "power_settings_new"
                    iconColor: Theme.c.dark5
                    onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                }
            }
        }
    }
}
