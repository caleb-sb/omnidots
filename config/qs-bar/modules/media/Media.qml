pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import "media.js" as Logic

// Spotify's MPRIS player and what the bar pill shows (media.js). Other
// players, browser tabs included, are ignored.
//
// Spotify's own tray icon is hidden from the bar's tray (Bar.qml): all it
// did was hide the window to the tray and show it again, which
// showWindow() and hideWindow() now do by triggering the same menu entries.
Singleton {
    id: root

    readonly property MprisPlayer player: Logic.pick(Mpris.players.values)
    readonly property bool shown: Logic.visible(player, player?.playbackState === MprisPlaybackState.Stopped)
    readonly property string text: Logic.label(player?.trackTitle, player?.trackArtist)
    readonly property bool playing: player?.isPlaying ?? false

    // Spotify's tray icon (a menu-only Ayatana item) and its window, which
    // is unmapped, not minimized, while it's in the tray.
    readonly property string trayId: "spotify-client"
    readonly property SystemTrayItem trayItem: SystemTray.items.values.find(i => i.id === trayId) ?? null
    readonly property Toplevel window: ToplevelManager.toplevels.values.find(t => t.appId.toLowerCase() === "spotify") ?? null
    readonly property var hideEntry: Logic.trayEntry(menu.children.values, true)
    readonly property var showEntry: Logic.trayEntry(menu.children.values, false)
    // Whether the window button can do anything: hide needs the tray menu;
    // show falls back to MPRIS Raise without it.
    readonly property bool canToggleWindow: window ? !!hideEntry : (!!showEntry || (player?.canRaise ?? false))

    // Set by showWindow() so the window is focused once it has mapped.
    property bool focusOnShow

    // Focus Spotify's window, switching to its workspace. The Lua config's
    // hl.focus takes a window selector: the class is a regex, "Spotify" or
    // "spotify" depending on the build, so match it case-insensitively.
    function focus(): void {
        Hyprland.dispatch(`hl.dsp.focus({ window = "class:(?i)spotify" })`);
    }

    // Bring the window back from the tray and focus it, or just focus it.
    function showWindow(): void {
        if (window) {
            focus();
            return;
        }
        focusOnShow = true;
        if (showEntry)
            showEntry.triggered();
        else
            player?.raise();
    }

    function hideWindow(): void {
        hideEntry?.triggered();
    }

    function toggleWindow(): void {
        if (window)
            hideWindow();
        else
            showWindow();
    }

    onWindowChanged: {
        if (window && focusOnShow) {
            focusOnShow = false;
            focus();
        }
    }

    QsMenuOpener {
        id: menu

        menu: root.trayItem?.menu ?? null
    }
}
