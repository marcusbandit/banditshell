// Adapted from WallpaperFx.qml in pocket-dots by Diego Malagrida, GPL-3.0:
// https://github.com/diegoMalagrida/pocket-dots/blob/main/home/.config/quickshell/WallpaperFx.qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../../services/wallpaper-transition.js" as Transition

Item {
    id: root

    property int screenWidth: 0
    property int screenHeight: 0

    property string asked: ""
    property string kind: ""
    property string fieldPath: ""
    property string linePath: ""
    property color ember: root.lifted(Appearance.colour.accent)
    property color ink: "white"
    property bool failed: false
    property real t: 0

    readonly property bool outline: root.kind === "outline"
    readonly property bool loaded: root.kind !== "" && fieldImage.status === Image.Ready && lineImage.status === Image.Ready
    readonly property bool settled: root.loaded || root.failed
    readonly property bool running: run.running
    readonly property Image field: fieldImage
    readonly property Image line: lineImage

    signal finished

    function lifted(c: color): color {
        return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55), Math.min(Math.max(c.hslLightness, 0.62), 0.82), 1);
    }

    function request(path: string): void {
        root.release();
        if (!path)
            return;
        root.asked = path;
        const still = Wallpaper.kindOf(path) === "still";
        picker.exec(["python3", Quickshell.shellPath("scripts/wallpaper-transition.py"), "pick", still ? path : "-", String(root.screenWidth), String(root.screenHeight)]);
        watchdog.restart();
    }

    function release(): void {
        run.stop();
        watchdog.stop();
        root.asked = "";
        root.kind = "";
        root.fieldPath = "";
        root.linePath = "";
        root.failed = false;
        root.t = 0;
    }

    function play(): void {
        watchdog.stop();
        run.duration = root.outline ? 2000 : 1800;
        root.t = 0;
        run.restart();
    }

    function hear(text: string): void {
        const found = Transition.readPick(text, Wallpaper.kindOf(root.asked) === "still" ? root.asked : "-");
        if (!found)
            return;
        if (found.failed) {
            root.failed = true;
            return;
        }
        root.ember = found.ember || root.lifted(Appearance.colour.accent);
        root.ink = found.ink || "white";
        root.fieldPath = found.field;
        root.linePath = found.line;
        root.kind = found.kind;
    }

    Process {
        id: picker

        stdout: StdioCollector {
            onStreamFinished: root.hear(text)
        }
    }

    Timer {
        id: watchdog

        interval: 2500
        onTriggered: if (!root.loaded)
            root.failed = true
    }

    NumberAnimation {
        id: run

        target: root
        property: "t"
        from: 0
        to: 1
        easing.type: Easing.Linear
        onFinished: root.finished()
    }

    Image {
        id: fieldImage

        visible: false
        asynchronous: true
        cache: false
        smooth: root.outline
        source: root.fieldPath ? `file://${root.fieldPath}` : ""
    }

    Image {
        id: lineImage

        visible: false
        asynchronous: true
        cache: false
        source: root.linePath ? `file://${root.linePath}` : ""
    }
}
