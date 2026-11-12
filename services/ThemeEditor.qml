pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "theme-editor.js" as Editor

Singleton {
    id: root

    property string saving: ""
    property var pending: null
    property string failure: ""

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
        if (Themes.parsed)
            Themes.previewing = Editor.previewFrom(Themes.parsed, colours);
    }

    function cancel(): void {
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

    Process {
        id: reader

        command: ["cat", root.sourcePath]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0 || !root.pending) {
                    root.finish("the current theme has no colours file to copy");
                    return;
                }
                writer.text = Editor.editedToml(text, root.pending);
                writer.running = true;
            }
        }

        onExited: code => {
            if (code !== 0)
                root.finish("the current theme has no colours file to copy");
        }
    }

    Process {
        id: writer

        property string text: ""

        command: ["sh", "-c", 'mkdir -p -- "$1" && cat > "$1/colors.toml" && theme-set "$2"', "sh", `${Themes.themeRoot}/themes/${root.saving}`, root.saving]
        stdinEnabled: true

        onStarted: {
            writer.write(writer.text);
            writer.stdinEnabled = false;
        }

        onExited: code => {
            writer.stdinEnabled = true;
            root.finish(code === 0 ? "" : "theme-set could not use the new theme");
        }
    }

    function finish(failure: string): void {
        root.failure = failure;
        if (failure !== "")
            console.warn(`ThemeEditor: ${failure}.`);
        if (failure === "")
            Themes.previewing = null;
        root.saving = "";
        root.pending = null;
    }
}
