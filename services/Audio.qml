pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

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

    // Everything that can be picked as an output or an input.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && n.audio && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && n.audio && !n.isStream)

    // The individual apps, split by which direction they point.
    //
    // `media.class` rather than `isSink`, which is true for a playback stream
    // (it feeds a sink) and reads like the opposite of what it means. PipeWire
    // says Stream/Output/Audio for something playing and Stream/Input/Audio for
    // something listening, and those are the two questions: what is making
    // noise, and what is hearing me.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
    readonly property var playing: streams.filter(n => (n.properties?.["media.class"] ?? "").includes("Output"))
    readonly property var recording: streams.filter(n => (n.properties?.["media.class"] ?? "").includes("Input"))

    function label(node: PwNode): string {
        return node?.nickname || node?.description || node?.name || "unknown";
    }

    // WHAT THE THING IS, WHERE IT PLUGS IN, AND WHAT TO CALL IT.
    //
    // A list of audio devices is only useful if you can tell which one is your
    // headphones. PipeWire will tell you, but each backend tells you something
    // different: ALSA sets `device.icon_name` and a human profile description,
    // while bluez sets neither on a source and not even `device.api`, leaving
    // nothing but a node name beginning with `bluez_`. So the answer is
    // assembled from what each backend actually provides, in that order, and
    // every step falls through to the next.

    function isBluetooth(node: PwNode): bool {
        return (node?.properties?.["device.api"] ?? "") === "bluez5" || (node?.name ?? "").startsWith("bluez");
    }

    // The MAC, which is the one thing the audio node and bluez both know. It is
    // in the properties when the backend filled them in and in the node name
    // when it did not, where a source spells it with colons and a sink with
    // underscores.
    function btAddress(node: PwNode): string {
        const direct = node?.properties?.["api.bluez5.address"] ?? "";
        if (direct)
            return direct.toUpperCase();
        const found = (node?.name ?? "").match(/bluez_(?:input|output)\.([0-9A-Fa-f]{2}(?:[:_][0-9A-Fa-f]{2}){5})/);
        return found ? found[1].replace(/_/g, ":").toUpperCase() : "";
    }

    // The glyph for a device's KIND, which is the question the icon answers:
    // headphones, speakers, a microphone, a television.
    //
    // For bluetooth it asks bluez, because the audio node has no idea what it is
    // attached to and bluez has known since it paired. Direction matters at the
    // end: the same headset is headphones when you are listening through it and
    // a headset microphone when you are talking into it.
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

    // Where it plugs in, WHEN THAT IS NEWS.
    //
    // Empty for anything soldered to the machine, which is most of the list.
    // "Built-in" under a row that says Speaker, and under both of the two
    // microphones, is a line of type that distinguishes nothing from nothing:
    // the name and the glyph have already said it. What is worth a second line
    // is the thing you would otherwise have to know: that this one is on the
    // radio, or hanging off a port.
    //
    // Bluetooth carries its profile, because that is the difference between
    // music and a telephone. Taking the headset microphone drops the whole
    // device into headset mode, and everything through it suddenly sounds like
    // 1998; saying so is the only warning anyone gets.
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

    // What to CALL it. ALSA's node name is the chipset ("ALC257 Analog", twice,
    // once for each direction); its profile description is what the thing is
    // ("Speaker", "Digital Microphone"), which is what a person would say. A
    // bluetooth device is already named by whoever made it.
    function deviceLabel(node: PwNode): string {
        if (root.isBluetooth(node))
            return root.label(node);
        return node?.properties?.["device.profile.description"] || root.label(node);
    }

    // What an app calls itself. `application.name` is right nearly always and
    // is what the app chose to be called; the rest are for the ones that set
    // nothing, where the process name is at least true.
    function streamLabel(node: PwNode): string {
        return node?.properties?.["application.name"] || node?.description || node?.properties?.["application.process.binary"] || node?.name || "unknown";
    }

    // What to LOOK it up as. A desktop entry is found by something close to the
    // binary far more often than by the display name an app invents for itself,
    // so both are offered and the caller takes whichever resolves.
    function streamBinary(node: PwNode): string {
        return node?.properties?.["application.process.binary"] || "";
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

    // One app, not the whole machine. Same shape as the pair above on purpose:
    // a stream is a volume like any other, and the mixer should not need to
    // know that it is a special kind.
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

    // SPEAKERS AND HEADPHONES, which is the one thing about a sink that
    // PipeWire cannot be asked.
    //
    // A node knows its bus, its profile and what the driver calls it, and none
    // of that answers which box you listen through and which one goes on your
    // head. Reading `device.icon_name` harder does not help: the machine this
    // was written on has an onboard chip that describes its speaker output as a
    // headphone jack and an interface that describes its headphone amp as a
    // line output, so the two devices claim each other's names. It is a
    // SETTING, one node name each in config/Config.qml's `audio` block, and
    // what is left for this file is resolving those names and saying plainly
    // when it cannot.

    // The names as configured, passed through rather than hidden behind the
    // nodes below, because "" is an answer a null node cannot give. A role that
    // resolves to nothing is EITHER unassigned OR assigned to something that is
    // not plugged in, and a keybind, a CLI and a settings row all want
    // different words for those two. The name is what tells them apart.
    readonly property string speakersName: Config.values.audio.speakers ?? ""
    readonly property string headphonesName: Config.values.audio.headphones ?? ""

    // The sink of that name, or null when it is not here.
    //
    // Searched over `sinks`, which is also what makes the tracker at the bottom
    // of this file enough for the two roles: anything this can hand back was
    // already in the list that tracker binds, so a resolved role reports real
    // numbers rather than the zeroes an untracked node reads as.
    function sinkByName(name: string): PwNode {
        if (!name)
            return null;
        return root.sinks.find(n => n.name === name) ?? null;
    }

    readonly property PwNode speakers: root.sinkByName(root.speakersName)
    readonly property PwNode headphones: root.sinkByName(root.headphonesName)

    // BOTH ROLES ON ONE SINK, which earns its own answer because it is the
    // failure that looks like success. The toggle works: it sets the default to
    // the device already playing and reports the role it landed on, so nothing
    // anywhere says no and the only symptom is a key that has quietly stopped
    // moving the sound. Two presses on the same device in the settings page is
    // all it takes to get here.
    readonly property bool rolesCollide: !!root.speakersName && root.speakersName === root.headphonesName

    // WHICH OF THE TWO IS PLAYING, compared BY NAME.
    //
    // Object identity is the wrong question even where it happens to work.
    // `Pipewire.defaultAudioSink` and the node found in `sinks` are one object
    // today, and comparing them would still be asking whether PipeWire handed
    // out one wrapper or two for one device rather than whether this is the
    // device that was configured. The name is what was written down and what is
    // being matched, so the name is what to compare.
    //
    // "" is a real place to be standing rather than an error: HDMI is a sink
    // like any other and nothing stops the default from being on it.
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

    // Through the properties above rather than through another lookup, so a
    // role resolves to the same object the bindings are watching.
    function roleNode(role: string): PwNode {
        return role === "speakers" ? root.speakers : role === "headphones" ? root.headphones : null;
    }

    // WHY A ROLE CANNOT BE SWITCHED TO, or "" when it can.
    //
    // Three failures, and they are three different things to go and do: assign
    // the device, plug it in, or fix the spelling. A setter that returned only
    // false would leave the CLI and the settings page each guessing which of
    // the three had happened, and they would guess differently.
    function roleProblem(role: string): string {
        if (role !== "speakers" && role !== "headphones")
            return "no such role, expected speakers or headphones";
        if (!root.roleName(role))
            return "not assigned";
        if (!root.roleNode(role))
            return "assigned, but not connected right now";
        return "";
    }

    // Go there, and say where you landed. "" means it did not move, and
    // `roleProblem` has the sentence for why.
    function setOutputRole(role: string): string {
        const node = root.roleNode(role);
        if (!node)
            return "";
        root.setSink(node);
        return role;
    }

    // THE KEY'S VERB: whichever one you are not on.
    //
    // Standing on NEITHER is the case worth thinking about, and doing nothing
    // there would be wrong. A key pressed while the sound is on HDMI is a key
    // asking to bring it back, and the speakers are the answer that is right on
    // every machine that has any, so that is the home it heads for. Only when
    // the speakers are not to be had does it take the headphones instead:
    // landing somewhere audible beats refusing over a role nobody named.
    //
    // Standing on one of the two, a refusal is the whole answer. Falling back
    // to the role already playing is not a toggle, it is a key that reports
    // having done something it did not do.
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

    // Nothing reports until it is tracked, and an untracked node reads 0 rather
    // than failing, so a forgotten stream looks like an app sitting at silence.
    //
    // The two roles need no entry of their own: `sinkByName` only ever returns
    // something it found in `sinks`, so the spread below already covers
    // whatever `speakers` and `headphones` resolve to.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.streams]
    }
}
