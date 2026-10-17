import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.panel

Scope {
    id: root

    required property var picker

    readonly property var hidden: ["launcher", "session", "clipboard", "media", "calculator", "keyboard", "settings", "hotkeys", "wallpapers"]
    readonly property var pinned: ["quickControls", "island"]

    IpcHandler {
        target: "border"

        function off(): string {
            if (!Config.values.edge.bare) {
                Config.set("edge.bare", true);
                return "border: off";
            }
            return "border already off";
        }

        function on(): string {
            if (Config.values.edge.bare) {
                Config.set("edge.bare", false);
                return "border: on";
            }
            return "border already on";
        }

        function toggle(): string {
            const next = !Config.values.edge.bare;
            Config.set("edge.bare", next);

            return `border: ${next ? "off" : "on"}`;
        }

        function status(): string {
            return Config.values.edge.bare ? "off (bare)" : "on";
        }
    }

    IpcHandler {
        target: "panels"

        function closeAll(): string {
            for (const part of root.hidden)
                PanelWindows.close(part);
            for (const part of root.pinned)
                PanelWindows.unpin(part);
            PanelWindows.close("menus");
            root.picker.close();
            return "closed";
        }
    }
}
