import QtQuick
import qs.config
import qs.components

// Bar item: output volume glyph, plus a mic_off badge while the input is
// muted. Left click opens the panel, right click mutes output, middle click
// mutes input, scroll changes output volume.
Item {
    id: root

    property bool active
    signal clicked

    implicitWidth: pill.width
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2

    Rectangle {
        id: pill

        height: parent.height
        width: row.width + height - 18
        radius: height / 2
        color: root.active ? Theme.c.blue7 : "transparent"

        Behavior on width {
            Anim {
                duration: Theme.anim.fastDuration
            }
        }
        Behavior on color {
            CAnim {}
        }

        StateLayer {
            radius: parent.radius
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                if (e.button === Qt.RightButton)
                    Audio.toggleMute(Audio.sink);
                else if (e.button === Qt.MiddleButton)
                    Audio.toggleMute(Audio.source);
                else
                    root.clicked();
            }
            onWheel: e => {
                const dir = e.angleDelta.y > 0 ? 1 : e.angleDelta.y < 0 ? -1 : 0;
                if (dir !== 0)
                    Audio.setVolume(Audio.sink, Audio.volume + dir * Audio.step);
            }
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 2

            MaterialIcon {
                size: 18
                fill: Audio.muted ? 0 : 1
                text: Audio.volumeIcon(Audio.volume, Audio.muted)
                color: Audio.muted ? Theme.c.comment : Theme.c.blue
            }

            Item {
                width: Audio.sourceMuted ? micOff.implicitWidth : 0
                height: micOff.implicitHeight
                visible: micOff.opacity > 0
                anchors.verticalCenter: parent.verticalCenter

                MaterialIcon {
                    id: micOff

                    size: 16
                    opacity: Audio.sourceMuted ? 1 : 0
                    text: "mic_off"
                    color: Theme.c.comment

                    Behavior on opacity {
                        Anim {
                            duration: Theme.anim.effectsDuration
                        }
                    }
                }
            }
        }
    }
}
