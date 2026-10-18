import Quickshell
import Quickshell.Io
import qs.config
import qs.services

IpcHandler {
    target: "stream"

    function on(screen: string): string {
        const names = Quickshell.screens.map(s => s.name);
        const wanted = screen || StreamState.screen;
        if (!wanted)
            return `refused: name the screen to stream from (connected: ${names.join(", ")})`;
        if (!names.includes(wanted))
            return `refused: no such screen: ${wanted}${screen ? "" : " (the stored one)"} (connected: ${names.join(", ")})`;
        if (!Config.writable)
            return `refused: ${Config.path} has not been read, so nothing can be stored`;
        if (StreamState.enabled && StreamState.screen === wanted)
            return `stream already on ${wanted}`;
        const was = StreamState.enabled ? StreamState.screen : "";
        StreamState.setOn(wanted);
        return was ? `stream: on ${wanted} (was ${was})` : `stream: on ${wanted}`;
    }

    function off(): string {
        if (!StreamState.enabled)
            return "stream already off";
        StreamState.setOff();
        return "stream: off";
    }

    function status(): string {
        const others = Quickshell.screens.map(s => s.name).filter(name => StreamState.floats(name));
        if (!StreamState.enabled)
            return StreamState.screen ? `off\nscreen    ${StreamState.screen} (stored for the next on)` : "off";
        return [`on ${StreamState.screen}${StreamState.connected ? "" : ", which is not connected"}`, `height    ${Appearance.sizes.streamHeight}`, `reserve   ${StreamState.connected ? `${StreamState.reserve} on the top` : "nothing"}`, `floating  ${others.join(", ") || "-"}`].join("\n");
    }
}
