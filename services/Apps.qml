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

    // WHAT YOU PUT AWAY, keyed by desktop entry id.
    //
    // `NoDisplay` is the freedesktop answer to "this entry is not a thing a
    // human launches", and the honour system it runs on is not widely observed:
    // a machine with a compiler on it has a dozen entries for inspectors,
    // settings panels and font viewers, all of them cheerfully displayable. So
    // the launcher gets a second filter that answers to you rather than to the
    // package.
    //
    // Filed, not deleted. `buried` is still a list, still sorted, and still one
    // gesture from coming back; see `launcher.hidden` in config.json.
    readonly property var hidden: Config.values.launcher.hidden

    function isHidden(entry: var): bool {
        return !!root.hidden[entry?.id ?? ""];
    }

    function setHidden(entry: var, away: bool): void {
        const id = entry?.id;
        if (!id)
            return;

        // A NEW object, for the same reason `record` builds one: QML only
        // notices assignment, and Config.set copies what it is given.
        const next = Object.assign({}, root.hidden);
        if (away)
            next[id] = true;
        else
            delete next[id];
        Config.set("launcher.hidden", next);
    }

    // WHAT YOU KEEP AT THE TOP, keyed by desktop entry id.
    //
    // The mirror of `hidden`, and for the mirrored reason: frecency answers
    // "what do you reach for" honestly and only in arrears, so the thing you
    // have decided you want at the top cannot get there until you have already
    // opened it enough times not to need the help. A star says it now.
    readonly property var starred: Config.values.launcher.starred

    function isStarred(entry: var): bool {
        return !!root.starred[entry?.id ?? ""];
    }

    function setStarred(entry: var, keep: bool): void {
        const id = entry?.id;
        if (!id)
            return;

        const next = Object.assign({}, root.starred);
        if (keep)
            next[id] = true;
        else
            delete next[id];
        Config.set("launcher.starred", next);
    }

    // Starred first, then whatever the ranking offers, and never the same entry
    // twice. Long enough to hold every star: the count is a floor on the section
    // rather than a ceiling on your choices.
    //
    // FILED APPLICATIONS ARE NOT LOOSE ONES. Something you put in a folder is in
    // the folder, and leaving it in this list as well would draw it twice in one
    // section: once in the folder's own mark and once beside it. The folder is
    // where it lives now, so it comes out of here.
    function pinned(count: int): var {
        const loose = root.visible.filter(e => !root.folderOf(e.id ?? ""));
        const stars = root.byUse(loose.filter(e => root.isStarred(e)));
        const rest = root.search("").filter(e => !root.isStarred(e) && !root.folderOf(e.id ?? ""));
        return [...stars, ...rest].slice(0, Math.max(count, stars.length));
    }

    // ------------------------------------------------------------------
    // AN ID BACK TO THE THING IT NAMES.
    //
    // Everything stored about an application is stored by ID, because a config
    // file outlives a process and a DesktopEntry does not. `hidden` and
    // `starred` never need the round trip, since they only ever ask a question
    // about an entry they were handed; a folder does, because a folder IS a list
    // of ids and has to produce the applications they stand for.
    readonly property var byId: {
        const out = {};
        for (const entry of root.all)
            out[entry.id] = entry;
        return out;
    }

    function entryById(id: string): var {
        return root.byId[id] ?? null;
    }

    // ------------------------------------------------------------------
    // FOLDERS, read straight off the config, which is also where they can be
    // edited by hand: a folder made in that file and one made by a long press
    // are the same object under the same rules.
    readonly property var folders: Config.values.launcher.folders

    // A DEEP COPY, because a folder holds a map inside a map and Object.assign
    // is one level: mutating `next[key].apps` on a shallow copy reaches straight
    // through into the live config, which QML then cannot tell has changed.
    // Everything in here is plain JSON by construction, so the round trip is
    // exact and is the cheapest correct answer.
    function foldersCopy(): var {
        return JSON.parse(JSON.stringify(root.folders));
    }

    // Which folder holds an id, or "" for the ones sitting loose.
    function folderOf(id: string): string {
        if (!id)
            return "";
        for (const key in root.folders)
            if (root.folders[key].apps?.[id] !== undefined)
                return key;
        return "";
    }

    // An id given a new home, or taken out of the one it had. The private half
    // of every folder operation: the invariant that an application is in AT MOST
    // ONE folder is kept by always clearing before adding, in one write.
    function fileAway(id: string, folder: string): void {
        const next = root.foldersCopy();
        let touched = false;

        for (const key in next) {
            if (next[key].apps?.[id] === undefined)
                continue;
            // KEPT, if it is only moving. A member's stamp is its place in the
            // folder, and dragging something from one folder to another is not a
            // reason to send it to the back of the new one; it is the same
            // decision, relocated.
            if (key === folder)
                return;
            delete next[key].apps[id];
            touched = true;
        }

        if (folder && next[folder]) {
            if (!next[folder].apps)
                next[folder].apps = {};
            next[folder].apps[id] = Date.now();
            touched = true;
        }

        if (touched)
            Config.set("launcher.folders", next);
    }

    // A readable key, because this is written into config.json and read back by
    // a human as often as by the shell. Numbered rather than made unique with a
    // timestamp for the same reason.
    function folderKey(name: string): string {
        const base = (name ?? "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "folder";
        let key = base;
        for (let n = 2; root.folders[key] !== undefined; n++)
            key = `${base}-${n}`;
        return key;
    }

    // A new folder, and the key it got, so the caller can put something in it
    // without having to guess what the name turned into.
    function createFolder(name: string): string {
        const key = root.folderKey(name);
        const next = root.foldersCopy();
        next[key] = {
            name: (name ?? "").trim() || "Folder",
            since: Date.now(),
            apps: ({})
        };
        Config.set("launcher.folders", next);
        return key;
    }

    function renameFolder(key: string, name: string): void {
        // The KEY does not follow the name, deliberately. It is what every
        // member is filed under and what an open folder is remembered by, so
        // renaming would mean rewriting the map and re-pointing whatever is on
        // screen, all to change a string nobody reads except in this file.
        if (!root.folders[key])
            return;
        const next = root.foldersCopy();
        next[key].name = (name ?? "").trim() || next[key].name;
        Config.set("launcher.folders", next);
    }

    // BROKEN UP, not deleted, and the difference is everything a member is.
    // Emptying a folder onto the floor would unstar every application in it,
    // which is a decision you did not make; they go back to sitting loose in the
    // favourites with the stars they already had.
    function dissolveFolder(key: string): void {
        if (!root.folders[key])
            return;
        const next = root.foldersCopy();
        delete next[key];
        Config.set("launcher.folders", next);
    }

    // FILED, which stars it if it was not starred already: dropping something
    // into a folder is a stronger statement than starring it, and asking for the
    // star first as a separate gesture would be a rule with no reason behind it.
    function fileInFolder(key: string, entry: var): void {
        const id = entry?.id;
        if (!id || !root.folders[key])
            return;
        if (!root.isStarred(entry))
            root.setStarred(entry, true);
        root.fileAway(id, key);
    }

    function takeOutOfFolder(entry: var): void {
        const id = entry?.id;
        if (id)
            root.fileAway(id, "");
    }

    // The applications inside a folder, in the order they were filed. Ids that
    // no longer resolve are dropped rather than drawn as a hole: an application
    // can be uninstalled while its name is still written in this file, and the
    // folder should simply be one shorter.
    function folderApps(key: string): var {
        const apps = root.folders[key]?.apps ?? {};
        return Object.keys(apps).sort((a, b) => apps[a] - apps[b]).map(id => root.entryById(id)).filter(e => e && !root.isHidden(e));
    }

    // The folders themselves, oldest first, which is the order you built them
    // in. Above the loose favourites rather than mixed among them: `starred` is
    // a set with no order to merge against, and a folder is the most deliberate
    // thing in the section, so it goes where deliberate things already go.
    readonly property var folderKeys: Object.keys(root.folders).sort((a, b) => (root.folders[a].since ?? 0) - (root.folders[b].since ?? 0))

    // The two halves, derived rather than maintained, so hiding one thing
    // updates every list that shows applications at once.
    readonly property var visible: root.all.filter(e => !root.isHidden(e))
    readonly property var buried: root.all.filter(e => root.isHidden(e)).sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""))

    // Most-used first, alphabetical between equals.
    //
    // The same tiebreak `search` applies WITHIN a tier, offered on its own for
    // the places that group before they rank. A letter's section is already
    // narrowed by its initial, so alphabetical order inside it says nothing you
    // did not just ask for; which of them you actually open does.
    function byUse(entries: var): var {
        const now = Date.now();
        return entries.slice().sort((a, b) => root.frecencyAt(b, now) - root.frecencyAt(a, now) || (a.name ?? "").localeCompare(b.name ?? ""));
    }

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

    // APPLICATIONS THIS SHELL DRAWS ITSELF: { regex: the file in
    // components/marks }.
    //
    // A last resort, and deliberately a short list. Most applications are served
    // by one of the three automatic answers (their own artwork, a brand glyph, a
    // category symbol); this is for the ones where all three are wrong. kitty is
    // the case it exists for: its real icon is an orange cat on a black terminal,
    // which is a photograph in a band made of one grey and one accent, and its
    // silhouette is a blob, so tinting it flat does not rescue it either. Drawn
    // from the official mark, in our colours, it is both recognisable and part of
    // the shell. See components/marks/Kitty.qml.
    readonly property var drawnMarks: ({
            "^kitty$": "Kitty"
        })

    function drawnFor(appClass: string): string {
        for (const pattern in root.drawnMarks) {
            try {
                if (new RegExp(pattern, "i").test(appClass))
                    return root.drawnMarks[pattern];
            } catch (e) {
                console.warn(`Apps: "${pattern}" is not a valid drawn-mark regex, skipping it.`, e);
            }
        }
        return "";
    }

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

    // THE APPLICATION'S OWN NAME for a window class, as a person would say it.
    //
    // A class is a programmer's string (`org.telegram.desktop`, `vesktop`), and
    // the desktop entry beside it is the one place the readable name lives. Found
    // through the same variant ladder the artwork is, and for the same reason:
    // the class is only approximately what anything files the application under.
    //
    // Falls back to the last meaningful segment of the class, capitalised, which
    // is the best a window with no entry at all can be called. Never empty for a
    // non-empty class, because every caller is putting this in front of somebody.
    function nameFor(appClass: string): string {
        const variants = root.nameVariants(appClass ?? "");
        for (const variant of variants) {
            const name = variant ? DesktopEntries.heuristicLookup(variant)?.name : "";
            if (name)
                return name;
        }
        const tail = variants[variants.length - 1] ?? "";
        return tail ? tail.charAt(0).toUpperCase() + tail.slice(1) : "";
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
    //
    // Over `visible`, so something put away stays away when you go looking for
    // it by name too. A filter that a search can walk around is not a filter.
    function search(needle: string): var {
        const now = Date.now();
        return root.visible.map(e => ({
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

    // THE ONE DOOR OUT. Everything that starts an application goes through here
    // or through launchAction below, so the wait between the key and the window
    // is registered once rather than at every call site.
    function launch(entry: var): void {
        root.record(entry);
        Launching.start(entry);
        // execute() handles the desktop-entry Exec field's own escaping and
        // field codes, which is a small horror worth not reimplementing.
        entry?.execute();
    }

    // A desktop entry's OWN action ("New Window", "New Private Window").
    //
    // Recorded and waited for against the APPLICATION, not the action: a new
    // private window is still you reaching for the browser, and both the
    // frecency table and the start-up clock are tables of applications.
    function launchAction(entry: var, action: var): void {
        root.record(entry);
        Launching.start(entry);
        action?.execute();
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

    // `frecency.json` AND NOT `usage.json`, which is not a rename for tidiness:
    // the old name was already taken. services/Usage.qml keeps the machine's
    // awake-time diary in `${dir}/usage.json` as an ARRAY OF SPANS, this keeps a
    // table of scores keyed by app id, and both wrote the whole file on every
    // write. Whichever wrote last simply erased the other: the launcher parsed
    // the diary's array, indexed it by app id, got nothing, and ranked every app
    // at zero for as long as that state has existed, and the next launch would
    // have written its object back over a year of the calendar's history. The
    // state directory is shared on purpose (AppIcons is in there too) and one
    // file per thing remembered is what makes that safe.
    //
    // Nothing is migrated across, because there is nothing left to migrate: the
    // file under the old name is the diary's, and it is the diary's to keep. The
    // launcher starts its scores from empty, which is where they effectively
    // were anyway, and earns them back in a few launches.
    readonly property string path: `${root.dir}/frecency.json`

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
                // THE SHAPE IS CHECKED, not assumed, and an array is refused by
                // name because `typeof [] === "object"` would let one through.
                // A wrong-shaped file used to be indistinguishable from an empty
                // one here: every lookup on it returned undefined, every score
                // came out zero, and the launcher went on ranking by name
                // without a word. That silence is the reason the collision above
                // survived as long as it did, so anything that is not a plain
                // table of scores starts over loudly instead.
                const data = JSON.parse(text());
                if (data && typeof data === "object" && !Array.isArray(data)) {
                    root.usage = data;
                } else {
                    console.warn(`Apps: ${root.path} does not hold a table of scores, starting the usage record over.`);
                    root.usage = {};
                }
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
