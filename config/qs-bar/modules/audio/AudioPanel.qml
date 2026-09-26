pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// Control-center style audio panel: output and input, each with a mute
// toggle, volume slider and device picker.
Item {
    id: root

    signal closeRequested

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
                radius: Audio.muted ? 22 : Theme.rounding.normal
                color: Audio.muted ? Theme.c.bgHighlight : Theme.c.blue

                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim {}
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 24
                    fill: Audio.muted ? 0 : 1
                    text: "graphic_eq"
                    color: Audio.muted ? Theme.c.dark5 : Theme.c.bgDark
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Audio"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.small
                    color: Theme.c.comment
                    text: Audio.sink ? Audio.label(Audio.sink) : "No output device"
                }
            }
        }

        Channel {
            title: "Output"
            node: Audio.sink
            devices: Audio.sinks
            volume: Audio.volume
            muted: Audio.muted
            icon: Audio.volumeIcon(Audio.volume, Audio.muted)
            emptyText: "No output devices"
        }

        Channel {
            title: "Input"
            node: Audio.source
            devices: Audio.sources
            volume: Audio.sourceVolume
            muted: Audio.sourceMuted
            icon: Audio.sourceMuted ? "mic_off" : "mic"
            emptyText: "No input devices"
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
                    Quickshell.execDetached(["pavucontrol"]);
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
                    text: "Sound settings"
                    color: Theme.c.fgDark
                }
            }
        }
    }

    // One direction (output or input): label, mute + slider, device list.
    component Channel: ColumnLayout {
        id: channel

        required property string title
        required property PwNode node
        required property var devices
        required property real volume
        required property bool muted
        required property string icon
        required property string emptyText

        Layout.fillWidth: true
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            Layout.leftMargin: 4
            Layout.bottomMargin: 4
            text: channel.title.toUpperCase()
            font.pixelSize: Theme.font.small - 1
            font.letterSpacing: 1.2
            font.weight: Font.DemiBold
            color: Theme.c.comment
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.spacing.small
            spacing: Theme.spacing.normal
            visible: !!channel.node

            // Mute toggle: filled while live, pill while muted.
            Rectangle {
                id: muteBtn

                implicitWidth: 40
                implicitHeight: 40
                radius: channel.muted ? 20 : Theme.rounding.normal
                color: channel.muted ? Theme.c.bgHighlight : Theme.c.blue

                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim {}
                }

                StateLayer {
                    color: channel.muted ? Theme.c.fg : Theme.c.bgDark
                    onClicked: Audio.toggleMute(channel.node)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 20
                    fill: channel.muted ? 0 : 1
                    text: channel.icon
                    color: channel.muted ? Theme.c.red : Theme.c.bgDark
                }
            }

            Slider {
                Layout.fillWidth: true
                value: channel.volume
                dimmed: channel.muted
                onMoved: v => Audio.setVolume(channel.node, v)
            }

            StyledText {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(channel.volume * 100)}%`
                font.features: ({
                        tnum: 1
                    })
                color: channel.muted ? Theme.c.comment : Theme.c.fgDark
            }
        }

        Repeater {
            model: channel.devices

            DeviceOption {
                selected: channel.node?.id === modelData.id
            }
        }

        StyledText {
            visible: channel.devices.length === 0
            Layout.leftMargin: 4
            text: channel.emptyText
            color: Theme.c.comment
        }
    }

    component DeviceOption: Rectangle {
        id: opt

        required property PwNode modelData
        property bool selected

        Layout.fillWidth: true
        implicitHeight: 44
        radius: selected ? Theme.rounding.normal : Theme.rounding.small
        color: selected ? Theme.c.bgHighlight : "transparent"

        Behavior on color {
            CAnim {}
        }
        Behavior on radius {
            Anim {}
        }

        StateLayer {
            disabled: opt.selected
            onClicked: Audio.setDefault(opt.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: Theme.spacing.normal

            MaterialIcon {
                size: 20
                fill: opt.selected ? 1 : 0
                text: Audio.deviceIcon(opt.modelData)
                color: opt.selected ? Theme.c.blue : Theme.c.dark5
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Audio.label(opt.modelData)
                color: opt.selected ? Theme.c.fg : Theme.c.fgDark
                font.weight: opt.selected ? Font.DemiBold : Font.Normal
            }

            MaterialIcon {
                size: 18
                text: "check"
                color: Theme.c.blue
                opacity: opt.selected ? 1 : 0
                scale: opt.selected ? 1 : 0.5

                Behavior on opacity {
                    Anim {
                        duration: Theme.anim.effectsDuration
                    }
                }
                Behavior on scale {
                    Anim {
                        duration: Theme.anim.fastDuration
                        easing.bezierCurve: Theme.anim.fastSpatial
                    }
                }
            }
        }
    }
}
