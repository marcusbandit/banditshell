pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "wallpaper-library.js" as Library

Singleton {
    id: root

    readonly property string shipped: Quickshell.shellPath("assets/wallpapers/")

    function expand(path: string): string {
        if (path && path.startsWith("shipped:"))
            return `${root.shipped}${path.slice("shipped:".length)}`;
        return path ? path.replace(/^~(?=\/|$)/, Quickshell.env("HOME")) : "";
    }

    function stored(path: string): string {
        return path.startsWith(root.shipped) ? `shipped:${path.slice(root.shipped.length)}` : path;
    }

    readonly property string dir: root.expand(Config.values.wallpaper.dir)

    property var aliases: ({})

    function normalise(path: string): string {
        if (!path || root.available.indexOf(path) >= 0)
            return path;
        return root.aliases[path] ?? path;
    }

    readonly property string fallback: `${root.shipped}moonrise.png`

    readonly property string configured: Config.loaded ? root.normalise(root.expand(Config.values.wallpaper.current)) : ""

    property string verified: ""
    property string missing: ""

    readonly property string current: {
        if (!Config.loaded)
            return "";
        const want = root.configured;
        if (!want || want === root.missing)
            return root.fallback;
        return want === root.verified || root.available.indexOf(want) >= 0 ? want : "";
    }

    onConfiguredChanged: root.verify()

    function verify(): void {
        const want = root.configured;
        if (!want || prober.running || want === root.verified || want === root.missing || root.available.indexOf(want) >= 0)
            return;
        prober.path = want;
        prober.exec(["test", "-e", want]);
    }

    Process {
        id: prober

        property string path: ""

        onExited: code => {
            if (code === 0)
                root.verified = prober.path;
            else
                root.missing = prober.path;
            if (prober.path !== root.configured)
                root.verify();
        }
    }

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

    property var shapes: ({})

    function aspectOf(path: string): real {
        const shape = root.shapes[path];
        return shape ? shape.width / shape.height : 0;
    }

    function sizeOf(path: string): size {
        return root.shapes[path] ?? Qt.size(0, 0);
    }

    property var colours: ({})

    readonly property string coloursCache: `${Config.cacheDir}/wallpaper-colours.json`

    function coloursOf(path: string): var {
        return root.colours[path] ?? [];
    }

    function measureColours(): void {
        if (!root.available.length)
            return;
        if (colourer.running) {
            colourer.again = true;
            return;
        }
        colourer.command = ["python3", Quickshell.shellPath("scripts/wallpaper-colours.py"), root.coloursCache, ...root.available];
        colourer.running = true;
    }

    Process {
        id: colourer

        property bool again: false

        onExited: if (colourer.again) {
            colourer.again = false;
            root.measureColours();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.trim().split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const groups = line.slice(tab + 1).trim();
                    out[line.slice(0, tab)] = groups ? groups.split(" ") : [];
                }
                root.colours = out;
            }
        }
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

    readonly property bool enabled: Config.values.wallpaper.enabled

    function nameOf(path: string): string {
        return path.split("/").pop();
    }

    readonly property string name: root.nameOf(root.currentOn(root.here))

    property var available: []

    property var previews: ({})
    property var previewOrigins: ({})

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

    function previewFrom(screen: string, path: string, x: real, y: real): void {
        if (!screen)
            return;
        const at = Object.assign({}, root.previewOrigins);
        at[screen] = Qt.point(x, y);
        root.previewOrigins = at;
        root.setPreview(screen, path);
    }

    function clearPreview(screen: string): void {
        if (!screen || !(screen in root.previews))
            return;
        const at = Object.assign({}, root.previewOrigins);
        delete at[screen];
        root.previewOrigins = at;
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

    property var origins: ({})

    readonly property point centre: Qt.point(0.5, 0.5)

    function originOn(screen: string): point {
        return root.previewOrigins[screen] ?? root.origins[screen] ?? root.centre;
    }

    function edgeTowards(delta: int): point {
        return delta > 0 ? Qt.point(1, 0.5) : delta < 0 ? Qt.point(0, 0.5) : root.centre;
    }

    function setOrigin(screen: string, x: real, y: real): void {
        const next = Object.assign({}, root.origins);
        next[screen] = Qt.point(x, y);
        root.origins = next;
    }

    signal replayRequested(screen: string)

    function replayOn(screen: string, x: real, y: real): void {
        root.setOrigin(screen, x, y);
        root.replayRequested(screen);
    }

    function setOn(screen: string, path: string): void {

        const name = root.normalise(path);

        if (!screen) {
            root.setAll(name);
            return;
        }

        if (root.hasOwn(screen) || name !== root.current) {
            const next = Object.assign({}, Config.values.wallpaper.perScreen ?? {});
            next[screen] = root.stored(name);
            Config.set("wallpaper.perScreen", next);
        }

        root.clearPreview(screen);
    }

    function setAll(path: string): void {

        Config.setMany([["wallpaper.perScreen", {}], ["wallpaper.current", root.stored(root.normalise(path))]]);
        root.previewOrigins = {};
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
        const edge = root.edgeTowards(delta);
        root.setOrigin(screen, edge.x, edge.y);
        const i = root.available.indexOf(root.currentOn(screen));

        const next = i < 0 ? 0 : (i + delta + root.available.length) % root.available.length;
        root.setOn(screen, root.available[next]);
    }

    function stepAll(delta: int): void {
        if (!root.available.length)
            return;

        const edge = {};
        for (const s of Quickshell.screens)
            edge[s.name] = root.edgeTowards(delta);
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

    readonly property string posterDir: `${Config.cacheDir}/posters`

    property var palette: []

    readonly property bool wantsPalette: Config.values.themeFromWallpaper

    function measure(): void {
        const face = root.wantsPalette ? root.faceOf(root.currentOn(root.here)) : "";
        if (!face) {
            root.palette = [];
            return;
        }

        paletter.command = ["python3", Quickshell.shellPath("scripts/palette.py"), face];
        paletter.running = true;
    }

    onWantsPaletteChanged: settle.restart()
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

    readonly property string libraryCache: `${Config.cacheDir}/wallpaper-library.json`

    function refresh(): void {
        if (!Config.loaded || !root.dir)
            return;

        const cmd = ["python3", Quickshell.shellPath("scripts/wallpaper-library.py"), root.libraryCache, root.posterDir, root.dir, root.extensions.join(","), root.formats.video.join(","), root.fallback];

        if (lister.running) {
            if (JSON.stringify(lister.command) === JSON.stringify(cmd))
                return;
            lister.running = false;
        }

        lister.listening = false;
        lister.found = [];
        lister.shapes = {};
        lister.posters = {};
        lister.frozen = {};
        lister.command = cmd;
        lister.running = true;
    }

    Component.onCompleted: refresh()

    onDirChanged: refresh()

    Connections {
        target: Config

        function onLoadedChanged(): void {
            root.refresh();
        }
    }

    function hear(line: string): void {
        const heard = Library.read(line);
        if (!heard)
            return;
        if (heard.kind === "begin") {
            lister.listening = heard.path === lister.command[4];
            return;
        }
        if (!lister.listening)
            return;
        if (heard.kind === "file") {
            lister.found.push(heard.path);
        } else if (heard.kind === "listed") {
            root.list(lister.found, heard.changed);
            lister.found = [];
        } else if (heard.kind === "shape") {
            lister.shapes[heard.path] = heard.width > 0 ? Qt.size(heard.width, heard.height) : null;
            publish.start();
        } else if (heard.kind === "poster") {
            lister.posters[heard.path] = heard.poster || null;
            publish.start();
        } else if (heard.kind === "frozen") {
            lister.frozen[heard.path] = heard.frozen || null;
            publish.start();
        } else if (heard.kind === "done") {
            root.publishMeasures();
        }
    }

    function list(found: var, changed: bool): void {
        const scanned = found.filter(p => p !== root.fallback);
        if (!scanned.length)
            console.info(`Wallpaper: nothing usable in ${root.dir}, so only the shipped picture is offered`);
        const next = [...scanned, root.fallback];
        if (JSON.stringify(next) !== JSON.stringify(root.available))
            root.available = next;
        root.measured(Library.kept(root.shapes, next), Library.kept(root.posters, next), Library.kept(root.frozen, next));
        if (changed || !Object.keys(root.colours).length)
            root.measureColours();
        root.reconcile();
    }

    function measured(shapes: var, posters: var, frozen: var): void {
        if (shapes !== root.shapes)
            root.shapes = shapes;
        if (posters !== root.posters)
            root.posters = posters;
        if (frozen !== root.frozen)
            root.frozen = frozen;
    }

    function publishMeasures(): void {
        publish.stop();
        root.measured(Library.merged(root.shapes, lister.shapes), Library.merged(root.posters, lister.posters), Library.merged(root.frozen, lister.frozen));
        lister.shapes = {};
        lister.posters = {};
        lister.frozen = {};
    }

    Timer {
        id: publish

        interval: 200
        onTriggered: root.publishMeasures()
    }

    Process {
        id: lister

        property bool listening: false
        property var found: []
        property var shapes: ({})
        property var posters: ({})
        property var frozen: ({})

        stdout: SplitParser {
            onRead: line => root.hear(line)
        }

        onExited: root.publishMeasures()
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
        target: Config.values

        function onWallpaperChanged(): void {
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
