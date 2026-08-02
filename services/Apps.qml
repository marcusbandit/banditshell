pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Installed applications, and how to find one by typing.
//
// The ranking is the whole service, and it is two independent things kept
// separate on purpose:
//
//   TIER: where the match landed. Substring matching alone puts "Disk Usage
//   Analyzer" above "Discord" for "disc", which makes a launcher feel broken
//   even though every result technically matches. The start of the name beats
//   the middle of the name, which beats the keywords, which beats the
//   description.
//
//   FRECENCY: what you actually use. Only ever a tiebreak WITHIN a tier, never
//   across one, because no amount of habit should make a worse match win. With
//   no query typed every candidate is the same tier, so the whole list is
//   ordered by what you reach for.
//
// They used to be added into one number, which meant the length penalty inside a
// tier silently outranked usage: an app you open daily lost to one with a name
// two letters shorter.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // What KIND of thing a window is, as one glyph.
    //
    // Keyed by freedesktop CATEGORY, not by application name. A name list is a
    // list that is permanently missing whatever was installed last week,
    // whereas every desktop entry already ships its categories, so an app this
    // shell has never heard of still gets the right mark. Registered names
    // only: https://specifications.freedesktop.org/menu-spec.
    //
    // ORDER IS THE PRIORITY. First match down this list wins, because entries
    // declare several: an IDE is `Development;IDE;TextEditor`, a terminal is
    // `System;TerminalEmulator;Utility`, and the specific one is the one worth
    // drawing. The generic buckets (Utility, System, Network) sit at the bottom
    // for exactly that reason.
    readonly property var categoryIcons: ({
            TerminalEmulator: "terminal",
            ConsoleOnly: "terminal",
            WebBrowser: "web",
            Email: "mail",
            InstantMessaging: "forum",
            IRCClient: "forum",
            Chat: "forum",
            IDE: "code",
            Development: "code",
            TextEditor: "edit_note",
            Emulator: "sports_esports",
            Game: "sports_esports",
            FileManager: "folder",
            FileTools: "folder",
            Archiving: "archive",
            Compression: "archive",
            AudioVideoEditing: "video_settings",
            Music: "music_note",
            Video: "movie",
            Player: "movie",
            Recorder: "mic",
            Audio: "music_note",
            AudioVideo: "movie",
            TV: "tv",
            "3DGraphics": "deployed_code",
            VectorGraphics: "draw",
            RasterGraphics: "photo_library",
            "2DGraphics": "photo_library",
            Photography: "photo_library",
            Graphics: "photo_library",
            Spreadsheet: "table_chart",
            Presentation: "slideshow",
            WordProcessor: "description",
            Calendar: "calendar_month",
            Office: "description",
            Documentation: "article",
            Education: "book",
            Science: "calculate",
            Math: "calculate",
            Maps: "map",
            PackageManager: "package",
            Security: "security",
            Printing: "print",
            Monitor: "monitor_heart",
            DesktopSettings: "settings",
            HardwareSettings: "settings",
            Settings: "settings",
            Viewer: "image",
            Network: "public",
            System: "host",
            Utility: "build"
        })

    // PER-APPLICATION MARKS, from the Nerd Fonts symbol face.
    //
    // This is the icon pack that fits: several thousand line glyphs drawn as one
    // set, monochrome by construction, so they take the shell's label colour the
    // way the Material Symbols do instead of arriving with a brand palette
    // attached. A category glyph says "a browser"; this says "Firefox", and it
    // still looks like it belongs in this bar.
    //
    // Keyed by a regex on the window class, first match wins, most specific
    // first. Values are the codepoint, because that is what a Nerd Font addresses
    // a glyph by; the name in the comment is the one the cheat sheet lists.
    //
    // NOT a substitute for `categoryIcons`, which is still the answer for the
    // thousands of applications no icon set has ever heard of. This is the top of
    // the ladder, not the whole of it.
    readonly property var brandGlyphs: ({
            // Zen is a Firefox build, so it gets the Firefox mark rather than
            // the generic browser one: the mark should say what the thing IS.
            "^(firefox|librewolf|floorp|waterfox|zen)": "\uf269",   // fa-firefox
            "^(chromium|chrome|brave|vivaldi|opera)": "\uf268",     // fa-chrome
            "(telegram)": "\uf2c6",                                 // fa-telegram
            "(discord|vesktop|webcord)": "\uf1ff",                  // fa-discord
            "(slack)": "\uf198",                                    // fa-slack
            "(teams)": "\uf02bb",                                   // md-microsoft-teams
            "(skype)": "\uf17e",                                    // fa-skype
            "(thunderbird)": "\uf370",                              // linux-thunderbird
            "^(kitty|alacritty|foot|wezterm|ghostty|konsole|xterm)": "\ue795", // dev-terminal
            "(nvim|neovim)": "\ue6ae",                              // custom-neovim
            "(gvim|^vim)": "\ue7c5",                                // dev-vim
            "(emacs)": "\ue7cf",                                    // dev-emacs
            "(vscode|code-oss|codium|^code$)": "\ue8da",            // dev-vscode
            "(jetbrains|idea|pycharm|webstorm|clion|rider|goland)": "\ue7b5", // dev-intellij
            "(android-?studio)": "\ue70e",                          // dev-android
            "(godot)": "\ue7ee",                                    // dev-godot
            "(blender)": "\ue766",                                  // dev-blender
            "(gimp)": "\ue7e7",                                     // dev-gimp
            "(inkscape)": "\ue801",                                 // dev-inkscape
            "(krita)": "\uf33d",                                    // linux-krita
            "(kdenlive)": "\uf33c",                                 // linux-kdenlive
            "(mpv|celluloid)": "\uf36e",                            // linux-mpv
            "(vlc)": "\uf057c",                                     // md-vlc
            "(spotify)": "\uf1bc",                                  // fa-spotify
            "(steam|lutris|heroic)": "\uf1b6",                      // fa-steam
            "(torrent|transmission|deluge)": "\uf076",              // fa-magnet
            "(docker|podman)": "\uf21f",                            // fa-docker
            "(libreoffice|onlyoffice|soffice)": "\uf376",           // linux-libreoffice
            "(zathura|evince|okular|papers|sioyek)": "\uf0226",     // md-file-pdf-box
            "(nautilus|dolphin|thunar|nemo|files|pcmanfm)": "\uf024b" // md-folder
        })

    // The generic mark, for a window whose class matches no desktop entry at
    // all: wine apps, games launched by an id, anything self-titled. Same glyph
    // the launcher falls back to, so "we could not identify this" looks the
    // same everywhere.
    readonly property string genericIcon: "apps"

    // Names that a reverse-DNS id can also be known by, most specific first.
    //
    // The icon THEME is where the artwork is, and it is enormous: Papirus alone
    // carries an icon for eight thousand applications, so the question is almost
    // never "does a picture of this app exist", it is "does the name this window
    // calls itself match the name the pack files it under". A window says
    // `org.telegram.desktop`; the pack has `telegram`. So the id is taken apart:
    // whole, then lowercased, then the last meaningful segment, which is what a
    // pack usually files it as.
    //
    // `desktop`, `app`, `gui` and friends are dropped from the tail first, or
    // `org.telegram.desktop` would ask the theme for "desktop" and cheerfully
    // come back with a picture of a computer.
    readonly property var idSuffixes: ["desktop", "app", "gui", "client", "bin"]

    function nameVariants(name: string): var {
        const out = [name];
        const lower = name.toLowerCase();
        if (lower !== name)
            out.push(lower);

        const parts = lower.split(".").filter(p => p);
        while (parts.length > 1 && root.idSuffixes.includes(parts[parts.length - 1]))
            parts.pop();
        if (parts.length > 1)
            out.push(parts[parts.length - 1]);

        // `Zen Browser` is a window title, an application.name, and no icon
        // anywhere; `zen-browser` is the file.
        if (lower.includes(" "))
            out.push(lower.replace(/\s+/g, "-"));

        return out;
    }

    // The icon FILE for an app, given whatever names the thing asking happens to
    // hold: a window class, a PipeWire `application.name`, a process binary.
    //
    // Several, in order, because none of them is authoritative and which one
    // resolves varies by app: PipeWire hears "Zen" from the browser whose entry
    // is `zen-browser`, and hears the binary `zen-bin` for the same process.
    // Returns "" when nothing resolves, which is the caller's cue to fall back
    // to the category glyph rather than to draw a hole.
    function iconSourceFor(names: var): string {
        // The desktop ENTRY first, for every name given, because an entry's own
        // `Icon=` is the one authoritative answer: it is what the application
        // says its picture is called, and it is how `zen` (the window class)
        // reaches `zen-browser` (the file), which no amount of string mangling
        // would find.
        for (const name of names) {
            for (const variant of root.nameVariants(name ?? "")) {
                if (!variant)
                    continue;
                const icon = DesktopEntries.heuristicLookup(variant)?.icon;
                const path = icon ? Quickshell.iconPath(icon, true) : "";
                if (path)
                    return path;
            }
        }

        // Then the theme directly, since a pack files most apps under the name
        // they already call themselves and a window can easily have no desktop
        // entry at all: anything started from a terminal, a game launched by an
        // id, a wine program.
        for (const name of names) {
            for (const variant of root.nameVariants(name ?? "")) {
                const path = variant ? Quickshell.iconPath(variant, true) : "";
                if (path)
                    return path;
            }
        }

        return "";
    }

    // Hand-picked marks, tried before anything is worked out: { regex: glyph }.
    // A category is a guess about what an application IS, and for some of them
    // the guess is simply wrong or too vague to be worth drawing; this is where
    // you say so. See `apps.icons` in config.json.
    readonly property var overrides: Config.values.apps.icons

    // The per-app glyph for a window class, or "" when the set has nothing for
    // it, which is the caller's cue to fall back to what KIND of thing it is.
    function brandFor(appClass: string): string {
        for (const pattern in root.brandGlyphs) {
            try {
                if (new RegExp(pattern, "i").test(appClass))
                    return root.brandGlyphs[pattern];
            } catch (e) {
                console.warn(`Apps: "${pattern}" is not a valid brand regex, skipping it.`, e);
            }
        }
        return "";
    }

    function overrideFor(appClass: string): string {
        for (const pattern in root.overrides) {
            try {
                if (new RegExp(pattern, "i").test(appClass))
                    return root.overrides[pattern];
            } catch (e) {
                console.warn(`Apps: "${pattern}" is not a valid regex, skipping that icon override.`, e);
            }
        }
        return "";
    }

    function iconFor(appClass: string): string {
        const picked = root.overrideFor(appClass);
        if (picked)
            return picked;

        // heuristicLookup, because a window's class is only approximately its
        // entry's id: `org.kde.dolphin` vs `dolphin`, `Alacritty` vs
        // `alacritty`. Matching those by hand is a rabbit hole Quickshell has
        // already been down.
        const categories = DesktopEntries.heuristicLookup(appClass)?.categories ?? [];
        for (const category in root.categoryIcons)
            if (categories.includes(category))
                return root.categoryIcons[category];
        return root.genericIcon;
    }

    // Match tiers, high to low. Named rather than written as literals at the
    // comparison sites, so "does a keyword match beat a word-start match" is
    // answered by reading the list instead of by comparing two magic numbers.
    readonly property int tierExact: 6
    readonly property int tierPrefix: 5
    readonly property int tierWordStart: 4
    readonly property int tierAnywhere: 3
    readonly property int tierMeta: 2
    readonly property int tierComment: 1
    readonly property int tierSubsequence: 0
    readonly property int tierNone: -1

    function tier(entry: var, needle: string): int {
        if (!needle)
            return root.tierExact;

        const q = needle.toLowerCase();
        const name = (entry.name ?? "").toLowerCase();
        const generic = (entry.genericName ?? "").toLowerCase();
        const comment = (entry.comment ?? "").toLowerCase();
        const keywords = (entry.keywords ?? []).join(" ").toLowerCase();

        if (name === q)
            return root.tierExact;
        if (name.startsWith(q))
            return root.tierPrefix;
        if (new RegExp(`\\b${root.escapeRegex(q)}`).test(name))
            return root.tierWordStart;
        if (name.includes(q))
            return root.tierAnywhere;
        if (generic.includes(q) || keywords.includes(q))
            return root.tierMeta;
        if (comment.includes(q))
            return root.tierComment;

        // Subsequence, so "ff" finds Firefox. Last resort: it matches almost
        // everything, so it must never outrank a real match.
        return root.subsequence(name, q) ? root.tierSubsequence : root.tierNone;
    }

    function escapeRegex(s: string): string {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function subsequence(haystack: string, needle: string): bool {
        let i = 0;
        for (const ch of haystack) {
            if (ch === needle[i])
                i++;
            if (i === needle.length)
                return true;
        }
        return false;
    }

    // Everything that matches, best first. NOT truncated: the list scrolls, and
    // a cap is the wrong answer to "there are a lot of results" when the top of
    // the list is already the answer you wanted.
    function search(needle: string): var {
        const now = Date.now();
        return root.all.map(e => ({
                    entry: e,
                    tier: root.tier(e, needle),
                    used: root.frecencyAt(e, now),
                    // Only while something is TYPED. Shorter is a better match
                    // for a query, and means nothing without one: with an empty
                    // box and no usage yet it sorted the whole menu by name
                    // length, so the launcher opened on "R".
                    length: needle ? (e.name ?? "").length : 0
                })).filter(r => r.tier > root.tierNone).sort((a, b) => b.tier - a.tier || b.used - a.used || a.length - b.length || (a.entry.name ?? "").localeCompare(b.entry.name ?? "")).map(r => r.entry);
    }

    function launch(entry: var): void {
        root.record(entry);
        // execute() handles the desktop-entry Exec field's own escaping and
        // field codes, which is a small horror worth not reimplementing.
        entry?.execute();
    }

    // What you actually use.
    //
    // FRECENCY, not a count. A thing opened forty times last year should not
    // outrank the one opened twice this week, and a pure count can never forget,
    // so a launcher tuned by a month of one project stays tuned to it forever.
    //
    // Each launch is worth 1 at the moment it happens and halves every
    // `halfLifeDays`. That needs no history: the stored score is decayed to now
    // before 1 is added, so one number per app carries the whole curve.
    readonly property real halfLifeDays: Config.values.launcher.halfLifeDays
    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/usage.json`

    property var usage: ({})

    function decay(fromMs: real, toMs: real): real {
        const days = Math.max(0, toMs - fromMs) / 86400000;
        return Math.pow(0.5, days / Math.max(root.halfLifeDays, 1 / 24));
    }

    function frecencyAt(entry: var, now: real): real {
        const rec = root.usage[entry?.id ?? ""];
        if (!rec)
            return 0;
        return rec.score * root.decay(rec.last, now);
    }

    function record(entry: var): void {
        const id = entry?.id;
        if (!id)
            return;

        const now = Date.now();
        const rec = root.usage[id];
        const next = {
            score: (rec ? rec.score * root.decay(rec.last, now) : 0) + 1,
            last: now
        };

        // A NEW object, not a mutated one. `usage` is a var property and QML
        // only notices assignment, so mutating it in place leaves every binding
        // that reads it showing the old order until something else happens to
        // invalidate them.
        root.usage = Object.assign({}, root.usage, {
            [id]: next
        });
        store.setText(JSON.stringify(root.usage));
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn(`Apps: ${root.path} is not valid JSON, starting the usage record over.`, e);
                root.usage = {};
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
        }
    }

    // First run: nothing to read, but the directory has to exist before the
    // first launch can write anything into it.
    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
    }
}
