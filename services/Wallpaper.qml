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
// ONE WALLPAPER PER SCREEN, and the shape of that is a DEFAULT plus a map of
// disagreements rather than a wallpaper per output.
//
//   wallpaper.current    what a screen wears when nothing says otherwise
//   wallpaper.perScreen  { "DP-1": path } for the screens that say otherwise
//
// So the answer to "what is on that monitor" is a function of a screen name and
// never a property, and every property in here that used to BE that answer is
// now the focused screen's copy of it, kept for the CLI and the settings row
// that ask about "the wallpaper" and mean the one you are looking at.
//
// WHY NOT A PATH PER OUTPUT. Because most of the screens on most machines want
// the same picture, and a map with an entry per monitor has to be edited once
// per monitor every time that picture changes: the second screen would quietly
// keep last month's wallpaper because nothing told it. A default that screens
// fall back to means "all of them" stays one write, and a screen that wants its
// own says so by having an entry. It also gives an unplugged-then-replugged
// monitor and a brand new one two different right answers with no code: the
// first has an entry and gets it back, the second has none and joins the rest.
//
// NOTHING IN HERE KNOWS HOW BIG A SCREEN IS, deliberately. A wallpaper is a
// file and a screen is a rectangle, and every question about how the one meets
// the other (a portrait monitor, a phone, a 32:9 panel, a rotation) is answered
// where the picture is actually drawn: components/WallpaperSource decodes at the
// surface's own pixels and covers it, and modules/wallpaper/WallpaperPicker
// draws its cards in the shape of the screen it is on. That keeps this file
// correct for a setup it has never heard of, which is the only way to be
// correct for ten monitors at ten aspect ratios.
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

    // `~` is expanded ONCE, here, and every path that leaves this file has been
    // through it. A tilde reaches config.json because a human typed it there,
    // and an Image handed `~/Pictures/x.png` fails to load with no message at
    // all, which is a black desktop and nothing to read about why.
    function expand(path: string): string {
        return path ? path.replace("~", Quickshell.env("HOME")) : "";
    }

    readonly property string dir: root.expand(Config.values.wallpaper.dir)

    // THE DEFAULT, which is what "the wallpaper" used to mean and still does on
    // a machine with one screen or with every screen agreeing. See the note at
    // the top: a screen with no entry of its own wears this.
    readonly property string current: root.expand(Config.values.wallpaper.current)

    // WHICH SCREENS DISAGREE, by output name. Raw off the config, so the values
    // may still hold a tilde; `currentOn` is the reader and it expands.
    readonly property var perScreen: Config.values.wallpaper.perScreen ?? ({})

    // Whether a screen has been given a wallpaper of its own, which is a
    // different question from what it is showing: a screen following the
    // default is showing something and owns nothing.
    function hasOwn(screen: string): bool {
        return !!(screen && root.perScreen[screen]);
    }

    // WHAT THAT SCREEN IS SET TO. The whole per-screen model is this one
    // function; everything else is a caller of it.
    //
    // An empty screen name answers with the default rather than with nothing,
    // because the callers that have no screen (a preview window, a harness, the
    // moment before the compositor has named the focused output) are asking
    // what a wallpaper IS, not what a particular monitor has.
    function currentOn(screen: string): string {
        return root.expand(root.perScreen[screen] ?? "") || root.current;
    }

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

    // THE SCREEN A QUESTION WITHOUT A SCREEN IS ABOUT: the focused one.
    //
    // services/Shell.qml's `forScreen("")` makes exactly this argument for the
    // twenty IPC verbs that go through it. `banditshell wallpaper next` and the
    // settings row that says which wallpaper you have are the same shape of
    // caller: they arrive with no screen and they mean the one in front of you.
    readonly property string here: Hypr.focusedScreen

    readonly property string kind: root.kindOf(root.currentOn(root.here))
    readonly property bool moves: root.movesOf(root.currentOn(root.here))

    // SVGs THAT WANT TO MOVE AND CANNOT, by path.
    //
    // An SVG can animate two ways, SMIL's `<animate>` elements and CSS
    // keyframes, and this shell draws neither: Qt's SVG renderer supports no
    // animation at all, and QQuickImage rasterises an SVG once and never asks
    // it again. So an animated SVG is a wallpaper of its first frame.
    //
    // That is a perfectly defensible limit and a terrible surprise, which is
    // the whole reason this map exists. A file called `drifting-blobs.svg` that
    // sits perfectly still looks like the shell being broken; a card that says
    // "SVG, drawn as a still" looks like the shell knowing what it is doing.
    // Measured rather than guessed, because plenty of SVGs are not animated and
    // labelling those would be its own lie.
    property var frozen: ({})

    function isFrozen(path: string): bool {
        return root.frozen[path] === true;
    }

    // ONE grep FOR THE WHOLE FOLDER, the poster maker's argument exactly: a
    // process per file would make the picker's first opening a burst of them.
    // `-l` prints the ones that matched and nothing else, which is the map.
    function findFrozen(): void {
        const svgs = root.available.filter(p => p.toLowerCase().endsWith(".svg"));
        if (!svgs.length) {
            root.frozen = {};
            return;
        }
        // Both spellings, and `animation:` for the CSS shorthand that names a
        // keyframe set without the word `keyframes` appearing near it.
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

    // WHAT SHAPE EACH FILE IS, as width over height. { path: 1.7777, ... }
    //
    // MEASURED, NEVER READ OFF THE PATH. A folder of wallpapers sorted into
    // `32x9/` and `5x8/` is telling you the answer and is not a source for it:
    // the folder is a human's filing, one picture in it is always the one that
    // was dropped in the wrong place, and a shell that trusted the directory
    // name would hide the file that actually fits while offering the one that
    // does not. The name of a folder is a label; the pixels are the fact.
    //
    // A PATH THAT IS NOT IN HERE HAS NO SHAPE, which is a real answer rather
    // than a missing one, and `fits` below treats it as fitting everything.
    // Two kinds land there and both want exactly that: an SVG has no pixels of
    // its own and rasterises to whatever rectangle it is given, so it genuinely
    // suits any screen; an audio file has no picture at all, so there is
    // nothing about it that could fail to suit one. Anything else that ends up
    // unmeasured is a file ffprobe could not open, and offering it is a better
    // failure than silently dropping it.
    property var shapes: ({})

    function aspectOf(path: string): real {
        return root.shapes[path] ?? 0;
    }

    // WHETHER A PICTURE SUITS A SCREEN, both given as width over height.
    //
    // Compared as a RATIO of the two aspects rather than a difference of them,
    // through a log so the comparison is symmetric. A difference is the wrong
    // instrument here: 32:9 and 21:9 are 1.2 apart in aspect and are obviously
    // different screens, while 9:16 and 5:8 are 0.005 apart and are the same
    // one. Aspect is a multiplicative quantity, so the honest question is "how
    // many times wider", and `log` makes a picture 25% too wide and a picture
    // 25% too tall the same distance from home instead of one of them being
    // dozens of times further out than the other.
    //
    // The tolerance is `wallpaper.fit`, a factor rather than a percentage, for
    // the same reason: see config/Config.qml.
    function fits(path: string, screenAspect: real): bool {
        const a = root.aspectOf(path);
        if (!a || !screenAspect)
            return true;
        return Math.abs(Math.log(a / screenAspect)) <= Math.log(Config.values.wallpaper.fit);
    }

    // The wallpapers that suit a screen of this shape, in the order `available`
    // already holds. MAY BE EMPTY, and the caller decides what an empty answer
    // means: the picker falls back to showing everything and says so, because a
    // strip with nothing in it is a dead end rather than a filter.
    function fittedFor(screenAspect: real): var {
        return root.available.filter(p => root.fits(p, screenAspect));
    }

    // The shape of a monitor by output name, which is the form every caller
    // outside the picker has the question in.
    //
    // NOTHING IS SAID ABOUT ROTATION, and that is the point. A screen stood on
    // its end reports the other pair of numbers, so a 1920x1200 panel at
    // transform 1 is 1200x1920 here and comes out at 0.625, which is 5:8, which
    // is what the pictures that suit it are. The rule falls out of the
    // measurement instead of being a case in it.
    function screenAspect(screen: string): real {
        const s = Quickshell.screens.find(m => m.name === screen);
        return s && s.height > 0 ? s.width / s.height : 0;
    }

    // ONE PROCESS FOR THE WHOLE FOLDER, the poster maker's argument again and
    // for the same numbers: a Process per file would make the first listing a
    // burst of them, and this runs on every re-list.
    //
    // ffprobe rather than ImageMagick's `identify`, though both are on this
    // machine and identify handles SVG better. ffmpeg is already a hard
    // dependency here (it is what lifts a poster frame out of a video), and one
    // tool that answers for a jpg and an mp4 in the same breath is worth more
    // than a second tool that answers for the stills slightly better. The
    // formats identify would have won are exactly the ones that do not need an
    // answer: see `shapes`.
    //
    // `csv=p=0` prints `W,H` and nothing else. A file with no video stream
    // prints nothing, the `case` drops it, and it ends up unmeasured, which is
    // the state the fitting rule already has a name for.
    function measureShapes(): void {
        if (!root.available.length) {
            root.shapes = {};
            return;
        }
        shaper.command = ["sh", "-c", `for f in "$@"; do
  s=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$f" </dev/null 2>/dev/null)
  case "$s" in
    [0-9]*,[0-9]*) printf '%s\\t%s\\n' "$f" "$s" ;;
  esac
done`, "sh", ...root.available];
        shaper.running = true;
    }

    Process {
        id: shaper

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
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

    // WHETHER IT IS SHOWN, which is a separate question from which one it is.
    //
    // Kept apart from `current` on purpose: clearing the path to hide the
    // picture would mean the shell has to guess one when you want it back, and
    // the guess is never the one you had. This says only "not right now", so
    // the choice survives being turned off. See config/Config.qml.
    readonly property bool enabled: Config.values.wallpaper.enabled

    // The name of the file, for the places that show which one it is. Empty
    // when nothing is set, rather than the "" a split would leave.
    function nameOf(path: string): string {
        return path.split("/").pop();
    }

    readonly property string name: root.nameOf(root.currentOn(root.here))

    // Absolute paths, sorted, of everything in `dir` we can show.
    property var available: []

    readonly property bool ready: current !== ""

    // WHAT IS ON THE SCREEN RIGHT NOW, which is not always what is in the
    // config. A picker scrubbing through the list puts each one on the actual
    // desktop as it passes, because a wallpaper is a thing you judge at full
    // size against your own windows and a thumbnail cannot stand in for that.
    // None of that is a decision until something is chosen, so it is kept here
    // rather than written: dismiss the picker and the setting was never touched.
    //
    // ONE PER SCREEN, and this is the change per-screen wallpapers most needed.
    // The picker is a per-screen surface, so scrubbing the strip on the left
    // monitor was repainting the right one too: you were judging a picture
    // against the wrong screen's windows, and the screen you were not looking
    // at kept flickering. A preview belongs to the surface previewing it.
    property var previews: ({})

    function previewOn(screen: string): string {
        return root.previews[screen] ?? "";
    }

    // COPY THEN ASSIGN, never an edit in place: QML notices assignment to
    // `previews` and nothing about the object it points at, so a mutated map
    // would change the desktop and tell no binding about it. Same rule as
    // services/Apps.qml's map and ScreensPage's array.
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

    // WHAT THAT SCREEN IS ACTUALLY DRAWING: the thing being previewed on it if
    // anything is, else what it is set to. This is the property WallpaperWindow
    // is written against, and the only one it needs.
    function shownOn(screen: string): string {
        return root.previewOn(screen) || root.currentOn(screen);
    }

    function shownNameOn(screen: string): string {
        return root.nameOf(root.shownOn(screen));
    }

    function shownKindOn(screen: string): string {
        return root.kindOf(root.shownOn(screen));
    }

    readonly property string shown: root.shownOn(root.here)
    readonly property string shownName: root.nameOf(root.shown)
    readonly property string shownKind: root.kindOf(root.shown)

    // WHERE THE CHANGE CAME FROM, normalised 0 to 1 across the screen.
    //
    // The new wallpaper opens out of this point (components/reveal.frag), so a
    // card you pressed is visibly the thing the picture arrived from. Anything
    // that has no point to have come from, which is every keybind and every CLI
    // verb, leaves it in the middle, where a circle growing out of nowhere in
    // particular is the honest answer.
    //
    // ONE POINT PER SCREEN, and it used to be one point for all of them.
    //
    // The old argument was that a wallpaper is one setting, so the change is
    // one event and should read as one event happening everywhere rather than
    // as two circles racing. That argument was correct about the shell it was
    // written for and is exactly backwards for this one: the change now happens
    // on ONE screen, and the reveal is the shell saying which. A shared origin
    // would put the second monitor's blob at a fraction of the way across a
    // screen where nothing was pressed.
    //
    // NORMALISED, which is what makes it survive ten monitors at ten aspect
    // ratios: 0 to 1 across whatever that surface turns out to be, and
    // components/reveal.frag corrects for the aspect itself so the blob is
    // round on a phone in portrait and on a 32:9 panel alike.
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

    // GIVE ONE SCREEN A WALLPAPER OF ITS OWN.
    //
    // Writes one key of the map, which is why this is a function on the service
    // and not `Config.set("wallpaper.perScreen." + screen, path)`: Config.set
    // walks a dotted path and refuses a leaf the defaults do not name, and the
    // defaults deliberately name no monitors at all.
    function setOn(screen: string, path: string): void {
        // NO SCREEN MEANS ALL OF THEM here, and only here. `currentOn("")`
        // reads the default because a reader with no screen is asking what a
        // wallpaper is; a WRITER with no screen is asking to change one, and
        // the only honest target for that is the default, which is what every
        // screen without an entry follows. The two are the same answer from
        // opposite ends.
        if (!screen) {
            root.setAll(path);
            return;
        }
        root.clearPreview(screen);

        // ALREADY THE ANSWER, so say nothing. Choosing the picture a screen is
        // already following the default to is not a reason to give that screen
        // an entry: it would pin it there, and the next `set everywhere` would
        // move every screen except this one.
        if (!root.hasOwn(screen) && path === root.current)
            return;

        const next = Object.assign({}, Config.values.wallpaper.perScreen ?? {});
        next[screen] = path;
        Config.set("wallpaper.perScreen", next);
    }

    // THE SAME ONE EVERYWHERE, which is a write to the default AND a clearing
    // of every disagreement with it. See config/Config.qml: a map that agreed
    // with the default in every entry would go on agreeing with the OLD default
    // the moment the default moved.
    function setAll(path: string): void {
        root.previews = {};
        Config.setMany([["wallpaper.perScreen", {}], ["wallpaper.current", path]]);
    }

    // BACK TO THE DEFAULT. Not "set it to whatever the default currently is":
    // the entry goes, so the screen follows the default from here on.
    function clearOn(screen: string): void {
        if (!root.hasOwn(screen))
            return;
        root.clearPreview(screen);
        const next = Object.assign({}, Config.values.wallpaper.perScreen);
        delete next[screen];
        Config.set("wallpaper.perScreen", next);
    }

    // Kept as the name every caller without a screen already used, and it means
    // what it always meant: all of them.
    function set(path: string): void {
        root.setAll(path);
    }

    // Chosen from somewhere on a particular screen. `x` and `y` are 0 to 1
    // across that screen.
    function setFrom(screen: string, path: string, x: real, y: real): void {
        root.setOrigin(screen, x, y);
        root.setOn(screen, path);
    }

    // THE SAME CHOICE, EVERYWHERE, made at a point on one screen.
    //
    // The origin is copied to every monitor as the same FRACTION, which is the
    // original shell-wide argument and the only one that survives ten screens
    // at ten aspect ratios: a point two thirds across a 32:9 panel has no
    // pixel-for-pixel counterpart on a phone in portrait, but two thirds across
    // is two thirds across on both, and reveal.frag corrects the aspect so the
    // blob is round on each. So the change reads as one event happening
    // everywhere, which is exactly what it now is.
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

    // Next/previous in the listing, wrapping. Enough to flick through them from
    // a keybind or the CLI without a picker.
    //
    // The reveal opens from the EDGE the new one is coming from rather than
    // from the middle: stepping forward is a picture arriving from the right,
    // and a circle that grows from the right edge says which direction you are
    // travelling through the folder without a single word on the screen.
    //
    // ON ONE SCREEN. Stepping is the keybind's picker, and a keybind means the
    // screen you are looking at, exactly as services/Shell.qml's forScreen("")
    // argues for the twenty verbs that go through it. Walking every monitor
    // through the folder at once is `wallpaper next all`, and it is the rarer of
    // the two by a wide margin.
    //
    // WHERE IT STARTS is that screen's own wallpaper rather than the default,
    // so two monitors stepping independently do not yank each other back in
    // step the moment one of them is nudged.
    function stepOn(screen: string, delta: int): void {
        if (!root.available.length)
            return;
        root.setOrigin(screen, delta > 0 ? 1 : 0, 0.5);
        const i = root.available.indexOf(root.currentOn(screen));
        // Not in the list (someone set a path elsewhere): start at the front.
        const next = i < 0 ? 0 : (i + delta + root.available.length) % root.available.length;
        root.setOn(screen, root.available[next]);
    }

    function step(delta: int): void {
        root.stepOn(root.here, delta);
    }

    // EVERY SCREEN, ONE STEP, and off the DEFAULT rather than off each screen's
    // own: this verb means "all of them together", and stepping each from where
    // it happens to be would leave them further apart than they started.
    function stepAll(delta: int): void {
        if (!root.available.length)
            return;
        // The same EDGE on each of them, not the same point on one of them:
        // normalised, so "coming in from the right" is the right edge of a
        // phone in portrait and of a 32:9 panel without either being named.
        const edge = {};
        for (const s of Quickshell.screens)
            edge[s.name] = Qt.point(delta > 0 ? 1 : 0, 0.5);
        root.origins = edge;
        const i = root.available.indexOf(root.current);
        const next = i < 0 ? 0 : (i + delta + root.available.length) % root.available.length;
        root.setAll(root.available[next]);
    }

    // A PICTURE OF A THING THAT IS NOT A PICTURE.
    //
    // The picker draws a card per wallpaper, and Image can decode every kind in
    // the list except one: it will show a GIF's first frame and rasterise an
    // SVG, and it has no idea what to do with an mp4. So every video gets a
    // still lifted out of it once, into the cache, and the card draws that.
    //
    // { path: posterPath } for the videos that have one. A path that is not in
    // here draws itself, which is the right answer for every other kind and the
    // right FALLBACK for a video whose poster has not been made yet: an Image
    // pointed at an mp4 fails to load and shows nothing, which is exactly what
    // an empty card looks like anyway.
    property var posters: ({})

    function poster(path: string): string {
        return root.posters[path] ?? "";
    }

    // What a card should actually point at.
    function faceOf(path: string): string {
        const k = root.kindOf(path);
        if (k === "audio")
            return "";
        return k === "video" ? root.poster(path) : path;
    }

    readonly property string posterDir: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/banditshell/posters`

    // ONE PROCESS FOR THE WHOLE FOLDER, not one per file. A wallpaper folder
    // holds a handful of videos at most, ffmpeg opens each of them for a single
    // frame, and spawning a Process per file would mean the picker's first
    // opening is a burst of them. The script prints `source<TAB>poster` for
    // everything it has, whether it made it just now or found it already there,
    // so the map is built from what EXISTS rather than from what was attempted.
    //
    // Keyed by a hash of the full path, so two folders' `loop.mp4` are two
    // posters, and `-n` leaves an existing one alone: this runs on every
    // re-list and must be free when nothing has changed.
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

    // THE COMMAND IS BUILT HERE, not bound.
    //
    // It used to be a binding on `dir`, and that quietly meant changing the
    // folder did nothing until the next restart. `onDirChanged` and the
    // command's own binding are two separate consequences of the same notify,
    // and QML does not promise which runs first: the handler fired, `running`
    // went true, and the process started on the command it still had, which was
    // the OLD folder's. The listing came back identical and the setting looked
    // inert.
    //
    // Assigned at the moment the listing starts, which is the only moment the
    // question "which folder" has one answer.
    // WHAT COLOURS THE WALLPAPER IS MOSTLY MADE OF.
    //
    // [{ colour: "#1b3a34", share: 0.41 }, ...], most of the picture first, and
    // the shares sum to one. Gathered and published and NOTHING ELSE: nothing
    // in the shell wears these yet. `theme.fromWallpaper` is the switch that
    // would, and it is deliberately a switch with no wiring behind it, because
    // deciding which of six colours is a surface and which is an accent is a
    // whole design question and this is only the measurement it would need.
    //
    // OFF THE COMMITTED WALLPAPER, not the previewed one. Scrubbing a picker
    // puts a dozen wallpapers on the desktop in a second and none of them is a
    // decision; a palette that chased that would spawn a dozen processes to
    // answer a question nobody asked.
    property var palette: []

    readonly property color dominant: root.palette.length ? root.palette[0].colour : "transparent"

    // OFF THE FOCUSED SCREEN'S WALLPAPER, which is the one question a single
    // palette can honestly answer once the screens can differ.
    //
    // One per screen was the other option and it is the wrong one twice over: a
    // python and an ffmpeg per monitor on every change, to feed a switch
    // (`themeFromWallpaper`) that is deliberately not wired to anything, and
    // then a shell that would have to decide what it means to be dressed in two
    // photographs at once. The shell is one shell; it can wear one of them.
    function measure(): void {
        const face = root.faceOf(root.currentOn(root.here));
        if (!face) {
            root.palette = [];
            return;
        }
        // Both arguments assigned here rather than bound, for the reason
        // refresh() spells out below: a handler and a binding are two
        // consequences of one notify and QML does not promise the order, so a
        // bound command can start on the previous path.
        paletter.command = ["python3", Quickshell.shellPath("scripts/palette.py"), face];
        paletter.running = true;
    }

    // A WALLPAPER CAN CHANGE FASTER THAN IT CAN BE MEASURED. `wallpaper next`
    // held down walks the folder at the speed of the key repeat, and each step
    // would otherwise start a python and an ffmpeg for a wallpaper that is
    // already not the current one by the time they finish. The last one to
    // stand still for a moment is the only one worth asking about.
    // Three notifies for one question: the default moved, this screen's own
    // entry moved, or you looked at a different screen. All three change the
    // answer to "what is the wallpaper in front of me made of".
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
        // The pattern is BUILT from `formats` rather than written out, so a
        // format added up there is offered down here without this line being
        // touched. `-iregex` matches the whole path, hence the leading `.*`.
        //
        // ALL THE WAY DOWN, where this used to stop at `-maxdepth 1`.
        //
        // A wallpaper collection that has outgrown one folder has been sorted
        // into subfolders, and it is almost always sorted by SHAPE: `32x9/`,
        // `16x9/`, `5x8/`. That is the same fact `shapes` measures, so a flat
        // listing was refusing to look in exactly the folders that exist
        // because the pictures in them are different from each other. One
        // setting names the collection and the whole collection is offered.
        //
        // `-L` because the folder is very often a symlink, and so is anything
        // inside it: a dotfiles repo checks the pictures in somewhere else and
        // links them into place, and `find` without this stops at the link and
        // reports nothing at all. `-type f` is evaluated against the TARGET
        // under -L, which is what makes a folder of links list as a folder of
        // pictures instead of as nothing.
        //
        // AND `realpath` ON THE WAY OUT, which the `-L` makes necessary rather
        // than merely tidy.
        //
        // A WALLPAPER IS A FILE, AND A PATH IS ONE OF ITS NAMES. Following
        // symlinks means the same picture can be reached by two of them, and
        // this shell compares wallpapers by STRING in every place it matters:
        // the ring on the card you are wearing, the index the picker opens at,
        // the position `next` steps from. Browse the collection through
        // `~/.config/wallpapers` and set it through the dotfiles path it points
        // at, and every one of those comparisons quietly says no: the strip
        // opens on the first file with no ring anywhere, which reads as the
        // shell having lost the wallpaper that is visibly on the screen behind
        // it. Found exactly that way.
        //
        // So one name is picked and it is the real one. `-exec ... +` batches,
        // so this is one more process for the folder rather than one per file,
        // and the collector drops repeats because two links to one picture are
        // one wallpaper.
        lister.command = ["sh", "-c", `exec find -L "$1" -type f -iregex "$2" -exec realpath -- {} +`, "sh", root.dir, `.*\\.\\(${root.extensions.join("\\|")}\\)$`];
        lister.running = true;
    }

    Component.onCompleted: refresh()

    // Re-list when the directory setting changes, not on a timer: wallpapers do
    // not appear on their own.
    onDirChanged: refresh()

    Process {
        id: lister

        // No `command` here: refresh() sets it. See its note.

        stdout: StdioCollector {
            onStreamFinished: {
                // Deduped, because `realpath` above can hand back the same
                // picture twice when two links in the tree point at it.
                root.available = [...new Set(text.trim().split("\n").filter(l => l))].sort();
                if (!root.available.length)
                    console.warn(`Wallpaper: nothing usable in ${root.dir}`);
                root.makePosters();
                root.findFrozen();
                root.measureShapes();
            }
        }
    }
}
