pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: !!sink?.ready

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: !!sink?.audio?.muted

    readonly property real sourceVolume: source?.audio?.volume ?? 0
    readonly property bool sourceMuted: !!source?.audio?.muted

    readonly property real maxVolume: 1.5

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && n.audio && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && n.audio && !n.isStream)

    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
    readonly property var playing: streams.filter(n => (n.properties?.["media.class"] ?? "").includes("Output"))
    readonly property var recording: streams.filter(n => (n.properties?.["media.class"] ?? "").includes("Input"))

    function label(node: PwNode): string {
        return node?.nickname || node?.description || node?.name || "unknown";
    }

    function isBluetooth(node: PwNode): bool {
        return (node?.properties?.["device.api"] ?? "") === "bluez5" || (node?.name ?? "").startsWith("bluez");
    }

    function btAddress(node: PwNode): string {
        const direct = node?.properties?.["api.bluez5.address"] ?? "";
        if (direct)
            return direct.toUpperCase();
        const found = (node?.name ?? "").match(/bluez_(?:input|output)\.([0-9A-Fa-f]{2}(?:[:_][0-9A-Fa-f]{2}){5})/);
        return found ? found[1].replace(/_/g, ":").toUpperCase() : "";
    }

    function deviceIcon(node: PwNode): string {
        const sink = !!node?.isSink;

        if (root.isBluetooth(node)) {
            const kind = Bluetooth.icon(Bluetooth.deviceAt(root.btAddress(node)));
            if (kind === "headphones")
                return sink ? "headphones" : "headset_mic";
            if (kind !== "bluetooth")
                return kind;
            return sink ? "speaker" : "mic";
        }

        const icon = (node?.properties?.["device.icon_name"] || node?.properties?.["device.icon-name"] || "").toLowerCase();
        const name = (node?.name ?? "").toLowerCase();

        if (icon.includes("headset"))
            return sink ? "headphones" : "headset_mic";
        if (icon.includes("headphone"))
            return "headphones";
        if (icon.includes("microphone") || icon.includes("input"))
            return "mic";
        if (name.includes("hdmi") || name.includes("displayport"))
            return "tv";
        if (icon.includes("speaker"))
            return "speaker";
        if ((node?.properties?.["device.bus"] ?? "") === "usb")
            return "usb";
        return sink ? "speaker" : "mic";
    }

    function deviceTransport(node: PwNode): string {
        if (root.isBluetooth(node)) {
            const profile = (node?.properties?.["api.bluez5.profile"] ?? "").toLowerCase();
            const codec = (node?.properties?.["api.bluez5.codec"] ?? "").toUpperCase();
            if (profile.includes("hsp") || profile.includes("hfp") || profile.includes("headset"))
                return "Bluetooth · headset mode";
            return codec ? `Bluetooth · ${codec}` : "Bluetooth";
        }

        const name = (node?.name ?? "").toLowerCase();
        if (name.includes("hdmi") || name.includes("displayport"))
            return "HDMI";
        if ((node?.properties?.["device.bus"] ?? "") === "usb")
            return "USB";
        return "";
    }

    function deviceLabel(node: PwNode): string {
        if (root.isBluetooth(node))
            return root.label(node);
        return node?.properties?.["device.profile.description"] || root.label(node);
    }

    function streamLabel(node: PwNode): string {
        return node?.properties?.["application.name"] || node?.description || node?.properties?.["application.process.binary"] || node?.name || "unknown";
    }

    function streamBinary(node: PwNode): string {
        return node?.properties?.["application.process.binary"] || "";
    }

    function quantise(v: real): real {
        return Math.round(Math.max(0, Math.min(root.maxVolume, v)) * 100) / 100;
    }

    function setVolume(v: real): void {
        if (!sink?.ready || !sink?.audio)
            return;

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

    function streamVolume(node: PwNode): real {
        return node?.audio?.volume ?? 0;
    }

    function streamMuted(node: PwNode): bool {
        return !!node?.audio?.muted;
    }

    function setStreamVolume(node: PwNode, v: real): void {
        if (!node?.ready || !node?.audio)
            return;
        node.audio.muted = false;
        node.audio.volume = root.quantise(v);
    }

    function toggleStreamMute(node: PwNode): void {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    function setSink(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    readonly property string speakersName: Config.values.audio.speakers ?? ""
    readonly property string headphonesName: Config.values.audio.headphones ?? ""

    function sinkByName(name: string): PwNode {
        if (!name)
            return null;
        return root.sinks.find(n => n.name === name) ?? null;
    }

    readonly property PwNode speakers: root.sinkByName(root.speakersName)
    readonly property PwNode headphones: root.sinkByName(root.headphonesName)

    readonly property bool rolesCollide: !!root.speakersName && root.speakersName === root.headphonesName

    readonly property string outputRole: {
        const now = root.sink?.name ?? "";
        if (!now)
            return "";
        if (now === root.speakersName)
            return "speakers";
        if (now === root.headphonesName)
            return "headphones";
        return "";
    }

    function roleName(role: string): string {
        return role === "speakers" ? root.speakersName : role === "headphones" ? root.headphonesName : "";
    }

    function roleNode(role: string): PwNode {
        return role === "speakers" ? root.speakers : role === "headphones" ? root.headphones : null;
    }

    function roleProblem(role: string): string {
        if (role !== "speakers" && role !== "headphones")
            return "no such role, expected speakers or headphones";
        if (!root.roleName(role))
            return "not assigned";
        if (!root.roleNode(role))
            return "assigned, but not connected right now";
        return "";
    }

    function setOutputRole(role: string): string {
        const node = root.roleNode(role);
        if (!node)
            return "";
        root.setSink(node);
        return role;
    }

    function toggleOutput(): string {
        if (root.rolesCollide)
            return "";

        const other = root.outputRole === "speakers" ? "headphones" : "speakers";
        const landed = root.setOutputRole(other);
        if (landed || root.outputRole)
            return landed;
        return root.setOutputRole(other === "speakers" ? "headphones" : "speakers");
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

    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.streams]
    }
}
