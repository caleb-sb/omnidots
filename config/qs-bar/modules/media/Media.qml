pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "media.js" as Logic

// Spotify's MPRIS player and what the bar pill shows (media.js). Other
// players, browser tabs included, are ignored.
Singleton {
    id: root

    readonly property MprisPlayer player: Logic.pick(Mpris.players.values)
    readonly property bool shown: Logic.visible(player, player?.playbackState === MprisPlaybackState.Stopped)
    readonly property string text: Logic.label(player?.trackTitle, player?.trackArtist)
    readonly property bool playing: player?.isPlaying ?? false

    // Focus Spotify's window, switching to its workspace. The Lua config's
    // hl.focus takes a window selector: the class is a regex, "Spotify" or
    // "spotify" depending on the build, so match it case-insensitively.
    function focus(): void {
        Hyprland.dispatch(`hl.dsp.focus({ window = "class:(?i)spotify" })`);
    }
}
