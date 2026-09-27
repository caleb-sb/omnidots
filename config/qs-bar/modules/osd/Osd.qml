import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.modules.audio
import qs.modules.display

// Volume and brightness popup, bottom centre of the primary screen. Only the
// IPC targets below (Hyprland's volume and brightness keys) change the level
// and show it, so changes made elsewhere stay quiet. Each press restarts the
// hide timer.
PanelWindow {
    id: root

    // What the popup shows: "volume" or "brightness".
    property string kind: "volume"
    property bool shown: false

    readonly property bool muted: kind === "volume" && Audio.muted
    readonly property real level: kind === "volume" ? Audio.volume : Brightness.percent / 100
    readonly property string icon: {
        if (kind === "volume")
            return Audio.volumeIcon(Audio.volume, Audio.muted);
        return level < 0.34 ? "brightness_low" : level < 0.67 ? "brightness_medium" : "brightness_high";
    }
    readonly property color accent: muted ? Theme.c.comment : kind === "volume" ? Theme.c.blue : Theme.c.yellow

    function show(what: string): void {
        kind = what;
        shown = true;
        hideTimer.restart();
    }

    screen: PrimaryScreen.screen
    anchors.bottom: true
    margins.bottom: 64
    implicitWidth: 300
    implicitHeight: 56
    exclusiveZone: 0
    color: "transparent"
    visible: card.opacity > 0

    WlrLayershell.namespace: "qs-bar-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    // Click-through.
    mask: Region {}

    Timer {
        id: hideTimer

        interval: 1500
        onTriggered: root.shown = false
    }

    // `ipc call volume up | down | mute` (the volume keys): 5% steps on the
    // default output, capped at 100%. Up and down unmute.
    IpcHandler {
        target: "volume"

        function up(): void {
            Audio.setVolume(Audio.sink, Audio.volume + Audio.step);
            root.show("volume");
        }
        function down(): void {
            Audio.setVolume(Audio.sink, Audio.volume - Audio.step);
            root.show("volume");
        }
        function mute(): void {
            Audio.toggleMute(Audio.sink);
            root.show("volume");
        }
    }

    // `ipc call brightness up | down` (the brightness keys): 5% steps, never
    // below 1%. Does nothing without a backlight.
    IpcHandler {
        target: "brightness"

        function up(): void {
            if (!Brightness.available)
                return;
            Brightness.change(1);
            root.show("brightness");
        }
        function down(): void {
            if (!Brightness.available)
                return;
            Brightness.change(-1);
            root.show("brightness");
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: height / 2
        color: Theme.c.bg
        border.width: 1
        border.color: Theme.c.bgHighlight
        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            Anim {
                duration: Theme.anim.effectsDuration
                easing.bezierCurve: Theme.anim.standard
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.large
            anchors.rightMargin: Theme.spacing.large
            spacing: Theme.spacing.normal

            MaterialIcon {
                id: glyph

                anchors.verticalCenter: parent.verticalCenter
                size: 22
                fill: root.muted ? 0 : 1
                text: root.icon
                color: root.accent
            }

            Rectangle {
                id: track

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - glyph.width - percent.width - parent.spacing * 2
                height: 6
                radius: height / 2
                color: Theme.c.bgHighlight

                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, root.level))
                    height: parent.height
                    radius: parent.radius
                    color: root.accent

                    Behavior on width {
                        Anim {
                            duration: Theme.anim.effectsDuration
                            easing.bezierCurve: Theme.anim.standard
                        }
                    }
                    Behavior on color {
                        CAnim {}
                    }
                }
            }

            StyledText {
                id: percent

                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(root.level * 100)}%`
                color: root.muted ? Theme.c.comment : Theme.c.fg
                font.pixelSize: Theme.font.normal
            }
        }
    }
}
