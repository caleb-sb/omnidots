pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon (replaces dunst while the bar runs). Each notification
// is copied into a NotifData so history outlives the sender and survives
// restarts (saved to the Quickshell state dir).
Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> popups: list.filter(n => n.popup)
    readonly property int count: list.length

    property bool dnd
    // Set by the bar while the notifications panel is open; popups stay hidden.
    property bool panelOpen
    // Set by game mode: like do-not-disturb, without changing the dnd setting.
    property bool quiet

    readonly property int defaultTimeout: 5000

    // Ticks so "5m ago" labels stay current.
    property date now: new Date()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    onPanelOpenChanged: {
        if (panelOpen)
            for (const n of list)
                n.popup = false;
    }

    function clear(): void {
        for (const n of list.slice())
            n.close();
    }

    function remove(n: NotifData): void {
        list = list.filter(x => x !== n);
        // Late, so cards animating out can still read it.
        n.destroy(2000);
    }

    function ago(t: date): string {
        const s = Math.max(0, (now - t) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return `${Math.floor(s / 86400)}d`;
    }

    // Icon source for a notification: explicit path/URL, theme icon name, or
    // the app's desktop entry. Empty = caller falls back to a glyph.
    function iconFor(n: NotifData): string {
        // notify-send -i puts the icon name in the image hint.
        if (n.image.startsWith("image://icon/"))
            return Quickshell.iconPath(n.image.slice(13), true);
        const i = n.appIcon;
        if (i.startsWith("/") || i.includes("://"))
            return i.startsWith("/") ? `file://${i}` : i;
        if (i)
            return Quickshell.iconPath(i, true);
        const entry = DesktopEntries.heuristicLookup(n.desktopEntry || n.appName);
        return entry?.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            const wantsPopup = !root.panelOpen && (!(root.dnd || root.quiet) || notif.urgency === NotificationUrgency.Critical);
            const existing = root.list.find(x => x.notification === notif);
            if (existing) {
                existing.sync();
                existing.time = new Date();
                existing.popup = wantsPopup;
                root.list = [existing, ...root.list.filter(x => x !== existing)];
                return;
            }
            const n = notifComp.createObject(root, {
                notification: notif,
                time: new Date(),
                popup: wantsPopup
            });
            root.list = [n, ...root.list];
        }
    }

    // ── Persistence ───────────────────────────────────────────────
    property bool loaded

    function save(): void {
        if (!loaded)
            return;
        storage.setText(JSON.stringify({
            dnd: dnd,
            notifs: list.filter(n => !n.isTransient).map(n => ({
                        time: n.time.getTime(),
                        appName: n.appName,
                        appIcon: n.appIcon,
                        desktopEntry: n.desktopEntry,
                        summary: n.summary,
                        body: n.body,
                        urgency: n.urgency,
                        // Raw image data only lives in memory.
                        image: n.image.startsWith("image://qsimage") ? "" : n.image
                    }))
        }));
    }

    onListChanged: saveTimer.restart()
    onDndChanged: saveTimer.restart()

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: root.save()
    }

    FileView {
        id: storage

        path: Quickshell.statePath("notifications.json")
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.dnd = !!data.dnd;
                const restored = (data.notifs ?? []).map(d => notifComp.createObject(root, Object.assign({}, d, {
                        time: new Date(d.time)
                    })));
                root.list = [...root.list, ...restored];
            } catch (e) {
                console.warn("notifications: bad state file,", e);
            }
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }

    // ── One notification ──────────────────────────────────────────
    component NotifData: QtObject {
        id: data

        // Live D-Bus notification; null once closed or for restored history.
        property Notification notification
        property date time
        property bool popup

        property string appName
        property string appIcon
        property string desktopEntry
        property string summary
        property string body
        property string image
        property int urgency: NotificationUrgency.Normal
        property bool isTransient
        readonly property var actions: notification?.actions ?? []
        readonly property int timeout: {
            const t = notification?.expireTimeout ?? -1;
            if (urgency === NotificationUrgency.Critical && t <= 0)
                return 0; // sticky
            return t > 0 ? t : root.defaultTimeout;
        }

        function sync(): void {
            const n = notification;
            if (!n)
                return;
            appName = n.appName;
            appIcon = n.appIcon;
            desktopEntry = n.desktopEntry;
            summary = n.summary;
            body = n.body;
            image = n.image;
            urgency = n.urgency;
            isTransient = n.transient;
        }

        // Popup timed out: keep it in history (unless the sender said not to).
        function expire(): void {
            popup = false;
            if (isTransient)
                close();
        }

        // User dismissed it (or cleared all).
        function close(): void {
            const n = notification;
            notification = null;
            n?.dismiss();
            root.remove(data);
        }

        function invoke(action: NotificationAction): void {
            action.invoke();
            if (!notification?.resident)
                close();
        }

        onNotificationChanged: sync()
        Component.onCompleted: sync()

        property Connections watcher: Connections {
            target: data.notification

            // Senders update in place (replaces_id); keep our copy in step.
            function onSummaryChanged(): void {
                data.sync();
            }
            function onBodyChanged(): void {
                data.sync();
            }
            function onImageChanged(): void {
                data.sync();
            }
            function onAppIconChanged(): void {
                data.sync();
            }
            function onUrgencyChanged(): void {
                data.sync();
            }
            function onClosed(reason: int): void {
                data.notification = null;
                // Closed by the sender: drop it. Our own dismissals already did.
                if (reason === NotificationCloseReason.CloseRequested)
                    root.remove(data);
            }
        }
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
