import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.config
import qs.components

// One Wi-Fi network. Click = primary action (connect / disconnect); new
// secured networks open an inline password field first.
Rectangle {
    id: root

    required property WifiNetwork modelData
    readonly property WifiNetwork network: modelData
    readonly property bool busy: network.stateChanging || network.state === ConnectionState.Connecting || network.state === ConnectionState.Disconnecting
    readonly property bool needsPassword: !network.known && !Net.isOpen(network)
    readonly property bool enterprise: Net.isEnterprise(network)

    // Kept in Net by SSID so it survives the row being re-created.
    readonly property bool askPassword: Net.passwordFor === network.name
    function setAskPassword(on: bool): void {
        Net.passwordFor = on ? network.name : "";
    }

    property string error

    function primaryAction(): void {
        if (busy)
            return;
        error = "";
        if (network.connected) {
            network.disconnect();
        } else if (enterprise && !network.known) {
            Net.openSettings();
        } else if (needsPassword) {
            setAskPassword(!askPassword);
        } else {
            network.connect();
        }
    }

    function submit(): void {
        if (field.text.length === 0)
            return;
        error = "";
        setAskPassword(false);
        network.connectWithPsk(field.text);
    }

    function statusText(): string {
        if (error)
            return error;
        switch (network.state) {
        case ConnectionState.Connecting:
            return "Connecting…";
        case ConnectionState.Disconnecting:
            return "Disconnecting…";
        }
        if (network.connected)
            return Net.limited ? "Connected · no internet" : "Connected";
        if (enterprise && !network.known)
            return "Enterprise · set up in settings";
        return network.known ? "Saved" : Net.securityText(network);
    }

    Connections {
        target: root.network

        function onConnectionFailed(reason: int): void {
            if (reason === ConnectionFailReason.NoSecrets) {
                root.error = root.network.known ? "Couldn't connect" : "Wrong password";
                root.setAskPassword(!Net.isOpen(root.network) && !root.enterprise);
            } else {
                root.error = "Couldn't connect";
            }
        }
        function onConnectedChanged(): void {
            if (root.network.connected)
                root.error = "";
        }
    }

    onAskPasswordChanged: {
        if (askPassword) {
            field.text = "";
            field.forceActiveFocus();
        }
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight
    radius: Theme.rounding.normal
    color: network.connected ? Qt.alpha(Theme.c.blue, 0.1) : askPassword ? Theme.c.bgHighlight : "transparent"

    // Entry animation, like caelestia's list items.
    opacity: 0
    scale: 0.85
    Component.onCompleted: {
        opacity = 1;
        scale = 1;
        if (askPassword)
            field.forceActiveFocus();
    }
    Behavior on opacity {
        Anim {
            duration: Theme.anim.effectsDuration
            easing.bezierCurve: Theme.anim.effects
        }
    }
    Behavior on scale {
        Anim {}
    }
    Behavior on color {
        CAnim {}
    }

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: content

        width: parent.width
        spacing: 0

        Item {
            Layout.fillWidth: true
            implicitHeight: 56

            StateLayer {
                radius: root.radius
                disabled: root.busy
                onClicked: root.primaryAction()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: Theme.spacing.normal

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: root.network.connected ? Theme.rounding.normal : 18
                    color: root.network.connected ? Theme.c.blue : Theme.c.bgHighlight

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on radius {
                        Anim {}
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 20
                        text: Net.signalIcon(root.network.signalStrength)
                        fill: 1
                        color: root.network.connected ? Theme.c.bgDark : Theme.c.fgDark
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.network.name
                        elide: Text.ElideRight
                        font.weight: root.network.connected ? Font.DemiBold : Font.Normal
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        MaterialIcon {
                            visible: !Net.isOpen(root.network)
                            size: 12
                            text: "lock"
                            color: status.color
                        }
                        StyledText {
                            id: status

                            Layout.fillWidth: true
                            text: root.statusText()
                            elide: Text.ElideRight
                            font.pixelSize: Theme.font.small
                            color: root.error ? Theme.c.red : root.network.connected ? (Net.limited ? Theme.c.yellow : Theme.c.blue) : Theme.c.comment
                        }
                    }
                }

                Spinner {
                    size: 18
                    running: root.busy
                    color: Theme.c.blue
                }

                IconButton {
                    visible: root.network.known && !root.busy
                    opacity: hover.hovered ? 1 : 0
                    disabled: !hover.hovered
                    size: 30
                    icon: "delete"
                    iconColor: Theme.c.red

                    Behavior on opacity {
                        Anim {
                            duration: Theme.anim.effectsDuration
                        }
                    }

                    onClicked: root.network.forget()
                }

                IconButton {
                    visible: !root.busy
                    size: 30
                    icon: root.network.connected ? "link_off" : root.enterprise && !root.network.known ? "open_in_new" : root.needsPassword ? (root.askPassword ? "close" : "key") : "link"
                    iconColor: root.network.connected ? Theme.c.blue : Theme.c.fgDark
                    onClicked: root.primaryAction()
                }
            }
        }

        // Password entry for new secured networks.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 8
            Layout.bottomMargin: 10
            spacing: Theme.spacing.small
            visible: root.askPassword

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.rounding.full
                color: Theme.c.bgDark
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? Theme.c.blue : Theme.c.fgGutter

                Behavior on border.color {
                    CAnim {}
                }

                TextInput {
                    id: field

                    property bool reveal

                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 38
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.c.fg
                    selectionColor: Theme.c.blue7
                    selectedTextColor: Theme.c.fg
                    font.family: Theme.font.sans
                    font.pixelSize: Theme.font.normal
                    echoMode: reveal ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"

                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: root.setAskPassword(false)

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text.length === 0
                        text: "Password"
                        color: Theme.c.comment
                    }
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    icon: field.reveal ? "visibility_off" : "visibility"
                    iconColor: Theme.c.dark5
                    onClicked: field.reveal = !field.reveal
                }
            }

            Rectangle {
                implicitWidth: 38
                implicitHeight: 38
                radius: Theme.rounding.full
                color: field.text.length > 0 ? Theme.c.blue : Theme.c.bgDark

                Behavior on color {
                    CAnim {}
                }

                StateLayer {
                    color: Theme.c.bgDark
                    disabled: field.text.length === 0
                    onClicked: root.submit()
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    size: 20
                    text: "arrow_forward"
                    color: field.text.length > 0 ? Theme.c.bgDark : Theme.c.dark3
                }
            }
        }
    }
}
