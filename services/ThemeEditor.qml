pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "theme-editor.js" as Editor

Singleton {
    id: root

    property string saving: ""
    property string awaiting: ""
    property var pending: null
    property string failure: ""

    signal saved(string name)

    readonly property string sourcePath: `${Themes.themeRoot}/themes/${Themes.activeName}/colors.toml`

    readonly property var current: ({
            dim: String(Themes.parsed?.dim ?? Themes.slate.dim),
            mid: String(Themes.parsed?.mid ?? Themes.slate.mid),
            bright: String(Themes.parsed?.bright ?? Themes.slate.bright),
            alarm: String(Themes.parsed?.alarm ?? Themes.slate.alarm)
        })

    function problem(name: string, colours: var): string {
        return Editor.problem(name, colours, Themes.availableNames);
    }

    function preview(colours: var): void {
        const next = Editor.overridesFrom(colours, root.current);
        if (JSON.stringify(next) !== JSON.stringify(Themes.previewing))
            Themes.previewing = next;
    }

    function cancel(): void {
        if (Themes.previewing !== null)
            Themes.previewing = null;
    }

    function save(name: string, colours: var): void {
        if (root.saving !== "" || root.problem(name, colours) !== "")
            return;
        root.failure = "";
        root.saving = Editor.slug(name);
        root.pending = colours;
        reader.running = true;
    }

    function settle(): void {
        const name = root.awaiting;
        root.awaiting = "";
        root.cancel();
        root.saving = "";
        root.saved(name);
    }

    function fail(message: string): void {
        root.failure = message;
        console.warn(`ThemeEditor: ${message}.`);
        root.saving = "";
        root.awaiting = "";
        root.pending = null;
    }

    Process {
        id: reader

        command: ["cat", root.sourcePath]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0 || !root.pending) {
                    root.fail("the current theme has no colours file to copy");
                    return;
                }
                writer.text = Editor.editedToml(text, root.pending);
                writer.running = true;
            }
        }
    }

    Process {
        id: writer

        property string text: ""

        command: ["sh", "-c", 'mkdir -p -- "$1" && cat > "$1/colors.toml"', "sh", `${Themes.themeRoot}/themes/${root.saving}`]
        stdinEnabled: true

        onStarted: {
            writer.write(writer.text);
            writer.stdinEnabled = false;
        }

        onExited: code => {
            writer.stdinEnabled = true;
            if (code !== 0) {
                root.fail("the new theme could not be written");
                return;
            }
            root.awaiting = root.saving;
            ThemeSwitcher.apply(root.saving, true);
            if (!ThemeSwitcher.switching)
                root.fail("themes cannot be switched right now");
        }
    }

    Connections {
        target: ThemeSwitcher

        function onFinished(name: string, ok: bool): void {
            if (name !== root.awaiting)
                return;
            if (!ok) {
                root.fail("theme-set could not use the new theme");
                return;
            }
            ThemeSwitcher.remember(name);
            if (Themes.activeName === name)
                root.settle();
        }
    }

    Connections {
        target: Themes

        function onActiveNameChanged(): void {
            if (root.awaiting !== "" && Themes.activeName === root.awaiting && !ThemeSwitcher.switching)
                root.settle();
        }
    }
}
