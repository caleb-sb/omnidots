import QtQuick
import qs.config
import qs.components

// Bar item: the Spotify track as "Title — Artist" with previous, play/pause
// and next buttons. Only there while Spotify has a track loaded. Clicking
// the text focuses Spotify.
BarGroup {
    id: root

    visible: Media.shown
    padding: 2

    Item {
        implicitWidth: label.implicitWidth + 28
        implicitHeight: root.implicitHeight

        StateLayer {
            radius: height / 2
            onClicked: Media.focus()
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
