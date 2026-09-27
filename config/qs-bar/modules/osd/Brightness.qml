pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The screen backlight, through brightnessctl. Without a backlight (or
// without brightnessctl) `available` stays false and change() does nothing.
Singleton {
    id: root

    property bool available: false
    property int percent: 0
    // Raw maximum, for the 1% floor.
    property int max: 0

    readonly property int step: 5

    // Steps asked for while brightnessctl was still running (key repeat),
    // sent together once it exits.
    property int pending: 0

    // Brighter (steps > 0) or dimmer (steps < 0) by `step` percent each,
    // never below 1%.
    function change(steps: int): void {
        if (!available)
            return;
        pending += steps;
        if (!setter.running)
            flush();
    }

    function flush(): void {
        const n = pending;
        pending = 0;
        if (n === 0)
            return;
        const floor = Math.max(1, Math.ceil(max / 100));
        const delta = `${Math.abs(n) * step}%${n > 0 ? "+" : "-"}`;
        setter.command = ["sh", "-c", 'brightnessctl -q -c backlight --min-value="$1" set "$2" && brightnessctl -m -c backlight', "sh", `${floor}`, delta];
        setter.running = true;
    }

    // brightnessctl -m: "intel_backlight,backlight,<raw>,<percent>%,<max>".
    function parse(text: string): bool {
        const f = text.trim().split("\n").pop().split(",");
        if (f.length < 5 || f[1] !== "backlight")
            return false;
        percent = parseInt(f[3]) || 0;
        max = parseInt(f[4]) || 0;
        return true;
    }

    Process {
        running: true
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.available = root.parse(text)
        }
    }

    Process {
        id: setter

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: root.flush()
    }
}
