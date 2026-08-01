pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire, adapted.
//
// Widgets read this, never `Pipewire` directly. Two things make that worth a
// file of its own:
//
// BINDING. A PwNode reports nothing until something is tracking it. Reading
// `volume` off an untracked node gives 0, not an error, so a forgotten tracker
// looks like silence rather than a bug. PwObjectTracker below keeps everything
// this shell might show bound, in one place, rather than each widget
// remembering.
//
// ROUNDING. PipeWire volume is a float and the UI is in whole percent. Feeding
// a slider's raw value straight back means 0.6100000143 and a label that
// flickers between 61 and 62 for one pixel of travel, so the setters quantise.
Singleton {
    id: root

    // The default output and input.
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: !!sink?.ready

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: !!sink?.audio?.muted

    readonly property real sourceVolume: source?.audio?.volume ?? 0
    readonly property bool sourceMuted: !!source?.audio?.muted

    // Above 1.0 is amplification. Allowed, because refusing to go there is the
    // kind of protective decision that makes a shell annoying, but it is the
    // caller's job to make it look like a warning.
    readonly property real maxVolume: 1.5

    // Everything that can be picked as an output. Streams are individual apps
    // and belong to a per-app mixer, not here.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && n.audio && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && n.audio && !n.isStream)

    function label(node: PwNode): string {
        return node?.nickname || node?.description || node?.name || "unknown";
    }

    // Whole percent, so a slider and a readout cannot disagree.
    function quantise(v: real): real {
        return Math.round(Math.max(0, Math.min(root.maxVolume, v)) * 100) / 100;
    }

    function setVolume(v: real): void {
        if (!sink?.ready || !sink?.audio)
            return;
        // Setting a volume is also asking to hear it.
        sink.audio.muted = false;
        sink.audio.volume = root.quantise(v);
    }

    function setSourceVolume(v: real): void {
        if (!source?.ready || !source?.audio)
            return;
        source.audio.muted = false;
        source.audio.volume = root.quantise(v);
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleSourceMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function setSink(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    function icon(v: real, isMuted: bool): string {
        if (isMuted)
            return "no_sound";
        if (v >= 0.5)
            return "volume_up";
        if (v > 0)
            return "volume_down";
        return "volume_mute";
    }

    // Nothing reports until it is tracked.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources]
    }
}
