pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Render scale of the main monitor: 1.5 normally, 2.5 for viewing from
// a distance. Only changes the live compositor state; a Hyprland config reload
// puts it back to the configured 1.5.
Singleton {
    id: root

    // Cycle order. Each one divides 3840x2160 into whole pixels.
    readonly property list<real> steps: [1.5, 2.5]
    readonly property real normal: steps[0]

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(PrimaryScreen.screen)
    readonly property real reported: monitor?.scale ?? normal
    // Scale just asked for, until Hyprland reports it back, so quick
    // repeated clicks keep stepping instead of re-reading the old value.
    property real pending: -1
    readonly property real scale: pending > 0 ? pending : reported
    onReportedChanged: {
        if (Math.abs(reported - pending) < 0.01)
            pending = -1;
    }
    readonly property bool enlarged: Math.abs(scale - normal) > 0.01

    // Next step after the current scale; anything off the list goes to normal.
    function toggle(): void {
        const i = steps.findIndex(s => Math.abs(s - scale) < 0.01);
        set(i < 0 ? normal : steps[(i + 1) % steps.length]);
    }

    function set(s: real): void {
        const m = monitor?.lastIpcObject;
        if (!m?.name)
            return;
        // Keep the current mode and position; only the scale changes.
        const mode = `${m.width}x${m.height}@${+m.refreshRate.toFixed(2)}`;
        pending = s;
        settle.restart();
        Quickshell.execDetached(["hyprctl", "eval", `hl.monitor({ output = "${m.name}", mode = "${mode}", position = "${m.x}x${m.y}", scale = ${s} })`]);
        refresh.restart();
    }

    // monitor.scale only updates when the monitor list is re-read, and until
    // the first read it holds the rounded-up integer scale.
    Component.onCompleted: Hyprland.refreshMonitors()
    // Give up on a pending scale Hyprland never applied.
    Timer {
        id: settle

        interval: 2000
        onTriggered: root.pending = -1
    }
    Timer {
        id: refresh

        interval: 300
        onTriggered: Hyprland.refreshMonitors()
    }
    Connections {
        target: Hyprland

        function onRawEvent(e: HyprlandEvent): void {
            if (e.name === "configreloaded" || e.name.startsWith("monitor"))
                refresh.restart();
        }
    }
}
