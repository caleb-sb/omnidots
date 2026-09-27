pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

// Power panel (Super+X): session actions, battery and battery saver (when
// there is a laptop battery) and the sleep timer. Keys run an action straight away, as wlogout did:
// L lock, E log out, R restart, S shut down. With the mouse, log out,
// restart and shut down need a second click.
Item {
    id: root

    signal closeRequested

    // Action waiting for its confirming click ("" = none).
    property string armed

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    // Created inside the popout's Loader, so focus only sticks once the panel
    // is in an active window.
    focus: true
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: {
        if (windowActive)
            root.forceActiveFocus();
    }
    Timer {
        running: true
        interval: 50
        onTriggered: root.forceActiveFocus()
    }

    Keys.onEscapePressed: root.closeRequested()
    Keys.onPressed: event => {
        const action = actions.children.find(a => a.key && a.key === event.text.toLowerCase());
        if (!action)
            return;
        event.accepted = true;
        root.closeRequested();
        action.triggered();
    }

    implicitWidth: 380
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.normal

        // ── Header ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: Theme.spacing.normal

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: Theme.rounding.normal
                color: Theme.c.blue

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 24
                    fill: 1
                    text: "power_settings_new"
                    color: Theme.c.bgDark
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Power"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }
                StyledText {
                    font.pixelSize: Theme.font.small
                    color: Theme.c.comment
                    text: Power.sleepMinutes > 0 ? `Sleeps after ${Power.sleepMinutes < 60 ? `${Power.sleepMinutes} min` : `${Power.sleepMinutes / 60} h`} idle` : "Never sleeps"
                }
            }
        }

        // ── Session actions ───────────────────────────────────────
        RowLayout {
            id: actions

            Layout.fillWidth: true
            spacing: Theme.spacing.small

            Action {
                name: "lock"
                key: "l"
                icon: "lock"
                label: "Lock"
                onTriggered: Power.lock()
            }
            Action {
                name: "logout"
                key: "e"
                icon: "logout"
                label: "Log out"
                confirm: true
                onTriggered: Power.logout()
            }
            Action {
                name: "reboot"
                key: "r"
                icon: "restart_alt"
                label: "Restart"
                confirm: true
                onTriggered: Power.reboot()
            }
            Action {
                name: "shutdown"
                key: "s"
                icon: "power_settings_new"
                label: "Shut down"
                confirm: true
                onTriggered: Power.shutdown()
            }
        }

        // ── Battery ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: SysStats.hasBattery
            implicitHeight: battery.implicitHeight + 28
            radius: Theme.rounding.normal
            color: Theme.c.bgHighlight

            UsageRow {
                id: battery

                anchors.fill: parent
                anchors.margins: 14
                icon: SysStats.batteryIcon()
                label: "Battery"
                value: {
                    const p = `${SysStats.batteryPercent}%`;
                    if (SysStats.full)
                        return `${p} · Full`;
                    if (SysStats.timeLeft > 0)
                        return `${p} · ${SysStats.duration(SysStats.timeLeft)} ${SysStats.charging ? "to full" : "left"}`;
                    return SysStats.charging ? `${p} · Charging` : p;
                }
                fraction: SysStats.batteryPercent / 100
                barColor: SysStats.batteryPercent <= 15 && !SysStats.charging ? Theme.c.red : Theme.c.blue
            }
        }

        // ── Battery saver ─────────────────────────────────────────
        Tile {
            visible: SysStats.hasBattery
            icon: "battery_saver"
            label: "Battery saver"
            sublabel: Power.batterySaver ? "Power-saver profile" : Power.gameMode ? "Off while game mode is on" : "Turns on at 20% on battery"
            checked: Power.batterySaver
            onClicked: Power.setBatterySaver(!Power.batterySaver)
        }

        // ── Sleep after ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sleepCol.implicitHeight + 28
            radius: Theme.rounding.normal
            color: Theme.c.bgHighlight

            ColumnLayout {
                id: sleepCol

                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    spacing: Theme.spacing.normal

                    MaterialIcon {
                        size: 20
                        fill: Power.sleepMinutes > 0 ? 1 : 0
                        text: "bedtime"
                        color: Power.sleepMinutes > 0 ? Theme.c.blue : Theme.c.comment
                    }
                    StyledText {
                        text: "Sleep after"
                        font.weight: Font.DemiBold
                    }
                }

                // Segmented choice of idle timeouts.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: Power.sleepSteps

                        Rectangle {
                            id: chip

                            required property int modelData
                            readonly property bool selected: Power.sleepMinutes === modelData

                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: selected ? height / 2 : Theme.rounding.small
                            color: selected ? Theme.c.blue : Theme.c.bg

                            Behavior on color {
                                CAnim {}
                            }
                            Behavior on radius {
                                Anim {
                                    duration: Theme.anim.fastDuration
                                }
                            }

                            StateLayer {
                                color: chip.selected ? Theme.c.bgDark : Theme.c.fg
                                onClicked: Power.sleepMinutes = chip.modelData
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: chip.modelData === 0 ? "Never" : chip.modelData < 60 ? `${chip.modelData}m` : `${chip.modelData / 60}h`
                                font.pixelSize: Theme.font.small
                                font.weight: chip.selected ? Font.DemiBold : Font.Normal
                                color: chip.selected ? Theme.c.bgDark : Theme.c.fgDark
                            }
                        }
                    }
                }
            }
        }
    }

    // Square-ish button with icon over label. With `confirm`, the first
    // click turns it red and only a second click (within 3 s) runs it.
    component Action: Rectangle {
        id: action

        required property string name
        required property string icon
        required property string label
        // Keyboard shortcut, shown in the corner.
        property string key
        property bool confirm
        readonly property bool isArmed: root.armed === name
        signal triggered

        Layout.fillWidth: true
        implicitHeight: 70
        radius: isArmed ? Theme.rounding.large : Theme.rounding.normal
        color: isArmed ? Theme.c.red : Theme.c.bgHighlight

        Behavior on color {
            CAnim {}
        }
        Behavior on radius {
            Anim {}
        }

        StateLayer {
            color: action.isArmed ? Theme.c.bgDark : Theme.c.fg
            onClicked: {
                if (action.confirm && !action.isArmed) {
                    root.armed = action.name;
                    disarm.restart();
                    return;
                }
                root.armed = "";
                root.closeRequested();
                action.triggered();
            }
        }

        StyledText {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 7
            text: action.key.toUpperCase()
            font.pixelSize: Theme.font.small - 3
            font.weight: Font.DemiBold
            color: action.isArmed ? Qt.alpha(Theme.c.bgDark, 0.6) : Theme.c.comment
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 22
                fill: 1
                text: action.icon
                color: action.isArmed ? Theme.c.bgDark : action.name === "shutdown" ? Theme.c.red : Theme.c.blue
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: action.isArmed ? "Confirm" : action.label
                font.pixelSize: Theme.font.small - 1
                font.weight: action.isArmed ? Font.DemiBold : Font.Normal
                color: action.isArmed ? Theme.c.bgDark : Theme.c.fgDark
            }
        }
    }
}
