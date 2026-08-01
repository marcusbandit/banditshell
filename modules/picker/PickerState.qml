pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The screenshot picker's state, and the capture itself.
//
// FREEZE happens before the overlay is even shown. The point of freeze mode is
// to capture something that will not survive being interacted with: an open
// menu, a hover state, a tooltip. So the frame is grabbed the instant the picker
// is asked for, and the picker then draws over a still image. Grabbing when the
// selection is released would capture a screen the user has already changed by
// using the picker, which is the one thing freeze exists to prevent.
//
// LIVE mode hides the overlay and lets grim take the region straight from the
// compositor, which is exact and needs no cropping.
Scope {
    id: root

    property bool open: false
    property bool freeze: false
    property bool clipboardOnly: false

    // Where the frozen frame is, "" in live mode.
    property string frozenPath: ""

    // Set while the overlay is hidden for a live capture, so it cannot be seen
    // in its own screenshot.
    property bool hiding: false

    // True once a capture has taken ownership of the frozen frame. close() must
    // not delete a file that ffmpeg is still reading: capture() closes the picker
    // immediately, which raced the crop and left every freeze capture producing
    // nothing at all. Whoever consumes the file also removes it.
    property bool consumed: false

    readonly property string stamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd-hhmmss")

    function show(doFreeze: bool, clipOnly: bool): void {
        if (root.open)
            return;
        root.freeze = doFreeze;
        root.clipboardOnly = clipOnly;
        root.frozenPath = "";
        root.hiding = false;
        root.consumed = false;

        if (doFreeze)
            freezer.running = true;
        else
            root.open = true;
    }

    function close(): void {
        root.open = false;
        root.hiding = false;
        if (root.frozenPath && !root.consumed)
            cleanup.exec(["rm", "-f", root.frozenPath]);
        root.frozenPath = "";
    }

    function capture(screen: var, x: int, y: int, w: int, h: int): void {
        const out = `${Config.values.picker.dir.replace("~", Quickshell.env("HOME"))}/banditshell-${root.stamp}.png`;

        if (root.freeze) {
            // Crop the still we already have. The overlay can stay up: it is not
            // in the image, because the image was taken before it existed.
            //
            // The command removes the frozen frame itself, once it is done with
            // it. Handing that to close() deleted the file out from under ffmpeg.
            const frozen = root.frozenPath;
            root.consumed = true;
            crop.exec(["sh", "-c", `mkdir -p "$(dirname '${out}')" && ffmpeg -y -loglevel error -i '${frozen}' -vf "crop=${w}:${h}:${x + screen.x}:${y + screen.y}" '${out}' && ${root.deliver(out)}; rm -f '${frozen}'`]);
            root.close();
            return;
        }

        // Live: the overlay has to be off the screen before grim looks at it.
        // One frame is not enough on a compositor that batches, so this waits for
        // the surface to actually go away.
        root.hiding = true;
        liveDelay.pending = ["sh", "-c", `mkdir -p "$(dirname '${out}')" && grim -g '${x + screen.x},${y + screen.y} ${w}x${h}' '${out}' && ${root.deliver(out)}`];
        liveDelay.restart();
    }

    function deliver(path: string): string {
        if (root.clipboardOnly)
            return `wl-copy --type image/png < '${path}' && notify-send -a banditshell -i '${path}' 'Screenshot copied' '${path}'`;
        return `${Config.values.picker.editor} '${path}'`;
    }

    Process {
        id: cleanup
    }
    Process {
        id: crop
    }
    Process {
        id: live
    }

    Timer {
        id: liveDelay

        property var pending: null

        interval: Appearance.anim.fast
        onTriggered: {
            if (pending)
                live.exec(pending);
            pending = null;
            root.close();
        }
    }

    // Grab the whole screen first, then open over it.
    Process {
        id: freezer

        command: ["sh", "-c", `f=$(mktemp /tmp/banditshell-freeze-XXXXXX.png) && grim "$f" && echo "$f"`]

        stdout: StdioCollector {
            onStreamFinished: {
                root.frozenPath = text.trim();
                root.open = true;
            }
        }
    }
}
