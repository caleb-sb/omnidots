pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink/source plus the device lists, shared by the bar icon and panel.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property list<PwNode> sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property list<PwNode> sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property real step: 0.05

    // Volume/mute only work on bound nodes.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function setVolume(node: PwNode, v: real): void {
        if (!node?.ready || !node.audio)
            return;
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute(node: PwNode): void {
        if (node?.ready && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    function setDefault(node: PwNode): void {
        if (node.isSink)
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
    }

    function label(node: PwNode): string {
        if (!node)
            return "None";
        return node.description || node.nickname || node.name;
    }

    // Material glyph for a device, from its PipeWire node name.
    function deviceIcon(node: PwNode): string {
        const n = node?.name ?? "";
        if (n.startsWith("bluez"))
            return "headphones";
        if (n.includes("hdmi"))
            return "tv";
        if (n.includes("usb"))
            return node.isSink ? "headset" : "mic_external_on";
        return node?.isSink ? "speaker" : "mic";
    }

    function volumeIcon(v: real, m: bool): string {
        if (m)
            return "volume_off";
        if (v <= 0.001)
            return "volume_mute";
        return v < 0.5 ? "volume_down" : "volume_up";
    }
}
