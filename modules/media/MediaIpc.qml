import qs.services
import qs.modules

PanelIpc {
    target: "media"

    function status(): string {
        const win = Shell.showing(w => w.media.open);
        return `open=${win?.media.open ?? false} player=${Media.app || "none"} playing=${Media.playing} title="${Media.title}"`;
    }
}
