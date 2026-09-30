pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    function expand(path: string): string {
        return path ? path.replace(/^~(?=\/|$)/, Quickshell.env("HOME")) : "";
    }

    readonly property string dir: root.expand(Config.values.wallpaper.dir)

    property var aliases: ({})

    function normalise(path: string): string {
        if (!path || root.available.indexOf(path) >= 0)
            return path;
        return root.aliases[path] ?? path;
    }

    readonly property string current: root.normalise(root.expand(Config.values.wallpaper.current))

    readonly property var perScreen: Config.values.wallpaper.perScreen ?? ({})

    function hasOwn(screen: string): bool {
        return !!(screen && root.perScreen[screen]);
    }

    function currentOn(screen: string): string {
        return root.normalise(root.expand(root.perScreen[screen] ?? "")) || root.current;
    }

    readonly property var formats: ({
            still: ["png", "jpg", "jpeg", "webp", "bmp", "avif", "svg"],
            motion: ["gif", "apng"],
            video: ["mp4", "webm", "mkv", "mov", "m4v"],

            audio: ["mp3", "flac", "ogg", "opus", "wav", "m4a"]
        })

    readonly property var extensions: [...root.formats.still, ...root.formats.motion, ...root.formats.video, ...root.formats.audio]

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

    function movesOf(path: string): bool {
        const k = root.kindOf(path);
        return k === "motion" || k === "video";
    }

    readonly property string here: Hypr.focusedScreen

    readonly property string kind: root.kindOf(root.currentOn(root.here))
    readonly property bool moves: root.movesOf(root.currentOn(root.here))

    property var frozen: ({})

    function isFrozen(path: string): bool {
        return root.frozen[path] === true;
    }

    function findFrozen(): void {
        const svgs = root.available.filter(p => p.toLowerCase().endsWith(".svg"));
        if (!svgs.length) {
            root.frozen = {};
            return;
        }

        freezer.command = ["grep", "-l", "-E", "-e", "<animate", "-e", "@keyframes", "-e", "animation *:", ...svgs];
        freezer.running = true;
    }

    Process {
        id: freezer

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.trim().split("\n"))
                    if (line)
                        out[line] = true;
                root.frozen = out;
            }
        }
    }

    property var shapes: ({})

    function aspectOf(path: string): real {
        return root.shapes[path] ?? 0;
    }

    function fits(path: string, screenAspect: real): bool {
        const a = root.aspectOf(path);
        if (!a || !screenAspect)
            return true;
        return Math.abs(Math.log(a / screenAspect)) <= Math.log(Config.values.wallpaper.fit);
    }

    function fittedFor(screenAspect: real): var {
        return root.available.filter(p => root.fits(p, screenAspect));
    }

    function screenAspect(screen: string): real {
        const s = Quickshell.screens.find(m => m.name === screen);
        return s && s.height > 0 ? s.width / s.height : 0;
    }

    function measureShapes(): void {
        if (!root.available.length) {
            root.shapes = {};
            return;
        }

        const known = {};
        for (const p of root.available)
            if (root.shapes[p] !== undefined)
                known[p] = root.shapes[p];

        const fresh = root.available.filter(p => root.shapes[p] === undefined);

        if (!fresh.length) {

            if (Object.keys(known).length !== Object.keys(root.shapes).length)
                root.shapes = known;
            return;
        }

        if (shaper.running)
            return;

        shaper.known = known;
        shaper.command = ["sh", "-c", `for f in "$@"; do
  s=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$f" </dev/null 2>/dev/null)
  case "$s" in
    [0-9]*,[0-9]*) printf '%s\\t%s\\n' "$f" "$s" ;;
  esac
done`, "sh", ...fresh];
        shaper.running = true;
    }

    Process {
        id: shaper

        property var known: ({})

        stdout: StdioCollector {
            onStreamFinished: {
                const out = Object.assign({}, shaper.known);
                for (const line of text.trim().split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const wh = line.slice(tab + 1).split(",");
                    const w = parseInt(wh[0], 10);
                    const h = parseInt(wh[1], 10);
                    if (w > 0 && h > 0)
                        out[line.slice(0, tab)] = w / h;
                }
                root.shapes = out;
            }
        }
    }

    readonly property bool enabled: Config.values.wallpaper.enabled

    function nameOf(path: string): string {
        return path.split("/").pop();
    }

    readonly property string name: root.nameOf(root.currentOn(root.here))

    property var available: []

    readonly property bool ready: current !== ""

    property var previews: ({})

    function previewOn(screen: string): string {
        return root.previews[screen] ?? "";
    }

    function setPreview(screen: string, path: string): void {
        if (!screen || root.previews[screen] === path)
            return;
        const next = Object.assign({}, root.previews);
        next[screen] = path;
        root.previews = next;
    }

    function clearPreview(screen: string): void {
        if (!screen || !(screen in root.previews))
            return;
        const next = Object.assign({}, root.previews);
        delete next[screen];
        root.previews = next;
    }

    function shownOn(screen: string): string {
        return root.previewOn(screen) || root.currentOn(screen);
    }

    function shownNameOn(screen: string): string {
        return root.nameOf(root.shownOn(screen));
    }

    readonly property string shown: root.shownOn(root.here)
    readonly property string shownName: root.nameOf(root.shown)
    readonly property string shownKind: root.kindOf(root.shown)

    property var origins: ({})

    readonly property point centre: Qt.point(0.5, 0.5)

    function originOn(screen: string): point {
        return root.origins[screen] ?? root.centre;
    }

    function setOrigin(screen: string, x: real, y: real): void {
        const next = Object.assign({}, root.origins);
        next[screen] = Qt.point(x, y);
        root.origins = next;
    }

    function setOn(screen: string, path: string): void {

        const name = root.normalise(path);

        if (!screen) {
            root.setAll(name);
            return;
        }

        if (root.hasOwn(screen) || name !== root.current) {
            const next = Object.assign({}, Config.values.wallpaper.perScreen ?? {});
            next[screen] = name;
            Config.set("wallpaper.perScreen", next);
        }

        root.clearPreview(screen);
    }

    function setAll(path: string): void {

        Config.setMany([["wallpaper.perScreen", {}], ["wallpaper.current", root.normalise(path)]]);
        root.previews = {};
    }

    function clearOn(screen: string): void {
        if (!root.hasOwn(screen))
            return;
        root.clearPreview(screen);
        const next = Object.assign({}, Config.values.wallpaper.perScreen);
        delete next[screen];
        Config.set("wallpaper.perScreen", next);
    }

    function set(path: string): void {
        root.setAll(path);
    }

    function setFrom(screen: string, path: string, x: real, y: real): void {
        root.setOrigin(screen, x, y);
        root.setOn(screen, path);
    }

    function setFromAll(path: string, x: real, y: real): void {
        const at = {};
        for (const s of Quickshell.screens)
            at[s.name] = Qt.point(x, y);
        root.origins = at;
        root.setAll(path);
    }

    function setEnabled(on: bool): void {
        Config.set("wallpaper.enabled", on);
    }

    function toggle(): void {
        root.setEnabled(!root.enabled);
    }

    function stepOn(screen: string, delta: int): void {
        if (!root.available.length)
            return;
        root.setOrigin(screen, delta > 0 ? 1 : 0, 0.5);
        const i = root.available.indexOf(root.currentOn(screen));

        const next = i < 0 ? 0 : (i + delta + root.available.length) % root.available.length;
        root.setOn(screen, root.available[next]);
    }

    function step(delta: int): void {
        root.stepOn(root.here, delta);
    }

    function stepAll(delta: int): void {
        if (!root.available.length)
            return;

        const edge = {};
        for (const s of Quickshell.screens)
            edge[s.name] = Qt.point(delta > 0 ? 1 : 0, 0.5);
        root.origins = edge;
        const i = root.available.indexOf(root.current);
        const next = i < 0 ? 0 : (i + delta + root.available.length) % root.available.length;
        root.setAll(root.available[next]);
    }

    property var posters: ({})

    function poster(path: string): string {
        return root.posters[path] ?? "";
    }

    function faceOf(path: string): string {
        const k = root.kindOf(path);
        if (k === "audio")
            return "";
        return k === "video" ? root.poster(path) : path;
    }

    readonly property string posterDir: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/banditshell/posters`

    function makePosters(): void {
        const videos = root.available.filter(p => root.kindOf(p) === "video");
        if (!videos.length) {
            root.posters = {};
            return;
        }
        posterer.command = ["sh", "-c", `mkdir -p "$0" || exit 0
