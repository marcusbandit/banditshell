pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.panel

Scope {
    id: root
    required property var inspector

    IpcHandler {
        target: "inspect"

        function island(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return PanelWindows.missing(screen);
            root.inspector.show(win);
            return "inspecting the island: pick a situation on the right, or build one. Esc, the close button or `banditshell dev inspect close` ends it and takes everything made up away";
        }

        function close(): string {
            root.inspector.close();
            return "closed";
        }
    }
}
