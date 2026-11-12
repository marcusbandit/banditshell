pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "theme-modes.js" as ThemeModes

Singleton {
    id: root

    property bool switching: false

    property string target: ""
    property string neutral: Themes.activeName

    readonly property bool light: Appearance.light
    readonly property string modeSlot: ThemeModes.slotOf(Config.values.colour, root.light)

    signal finished(string name, bool ok)

    function follow(): void {
        if (Config.values.themeFromWallpaper)
            return;
        const name = ThemeModes.targetFor(Config.values.colour, root.light, root.neutral || Config.values.theme, Themes.activeName, Themes.availableNames);
        if (name !== "")
            root.apply(name);
    }

    onLightChanged: root.follow()
    onModeSlotChanged: root.follow()

    Connections {
        target: Themes

        function onActiveNameChanged(): void {
            root.neutral = ThemeModes.neutralAfter(Config.values.colour, root.light, root.neutral, Themes.activeName);
        }
    }

    function remember(name: string): void {
        const keep = ThemeModes.slotToKeep(Config.values.colour, Appearance.light, name);
        if (keep)
            Config.set(`colour.${keep.key}`, keep.value);
    }

    readonly property bool available: !ToolInstaller.probed || ToolInstaller.has("theme-set")
    readonly property string unavailableWhy: "themes are switched by theme-set, which is not installed on this machine"

    function apply(name: string, fresh: bool): void {
        if (root.switching || name === Themes.activeName)
            return;

        if (!root.available) {
            console.warn(`ThemeSwitcher: ${root.unavailableWhy}.`);
            return;
        }

        if (!fresh && !Themes.availableNames.includes(name)) {
            console.warn(`ThemeSwitcher: nothing on this machine renders a theme called ${name}.`);
            return;
        }

        root.switching = true;
        root.target = name;
        switcher.exec(["theme-set", name]);
    }

    Process {
        id: switcher

        onExited: (code, status) => {
            root.switching = false;
            root.finished(root.target, code === 0);
            if (code !== 0)
                console.warn(`ThemeSwitcher: theme-set exited ${code}, so the machine kept the theme it had.`);
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const said = text.trim();
                if (said.length > 0)
                    console.warn(`ThemeSwitcher: theme-set said: ${said}`);
            }
        }
    }
}
