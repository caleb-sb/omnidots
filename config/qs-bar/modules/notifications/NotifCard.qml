pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.components

// One notification, used by the popups (with a countdown) and the panel.
Rectangle {
    id: root

    required property var modelData
    readonly property var notif: modelData
    // Popup mode: countdown bar, hover pauses it, timeout hides the popup.
    property bool popup
    // Inside an app group in the panel: no background, no app line, and the
    // badge only when there's a picture.
    property bool grouped

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property bool live: !!notif.notification
    readonly property var actions: live ? notif.actions : []
    readonly property var defaultAction: actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: actions.filter(a => a.identifier !== "default" && a.text)

    // `image://icon/…` is just an icon name (notify-send -i); anything else is a picture.
    readonly property bool imageIsIcon: notif.image.startsWith("image://icon/")
    readonly property string photo: notif.image && !imageIsIcon ? notif.image : ""
    readonly property string icon: Notifs.iconFor(notif)

    implicitHeight: content.implicitHeight + (grouped ? 16 : 24)
    radius: Theme.rounding.large
    color: popup ? Theme.c.bg : grouped ? "transparent" : Qt.alpha(Theme.c.bgHighlight, 0.55)
    border.width: popup || critical ? 1 : 0
    border.color: critical ? Qt.alpha(Theme.c.red, 0.6) : Theme.c.bgHighlight

    HoverHandler {
        id: hover
    }

    // Countdown (popups only). Paused while hovered.
    property real progress: 1
    NumberAnimation on progress {
        id: countdown

        running: root.popup && root.notif.timeout > 0
        paused: running && hover.hovered
        from: 1
        to: 0
        duration: root.notif.timeout
        onFinished: root.notif.expire()
    }

    StateLayer {
        radius: root.radius
        disabled: !root.defaultAction && !root.popup
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.defaultAction)
                root.notif.invoke(root.defaultAction);
            else if (root.popup)
                root.notif.expire();
        }
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.topMargin: root.grouped ? 4 : 12
        spacing: Theme.spacing.normal

        // ── Badge: picture, app icon, or glyph ───────────────────
        Item {
            Layout.alignment: Qt.AlignTop
            visible: !root.grouped || !!root.photo
            implicitWidth: 40
            implicitHeight: 40

            ClippingRectangle {
                anchors.fill: parent
                radius: root.photo ? Theme.rounding.normal : 20
                color: root.critical ? Qt.alpha(Theme.c.red, 0.15) : Theme.c.bgHighlight

                Image {
                    anchors.fill: parent
                    visible: !!root.photo
                    source: root.photo
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(80, 80)
                }

                IconImage {
                    anchors.centerIn: parent
                    visible: !root.photo && !!root.icon && status === Image.Ready
                    implicitSize: 24
                    source: root.photo ? "" : root.icon
                    asynchronous: true
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !root.photo && (!root.icon)
                    size: 22
                    fill: 1
                    text: root.critical ? "priority_high" : "notifications"
                    color: root.critical ? Theme.c.red : Theme.c.fgDark
                }
            }

            // App icon in the corner when the badge shows a picture.
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -3
                width: 20
                height: 20
                radius: 10
                color: root.popup ? Theme.c.bg : Theme.c.bgHighlight
                visible: !!root.photo && !!root.icon

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 14
                    source: root.photo ? root.icon : ""
                    asynchronous: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.small

                // App · time normally; in a group the title takes this line.
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: root.grouped ? Theme.font.normal : Theme.font.small
                    font.weight: root.grouped ? Font.DemiBold : Font.Normal
                    color: root.grouped ? Theme.c.fg : root.critical ? Theme.c.red : Theme.c.comment
                    text: root.grouped ? root.notif.summary : `${root.notif.appName || "Notification"} · ${Notifs.ago(root.notif.time)}`
                }

                StyledText {
                    visible: root.grouped
                    font.pixelSize: Theme.font.small
                    color: root.critical ? Theme.c.red : Theme.c.comment
                    text: Notifs.ago(root.notif.time)
                }

                IconButton {
                    size: 22
                    icon: "close"
                    iconColor: Theme.c.dark5
                    opacity: hover.hovered ? 1 : 0.0
                    disabled: !hover.hovered
                    onClicked: root.notif.close()

                    Behavior on opacity {
                        Anim {
                            duration: Theme.anim.effectsDuration
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !root.grouped && text.length > 0
                text: root.notif.summary
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.notif.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 3 : 5
                elide: Text.ElideRight
                color: Theme.c.fgDark
                linkColor: Theme.c.blue
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.small
                visible: root.buttons.length > 0
                spacing: Theme.spacing.small

                Repeater {
                    model: root.buttons

                    Rectangle {
                        id: btn

                        required property var modelData
                        required property int index

                        implicitWidth: label.implicitWidth + 28
                        implicitHeight: 30
                        radius: Theme.rounding.full
                        color: index === 0 ? Theme.c.blue : Theme.c.bgHighlight

                        StateLayer {
                            color: btn.index === 0 ? Theme.c.bgDark : Theme.c.fg
                            onClicked: root.notif.invoke(btn.modelData)
                        }

                        StyledText {
                            id: label

                            anchors.centerIn: parent
                            text: btn.modelData.text
                            font.pixelSize: Theme.font.small
                            font.weight: Font.DemiBold
                            color: btn.index === 0 ? Theme.c.bgDark : Theme.c.fg
                        }
                    }
                }
            }
        }
    }

    // Countdown line.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 1
        anchors.leftMargin: root.radius
        visible: countdown.running
        width: (parent.width - root.radius * 2) * root.progress
        height: 2
        radius: 1
        color: Qt.alpha(root.critical ? Theme.c.red : Theme.c.blue, 0.6)
    }
}
