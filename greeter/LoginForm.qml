pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The login form: the password field, styled like hyprlock's input field
// (config/hypr/hyprlock.conf): dark inside, square-ish, blue outline, red
// after a failure. Messages go under it, and the user field above it when
// there's no owner to log in as (see Auth.owner). Its size is the password
// field's, so it can be placed by that field alone.
Item {
    id: root

    required property Auth auth
    // Logical px per hyprlock px (hyprlock's sizes are in physical pixels).
    property real unit: 1

    implicitWidth: 360
    implicitHeight: 56

    property bool failed: false

    // Field and message text, a size up from qs-bar's.
    readonly property int textSize: 20
    readonly property int messageSize: 15

    function focusField(): void {
        if (userBox.visible && !userField.text)
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

    // ── User, only without an owner ───────────────────────────────
    Field {
        id: userBox

        visible: !root.auth.owner
        anchors.bottom: answerBox.top
        anchors.bottomMargin: Theme.spacing.normal

        TextInput {
            id: userField

            anchors.fill: parent
            // The remembered user; later changes come through onUserChanged
            // above.
            text: root.auth.user
            color: Theme.c.fg
            selectionColor: Theme.c.blue7
            font.family: Theme.font.sans
            font.pixelSize: root.textSize
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
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

            Placeholder {
                visible: !parent.text
                text: "User"
            }
        }
    }

    // ── Prompt (the password) ────────────────────────────────────
    Field {
        id: answerBox

        anchors.fill: parent
        border.color: root.failed ? Theme.c.red : Theme.c.blue
        opacity: root.auth.busy ? 0.6 : 1

        TextInput {
            id: answerField

            anchors.fill: parent
            color: Theme.c.fg
            selectionColor: Theme.c.blue7
            font.family: Theme.font.sans
            font.pixelSize: root.textSize
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            echoMode: root.auth.echo ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            clip: true
            readOnly: root.auth.busy
            KeyNavigation.tab: userBox.visible ? userField : null

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
                if (userBox.visible) {
                    userField.forceActiveFocus();
                    userField.selectAll();
                }
            }

            Placeholder {
                visible: !parent.text
                // PAM's own prompt, e.g. "Password:", without the colon.
                text: (root.auth.prompt || "Password").replace(/:\s*$/, "")
            }
        }

        Spinner {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            size: 20
            color: Theme.c.blue
            running: root.auth.busy
        }
    }

    // ── Messages, where hyprlock shows its fingerprint prompt ────
    StyledText {
        anchors.top: answerBox.bottom
        anchors.topMargin: Theme.spacing.large
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        visible: text
        text: root.auth.message
        color: root.auth.messageIsError ? Theme.c.red : Theme.c.fgDark
        font.pixelSize: root.messageSize
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }

    // hyprlock's input field: rounding 6, outline 2, in its units.
    component Field: Rectangle {
        width: root.width
        height: root.height
        radius: 6 * root.unit
        color: Theme.c.bgDark
        border.width: 2 * root.unit
        border.color: Theme.c.blue

        Behavior on border.color {
            CAnim {}
        }
        Behavior on opacity {
            Anim {
                duration: Theme.anim.effectsDuration
            }
        }
    }

    component Placeholder: StyledText {
        anchors.fill: parent
        color: Theme.c.comment
        font.pixelSize: root.textSize
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
