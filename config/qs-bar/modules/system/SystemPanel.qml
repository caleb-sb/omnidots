import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components

// System panel: CPU and GPU load with temperatures, memory, disk, and the
// game mode toggle. CPU/GPU/temperature readings only run while it's open.
Item {
    id: root

    signal closeRequested

    Component.onCompleted: SysStats.watching++
    Component.onDestruction: SysStats.watching--

    property real uptime
    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: root.uptime = parseFloat(text())
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: uptimeFile.reload()
    }

    function pct(f: real): string {
        return f < 0 ? "–" : `${Math.round(f * 100)}%`;
    }
    function clock(mhz: real): string {
        return mhz < 0 ? "" : ` @ ${Math.round(mhz)} MHz`;
    }
    function temp(t: real): string {
        return t < 0 ? "" : ` · ${Math.round(t)}°C`;
    }
    // Hot sensors are flagged in the value text.
    function tempColor(t: real, warm: real, hot: real): color {
        return t >= hot ? Theme.c.red : t >= warm ? Theme.c.yellow : Theme.c.fgDark;
    }

    implicitWidth: 380
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.normal

        // ── Header ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: Theme.spacing.normal

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: Theme.rounding.normal
                color: Theme.c.blue

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 24
                    fill: 1
                    text: "monitor_heart"
                    color: Theme.c.bgDark
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "System"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.small
                    color: Theme.c.comment
                    text: [SysStats.cpuName, root.uptime > 0 ? `up ${SysStats.duration(root.uptime)}` : ""].filter(s => s).join(" · ")
                }
            }
        }

        // ── Processors ────────────────────────────────────────────
        Card {
            UsageRow {
                icon: "memory"
                label: "CPU"
                value: root.pct(SysStats.cpuUsage) + root.temp(SysStats.cpuTemp)
                fraction: SysStats.cpuUsage
                valueColor: root.tempColor(SysStats.cpuTemp, 75, 90)
            }
            UsageRow {
                visible: SysStats.hasGpu
                icon: "developer_board"
                label: "GPU"
                value: root.pct(SysStats.gpuUsage) + root.clock(SysStats.gpuClock) + root.temp(SysStats.gpuTemp)
                fraction: SysStats.gpuUsage
                valueColor: root.tempColor(SysStats.gpuTemp, 75, 85)
            }
        }

        // ── Storage ───────────────────────────────────────────────
        Card {
            UsageRow {
                icon: "memory_alt"
                label: "Memory"
                value: `${SysStats.gb(SysStats.memUsed)} of ${SysStats.gb(SysStats.memTotal)}`
                fraction: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : -1
            }
            UsageRow {
                icon: "hard_drive"
                label: "Disk"
                value: `${SysStats.gb(SysStats.diskUsed)} of ${SysStats.gb(SysStats.diskTotal)}` + root.temp(SysStats.diskTemp)
                fraction: SysStats.diskTotal > 0 ? SysStats.diskUsed / SysStats.diskTotal : -1
                valueColor: root.tempColor(SysStats.diskTemp, 60, 70)
            }
        }

        // ── Game mode ─────────────────────────────────────────────
        Tile {
            icon: "sports_esports"
            label: "Game mode"
            sublabel: "Effects, transparency and popups off"
            checked: Power.gameMode
            onClicked: Power.setGameMode(!Power.gameMode)
        }
    }

    component Card: Rectangle {
        default property alias rows: rows.data

        Layout.fillWidth: true
        implicitHeight: rows.implicitHeight + 28
        radius: Theme.rounding.normal
        color: Theme.c.bgHighlight

        ColumnLayout {
            id: rows

            anchors.fill: parent
            anchors.margins: 14
            spacing: 14
        }
    }
}
