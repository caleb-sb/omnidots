pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

// Clipboard history: search, click (or Enter) to copy, delete on hover,
// clear everything from the footer.
Item {
    id: root

    signal closeRequested

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var results: query ? Clip.entries.filter(e => e.search.includes(query)) : Clip.entries
    property int selected: 0
    // Show the selection only once the keyboard is in use.
    property bool navigated

    onQueryChanged: selected = 0

    function move(by: int): void {
        navigated = true;
        selected = Math.max(0, Math.min(results.length - 1, selected + by));
    }
    function pickSelected(): void {
        if (results[selected])
            pick(results[selected]);
    }

    function pick(entry: var): void {
        Clip.copy(entry);
        closeRequested();
    }

    implicitWidth: 380
    implicitHeight: column.implicitHeight

    Component.onCompleted: Clip.reload()

    // Created inside the popout's Loader, so focus only sticks once the panel
    // is in an active window.
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: {
        if (windowActive)
            search.forceActiveFocus();
    }
    Timer {
        running: true
        interval: 50
        onTriggered: search.forceActiveFocus()
    }

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.normal

        // ── Header ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.normal

            Rectangle {
                readonly property bool on: Clip.count > 0

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
                    text: "assignment"
                    color: parent.on ? Theme.c.bgDark : Theme.c.dark5
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Clipboard"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.small
                    color: Theme.c.comment
                    text: {
                        if (Clip.count === 0)
                            return "History is empty";
                        if (root.query)
                            return `${root.results.length} of ${Clip.count} items`;
                        return `${Clip.count} item${Clip.count === 1 ? "" : "s"}`;
                    }
                }
            }
        }

        // ── Search ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.rounding.full
            color: Theme.c.bgHighlight
            border.width: search.activeFocus ? 1 : 0
            border.color: Qt.alpha(Theme.c.blue, 0.5)

            MaterialIcon {
                id: searchIcon

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                text: "search"
                color: Theme.c.dark5
            }

            TextInput {
                id: search

                anchors.left: searchIcon.right
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 38
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Theme.c.fg
                selectionColor: Theme.c.blue7
                selectedTextColor: Theme.c.fg
                font.family: Theme.font.sans
                font.pixelSize: Theme.font.normal

                Keys.onEscapePressed: text ? text = "" : root.closeRequested()
                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onReturnPressed: root.pickSelected()
                Keys.onEnterPressed: root.pickSelected()
                Keys.onDeletePressed: event => {
                    // Shift+Delete removes the selected entry.
                    if (event.modifiers & Qt.ShiftModifier && root.results[root.selected])
                        Clip.remove(root.results[root.selected]);
                    else
                        event.accepted = false;
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text.length === 0
                    text: "Search history"
                    color: Theme.c.comment
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text.length > 0
                size: 30
                icon: "close"
                iconColor: Theme.c.dark5
                onClicked: search.text = ""
            }
        }

        // ── History ───────────────────────────────────────────────
        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 420)
            visible: root.results.length > 0
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.selected
            highlightFollowsCurrentItem: false

            // Keep the keyboard selection in view.
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            model: ScriptModel {
                values: root.results
            }
            delegate: ClipRow {
                width: ListView.view?.width ?? 0
                current: modelData.id === Clip.entries[0]?.id
                highlighted: index === root.selected && (root.navigated || !!root.query)
                onActivated: root.pick(modelData)
                onDeleted: Clip.remove(modelData)
            }

            populate: ListEnter {}
            add: ListEnter {}
            remove: ListExit {}
            displaced: ListShift {}
        }

        Placeholder {
            visible: root.results.length === 0
            icon: root.query ? "search_off" : "content_paste_off"
            text: root.query ? "No matches" : "Nothing copied yet"
        }

        // ── Footer ────────────────────────────────────────────────
        // Two-step: the first click arms it, the second wipes.
        Rectangle {
            id: wipe

            property bool armed

            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            implicitHeight: 40
            radius: Theme.rounding.full
            color: armed ? Qt.alpha(Theme.c.red, 0.18) : Theme.c.bgHighlight
            opacity: Clip.count > 0 ? 1 : 0.5

            Behavior on color {
                CAnim {}
            }

            Timer {
                running: wipe.armed
                interval: 3000
                onTriggered: wipe.armed = false
            }

            StateLayer {
                color: wipe.armed ? Theme.c.red : Theme.c.fg
                disabled: Clip.count === 0
                onClicked: {
                    if (wipe.armed) {
                        wipe.armed = false;
                        Clip.wipe();
                    } else {
                        wipe.armed = true;
                    }
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacing.small

                MaterialIcon {
                    size: 18
                    text: "delete_sweep"
                    color: wipe.armed ? Theme.c.red : Theme.c.fgDark
                }
                StyledText {
                    text: wipe.armed ? "Click again to clear history" : "Clear history"
                    color: wipe.armed ? Theme.c.red : Theme.c.fgDark
                }
            }
        }
    }
}
