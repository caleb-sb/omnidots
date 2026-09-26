import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// One history entry: kind badge (or image preview), text, delete on hover.
Rectangle {
    id: row

    required property var modelData
    required property int index
    property bool current      // on the clipboard right now
    property bool highlighted  // keyboard selection
    signal activated
    signal deleted

    readonly property bool image: modelData.kind === "image"
    readonly property bool hovered: hover.hovered

    implicitHeight: image ? 88 : Math.max(52, textCol.implicitHeight + 18)
    radius: Theme.rounding.normal
    color: current ? Qt.alpha(Theme.c.blue, 0.1) : highlighted ? Theme.c.bgHighlight : "transparent"

    Behavior on color {
        CAnim {}
    }

    HoverHandler {
        id: hover
    }

    StateLayer {
        onClicked: row.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: Theme.spacing.normal

        // ── Badge / preview ──────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: row.image ? 96 : 32
            Layout.preferredHeight: row.image ? 72 : 32
            radius: row.image ? Theme.rounding.small : 16
            color: row.current && !row.image ? Theme.c.blue : Theme.c.bgHighlight
            clip: true

            Behavior on color {
                CAnim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !row.image || thumb.status !== Image.Ready
                size: 18
                fill: row.current ? 1 : 0
                text: ({ image: "image", link: "link", color: "palette", text: "notes" })[row.modelData.kind]
                color: row.current && !row.image ? Theme.c.bgDark : Theme.c.dark5
            }

            // Hex colour: show it.
            Rectangle {
                anchors.centerIn: parent
                visible: row.modelData.kind === "color"
                width: 18
                height: 18
                radius: 9
                color: visible ? row.modelData.preview.trim() : "transparent"
                border.width: 2
                border.color: row.current ? Theme.c.bgDark : Theme.c.bg
            }

            Image {
                id: thumb

                anchors.fill: parent
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                sourceSize.height: 144
                asynchronous: true
                cache: false
            }
        }

        // ── Text ─────────────────────────────────────────────────
        ColumnLayout {
            id: textCol

            Layout.fillWidth: true
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                visible: !row.image
                text: row.modelData.preview.trim()
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                textFormat: Text.PlainText
                color: row.modelData.kind === "link" ? Theme.c.cyan : Theme.c.fg
            }
            StyledText {
                Layout.fillWidth: true
                visible: row.image
                text: row.image ? `${row.modelData.ext.toUpperCase()} image` : ""
                color: Theme.c.fg
            }
            StyledText {
                Layout.fillWidth: true
                visible: row.image || row.current
                elide: Text.ElideRight
                font.pixelSize: Theme.font.small
                color: row.current ? Theme.c.blue : Theme.c.comment
                text: {
                    const e = row.modelData;
                    if (e.kind === "image")
                        return row.current ? `On clipboard · ${e.w}×${e.h} · ${e.size}` : `${e.w}×${e.h} · ${e.size}`;
                    return "On clipboard";
                }
            }
        }

        IconButton {
            size: 30
            icon: "delete"
            iconColor: Theme.c.dark5
            opacity: row.hovered ? 1 : 0
            disabled: !row.hovered
            onClicked: row.deleted()

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.fastDuration
                    easing.bezierCurve: Theme.anim.effects
                }
            }
        }
    }

    // Decode image entries to the cache once, then show them.
    Process {
        running: row.image
        command: {
            const f = Clip.thumbPath(row.modelData);
            return ["sh", "-c", `mkdir -p '${Clip.thumbDir}' && { [ -s '${f}' ] || cliphist decode ${row.modelData.id} > '${f}'; }`];
        }
        onExited: code => {
            if (code === 0)
                thumb.source = "file://" + Clip.thumbPath(row.modelData);
        }
    }
}
