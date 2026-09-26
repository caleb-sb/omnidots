pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.notifications

// Session actions, sleep-after-idle and game mode. Settings are kept in
// the Quickshell state dir so they survive restarts.
Singleton {
    id: root

    // Minutes of idle before suspending; 0 = never.
    property int sleepMinutes: 0
    readonly property list<int> sleepSteps: [0, 5, 15, 30, 60]
    // Blur, animations, window transparency and notification popups off;
    // XWayland apps render unscaled (force_zero_scaling).
    property bool gameMode

    function lock(): void {
        Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]);
    }
    function suspend(): void {
        // Lock first so the session is locked on wake.
        Quickshell.execDetached(["sh", "-c", "pidof hyprlock || { hyprlock & sleep 1; }; systemctl suspend"]);
    }
    function logout(): void {
        Hyprland.dispatch("hl.dsp.exit()");
    }
    function reboot(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function shutdown(): void {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    // Live compositor settings only; the Hyprland config itself is untouched.
    // Transparency comes from per-app window rules, so game mode adds one
    // last catch-all rule that forces full opacity and toggles it. The rule
    // lives in a Lua global, which persists between evals.
    function applyGameMode(): void {
        const g = root.gameMode;
        Quickshell.execDetached(["hyprctl", "eval", `
            hl.config({
                decoration = { blur = { enabled = ${!g} } },
                animations = { enabled = ${!g} },
                xwayland = { force_zero_scaling = ${g} },
            })
            _G.qsGameOpacity = _G.qsGameOpacity or hl.window_rule({
                name = "qs-gamemode-opacity",
                match = { class = ".*" },
                opacity = "1.0 override 1.0 override",
            })
            _G.qsGameOpacity:set_enabled(${g})
        `]);
    }

    onGameModeChanged: {
        if (loaded)
            applyGameMode();
        saveTimer.restart();
    }
    onSleepMinutesChanged: saveTimer.restart()

    Binding {
        target: Notifs
        property: "quiet"
        value: root.gameMode
    }

    // A config reload puts blur and animations back; take them off again.
    Connections {
        target: Hyprland

        function onRawEvent(e: HyprlandEvent): void {
            if (e.name === "configreloaded" && root.gameMode)
                root.applyGameMode();
        }
    }

    IdleMonitor {
        enabled: root.sleepMinutes > 0
        timeout: root.sleepMinutes * 60
        // Video players and games that inhibit idle keep the machine awake.
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            root.suspend()
    }

    // ── Persistence ───────────────────────────────────────────────
    property bool loaded

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: if (root.loaded)
            storage.setText(JSON.stringify({
                sleepMinutes: root.sleepMinutes,
                gameMode: root.gameMode
            }))
    }

    FileView {
        id: storage

        path: Quickshell.statePath("power.json")
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.sleepMinutes = data.sleepMinutes ?? 0;
                root.gameMode = !!data.gameMode;
            } catch (e) {
                console.warn("power: bad state file,", e);
            }
            root.loaded = true;
            if (root.gameMode)
                root.applyGameMode();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }
}
