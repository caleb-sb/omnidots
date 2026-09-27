pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The screen for the full bar and the notification popups: the primary output
// Hyprland's monitors.lua names in $XDG_RUNTIME_DIR, else the first screen.
Singleton {
    id: root

    property string name: ""

    readonly property ShellScreen screen: {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === root.name)
                return screens[i];
        }
        return screens[0] ?? null;
    }

    FileView {
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/omnidots-primary-output`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.name = text().trim()
    }
}
