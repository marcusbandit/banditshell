import QtQuick
import qs.config
import qs.services
import "../system-asks.js" as Asks
import "../../../services/brightness.js" as Brightness

QtObject {
    id: root

    required property var search

    readonly property var settings: Config.values.launcher.systemControls ?? {}
    readonly property bool enabled: root.settings.brightness !== false
    readonly property int lowest: root.settings.lowestBrightness ?? 5

    readonly property var asked: root.enabled ? Asks.brightnessAsk(root.search.text) : null
    readonly property bool near: root.enabled && !root.asked && Asks.brightnessNear(root.search.text)
    readonly property bool wanted: root.asked !== null || root.near

    readonly property bool intent: root.asked !== null

    readonly property int displayCount: Display.displays.length

    onDisplayCountChanged: if (root.wanted)
        Display.readLevels()

    onWantedChanged: if (root.wanted) {
        ToolInstaller.probe();
        Backlight.refresh();
        Display.readLevels();
    }

    readonly property var kinds: ["brightness", "brightnessall", "brightnessstep", "brightnessinstall", "brightnessnone"]

    readonly property var caps: ({
            brightness: 10
        })

    readonly property var screens: {
        const out = [];
        const several = Backlight.devices.length > 1;
        for (const device of Backlight.devices) {
            const name = device.name;
            out.push({
                id: `backlight:${name}`,
                label: "Built-in screen",
                detail: several ? name : "",
                icon: "laptop_chromebook",
                value: () => Backlight.levelOf(name),
                set: v => Backlight.setLevel(name, v)
            });
        }
        for (const display of Display.displays) {
            const shown = display;
            out.push({
                id: `monitor:${display.index}`,
                label: display.model || display.name,
                detail: display.name,
                icon: "monitor",
                value: () => Display.levelOf(shown),
                set: v => Display.setDisplayLevel(shown, v)
            });
        }
        return out;
    }

    readonly property bool needsDdcutil: ToolInstaller.probed && (!ToolInstaller.has("ddcutil") || Display.ddcutilMissing)

    function clamped(v: real): real {
        return Brightness.clamp(v, root.lowest);
    }

    function setAll(fraction: real): void {
        const level = root.clamped(fraction);
        for (const device of Backlight.devices)
            Backlight.setLevel(device.name, level);
        if (Display.displays.length)
            Display.setLevel(level);
    }

    function step(direction: int): void {
        for (const screen of root.screens)
            if (screen.value() >= 0)
                screen.set(Brightness.stepped(screen.value(), direction, root.lowest));
    }

    function levelsText(): string {
        const seen = [];
        for (const screen of root.screens) {
            const text = Brightness.percentText(screen.value());
            if (text && !seen.includes(text))
                seen.push(text);
        }
        return seen.join(", ");
    }

    function screenRow(screen: var, score: real): var {
        return {
            key: `brightness:${screen.id}`,
            kind: "brightness",
            screen: screen,
            label: screen.label,
            detail: screen.detail,
            icon: screen.icon,
            slider: {
                value: () => Math.max(0, screen.value()),
                set: v => screen.set(root.clamped(v)),
                text: () => Brightness.percentText(screen.value()),
                to: 1,
                step: 0.05
            },
            score: score
        };
    }

    function stepRow(direction: int): var {
        return {
            key: direction > 0 ? "brightness:brighter" : "brightness:dimmer",
            kind: "brightnessstep",
            direction: direction,
            label: direction > 0 ? "Brighter" : "Dimmer",
            detail: root.levelsText(),
            icon: direction > 0 ? "brightness_high" : "brightness_low",
            score: Infinity
        };
    }

    function rowById(id: string): var {
        if (!root.enabled)
            return null;
        if (id === "brightness:brighter")
            return root.stepRow(1);
        if (id === "brightness:dimmer")
            return root.stepRow(-1);
        const screen = root.screens.find(s => `brightness:${s.id}` === id);
        return screen ? root.screenRow(screen, 1) : null;
    }

    readonly property var rows: {
        if (!root.wanted)
            return [];
        const ask = root.asked;
        const score = root.near ? 0.4 : Infinity;
        const out = [];
        if (ask?.kind === "set" && root.screens.length) {
            const level = Math.round(root.clamped(ask.level / 100) * 100);
            out.push({
                key: `brightnessall:${level}`,
                kind: "brightnessall",
                level: level,
                label: `Set brightness to ${level}%`,
                detail: root.screens.length > 1 ? `${root.screens.length} screens` : root.screens[0].label,
                icon: "brightness_medium",
                score: Infinity
            });
        }
        if (ask?.kind === "step" && root.screens.length)
            out.push(root.stepRow(ask.direction));
        for (const screen of root.screens)
            out.push(root.screenRow(screen, score));
        if (root.near)
            return out;
        if (root.needsDdcutil && ToolInstaller.canInstall("ddcutil"))
            out.push({
                key: "brightnessinstall",
                kind: "brightnessinstall",
                label: ToolInstaller.installLabel("ddcutil"),
                detail: "",
                icon: "download",
                score: Infinity
            });
        else if (!root.screens.length && ToolInstaller.probed && Backlight.read && !Display.queue.length)
            out.push({
                key: "brightnessnone",
                kind: "brightnessnone",
                label: "No screen here takes brightness changes",
                detail: ToolInstaller.has("ddcutil") ? "ddcutil found no monitors" : "",
                icon: "brightness_empty",
                score: Infinity
            });
        return out;
    }

    readonly property var groups: [
        {
            key: "brightness",
            title: "Brightness",
            items: root.rows
        }
    ]

    function activate(row: var): void {
        switch (row.kind) {
        case "brightnessall":
            {
                const level = row.level / 100;
                root.search.leave(() => root.setAll(level));
                return;
            }
        case "brightnessstep":
            root.step(row.direction);
            return;
        case "brightnessinstall":
            ToolInstaller.install("ddcutil");
            return;
        case "brightness":
            root.search.leave(() => {});
            return;
        }
    }

    function actionsFor(row: var): var {
        switch (row.kind) {
        case "brightnessall":
            return [
                {
                    icon: "brightness_medium",
                    label: row.label,
                    run: () => root.activate(row)
                }
            ];
        case "brightnessstep":
            return [
                {
                    icon: row.icon,
                    label: row.label,
                    run: () => root.activate(row)
                }
            ];
        case "brightnessinstall":
            return [
                {
                    icon: "download",
                    label: "Install",
                    run: () => root.activate(row)
                }
            ];
        case "brightness":
            {
                const screen = row.screen;
                return [
                    {
                        icon: "check",
                        label: "Done",
                        run: () => root.activate(row)
                    },
                    {
                        icon: "brightness_low",
                        label: "Dimmer",
                        tucked: true,
                        run: () => screen.value() >= 0 && screen.set(Brightness.stepped(screen.value(), -1, root.lowest))
                    },
                    {
                        icon: "brightness_high",
                        label: "Brighter",
                        tucked: true,
                        run: () => screen.value() >= 0 && screen.set(Brightness.stepped(screen.value(), 1, root.lowest))
                    }
                ];
            }
        }
        return [];
    }
}
