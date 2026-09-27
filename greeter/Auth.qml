import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// The login flow: one greetd session at a time, driven by PAM's conversation.
// greetd sends any number of messages; the ones that need an answer (the
// password, or a visible prompt) set `prompt`, and info and error messages
// set `message`. Once PAM is done, Hyprland is launched and Quickshell exits,
// which ends the greeter cleanly (see omnidots-greeter).
//
// greetd answers a cancel with a plain success, which Quickshell would take
// for the end of the next login's authentication if that login started
// before the answer came. So a new login never follows a cancel directly: a
// cancel happens when the user field is edited (or by Quickshell itself after
// a failure), and the next login starts when the user presses Enter.
Item {
    id: root

    // The machine's user, from the `user` file 88-greeter.sh deploys next to
    // this one. With it there's no user field; without it, there is.
    property string owner: ""
    // The owner's first name, from their account's full name, for the
    // greeting (as lockinfo.sh does for hyprlock).
    property string firstName: ""

    // The user being logged in.
    property string user: ""

    // The pending PAM prompt, e.g. "Password: ", and whether to show what's
    // typed. Empty when nothing is being asked.
    property string prompt: ""
    property bool echo: false
    // The latest info or error message, from PAM or greetd.
    property string message: ""
    property bool messageIsError: false
    readonly property bool active: Greetd.state !== GreetdState.Inactive
    // Waiting on greetd: between an answer and the next message.
    readonly property bool busy: active && !prompt
    // Bumped on a failed login, so the form can shake.
    property int failures: 0
    // Typed before the login it answers had started (after a failure):
    // the answer to that login's first prompt.
    property string pendingAnswer: ""

    // Without an owner, the user from the last login, kept in the greeter
    // user's home (/var/lib/greetd), which greetd's package makes writable
    // for it.
    readonly property string statePath: `${Quickshell.env("HOME")}/omnidots-greeter.json`

    // start(user, answer) — log in as user, with the answer to its first
    // prompt if already typed. Only between logins; see editUser().
    function start(name: string, answer: string): void {
        name = name.trim();
        if (!name || active)
            return;
        user = name;
        prompt = "";
        message = "";
        pendingAnswer = answer ?? "";
        Greetd.createSession(name);
    }

    // editUser() — the user field is being changed: drop the login in
    // progress, if any.
    function editUser(): void {
        if (!active)
            return;
        prompt = "";
        pendingAnswer = "";
        Greetd.cancelSession();
    }

    // answer(text) — respond to the pending prompt.
    function answer(text: string): void {
        if (!prompt)
            return;
        prompt = "";
        Greetd.respond(text);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (!responseRequired) {
                root.message = message.trim();
                root.messageIsError = error;
            } else if (root.pendingAnswer) {
                const text = root.pendingAnswer;
                root.pendingAnswer = "";
                Greetd.respond(text);
            } else {
                root.prompt = message.trim() || "Password:";
                root.echo = echoResponse;
            }
        }

        function onAuthFailure(message: string): void {
            // greetd passes PAM's error through, e.g. "pam_authenticate:
            // AUTH_ERR" for a wrong password.
            root.message = /AUTH_ERR/.test(message) ? "Wrong password" : message.trim() || "Login failed";
            root.messageIsError = true;
            root.prompt = "";
            root.pendingAnswer = "";
            root.failures++;
        }

        function onError(error: string): void {
            root.message = error.trim() || "greetd error";
            root.messageIsError = true;
            root.prompt = "";
            root.pendingAnswer = "";
            root.failures++;
        }

        // Hyprland is the only session, started the way its session file
        // (/usr/share/wayland-sessions/hyprland.desktop) and tuigreet do.
        function onReadyToLaunch(): void {
            if (!root.owner)
                stateFile.setText(JSON.stringify({
                    user: root.user
                }) + "\n");
            Greetd.launch(["start-hyprland"], ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland"]);
        }
    }

    // greetd not answering at all means the greeter can't log anyone in:
    // exit with an error, so omnidots-greeter falls back to tuigreet.
    Timer {
        running: root.busy
        interval: 30000
        onTriggered: {
            console.error("greetd stopped answering");
            Qt.exit(1);
        }
    }

    Process {
        running: root.owner !== ""
        command: ["getent", "passwd", root.owner]
        stdout: StdioCollector {
            onStreamFinished: root.firstName = text.split(":")[4]?.split(",")[0].split(" ")[0] ?? ""
        }
    }

    FileView {
        id: ownerFile

        path: Quickshell.shellPath("user")
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: stateFile

        path: root.statePath
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        owner = ownerFile.text().trim();
        let saved = {};
        try {
            saved = JSON.parse(stateFile.text() || "{}");
        } catch (e) {}
        start(owner || saved.user || "", "");
    }
}
