import qs.services
import qs.modules

PanelIpc {
    target: "session"

    function status(): string {
        const win = Shell.showing(w => w.session.open);
        return `open=${win?.session.open ?? false}`;
    }
}
