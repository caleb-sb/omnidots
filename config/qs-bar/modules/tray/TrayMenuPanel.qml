pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components

// A tray app's menu (e.g. Steam → Exit). Submenus open in place with a Back
// row; the stack resets whenever a different app's menu is shown.
Item {
    id: root

    property QsMenuHandle handle
    property string title
    signal closeRequested

    property var stack: []
    readonly property QsMenuHandle current: stack.length > 0 ? stack[stack.length - 1] : null

    function reset(): void {
        stack = handle ? [handle] : [];
    }

    // Menu labels use GTK-style mnemonics ("_Exit"; "__" is a literal "_").
    function label(text: string): string {
        return text.replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    onHandleChanged: {
        if (!handle)
            closeRequested();
        reset();
    }
    Component.onCompleted: reset()

    implicitWidth: 260
    implicitHeight: column.implicitHeight

    QsMenuOpener {
        id: opener

        menu: root.current
    }

    ColumnLayout {
        id: column

        width: parent.width
        spacing: 2

        // App name, or Back inside a submenu.
        Item {
            Layout.fillWidth: true
            implicitHeight: 32

            Rectangle {
                anchors.fill: parent
                radius: Theme.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    disabled: root.stack.length < 2
                    onClicked: root.stack = root.stack.slice(0, -1)
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: Theme.spacing.small

                MaterialIcon {
                    visible: root.stack.length > 1
                    size: 18
                    text: "chevron_left"
                    color: Theme.c.blue
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.stack.length > 1 ? "Back" : root.title
                    elide: Text.ElideRight
                    font.pixelSize: Theme.font.small
                    font.weight: Font.DemiBold
                    color: root.stack.length > 1 ? Theme.c.blue : Theme.c.comment
                }
            }
        }

        Repeater {
            model: opener.children

            Item {
                id: entry

                required property QsMenuEntry modelData
                readonly property bool separator: modelData.isSeparator

                Layout.fillWidth: true
                implicitHeight: separator ? 9 : 36

                Rectangle {
                    visible: entry.separator
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: 1
                    color: Theme.c.fgGutter
                }

                Rectangle {
                    visible: !entry.separator
                    anchors.fill: parent
                    radius: Theme.rounding.small
                    color: "transparent"

                    StateLayer {
                        radius: parent.radius
                        disabled: !entry.modelData.enabled
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                root.stack = [...root.stack, entry.modelData];
                            } else {
                                entry.modelData.triggered();
                                root.closeRequested();
                            }
                        }
                    }
                }

                RowLayout {
                    visible: !entry.separator
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: Theme.spacing.normal

                    MaterialIcon {
                        readonly property bool checked: entry.modelData.checkState === Qt.Checked

                        visible: entry.modelData.buttonType !== QsMenuButtonType.None
                        size: 18
                        fill: checked ? 1 : 0
                        text: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? (checked ? "radio_button_checked" : "radio_button_unchecked") : (checked ? "check_box" : "check_box_outline_blank")
                        color: checked ? Theme.c.blue : Theme.c.comment
                    }

                    IconImage {
                        visible: entry.modelData.icon !== ""
                        implicitSize: 18
                        source: entry.modelData.icon
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.label(entry.modelData.text)
                        elide: Text.ElideRight
                        color: entry.modelData.enabled ? Theme.c.fg : Theme.c.comment
                    }

                    MaterialIcon {
                        visible: entry.modelData.hasChildren
                        size: 18
                        text: "chevron_right"
                        color: Theme.c.comment
                    }
                }
            }
        }
    }
}
