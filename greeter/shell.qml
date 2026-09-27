//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.config
import qs.components

// The login screen, run by greetd inside a minimal Hyprland session (see
// hyprland.lua and installer/greeter/omnidots-greeter.sh), made to look like
// the lock screen (config/hypr/hyprlock.conf). Every screen gets the blurred
// wallpaper, the clock and the greeting; the login form goes on the screen
// Hyprland focused first. Theme and components are qs-bar's.
ShellRoot {
    id: shell

    // The screen with the login form, fixed once known so typing never moves.
    property string formScreen: ""
    readonly property string focused: Hyprland.focusedMonitor?.name ?? ""
    onFocusedChanged: {
        if (!formScreen || !Quickshell.screens.some(s => s.name === formScreen))
            formScreen = focused;
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

    // Each output's scale, for hyprlock's sizes, which are in physical
    // pixels. From hyprctl, since Quickshell reports fractional scales
    // rounded up.
    property var scales: ({})

    Process {
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const scales = {};
                try {
                    for (const m of JSON.parse(text))
                        scales[m.name] = m.scale;
                } catch (e) {}
                shell.scales = scales;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            readonly property bool hasForm: modelData.name === shell.formScreen || (!shell.formScreen && modelData === Quickshell.screens[0])
            // Logical px per hyprlock px.
            readonly property real unit: 1 / (shell.scales[modelData.name] || 1)

            // lockFont(size) — hyprlock's font_size (points at 96 dpi, in
            // physical pixels) in logical px.
            function lockFont(size: real): real {
                return size * 4 / 3 * unit;
            }

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            // Until the wallpaper loads, or if it can't, as hyprlock does
            // without its screenshot.
            color: Theme.c.bg

            WlrLayershell.namespace: "omnidots-greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: hasForm ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // The wallpaper, blurred and darkened like hyprlock's background
            // (brightness 0.6). 88-greeter.sh deploys it as `background`.
            Image {
                id: wallpaper

                anchors.fill: parent
                source: Qt.resolvedUrl("background")
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wallpaper
                visible: wallpaper.status === Image.Ready
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
            }
            Rectangle {
                anchors.fill: parent
                visible: wallpaper.status === Image.Ready
                color: "black"
                opacity: 0.4
            }

            // ── Time, date and greeting, where hyprlock has them ─────
            LockLabel {
                offset: 240
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: win.lockFont(96)
                font.weight: Font.Bold
            }
            LockLabel {
                offset: 140
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.c.fgDark
                font.pixelSize: win.lockFont(20)
            }
            LockLabel {
                offset: 60
                visible: authFlow.owner !== ""
                text: `Hi, ${authFlow.firstName || authFlow.owner}`
                color: Theme.c.blue
                font.pixelSize: win.lockFont(16)
            }

            LoginForm {
                id: form

                auth: authFlow
                unit: win.unit
                visible: win.hasForm
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 20 * win.unit
                width: implicitWidth
                height: implicitHeight

                onVisibleChanged: if (visible)
                    focusField()
                Component.onCompleted: if (visible)
                    focusField()
            }

            // The way out if this screen misbehaves (see hyprland.lua).
            StyledText {
                visible: win.hasForm
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 24
                text: "Ctrl+Alt+Backspace: text login"
                color: Theme.c.comment
                font.pixelSize: 15
            }

            // Power off and restart, bottom right.
            Row {
                visible: win.hasForm
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

            // A hyprlock label: centred, `offset` hyprlock px above the
            // middle, in hyprlock's font.
            component LockLabel: StyledText {
                property real offset

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -offset * win.unit
                font.family: "JetBrainsMono Nerd Font"
            }
        }
    }
}
