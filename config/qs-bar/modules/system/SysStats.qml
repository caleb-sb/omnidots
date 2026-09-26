pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Memory, root disk and battery readings for the device monitor, plus CPU,
// GPU and temperatures, which only update while something is `watching`
// (the system panel), since the bar itself doesn't show them.
Singleton {
    id: root

    // Bytes.
    property real memUsed
    property real memTotal
    property real diskUsed
    property real diskTotal

    // Number of open views that want CPU/GPU/temperature readings.
    property int watching
    readonly property bool detailed: watching > 0

    // 0..1, -1 until known.
    property real cpuUsage: -1
    property real gpuUsage: -1
    // Graphics clock in MHz, -1 until known. utilization.gpu is busy time at
    // the current clock, so an idle card at its lowest clock can read 30-40%.
    property real gpuClock: -1
    // °C, -1 when there's no such sensor.
    property real cpuTemp: -1
    property real gpuTemp: -1
    property real diskTemp: -1
    property string cpuName
    property string gpuName
    readonly property bool hasGpu: gpuName !== ""

    readonly property UPowerDevice battery: UPower.displayDevice
    // Only report a battery when there is one with a percentage (desktops
    // still get a display device from UPower, just not a laptop battery).
    readonly property bool hasBattery: !!battery?.isLaptopBattery && battery.isPresent
    readonly property int batteryPercent: Math.round((battery?.percentage ?? 0) * 100)
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: battery?.state === UPowerDeviceState.FullyCharged
    // Seconds; 0 while UPower is still estimating.
    readonly property real timeLeft: charging ? battery?.timeToFull ?? 0 : battery?.timeToEmpty ?? 0

    // 7.3G / 296G style, one decimal below 10.
    function gb(bytes: real): string {
        const g = bytes / 1073741824;
        return g < 10 ? `${g.toFixed(1)}G` : `${Math.round(g)}G`;
    }

    function duration(secs: real): string {
        const m = Math.round(secs / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? `${h}h ${m % 60}m` : `${m}m`;
    }

    function batteryIcon(): string {
        if (charging || full)
            return "battery_charging_full";
        const p = batteryPercent;
        if (p >= 95)
            return "battery_full";
        // battery_0_bar .. battery_6_bar
        return `battery_${Math.max(0, Math.min(6, Math.floor(p / 14)))}_bar`;
    }

    // hwmon numbers change between boots, so find sensors by name once.
    property string cpuHwmon
    property string diskHwmon
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do echo \"$(cat $h/name) $h\"; done; grep -m1 'model name' /proc/cpuinfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const [name, path] = line.split(" ");
                    if ((name === "k10temp" || name === "coretemp") && !root.cpuHwmon)
                        root.cpuHwmon = path;
                    else if (name === "nvme" && !root.diskHwmon)
                        root.diskHwmon = path;
                }
                // "AMD Ryzen 7 5700G with Radeon Graphics" -> "AMD Ryzen 7 5700G"
                root.cpuName = (text.match(/model name\s*:\s*(.*)/)?.[1] ?? "").replace(/ with .*| \d+-Core.*| CPU.*/, "").trim();
            }
        }
    }

    FileView {
        id: cpuTempFile

        path: root.cpuHwmon ? `${root.cpuHwmon}/temp1_input` : ""
        onLoaded: root.cpuTemp = parseInt(text()) / 1000
    }
    FileView {
        id: diskTempFile

        path: root.diskHwmon ? `${root.diskHwmon}/temp1_input` : ""
        onLoaded: root.diskTemp = parseInt(text()) / 1000
    }

    // CPU usage from the change in /proc/stat's idle vs total time.
    property var lastCpu
    // Start from a fresh sample each time, not one from hours ago.
    onDetailedChanged: {
        lastCpu = null;
        cpuUsage = -1;
    }
    FileView {
        id: procStat

        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.slice(0, 8).reduce((a, b) => a + b, 0);
            const last = root.lastCpu;
            if (last && total > last.total)
                root.cpuUsage = 1 - (idle - last.idle) / (total - last.total);
            root.lastCpu = { idle, total };
        }
    }

    Process {
        id: nvidia

        command: ["nvidia-smi", "--query-gpu=name,temperature.gpu,utilization.gpu,clocks.gr", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",").map(x => x.trim());
                if (f.length < 4)
                    return;
                root.gpuName = f[0].replace(/^NVIDIA (GeForce )?/, "");
                root.gpuTemp = +f[1];
                root.gpuUsage = +f[2] / 100;
                root.gpuClock = +f[3];
            }
        }
    }

    Timer {
        interval: 2000
        running: root.detailed
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procStat.reload();
            cpuTempFile.reload();
            diskTempFile.reload();
            nvidia.running = true;
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => +(text().match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))?.[1] ?? 0) * 1024;
            root.memTotal = kb("MemTotal");
            root.memUsed = root.memTotal - kb("MemAvailable");
        }
    }

    Process {
        id: df

        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n").pop().trim().split(/\s+/);
                root.diskUsed = +f[0] || 0;
                root.diskTotal = +f[1] || 0;
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: meminfo.reload()
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }
}
