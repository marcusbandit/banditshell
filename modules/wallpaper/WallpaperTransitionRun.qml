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
    property int tickets: 0
    property string ticket: ""
    property string kind: ""
    property string fieldPath: ""
    property string linePath: ""
    property color ember: Appearance.colour.accentBright
    property bool failed: false
    property real t: 0

    readonly property bool outline: root.kind === "outline"
    readonly property bool loaded: root.kind !== "" && fieldImage.status === Image.Ready && lineImage.status === Image.Ready
    readonly property bool settled: root.loaded || root.failed
    readonly property bool running: clock.running
    readonly property Image field: fieldImage
    readonly property Image line: lineImage

    signal finished

    function request(path: string): void {
        root.release();
        if (!path)
            return;
        root.asked = path;
        root.ticket = String(++root.tickets);
        const still = Wallpaper.kindOf(path) === "still";
        picker.exec(["python3", Quickshell.shellPath("scripts/wallpaper-transition.py"), "pick", still ? path : "-", String(root.screenWidth), String(root.screenHeight), root.ticket]);
        watchdog.restart();
    }

    function release(): void {
        clock.stop();
        watchdog.stop();
        root.asked = "";
        root.ticket = "";
        root.kind = "";
        root.fieldPath = "";
        root.linePath = "";
        root.failed = false;
        root.t = 0;
    }

    function play(): void {
        watchdog.stop();
        clock.duration = Math.max(1, Appearance.sizes.wallpaperReveal * (root.outline ? 20 / 9 : 2));
        root.t = 0;
        clock.restart();
    }

    function hear(text: string): void {
        const found = root.ticket ? Transition.readPick(text, root.ticket) : null;
        if (!found)
            return;
        if (found.failed) {
            root.failed = true;
            return;
        }
        root.ember = found.ember || Appearance.colour.accentBright;
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

    FrameAnimation {
        id: clock

        property real duration: 1800

        onTriggered: {
            root.t = Math.min(1, clock.elapsedTime * 1000 / clock.duration);
            if (root.t < 1)
                return;
            clock.stop();
            root.finished();
        }
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
