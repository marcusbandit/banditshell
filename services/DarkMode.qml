pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "dark-mode.js" as Schemes

Singleton {
    id: root

    property string scheme: ""

    property string lightScheme: "default"

    property string wanted: ""

    property string sending: ""

    property string before: ""

    readonly property bool available: root.scheme !== ""

    readonly property bool dark: root.scheme === "prefer-dark"

    readonly property string mode: Appearance.mode

    readonly property bool wantsDark: !Appearance.light

    readonly property bool settled: Config.loaded && root.available

    readonly property bool appsDisagree: root.available && root.dark !== root.wantsDark

    property bool scheduled: false

    property bool night: true

    property double nextFlip: 0

    function take(text: string): void {
        const next = Schemes.parse(text);
        if (!next)
            return;
        root.scheme = next;
        root.lightScheme = Schemes.lightAfter(root.lightScheme, next);
    }

    function choose(next: string): void {
        if (next === root.mode)
            return root.set(root.wantsDark);
        Config.set("colour.mode", next);
    }

    function set(on: bool): void {
        const next = Schemes.schemeFor(on, root.lightScheme);
        root.wanted = next;
        if (writer.running)
            return;
        root.write();
    }

    function write(): void {
        root.wanted = Schemes.pending(root.wanted, root.scheme);
        if (root.wanted === "")
            return;
        root.sending = root.wanted;
        root.before = root.scheme;
        root.scheme = root.sending;
        writer.exec(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", root.sending]);
    }

    function written(code: int): void {
        const after = Schemes.settle(code, root.sending, root.before, root.wanted);
        root.scheme = after.scheme;
        root.wanted = after.wanted;
        if (code !== 0)
            console.warn(`DarkMode: gsettings could not set color-scheme to ${root.sending} (exit ${code}), so apps keep ${root.scheme}`);
        root.sending = "";
        reader.running = true;
        root.write();
    }

    function evaluate(): void {
        const now = Date.now();
        const at = Display.nightAt(now);
        root.scheduled = at.known;
        root.night = at.night;
        root.nextFlip = at.next;
        Appearance.daylight = !at.night;
        if (root.mode !== "auto")
            return flip.stop();
        flip.interval = Math.max(1000, Math.min(60000, at.next > now ? at.next - now + 500 : 60000));
        flip.restart();
    }

    onWantsDarkChanged: {
        if (root.settled)
            root.set(root.wantsDark);
    }

    onSettledChanged: {
        if (root.settled && root.mode === "auto")
            root.set(root.wantsDark);
    }

    onModeChanged: root.evaluate()

    Component.onCompleted: root.evaluate()

    Connections {
        target: Display

        function onWarmWindowChanged(): void {
            if (root.mode === "auto")
                root.evaluate();
        }

        function onScheduleModeChanged(): void {
            root.evaluate();
        }
    }

    Timer {
        id: flip

        onTriggered: root.evaluate()
    }

    Process {
        id: writer

        onExited: (code, status) => root.written(code)
    }

    Process {
        id: reader

        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }

    Process {
        running: root.available
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
    }
}
