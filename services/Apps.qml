pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    readonly property var hidden: Config.values.launcher.hidden

    function isHidden(entry: var): bool {
        return !!root.hidden[entry?.id ?? ""];
    }

    function setHidden(entry: var, away: bool): void {
        const id = entry?.id;
        if (!id)
            return;

        const next = Object.assign({}, root.hidden);
        if (away)
            next[id] = true;
        else
            delete next[id];
        Config.set("launcher.hidden", next);
    }

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

    function pinned(count: int): var {
        const loose = root.visible.filter(e => !root.folderOf(e.id ?? ""));
        const stars = root.byUse(loose.filter(e => root.isStarred(e)));
        const rest = root.search("").filter(e => !root.isStarred(e) && !root.folderOf(e.id ?? ""));
        return [...stars, ...rest].slice(0, Math.max(count, stars.length));
    }

    readonly property var byId: {
        const out = {};
        for (const entry of root.all)
            out[entry.id] = entry;
        return out;
    }

    function entryById(id: string): var {
        return root.byId[id] ?? null;
    }

    readonly property var folders: Config.values.launcher.folders

    function foldersCopy(): var {
        return JSON.parse(JSON.stringify(root.folders));
    }

    function folderOf(id: string): string {
        if (!id)
            return "";
        for (const key in root.folders)
            if (root.folders[key].apps?.[id] !== undefined)
                return key;
        return "";
    }

    function fileAway(id: string, folder: string): void {
        const next = root.foldersCopy();
        let touched = false;

        for (const key in next) {
            if (next[key].apps?.[id] === undefined)
                continue;

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

    function folderKey(name: string): string {
        const base = (name ?? "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "folder";
        let key = base;
        for (let n = 2; root.folders[key] !== undefined; n++)
            key = `${base}-${n}`;
        return key;
    }

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

        if (!root.folders[key])
            return;
        const next = root.foldersCopy();
        next[key].name = (name ?? "").trim() || next[key].name;
        Config.set("launcher.folders", next);
    }

    function dissolveFolder(key: string): void {
        if (!root.folders[key])
            return;
        const next = root.foldersCopy();
        delete next[key];
        Config.set("launcher.folders", next);
    }

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

    function folderApps(key: string): var {
        const apps = root.folders[key]?.apps ?? {};
        return Object.keys(apps).sort((a, b) => apps[a] - apps[b]).map(id => root.entryById(id)).filter(e => e && !root.isHidden(e));
    }

    readonly property var folderKeys: Object.keys(root.folders).sort((a, b) => (root.folders[a].since ?? 0) - (root.folders[b].since ?? 0))

    readonly property var visible: root.all.filter(e => !root.isHidden(e))
    readonly property var buried: root.all.filter(e => root.isHidden(e)).sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""))

    function byUse(entries: var): var {
        const now = Date.now();
        return entries.slice().sort((a, b) => root.frecencyAt(b, now) - root.frecencyAt(a, now) || (a.name ?? "").localeCompare(b.name ?? ""));
    }

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

    readonly property var brandGlyphs: ({

            "^(firefox|librewolf|floorp|waterfox|zen)": "\uf269",
            "^(chromium|chrome|brave|vivaldi|opera)": "\uf268",
            "(telegram)": "\uf2c6",
            "(discord|vesktop|webcord)": "\uf1ff",
            "(slack)": "\uf198",
            "(teams)": "\uf02bb",
            "(skype)": "\uf17e",
            "(thunderbird)": "\uf370",
            "^(kitty|alacritty|foot|wezterm|ghostty|konsole|xterm)": "\ue795",
            "(nvim|neovim)": "\ue6ae",
            "(gvim|^vim)": "\ue7c5",
            "(emacs)": "\ue7cf",
            "(vscode|code-oss|codium|^code$)": "\ue8da",
            "(jetbrains|idea|pycharm|webstorm|clion|rider|goland)": "\ue7b5",
            "(android-?studio)": "\ue70e",
            "(godot)": "\ue7ee",
            "(blender)": "\ue766",
            "(gimp)": "\ue7e7",
            "(inkscape)": "\ue801",
            "(krita)": "\uf33d",
            "(kdenlive)": "\uf33c",
            "(mpv|celluloid)": "\uf36e",
            "(vlc)": "\uf057c",
            "(spotify)": "\uf1bc",
            "(steam|lutris|heroic)": "\uf1b6",
            "(torrent|transmission|deluge)": "\uf076",
            "(docker|podman)": "\uf21f",
            "(libreoffice|onlyoffice|soffice)": "\uf376",
            "(zathura|evince|okular|papers|sioyek)": "\uf0226",
            "(nautilus|dolphin|thunar|nemo|files|pcmanfm)": "\uf024b"
        })

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

    readonly property string genericIcon: "apps"

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

        if (lower.includes(" "))
            out.push(lower.replace(/\s+/g, "-"));

        return out;
    }

    function iconSourceFor(names: var): string {

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

        for (const name of names) {
            for (const variant of root.nameVariants(name ?? "")) {
                const path = variant ? Quickshell.iconPath(variant, true) : "";
                if (path)
                    return path;
            }
        }

        return "";
    }

    readonly property var overrides: Config.values.apps.icons

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

        const categories = DesktopEntries.heuristicLookup(appClass)?.categories ?? [];
        for (const category in root.categoryIcons)
            if (categories.includes(category))
                return root.categoryIcons[category];
        return root.genericIcon;
    }

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

    function search(needle: string): var {
        const now = Date.now();
        return root.visible.map(e => ({
                    entry: e,
                    tier: root.tier(e, needle),
                    used: root.frecencyAt(e, now),

                    length: needle ? (e.name ?? "").length : 0
                })).filter(r => r.tier > root.tierNone).sort((a, b) => b.tier - a.tier || b.used - a.used || a.length - b.length || (a.entry.name ?? "").localeCompare(b.entry.name ?? "")).map(r => r.entry);
    }

    function launch(entry: var): void {
        root.record(entry);
        Launching.start(entry);

        entry?.execute();
    }

    function launchAction(entry: var, action: var): void {
        root.record(entry);
        Launching.start(entry);
        action?.execute();
    }

    readonly property real halfLifeDays: Config.values.launcher.halfLifeDays
    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`

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

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
    }
}
