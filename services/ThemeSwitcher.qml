pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool switching: false

    function apply(name: string): void {
        if (root.switching || name === Themes.activeName)
            return;

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
