import qs.services
import qs.modules.panel

PanelIpc {
    target: "session"

    function status(): string {
        const win = Shell.showing(w => w.session.open);
        return `open=${win?.session.open ?? false}`;
    }
}
