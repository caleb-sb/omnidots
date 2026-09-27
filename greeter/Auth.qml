import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import "sessions.js" as Sessions

// The login flow: one greetd session at a time, driven by PAM's conversation.
// greetd sends any number of messages; the ones that need an answer (the
// password, or a visible prompt) set `prompt`, and info and error messages
// set `message`. Once PAM is done, the chosen session is launched and
// Quickshell exits, which ends the greeter cleanly (see omnidots-greeter).
//
// greetd answers a cancel with a plain success, which Quickshell would take
// for the end of the next login's authentication if that login started
// before the answer came. So a new login never follows a cancel directly: a
// cancel happens when the user field is edited (or by Quickshell itself after
// a failure), and the next login starts when the user presses Enter.
Item {
    id: root

    // The user being logged in, and the session to start.
    property string user: ""
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] ?? null

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
    // Bumped on a failed login, so the card can shake.
    property int failures: 0
    // Typed before the login it answers had started (after a failure):
    // the answer to that login's first prompt.
    property string pendingAnswer: ""

    // The user and session from the last login, kept in the greeter user's
    // home (/var/lib/greetd), which greetd's package makes writable for it.
    readonly property string statePath: `${Quickshell.env("HOME")}/omnidots-greeter.json`
    property string rememberedSession: ""

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

    function cycleSession(by: int): void {
        if (sessions.length)
            sessionIndex = (sessionIndex + by + sessions.length) % sessions.length;
    }

    function remember(): void {
        stateFile.setText(JSON.stringify({
            user: root.user,
            session: root.session?.name ?? ""
        }) + "\n");
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

        function onReadyToLaunch(): void {
            const s = root.session;
            root.remember();
            Greetd.launch([s.command], Sessions.environment(s));
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

    // The session files whose TryExec, if any, is installed.
    Process {
        running: true
        command: ["sh", "-c", `
            for f in /usr/share/wayland-sessions/*.desktop; do
                [ -f "$f" ] || continue
                try=$(sed -n 's/^TryExec=//p' "$f" | head -n 1)
                [ -z "$try" ] || command -v "$try" >/dev/null || continue
                cat "$f"; echo
            done`]
        stdout: StdioCollector {
            onStreamFinished: root.setSessions(text)
        }
    }

    function setSessions(listing: string): void {
        sessions = Sessions.parse(listing);
        sessionIndex = Sessions.defaultIndex(sessions, rememberedSession);
    }

    FileView {
        id: stateFile

        path: root.statePath
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        // Until the session files are read, and if they can't be.
        setSessions("");
        let saved = {};
        try {
            saved = JSON.parse(stateFile.text() || "{}");
        } catch (e) {}
        rememberedSession = saved.session ?? "";
        if (saved.user)
            start(saved.user, "");
    }
}
