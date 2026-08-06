pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The wallpaper, and the list of wallpapers to choose from.
//
// The current one lives in config.json like every other setting, so it survives
// a restart and can be changed by `banditshell set wallpaper.current <path>`
// without a picker existing yet.
//
// The directory is listed by `find` rather than by a QML folder model because
// the list is wanted once, sorted, filtered to things Qt can actually decode,
// and a FolderListModel would have to be pumped into a plain array anyway.
//
// A WALLPAPER IS NOT ONLY A PICTURE. Three kinds live here, and the difference
// between them is which Qt element can draw the file rather than anything about
// what it looks like:
//
//   still     png, jpg, webp, bmp, avif, and SVG, which Image draws through
//             Qt's SVG plugin and which is a still like any other as long as it
//             is rasterised at the size it is drawn at
//   motion    gif and apng, which AnimatedImage draws and which can be paused
//   video     mp4, webm, mkv, mov, and the audio-only files that have no
//             picture in them at all, which QtMultimedia plays
//
// The kind is decided by EXTENSION rather than by asking the file, because the
// answer is needed before anything has been opened: it decides which element
// the surface builds, and building the wrong one first would mean a visible
// swap once the truth arrived. `find` already filters to this same set, so an
// extension that lies is a file the list never offered in the first place.
Singleton {
    id: root

    readonly property string dir: Config.values.wallpaper.dir.replace("~", Quickshell.env("HOME"))
    readonly property string current: Config.values.wallpaper.current.replace("~", Quickshell.env("HOME"))

    // WHAT EACH KIND IS MADE OF, as the one list everything else reads.
    //
    // The `find` filter, the classifier and the picker's labels all come from
    // here, so adding a format is one line rather than three places that have
    // to agree. Lower case; the match folds case at the point of use.
    readonly property var formats: ({
            still: ["png", "jpg", "jpeg", "webp", "bmp", "avif", "svg"],
            motion: ["gif", "apng"],
            video: ["mp4", "webm", "mkv", "mov", "m4v"],
            // AUDIO WITH NO PICTURE IN IT. Kept in the same family as video
            // because the same player plays it and the same surface holds it;
            // what is different is that there is nothing to see, so the surface
            // shows the black it would show for no wallpaper at all. A gimmick,
            // and it costs one line to let it be one.
            audio: ["mp3", "flac", "ogg", "opus", "wav", "m4a"]
        })

    readonly property var extensions: [...root.formats.still, ...root.formats.motion, ...root.formats.video, ...root.formats.audio]

    // "still" | "motion" | "video" | "audio" | "" for a path with no extension
    // this shell knows.
    function kindOf(path: string): string {
        const dot = path.lastIndexOf(".");
        if (dot < 0)
            return "";
        const ext = path.slice(dot + 1).toLowerCase();
        for (const kind in root.formats)
            if (root.formats[kind].indexOf(ext) >= 0)
                return kind;
        return "";
    }

    // Whether a path is a thing that moves, which is the question the playback
    // gate asks and the only one it asks: a still costs nothing to leave on
    // screen, so nothing has to be decided about it.
    function movesOf(path: string): bool {
        const k = root.kindOf(path);
        return k === "motion" || k === "video";
    }

    readonly property string kind: root.kindOf(root.current)
    readonly property bool moves: root.movesOf(root.current)

    // WHETHER IT IS SHOWN, which is a separate question from which one it is.
    //
    // Kept apart from `current` on purpose: clearing the path to hide the
    // picture would mean the shell has to guess one when you want it back, and
    // the guess is never the one you had. This says only "not right now", so
    // the choice survives being turned off. See config/Config.qml.
    readonly property bool enabled: Config.values.wallpaper.enabled

    // The name of the file, for the places that show which one it is. Empty
    // when nothing is set, rather than the "" a split would leave.
    readonly property string name: root.current.split("/").pop()

    // Absolute paths, sorted, of everything in `dir` we can show.
    property var available: []

    readonly property bool ready: current !== ""

    // WHAT IS ON THE SCREEN RIGHT NOW, which is not always what is in the
    // config. A picker scrubbing through the list puts each one on the actual
    // desktop as it passes, because a wallpaper is a thing you judge at full
    // size against your own windows and a thumbnail cannot stand in for that.
    // None of that is a decision until something is chosen, so it is kept here
    // rather than written: dismiss the picker and the setting was never touched.
    property string preview: ""

    readonly property string shown: root.preview || root.current
    readonly property string shownName: root.shown.split("/").pop()
    readonly property string shownKind: root.kindOf(root.shown)

    function set(path: string): void {
        root.preview = "";
        Config.set("wallpaper.current", path);
    }

    function setEnabled(on: bool): void {
        Config.set("wallpaper.enabled", on);
    }

    function toggle(): void {
        root.setEnabled(!root.enabled);
    }

    // Next/previous in the listing, wrapping. Enough to flick through them from
    // a keybind or the CLI without a picker.
    function step(delta: int): void {
        if (!root.available.length)
            return;
        const i = root.available.indexOf(root.current);
        // Not in the list (someone set a path elsewhere): start at the front.
        const next = i < 0 ? 0 : (i + delta + root.available.length) % root.available.length;
        root.set(root.available[next]);
    }

    function refresh(): void {
        lister.running = true;
    }

    Component.onCompleted: refresh()

    // Re-list when the directory setting changes, not on a timer: wallpapers do
    // not appear on their own.
    onDirChanged: refresh()

    Process {
        id: lister

        // The pattern is BUILT from `formats` rather than written out, so a
        // format added up there is offered down here without this line being
        // touched. `-iregex` matches the whole path, hence the leading `.*`.
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "-iregex", `.*\\.\\(${root.extensions.join("\\|")}\\)$`]

        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim().split("\n").filter(l => l).sort();
                if (!root.available.length)
                    console.warn(`Wallpaper: nothing usable in ${root.dir}`);
            }
        }
    }
}
