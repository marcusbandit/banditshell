pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "theme-modes.js" as ThemeModes

Singleton {
    id: root

    property bool switching: false

    readonly property string modeTheme: ThemeModes.wantedTheme(Config.values.colour, Appearance.light, Config.values.themeFromWallpaper, Themes.activeName, Themes.availableNames)

    onModeThemeChanged: if (root.modeTheme !== "" && !root.switching)
        root.apply(root.modeTheme)

    function remember(name: string): void {
        const keep = ThemeModes.slotToKeep(Config.values.colour, Appearance.light, name);
        if (keep)
            Config.set(`colour.${keep.key}`, keep.value);
    }

    readonly property bool available: !ToolInstaller.probed || ToolInstaller.has("theme-set")
    readonly property string unavailableWhy: "themes are switched by theme-set, which is not installed on this machine"

    function apply(name: string): void {
        if (root.switching || name === Themes.activeName)
            return;

        if (!root.available) {
            console.warn(`ThemeSwitcher: ${root.unavailableWhy}.`);
            return;
        }

        if (!Themes.availableNames.includes(name)) {
            console.warn(`ThemeSwitcher: nothing on this machine renders a theme called ${name}.`);
            return;
        }

        root.switching = true;
        switcher.exec(["theme-set", name]);
    }

    Process {
        id: switcher

        onExited: (code, status) => {
            root.switching = false;
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
