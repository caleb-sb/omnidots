pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, backed by cliphist (the wl-paste watchers started by
// Hyprland store every copy). Newest first; the first entry is what's on the
// clipboard now.
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length

    // Decoded image previews, keyed by cliphist id.
    readonly property string thumbDir: Quickshell.cachePath("clipboard")

    // Entry objects are reused across reloads (keyed by id), so ScriptModels
    // keep their delegates and only real changes animate.
    property var cache: ({})

    function reload(): void {
        lister.running = true;
    }

    function copy(entry: var): void {
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${entry.id} | wl-copy`]);
    }

    function remove(entry: var): void {
        entries = entries.filter(e => e !== entry);
        Quickshell.execDetached(["sh", "-c", `printf '%s\\t\\n' ${entry.id} | cliphist delete; rm -f '${thumbDir}/${entry.id}.${entry.ext}'`]);
    }

    function wipe(): void {
        entries = [];
        cache = {};
        Quickshell.execDetached(["sh", "-c", `cliphist wipe; rm -rf '${thumbDir}'`]);
    }

    // Where an image entry's decoded preview lives (see ClipRow).
    function thumbPath(entry: var): string {
        return `${thumbDir}/${entry.id}.${entry.ext}`;
    }

    function parse(line: string): var {
        const tab = line.indexOf("\t");
        if (tab < 0)
            return null;
        const id = line.slice(0, tab);
        const preview = line.slice(tab + 1);
        const key = `${id}\t${preview}`;
        if (cache[key])
            return cache[key];

        const img = preview.match(/^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/);
        const e = img ? {
            id,
            preview,
            kind: "image",
            size: img[1],
            ext: img[2],
            w: +img[3],
            h: +img[4],
            search: `image ${img[2]}`
        } : {
            id,
            preview,
            kind: /^(https?|ftp):\/\/\S+$/.test(preview.trim()) ? "link" : /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(preview.trim()) ? "color" : "text"
        };
        if (!e.search)
            e.search = preview.toLowerCase();
        cache[key] = e;
        return e;
    }

    Process {
        id: lister

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = text.split("\n").map(l => root.parse(l)).filter(e => e);
                // Drop cache entries that fell out of history.
                const keep = {};
                for (const e of next)
                    keep[`${e.id}\t${e.preview}`] = e;
                root.cache = keep;
                root.entries = next;
            }
        }
    }

    // Reload whenever the clipboard changes. The delay lets cliphist's own
    // watcher store the new item first.
    Process {
        running: true
        command: ["wl-paste", "--watch", "sh", "-c", "cat > /dev/null; echo"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }
    Timer {
        id: debounce

        interval: 300
        onTriggered: root.reload()
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", `mkdir -p '${thumbDir}' && find '${thumbDir}' -type f -mtime +7 -delete`]);
        reload();
    }
}
