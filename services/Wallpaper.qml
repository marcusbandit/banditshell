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
Singleton {
    id: root

    readonly property string dir: Config.values.wallpaper.dir.replace("~", Quickshell.env("HOME"))
    readonly property string current: Config.values.wallpaper.current.replace("~", Quickshell.env("HOME"))

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

    function set(path: string): void {
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

        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "-iregex", ".*\\.\\(png\\|jpe?g\\|webp\\|bmp\\)$"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim().split("\n").filter(l => l).sort();
                if (!root.available.length)
                    console.warn(`Wallpaper: nothing usable in ${root.dir}`);
            }
        }
    }
}
