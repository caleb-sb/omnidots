pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.components
import "media.js" as Logic

// Spotify panel, opened from the media pill: album art and the track, a
// scrubber, playback controls with shuffle and repeat, and the window
// button that replaces Spotify's tray icon (hide to tray / show).
Item {
    id: root

    signal closeRequested

    readonly property MprisPlayer player: Media.player
    // MPRIS reports lengths it doesn't know as huge numbers.
    readonly property bool hasLength: (player?.lengthSupported ?? false) && player.length > 0 && player.length < 2147483647
    readonly property bool canSeek: hasLength && (player?.canSeek ?? false) && (player?.positionSupported ?? false)

    implicitWidth: 380
    implicitHeight: column.implicitHeight

    // Nothing left to show once Spotify quits or stops.
    Connections {
        target: Media

        function onShownChanged(): void {
            if (!Media.shown)
                root.closeRequested();
        }
    }

    // Quickshell doesn't track the position on its own; ask for it while
    // the panel is open. positionChanged() re-reads it from the player.
    Timer {
        running: Media.playing && root.visible
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.large

        // ── Art and track ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.large

            // Clicking the art brings Spotify's window up.
            ClippingRectangle {
                id: art

                implicitWidth: 104
                implicitHeight: 104
                radius: Theme.rounding.normal
                color: Theme.c.bgHighlight
                // Settles back a little while paused.
                scale: Media.playing ? 1 : 0.92

                Behavior on scale {
                    Anim {
                        easing.bezierCurve: Theme.anim.spatial
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 40
                    text: "music_note"
                    color: Theme.c.comment
                    visible: cover.status !== Image.Ready
                }

                Image {
                    id: cover

                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    sourceSize.width: 208
                    sourceSize.height: 208
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Theme.anim.effectsDuration
                        }
                    }
                }

                StateLayer {
                    onClicked: {
                        Media.showWindow();
                        root.closeRequested();
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle ?? ""
                    font.pixelSize: Theme.font.large
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.player?.trackArtist ?? ""
                    color: Theme.c.fgDark
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.player?.trackAlbum ?? ""
                    font.pixelSize: Theme.font.small
                    color: Theme.c.comment
                    elide: Text.ElideRight
                }
            }
        }

        // ── Scrubber ──────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            visible: root.hasLength

            Slider {
                id: scrubber

                Layout.fillWidth: true
                value: root.hasLength ? root.player.position / root.player.length : 0
                step: 5 / Math.max(1, root.player?.length ?? 1)
                dimmed: !root.canSeek
                enabled: root.canSeek
                // Seek once the drag ends; the wheel seeks straight away.
                onMoved: v => {
                    if (!pressed)
                        root.seek(v);
                }
                onReleased: v => root.seek(v)
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: Logic.clock((scrubber.pressed ? scrubber.dragValue : scrubber.value) * (root.player?.length ?? 0))
                    font.pixelSize: Theme.font.small
                    font.features: ({
                            tnum: 1
                        })
                    color: Theme.c.comment
                }
                Item {
                    Layout.fillWidth: true
                }
                StyledText {
                    text: Logic.clock(root.player?.length ?? 0)
                    font.pixelSize: Theme.font.small
                    font.features: ({
                            tnum: 1
                        })
                    color: Theme.c.comment
                }
            }
        }

        // ── Controls ──────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacing.normal

            IconButton {
                size: 36
                icon: "shuffle"
                disabled: !(root.player?.shuffleSupported ?? false)
                iconColor: root.player?.shuffle ? Theme.c.blue : Theme.c.comment
                onClicked: root.player.shuffle = !root.player.shuffle
            }

            IconButton {
                size: 44
                icon: "skip_previous"
                fill: 1
                disabled: !root.player?.canGoPrevious
                iconColor: disabled ? Theme.c.comment : Theme.c.fg
                onClicked: root.player.previous()
            }

            // Play/pause: a filled square while playing, a pill while paused.
            Rectangle {
                implicitWidth: 64
                implicitHeight: 52
                radius: Media.playing ? Theme.rounding.normal : height / 2
                color: Theme.c.blue

                Behavior on radius {
                    Anim {}
                }

                StateLayer {
                    color: Theme.c.bgDark
                    disabled: !root.player?.canTogglePlaying
                    onClicked: root.player.togglePlaying()
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 28
                    fill: 1
                    text: Media.playing ? "pause" : "play_arrow"
                    color: Theme.c.bgDark
                }
            }

            IconButton {
                size: 44
                icon: "skip_next"
                fill: 1
                disabled: !root.player?.canGoNext
                iconColor: disabled ? Theme.c.comment : Theme.c.fg
                onClicked: root.player.next()
            }

            // Off, then the whole playlist, then this track, as in Spotify.
            IconButton {
                readonly property int loop: root.player?.loopState ?? MprisLoopState.None

                size: 36
                icon: loop === MprisLoopState.Track ? "repeat_one" : "repeat"
                disabled: !(root.player?.loopSupported ?? false)
                iconColor: loop === MprisLoopState.None ? Theme.c.comment : Theme.c.blue
                onClicked: root.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        // ── Window ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.rounding.full
            color: Theme.c.bgHighlight
            opacity: Media.canToggleWindow ? 1 : 0.5

            StateLayer {
                disabled: !Media.canToggleWindow
                onClicked: {
                    Media.toggleWindow();
                    root.closeRequested();
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacing.small

                MaterialIcon {
                    size: 18
                    text: Media.window ? "visibility_off" : "open_in_new"
                    color: Theme.c.fgDark
                }
                StyledText {
                    text: Media.window ? "Hide to tray" : "Show Spotify"
                    color: Theme.c.fgDark
                }
            }
        }
    }

    function seek(frac: real): void {
        if (root.canSeek)
            root.player.position = frac * root.player.length;
    }
}
