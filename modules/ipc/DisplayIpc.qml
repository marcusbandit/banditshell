import Quickshell
import Quickshell.Io
import qs.services

Scope {
    readonly property var colourScheme: DarkMode

    IpcHandler {
        target: "screen"

        function brightness(value: string): string {
            if (!Display.brightnessReady)
                return "no display answers DDC";
            const n = parseFloat(value);
            if (!isFinite(n))
                return `not a number: ${value}`;
            if (!Display.levelKnown)
                return "brightness not read yet, ask again in a moment";
            const relative = value.startsWith("+") || value.startsWith("-");
            Display.setLevel(relative ? Display.level + n / 100 : n / 100);
            return `${Math.round(Display.level * 100)}%`;
        }

        function temperature(value: string): string {
            if (value === "off") {
                Display.setWarmth(0);
                return "off";
            }
            const n = parseInt(value, 10);
            if (!isFinite(n) || n <= 0)
                return `not a kelvin number or "off": ${value}`;
            Display.setWarmth(n);
            return `${Display.kelvin}K`;
        }

        function status(): string {
            return Display.status();
        }
    }

    IpcHandler {
        target: "tablet"

        function on(from: string): string {
            return Tablet.apply("on", from || "cli");
        }

        function off(from: string): string {
            return Tablet.apply("off", from || "cli");
        }

        function toggle(from: string): string {
            return Tablet.apply("toggle", from || "cli");
        }

        function lid(state: string, from: string): string {
            return Tablet.applyLid(state, from || "cli");
        }

        function status(): string {
            const state = Tablet.folding ? "folded" : "flat";
            const hinge = `${Tablet.known ? "known" : "assumed"}, via ${Tablet.source}`;
            const lid = `${Tablet.lidClosed ? "closed" : "open"}, ${Tablet.lidKnown ? "known" : "assumed"}, via ${Tablet.lidSource}`;

            return `${state} (hinge ${Tablet.hinge ? "on" : "off"}, ${hinge}; lid ${lid})`;
        }
    }
}
