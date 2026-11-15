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
        return Mixer.statusLine();
    }
}
