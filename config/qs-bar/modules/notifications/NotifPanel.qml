pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.components

// Control-center style notification history: do-not-disturb, clear all,
// and every notification, newest first.
Item {
    id: root

    signal closeRequested

    implicitWidth: 380
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.normal

        // ── Header ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            Rectangle {
                readonly property bool on: Notifs.count > 0 && !Notifs.dnd

                implicitWidth: 44
                implicitHeight: 44
                radius: on ? Theme.rounding.normal : 22
                color: on ? Theme.c.blue : Theme.c.bgHighlight

                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim {}
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 24
                    fill: parent.on ? 1 : 0
                    text: Notifs.dnd ? "notifications_off" : "notifications"
                    color: parent.on ? Theme.c.bgDark : Theme.c.dark5
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Notifications"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.small
                    color: Theme.c.comment
                    text: {
                        const n = Notifs.count;
                        const what = n === 0 ? "All caught up" : `${n} notification${n === 1 ? "" : "s"}`;
                        return Notifs.dnd ? `${what} · Do not disturb` : what;
                    }
                }
            }
        }

        // ── Quick toggles ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            Tile {
                icon: "do_not_disturb_on"
                label: "Do not disturb"
                sublabel: Notifs.dnd ? "Popups hidden" : "Off"
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Tile {
                icon: "clear_all"
                label: "Clear all"
                sublabel: Notifs.count > 0 ? `${Notifs.count} to clear` : "Nothing here"
                disabled: Notifs.count === 0
                onClicked: Notifs.clear()
            }
        }

        // ── History ───────────────────────────────────────────────
        // ListViews (not Repeaters) so removals animate out and the cards
        // below slide up into the gap.
        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 460)
            visible: Notifs.count > 0
            spacing: Theme.spacing.small
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Keyed by app name (strings), so a group keeps its delegate
            // and expanded state as notifications come in.
            model: ScriptModel {
                values: root.groupKeys
            }
            delegate: Group {}

            populate: ListEnter {}
            add: ListEnter {}
            remove: ListExit {}
            displaced: ListShift {}
        }

        Placeholder {
            visible: Notifs.count === 0
            icon: "notifications_paused"
            text: "No notifications"
        }
    }

    // Apps in order of their newest notification (Notifs.list is newest first).
    readonly property var groupKeys: [...new Set(Notifs.list.map(n => groupKey(n)))]
    function groupKey(n: var): string {
        return n.appName || "Notifications";
    }

    // One app: header (icon, name, count, time, expand, clear) and its
    // notifications; collapsed shows only the newest.
    component Group: Rectangle {
        id: group

        required property string modelData
        readonly property var notifs: Notifs.list.filter(n => root.groupKey(n) === modelData)
        readonly property var latest: notifs[0] ?? null
        readonly property bool many: notifs.length > 1
        property bool expanded

        width: ListView.view?.width ?? 0
        implicitHeight: body.implicitHeight + 8
        height: implicitHeight
        radius: Theme.rounding.large
        color: Qt.alpha(Theme.c.bgHighlight, 0.55)
        border.width: notifs.some(n => n.urgency === NotificationUrgency.Critical) ? 1 : 0
        border.color: Qt.alpha(Theme.c.red, 0.6)

        // Grows/shrinks smoothly as cards inside come and go, so the groups
        // below glide instead of jumping.
        Behavior on height {
            Anim {}
        }

        HoverHandler {
            id: groupHover
        }

        // How far a text item's actual glyphs sit above its box centre, in
        // whole pixels (text is drawn pixel-snapped).
        function glyphLift(t: Item, m: FontMetrics): real {
            const ink = m.tightBoundingRect(t.text);
            const inkCentre = t.baselineOffset + ink.y + ink.height / 2;
            return Math.round(t.height / 2 - inkCentre);
        }
        FontMetrics {
            id: nameMetrics

            font: appName.font
        }

        ColumnLayout {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            spacing: 0

            // ── Header ───────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 44

                StateLayer {
                    radius: Theme.rounding.large
                    disabled: !group.many
                    onClicked: group.expanded = !group.expanded
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: Theme.spacing.small

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: Theme.c.bgHighlight

                        readonly property string src: group.latest ? Notifs.iconFor(group.latest) : ""

                        IconImage {
                            anchors.centerIn: parent
                            visible: !!parent.src && status === Image.Ready
                            implicitSize: 18
                            source: parent.src
                            asynchronous: true
                        }
                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !parent.src
                            size: 16
                            fill: 1
                            text: "notifications"
                            color: Theme.c.fgDark
                        }
                    }

                    StyledText {
                        id: appName

                        Layout.maximumWidth: 170
                        elide: Text.ElideRight
                        text: group.modelData
                        font.weight: Font.DemiBold
                        color: Theme.c.fgDark
                    }

                    // Clears this app's notifications. Fades in on hover.
                    // Centred on the app name's letters (a text box centres
                    // its line box, which leaves the glyphs sitting high).
                    Rectangle {
                        Layout.bottomMargin: Math.max(0, 2 * group.glyphLift(appName, nameMetrics))
                        implicitWidth: clearLabel.implicitWidth + 12
                        implicitHeight: 18
                        radius: Theme.rounding.full
                        color: Qt.alpha(Theme.c.fg, 0.1)
                        opacity: groupHover.hovered ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                duration: Theme.anim.fastDuration
                                easing.bezierCurve: Theme.anim.effects
                            }
                        }

                        StateLayer {
                            disabled: !groupHover.hovered
                            onClicked: {
                                for (const n of group.notifs.slice())
                                    n.close();
                            }
                        }

                        StyledText {
                            id: clearLabel

                            // Rounded, not centerIn: a half-pixel offset snaps
                            // upward and leaves the letters high in the pill.
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round((parent.height - height) / 2)
                            text: "Clear all"
                            font.pixelSize: Theme.font.small - 3
                            font.weight: Font.DemiBold
                            color: Theme.c.fgDark
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Count pill.
                    Rectangle {
                        visible: group.many
                        implicitWidth: countLabel.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: Qt.alpha(Theme.c.blue, 0.18)

                        StyledText {
                            id: countLabel

                            anchors.centerIn: parent
                            text: group.notifs.length
                            font.pixelSize: Theme.font.small - 1
                            font.weight: Font.DemiBold
                            color: Theme.c.blue
                        }
                    }

                    MaterialIcon {
                        visible: group.many
                        size: 18
                        text: "expand_more"
                        color: Theme.c.dark5
                        rotation: group.expanded ? 180 : 0

                        Behavior on rotation {
                            Anim {
                                duration: Theme.anim.fastDuration
                            }
                        }
                    }
                }
            }

            // ── Notifications ────────────────────────────────────
            ListView {
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false

                model: ScriptModel {
                    values: group.expanded ? group.notifs : group.notifs.slice(0, 1)
                }
                delegate: NotifCard {
                    width: ListView.view?.width ?? 0
                    grouped: true
                }

                add: ListEnter {}
                remove: ListExit {}
                displaced: ListShift {}
            }

            // Collapsed: hint at what's hidden.
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.bottomMargin: 8
                visible: group.many && !group.expanded
                text: `+${group.notifs.length - 1} more`
                font.pixelSize: Theme.font.small
                color: Theme.c.blue

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: group.expanded = true
                }
            }
        }
    }
}
