pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// The login form: user, the PAM prompt (the password), messages, and the
// session to start. Styled like hyprlock's input field: dark inside, blue
// outline, red after a failure.
Rectangle {
    id: root

    required property Auth auth

    implicitWidth: 380
    implicitHeight: column.implicitHeight + 2 * Theme.spacing.large * 1.5
    radius: Theme.popout.radius
    color: Theme.c.bgDark
    border.width: 2
    border.color: failed ? Theme.c.red : Theme.c.blue

    property bool failed: false

    Behavior on border.color {
        CAnim {}
    }

    function focusField(): void {
        if (!userField.text)
            userField.forceActiveFocus();
        else
            answerField.forceActiveFocus();
    }

    // Focus sticks only once the window is active.
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: {
        if (windowActive && visible)
            focusField();
    }

    // The password field once the user is set, whatever PAM asks next.
    Connections {
        target: root.auth

        function onPromptChanged(): void {
            if (root.auth.prompt)
                answerField.forceActiveFocus();
        }
        function onFailuresChanged(): void {
            root.failed = true;
            shake.restart();
        }
        function onUserChanged(): void {
            userField.text = root.auth.user;
        }
    }

    SequentialAnimation {
        id: shake

        readonly property int step: 40

        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: 12; duration: shake.step }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: -12; duration: shake.step }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: 8; duration: shake.step }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: -8; duration: shake.step }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: 0; duration: shake.step }
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Theme.spacing.large * 1.5
        spacing: Theme.spacing.normal

        // ── User ──────────────────────────────────────────────────
        Field {
            icon: "person"

            TextInput {
                id: userField

                Layout.fillWidth: true
                // The remembered user; later changes come through
                // onUserChanged above.
                text: root.auth.user
                color: Theme.c.fg
                selectionColor: Theme.c.blue7
                font.family: Theme.font.sans
                font.pixelSize: Theme.font.large
                clip: true
                KeyNavigation.tab: answerField

                // Typing a different user drops the login in progress; Enter
                // starts the new one.
                onTextEdited: root.auth.editUser()

                function submit(): void {
                    if (root.auth.active)
                        answerField.forceActiveFocus();
                    else
                        root.auth.start(text, "");
                }

                Keys.onReturnPressed: submit()
                Keys.onEnterPressed: submit()

                StyledText {
                    anchors.fill: parent
                    visible: !parent.text
                    text: "User"
                    color: Theme.c.comment
                    font.pixelSize: Theme.font.large
                }
            }
        }

        // ── Prompt (the password) ────────────────────────────────
        Field {
            icon: root.auth.echo ? "edit" : "lock"
            opacity: root.auth.busy ? 0.6 : 1

            TextInput {
                id: answerField

                Layout.fillWidth: true
                color: Theme.c.fg
                selectionColor: Theme.c.blue7
                font.family: Theme.font.sans
                font.pixelSize: Theme.font.large
                echoMode: root.auth.echo ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                clip: true
                readOnly: root.auth.busy
                KeyNavigation.tab: userField

                onTextChanged: root.failed = false

                function submit(): void {
                    if (root.auth.prompt)
                        root.auth.answer(text);
                    else if (!root.auth.active)
                        // After a failure: log in again, with this answer.
                        root.auth.start(userField.text, text);
                    else
                        return;
                    text = "";
                }

                Keys.onReturnPressed: submit()
                Keys.onEnterPressed: submit()
                Keys.onEscapePressed: {
                    text = "";
                    userField.forceActiveFocus();
                    userField.selectAll();
                }

                StyledText {
                    anchors.fill: parent
                    visible: !parent.text
                    // PAM's own prompt, e.g. "Password:", without the colon.
                    text: (root.auth.prompt || "Password").replace(/:\s*$/, "")
                    color: Theme.c.comment
                    font.pixelSize: Theme.font.large
                    elide: Text.ElideRight
                }
            }

            Spinner {
                size: 20
                color: Theme.c.blue
                running: root.auth.busy
            }
        }

        // ── Messages ──────────────────────────────────────────────
        StyledText {
            Layout.fillWidth: true
            visible: text
            text: root.auth.message
            color: root.auth.messageIsError ? Theme.c.red : Theme.c.fgDark
            font.pixelSize: Theme.font.small
            wrapMode: Text.Wrap
        }

        // ── Session ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            spacing: Theme.spacing.small

            IconButton {
                icon: "chevron_left"
                iconColor: Theme.c.dark5
                disabled: root.auth.sessions.length < 2
                onClicked: root.auth.cycleSession(-1)
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.auth.session?.name ?? ""
                color: Theme.c.fgDark
                elide: Text.ElideRight
            }

            IconButton {
                icon: "chevron_right"
                iconColor: Theme.c.dark5
                disabled: root.auth.sessions.length < 2
                onClicked: root.auth.cycleSession(1)
            }
        }
    }

    // A rounded row with an icon and its input.
    component Field: Rectangle {
        id: field

        property alias icon: glyph.text
        default property alias content: row.data

        Layout.fillWidth: true
        implicitHeight: 48
        radius: Theme.rounding.full
        color: Theme.c.bgHighlight

        Behavior on opacity {
            Anim {
                duration: Theme.anim.effectsDuration
            }
        }

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            MaterialIcon {
                id: glyph

                size: 20
                color: Theme.c.dark5
            }
        }
    }
}
