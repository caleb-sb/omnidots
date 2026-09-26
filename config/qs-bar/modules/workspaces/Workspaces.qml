import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

// Bar item: Hyprland workspaces in a pill. Always shows 1..5 (more if a higher
// one is in use). Inactive workspaces are dots, brighter when they have
// windows; the active one is a magenta pill with its
// number, and the focused app's name follows the dots.
Rectangle {
    id: root

    required property ShellScreen screen

    readonly property int minShown: 5
    readonly property int padding: 3
    readonly property int slot: implicitHeight - padding * 2
    // The active slot is wider so the number has room around it.
    readonly property int activeWidth: slot + 14
    readonly property int maxTitle: 220

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: idOf(monitor?.activeWorkspace) ?? 1

    // Focused app's name, only if it's on this monitor's active workspace.
    // Uses the desktop entry name when there is one (kitty -> "kitty",
    // firefox -> "Firefox"), else the app id without its reverse-DNS prefix.
    readonly property string title: {
        let t = Hyprland.activeToplevel;
        // activeToplevel is unset until the first focus change after startup;
        // fall back to the workspace's last focused window.
        if (!t) {
            const last = monitor?.activeWorkspace?.lastIpcObject?.lastwindow;
            t = Hyprland.toplevels.values.find(w => last && `0x${w.address}` === last) ?? null;
        }
        if (!t || wsIdOf(t) !== activeId)
            return "";
        const id = t.wayland?.appId || t.lastIpcObject?.class || "";
        if (!id)
            return "";
        // Depend on the entry list so the name updates once it has loaded.
        void DesktopEntries.applications.values;
        return DesktopEntries.heuristicLookup(id)?.name || id.split(".").pop();
    }

    // id -> true for workspaces with windows.
    readonly property var occupied: {
        const o = {};
        for (const t of Hyprland.toplevels.values) {
            const id = wsIdOf(t);
            if (id > 0)
                o[id] = true;
        }
        return o;
    }
    readonly property int shown: {
        let n = Math.max(minShown, activeId);
        for (const id in occupied)
            n = Math.max(n, +id);
        return Math.min(n, 10);
    }

    // Workspace objects created from events (on switch, or right after
    // startup) are placeholders with id -1 until refreshed; their name is
    // already right, and numbered workspaces are named after their number.
    function idOf(ws: HyprlandWorkspace): int {
        if (!ws)
            return -1;
        return ws.id > 0 ? ws.id : parseInt(ws.name) || -1;
    }
    function wsIdOf(t: HyprlandToplevel): int {
        const id = idOf(t.workspace);
        return id > 0 ? id : t.lastIpcObject?.workspace?.id ?? -1;
    }

    // Fill in placeholder workspaces with their real data.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (["workspacev2", "createworkspacev2", "movewindowv2"].includes(event.name))
                Hyprland.refreshWorkspaces();
        }
    }

    Component.onCompleted: {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    implicitWidth: row.width + labelBox.width + padding * 2
    implicitHeight: Theme.bar.height - Theme.bar.padding * 2
    radius: height / 2
    color: Theme.c.bgHighlight

    // Active workspace: a magenta pill with the number that slides between
    // slots, stretching on the way (leading edge fast, trailing edge slower).
    Rectangle {
        id: indicator

        readonly property real target: root.padding + (root.activeId - 1) * root.slot
        property real lead: target
        property real trail: target

        x: Math.min(lead, trail)
        y: root.padding
        width: Math.abs(lead - trail) + root.activeWidth
        height: root.slot
        radius: height / 2
        color: Qt.alpha(Theme.c.magenta, 0.2)
        visible: root.activeId > 0 && root.activeId <= root.shown

        Behavior on lead {
            Anim {
                duration: Theme.anim.fastDuration
                easing.bezierCurve: Theme.anim.standard
            }
        }
        Behavior on trail {
            Anim {
                easing.bezierCurve: Theme.anim.standard
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: root.activeId
            font.pixelSize: Theme.font.bar
            font.weight: Font.Bold
            font.features: ({ tnum: 1 })
            color: Theme.c.magenta
        }
    }

    Row {
        id: row

        x: root.padding
        y: root.padding

        Repeater {
            model: root.shown

            Item {
                id: ws

                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeId
                readonly property bool hasWindows: !!root.occupied[wsId]

                width: isActive ? root.activeWidth : root.slot
                height: root.slot

                Behavior on width {
                    Anim {
                        easing.bezierCurve: Theme.anim.standard
                    }
                }

                StateLayer {
                    radius: height / 2
                    disabled: ws.isActive
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws.wsId} })`)
                }

                // Inactive: a dot (hidden under the indicator when active).
                Rectangle {
                    anchors.centerIn: parent
                    width: ws.hasWindows ? 8 : 6
                    height: width
                    radius: width / 2
                    color: ws.hasWindows ? Theme.c.fgDark : Theme.c.comment
                    opacity: ws.isActive ? 0 : 1
                    scale: ws.isActive ? 0.4 : 1

                    Behavior on opacity {
                        Anim {
                            duration: Theme.anim.effectsDuration
                            easing.bezierCurve: Theme.anim.effects
                        }
                    }
                    Behavior on scale {
                        Anim {}
                    }
                }
            }
        }
    }

    // Focused app name after the dots, behind a separator; collapses when
    // there is none.
    Item {
        id: labelBox

        anchors.left: row.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.title ? label.x + label.width + 10 : 0
        height: parent.height
        clip: true

        Behavior on width {
            Anim {}
        }

        // Separator between the dots and the name: a thin divider, then the
        // Fedora logo. The logo gap (23) matches the visible gap between the
        // last dot and the divider (half an empty slot plus 12).
        Rectangle {
            id: divider

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: Math.round(parent.height * 0.45)
            radius: 1
            color: Theme.c.dark3
            opacity: root.title ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.effectsDuration
                    easing.bezierCurve: Theme.anim.effects
                }
            }
        }

        StyledText {
            id: sep

            x: divider.x + divider.width + 23
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf30a"
            font.pixelSize: Theme.font.bar
            color: Theme.c.blue
            opacity: root.title ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.effectsDuration
                    easing.bezierCurve: Theme.anim.effects
                }
            }
        }

        StyledText {
            id: label

            x: sep.x + sep.implicitWidth + 8
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTitle)
            text: root.title
            elide: Text.ElideRight
            font.pixelSize: Theme.font.bar
            font.weight: Font.Bold
            color: Theme.c.fg
            opacity: root.title ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.effectsDuration
                    easing.bezierCurve: Theme.anim.effects
                }
            }
        }
    }
}
