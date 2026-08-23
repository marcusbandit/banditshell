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
// ONE FRAME PER OUTPUT, because one frame per DESK is the wrong shape for what
// reads it. A bare `grim` writes the whole layout as a single image, and the
// overlay is one surface per screen; every surface then drew the entire layout,
// both monitors and all, squeezed across its own width. `grim -o <name>` asks
// each output the question the surface on it is going to ask, and the answers
// go into a map keyed by the output's own name so a surface can find the one
// that is about itself.
//
// LIVE mode hides the overlay and lets grim take the region straight from the
// compositor, which is exact and needs no cropping.
Scope {
    id: root

    property bool open: false
    property bool freeze: false
    property bool clipboardOnly: false

    // WHERE EACH SCREEN'S FROZEN FRAME IS, keyed by the screen's own name, and
    // empty in live mode. A missing key means that output has no frame rather
    // than an empty one, which is the honest state when grim could not read it.
    //
    // REASSIGNED rather than written into, the same rule
    // `services/Hypr.qml:204` keeps for its own per-monitor map: a `var`
    // property notifies on the object changing identity, not on a key landing
    // in the one it already holds, and every reader of this is a binding over
    // it.
    property var frozenByScreen: ({})

    // Set while the overlay is hidden for a live capture, so it cannot be seen
    // in its own screenshot.
    property bool hiding: false

    readonly property string stamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd-hhmmss")

    function show(doFreeze: bool, clipOnly: bool): void {
        if (root.open)
            return;
        root.freeze = doFreeze;
        root.clipboardOnly = clipOnly;
        root.frozenByScreen = ({});
        root.hiding = false;

        if (!doFreeze) {
            root.open = true;
            return;
        }

        // The names go to sh as ARGUMENTS rather than pasted into the script,
        // so an output is a string it is handed and never something it parses.
        const names = [];
        for (const s of Quickshell.screens)
            if (s.name)
                names.push(s.name);
        freezer.command = ["sh", "-c", `
            for n in "$@"; do
                f=$(mktemp /tmp/banditshell-freeze-XXXXXX.png) || continue
                grim -o "$n" "$f" && printf '%s\\t%s\\n' "$n" "$f" || rm -f "$f"
            done
        `, "sh", ...names];
        freezer.running = true;
    }

    function close(): void {
        root.open = false;
        root.hiding = false;
        // EVERY frame still here, which on a second monitor is the one nobody
        // ever looked at as well as the one that was cancelled. Deleting a
        // single path was right while there was a single path; now the map is
        // the list of what this still owns, and what it owns is what goes.
        const orphans = Object.values(root.frozenByScreen);
        if (orphans.length)
            cleanup.exec(["rm", "-f", ...orphans]);
        root.frozenByScreen = ({});
    }

    // ONE SCREEN'S FRAME, HANDED OVER. close() must not delete a file that
    // ffmpeg is still reading: capture() closes the picker immediately, which
    // raced the crop and left every freeze capture producing nothing at all.
    // Ownership used to be a single bool, which was enough while there was a
    // single file; with a frame per output the question stopped being WHETHER
    // one had been taken and became WHICH. So taking a frame removes it from
    // the map, close() goes on meaning "delete everything still in here", and
    // whoever took it removes it when it is done with it.
    function take(name: string): string {
        const path = root.frozenByScreen[name] ?? "";
        const rest = Object.assign({}, root.frozenByScreen);
        delete rest[name];
        root.frozenByScreen = rest;
        return path;
    }

    function capture(screen: var, x: int, y: int, w: int, h: int): void {
        const out = `${Config.values.picker.dir.replace("~", Quickshell.env("HOME"))}/banditshell-${root.stamp}.png`;

        if (root.freeze) {
            // Crop the still we already have for THIS screen. The overlay can
            // stay up: it is not in the image, because the image was taken
            // before it existed.
            //
            // The crop is measured from the frame's own top-left, with no
            // layout offset added. The selection's coordinates are relative to
            // the screen it was dragged on, and the frame is now that screen's
            // alone, so the two already agree. Adding `screen.x` was right
            // only while one image held every monitor, because a position in
            // the layout is not a place in a file that holds one output. The
            // SIZE of a pixel is a separate question, answered just below.
            //
            // The command removes the frame itself, once it is done with it.
            // Handing that to close() deleted the file out from under ffmpeg.
            const frozen = root.take(screen.name);
            // No frame for this screen: grim could not read that output. There
            // is nothing to crop, so this cancels rather than pointing ffmpeg
            // at a path that was never written.
            if (!frozen)
                return root.close();

            // THE FRAME IS COUNTED IN PIXELS AND THE SELECTION IN POINTS.
            //
            // grim writes the output's own buffer, which is its logical size
            // multiplied by its scale, while the selection was dragged on a
            // layer surface measured in logical pixels. On a scaled monitor
            // those are two different numbers for the same edge, so the crop
            // goes through the ratio rather than being taken as dragged. At
            // scale 1.0 this multiplies by one and reads exactly as it did,
            // which is why the whole class of bug stayed invisible.
            const dpr = screen.devicePixelRatio;
            const cw = Math.round(w * dpr);
            const ch = Math.round(h * dpr);
            const cx = Math.round(x * dpr);
            const cy = Math.round(y * dpr);

            crop.exec(["sh", "-c", `mkdir -p "$(dirname '${out}')" && ffmpeg -y -loglevel error -i '${frozen}' -vf "crop=${cw}:${ch}:${cx}:${cy}" '${out}' && ${root.deliver(out)}; rm -f '${frozen}'`]);
            root.close();
            return;
        }

        // Live: the overlay has to be off the screen before grim looks at it.
        // One frame is not enough on a compositor that batches, so this waits for
        // the surface to actually go away.
        //
        // The offsets stay HERE. grim takes this region from the compositor,
        // which answers in layout coordinates, so a region on the second
        // monitor is only findable by where that monitor sits.
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

    // Grab every output first, then open over them. The loop finishing is what
    // "all of them have landed" means here: sh exits when the last grim has
    // written its file, so the picker opens on a complete set without a counter
    // that could fall out of step with how many monitors there are.
    //
    // Each line is a name and the path that holds it. An output that could not
    // be read prints nothing and takes its temp file with it, so a name is in
    // the map only when there is a real frame behind it.
    Process {
        id: freezer

        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.trim().split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0)
                        next[line.slice(0, tab)] = line.slice(tab + 1);
                }
                root.frozenByScreen = next;
                root.open = true;
            }
        }
    }
}
