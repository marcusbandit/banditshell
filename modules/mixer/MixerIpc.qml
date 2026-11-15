import Quickshell.Io
import qs.services

IpcHandler {
    target: "mixer"

    function open(): string {
        Mixer.show();
        return "open";
    }

    function toggle(): string {
        Mixer.toggle();
        return Mixer.windowOpen ? "open" : "closed";
    }

    function close(): string {
        Mixer.hide();
        return "closed";
    }

    function status(): string {
        const apps = Mixer.outputApps.map(a => `${a.display}=${Mixer.stateOf(a)}`).join(",");
        const listening = Mixer.inputApps.map(a => `${a.display}=${Mixer.stateOf(a)}`).join(",");
        return `open=${Mixer.windowOpen} watching=${Mixer.watching} apps=[${apps}] listening=[${listening}]`;
    }
}
