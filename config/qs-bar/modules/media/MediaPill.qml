import QtQuick
import qs.config
import qs.components

// Bar item: the Spotify track as "Title — Artist" with previous, play/pause
// and next buttons. Only there while Spotify has a track loaded. Clicking
// the text opens the media panel; right-clicking it hides Spotify's window
// to the tray or shows it again, as its tray icon did.
BarGroup {
    id: root

    property bool active
    signal clicked

    visible: Media.shown
    padding: 2

    Rectangle {
        implicitWidth: label.implicitWidth + 28
        implicitHeight: root.implicitHeight - root.padding * 2
        radius: height / 2
        color: root.active ? Theme.c.blue7 : "transparent"

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            radius: parent.radius
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => {
                if (e.button === Qt.RightButton)
                    Media.toggleWindow();
                else
                    root.clicked();
            }
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: Media.text
            font.pixelSize: Theme.font.bar
            color: Theme.c.fgDark
        }
    }

    IconButton {
        size: 30
        icon: "skip_previous"
        fill: 1
        disabled: !Media.player?.canGoPrevious
        iconColor: disabled ? Theme.c.comment : Theme.c.fgDark
        onClicked: Media.player.previous()
    }

    IconButton {
        size: 30
        icon: Media.playing ? "pause" : "play_arrow"
        fill: 1
        disabled: !Media.player?.canTogglePlaying
        iconColor: disabled ? Theme.c.comment : Theme.c.fg
        onClicked: Media.player.togglePlaying()
    }

    IconButton {
        size: 30
        icon: "skip_next"
        fill: 1
        disabled: !Media.player?.canGoNext
        iconColor: disabled ? Theme.c.comment : Theme.c.fgDark
        onClicked: Media.player.next()
    }
}