for f in "$@"; do
  h=$(printf %s "$f" | md5sum | cut -d" " -f1)
  out="$0/$h.jpg"
  [ -f "$out" ] || ffmpeg -v error -y -ss 0 -i "$f" -frames:v 1 -vf scale=640:-2 "$out" </dev/null >/dev/null 2>&1
  [ -f "$out" ] && printf '%s\\t%s\\n' "$f" "$out"
done`, root.posterDir, ...videos];
        posterer.running = true;
    }

    Process {
        id: posterer

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.trim().split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0)
                        out[line.slice(0, tab)] = line.slice(tab + 1);
                }
                root.posters = out;
            }
        }
    }

    property var palette: []

    readonly property color dominant: root.palette.length ? root.palette[0].colour : "transparent"

    function measure(): void {
        const face = root.faceOf(root.currentOn(root.here));
        if (!face) {
            root.palette = [];
            return;
        }

        paletter.command = ["python3", Quickshell.shellPath("scripts/palette.py"), face];
        paletter.running = true;
    }

    onCurrentChanged: settle.restart()
    onPerScreenChanged: settle.restart()
    onHereChanged: settle.restart()
    onPostersChanged: settle.restart()

    Timer {
        id: settle

        interval: 250
        onTriggered: root.measure()
    }

    Process {
        id: paletter

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    const bits = line.trim().split(/\s+/);
                    if (bits.length === 2 && bits[0].startsWith("#"))
                        out.push({
                            colour: bits[0],
                            share: parseFloat(bits[1])
                        });
                }
                root.palette = out;
            }
        }
    }

    function refresh(): void {

        if (!root.dir)
            return;

        const cmd = ["sh", "-c", `exec find -L "$1" -type f -iregex "$2" -printf '%D:%i\\t%p\\n'`, "sh", root.dir, `.*\\.\\(${root.extensions.join("\\|")}\\)$`];

        if (lister.running) {
            if (JSON.stringify(lister.command) === JSON.stringify(cmd))
                return;
            lister.running = false;
        }

        lister.command = cmd;
        lister.running = true;
    }

    Component.onCompleted: refresh()

    onDirChanged: refresh()

    Process {
        id: lister

        stdout: StdioCollector {
            onStreamFinished: {

                const byFile = {};
                for (const line of text.trim().split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const key = line.slice(0, tab);
                    const path = line.slice(tab + 1);
                    if (byFile[key] === undefined || path < byFile[key])
                        byFile[key] = path;
                }
                root.available = Object.keys(byFile).map(k => byFile[k]).sort();
                if (!root.available.length)
                    console.warn(`Wallpaper: nothing usable in ${root.dir}`);
                root.makePosters();
                root.findFrozen();
                root.measureShapes();
                root.reconcile();
            }
        }
    }

    property var asked: ({})

    function reconcile(): void {

        if (!root.available.length || resolver.running)
            return;

        const per = Config.values.wallpaper.perScreen ?? {};
        const wanted = [root.expand(Config.values.wallpaper.current), ...Object.keys(per).map(s => root.expand(per[s]))];

        const strange = [];
        for (const p of wanted)
            if (p && root.available.indexOf(p) < 0 && !root.aliases[p] && !root.asked[p] && strange.indexOf(p) < 0)
                strange.push(p);
        if (!strange.length)
            return;

        const seen = Object.assign({}, root.asked);
        for (const p of strange)
            seen[p] = true;
        root.asked = seen;

        resolver.strange = strange;
        resolver.listed = root.available;
        resolver.command = ["realpath", "-m", "--", ...strange, ...root.available];
        resolver.running = true;
    }

    Connections {
        target: Config

        function onValuesChanged(): void {
            root.reconcile();
        }
    }

    Process {
        id: resolver

        property var strange: []
        property var listed: []

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const n = resolver.strange.length;
                if (lines.length !== n + resolver.listed.length) {
                    console.warn(`Wallpaper: could not match ${n} configured wallpaper(s) against ${root.dir}`);
                    return;
                }

                const home = {};
                for (let i = 0; i < resolver.listed.length; i++)
                    home[lines[n + i]] = resolver.listed[i];

                const map = Object.assign({}, root.aliases);
                for (let i = 0; i < n; i++)
                    if (home[lines[i]])
                        map[resolver.strange[i]] = home[lines[i]];
                root.aliases = map;

                const pairs = [];
                const fixed = map[root.expand(Config.values.wallpaper.current)];
                if (fixed)
                    pairs.push(["wallpaper.current", fixed]);

                const per = Config.values.wallpaper.perScreen ?? {};
                const next = Object.assign({}, per);
                let moved = false;
                for (const screen in per) {
                    const own = map[root.expand(per[screen])];
                    if (own) {
                        next[screen] = own;
                        moved = true;
                    }
                }
                if (moved)
                    pairs.push(["wallpaper.perScreen", next]);

                if (pairs.length)
                    Config.setMany(pairs);
            }
        }
    }
}
