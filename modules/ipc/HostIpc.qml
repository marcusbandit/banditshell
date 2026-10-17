import Quickshell.Io
import qs.config

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
