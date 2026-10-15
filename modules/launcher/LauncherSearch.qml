pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.settings
import "search.js" as Search
import "../files/marks.js" as Marks
import "../settings/catalogue.js" as Catalogue
import "../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property string query
    required property string screenName

    property string armed: ""

    signal launch(var what)
    signal leave(var what)
    signal retype(string text)

    readonly property var caps: ({
            apps: 8,
            commands: 4,
            settings: 5,
            files: 6
        })

    readonly property string text: root.query.trim()
    readonly property var path: Search.pathQuery(root.query, Files.home)
    readonly property string url: Search.urlOf(root.text)

    onQueryChanged: {
        root.armed = "";
        const typed = Search.pathQuery(root.query, Files.home);
        if (typed)
            FileSearch.list(typed.dir);
        else
            FileSearch.find(root.query);
    }

    function appScore(entry: var): real {
        const tier = Apps.tier(entry, root.text);
        return tier >= 3 ? tier - 2 : tier === 2 ? 0.5 : tier === 1 ? 0.25 : 0.1;
    }

    function wordScore(label: string, words: string): real {
        return Math.max(Ranking.place(label, root.text), Ranking.place(words, root.text) - 0.5);
    }

    readonly property var commands: [
        {
            id: "lock",
            icon: "lock",
            label: "Lock screen",
            words: "lock screen away",
            run: () => Lock.lock()
        },
        {
            id: "suspend",
            icon: "bedtime",
            label: "Suspend",
            words: "sleep suspend",
            run: () => Suspension.perform("suspend")
        },
        {
            id: "hibernate",
            icon: "mode_standby",
            label: "Hibernate",
            words: "hibernate",
            hidden: !Suspension.hibernatePossible,
            run: () => Suspension.perform("hibernate")
        },
        {
            id: "reboot",
            icon: "restart_alt",
            label: "Restart",
            words: "reboot restart",
            confirm: true,
            run: () => root.power("reboot")
        },
        {
            id: "poweroff",
            icon: "power_settings_new",
            label: "Shut down",
            words: "shut down power off turn off shutdown",
            confirm: true,
            run: () => root.power("poweroff")
        },
        {
            id: "logout",
            icon: "logout",
            label: "Log out",
            words: "log out sign out logout exit",
            confirm: true,
            run: () => root.power("logout")
        },
        {
            id: "clipboard",
            icon: "content_paste",
            label: "Clipboard history",
            words: "clipboard paste copied history",
            run: () => Shell.forScreen(root.screenName)?.clipboard.show()
        },
        {
            id: "wallpapers",
            icon: "wallpaper",
            label: "Wallpapers",
            words: "wallpaper background picture",
            run: () => Shell.forScreen(root.screenName)?.wallpapers.show()
        },
        {
            id: "settings",
            icon: "tune",
            label: "Settings",
            words: "settings preferences options",
            run: () => Settings.show(root.screenName, "")
        },
        {
            id: "playpause",
            icon: Media.playing ? "pause" : "play_arrow",
            label: Media.playing ? "Pause" : "Play",
            words: "play pause resume music media",
            hidden: !Media.available,
            run: () => Media.toggle()
        },
        {
            id: "next",
            icon: "skip_next",
            label: "Next track",
            words: "next skip track song music",
            hidden: !Media.available,
            run: () => Media.next()
        },
        {
            id: "previous",
            icon: "skip_previous",
            label: "Previous track",
            words: "previous back track song music",
            hidden: !Media.available,
            run: () => Media.previous()
        }
    ]

    function power(key: string): void {
        const entry = Power.actions.find(a => a.key === key);
        if (entry)
            Power.run(entry);
    }

    function liveToggle(row: var): bool {
        return row.kind === "toggle" && !SettingsState.plannedKey(row.k) && !(row.dis && row.dis(SettingsState));
    }

    readonly property var appRows: Apps.search(root.text).map(entry => ({
                key: `app:${entry.id}`,
                kind: "app",
                entry: entry,
                label: entry.name ?? "",
                detail: entry.genericName || entry.comment || "",
                iconSource: entry.icon ? Quickshell.iconPath(entry.icon, true) : "",
                icon: "apps",
                score: root.appScore(entry)
            }))

    readonly property var commandRows: root.text.length < 2 ? [] : root.commands.filter(c => !c.hidden).map(c => ({
                key: `command:${c.id}`,
                kind: "command",
                command: c,
                label: root.armed === c.id ? `Press Enter again to ${c.label.toLowerCase()}` : c.label,
                detail: "",
                icon: c.icon,
                score: root.wordScore(c.label, c.words)
            })).filter(r => r.score > 0).sort((a, b) => b.score - a.score)

    readonly property var settingRows: root.text.length < 2 ? [] : Catalogue.search(root.text).map(hit => {
        const live = root.liveToggle(hit.row);
        const group = typeof hit.group.t === "string" ? hit.group.t : "";
        return {
            key: `setting:${hit.page.id}:${hit.row.k ?? hit.label}`,
            kind: "setting",
            hit: hit,
            label: hit.label,
            detail: group ? `${hit.page.name} › ${group}` : hit.page.name,
            icon: hit.row.icon || hit.page.icon || "tune",
            toggle: live ? !!SettingsState.v(hit.row.k) : undefined,
            score: Math.max(0.5, Ranking.place(hit.label, root.text))
        };
    })

    function fileRow(f: var, prefix: string): var {
        return {
            key: `${prefix}:${f.path}`,
            kind: "file",
            path: f.path,
            dir: f.dir,
            label: f.name,
            detail: Search.shortPath(f.path.slice(0, f.path.lastIndexOf("/")) || "/", Files.home),
            icon: Marks.iconFor(f.path, f.name, f.dir, Files.home) || (f.dir ? "folder" : "draft"),
            score: f.score ?? 0
        };
    }

    readonly property var fileRows: root.path || root.text.length < FileSearch.least ? [] : Search.fileRows(FileSearch.lines, root.text, Ranking.place).map(f => root.fileRow(Object.assign({}, f, {
                score: f.score - Ranking.EXACT
            }), "file"))

    readonly property var pathRows: root.path && FileSearch.listedDir === root.path.dir ? Search.pathRows(FileSearch.entries, root.path, FileSearch.hidden, Files.home).map(f => root.fileRow(f, "path")) : []

    readonly property var rows: root.keyed(root.arranged)

    function keyed(rows: var): var {
        return rows.map(r => r.header ? r : Object.assign({}, r, {
                key: `${r.key}|${r.label}|${r.toggle}`
            }));
    }

    readonly property var arranged: {
        if (!root.text)
            return root.appRows;
        if (root.path)
            return root.pathRows;
        const groups = [];
        if (root.url)
            groups.push({
                key: "link",
                title: "Link",
                items: [
                    {
                        key: `link:${root.url}`,
                        kind: "link",
                        label: `Open ${root.text}`,
                        detail: "",
                        icon: "link",
                        score: Infinity
                    }
                ]
            });
        groups.push({
            key: "apps",
            title: "Apps",
            items: root.appRows
        }, {
            key: "commands",
            title: "Commands",
            items: root.commandRows
        }, {
            key: "settings",
            title: "Settings",
            items: root.settingRows
        }, {
            key: "files",
            title: "Files",
            items: root.fileRows
        }, {
            key: "web",
            title: "Web",
            items: [
                {
                    key: "web",
                    kind: "web",
                    label: `Search the web for “${root.text}”`,
                    detail: "",
                    icon: "travel_explore",
                    score: -Infinity
                }
            ]
        });
        return Search.arrange(groups, root.caps);
    }

    function openSetting(row: var): void {
        const hit = row.hit;
        root.leave(() => Settings.openAt(root.screenName, hit.page.id, hit.row.k ?? ""));
    }

    function activate(row: var): void {
        switch (row?.kind) {
        case "app":
            root.launch(() => Apps.launch(row.entry));
            return;
        case "command":
            if (row.command.confirm && root.armed !== row.command.id) {
                root.armed = row.command.id;
                return;
            }
            root.leave(row.command.run);
            return;
        case "setting":
            if (row.toggle !== undefined)
                SettingsState.set(row.hit.row.k, !row.toggle);
            else
                root.openSetting(row);
            return;
        case "file":
            if (row.dir && root.path)
                root.retype(`${Search.shortPath(row.path, Files.home)}/`);
            else if (row.dir)
                root.leave(() => Files.show(row.path));
            else
                root.launch(() => Files.openWith(row.path));
            return;
        case "link":
            root.launch(() => Quickshell.execDetached(["xdg-open", root.url]));
            return;
        case "web":
            root.launch(() => Quickshell.execDetached(["xdg-open", Search.webSearchUrl(Config.values.launcher.webSearch, root.text)]));
            return;
        }
    }

    function complete(row: var): bool {
        if (row?.kind !== "file")
            return false;
        root.retype(`${Search.shortPath(row.path, Files.home)}${row.dir ? "/" : ""}`);
        return true;
    }

    function actionsFor(row: var): var {
        switch (row?.kind) {
        case "file":
            return [
                {
                    icon: row.dir ? "folder_open" : "open_in_new",
                    label: "Open",
                    run: () => row.dir ? root.leave(() => Files.show(row.path)) : root.launch(() => Files.openWith(row.path))
                },
                {
                    icon: "drive_file_move",
                    label: "Show in folder",
                    run: () => root.leave(() => Files.reveal(row.path))
                },
                {
                    icon: "content_copy",
                    label: "Copy path",
                    run: () => root.leave(() => Files.copyText(row.path))
                }
            ];
        case "setting":
            return row.toggle === undefined ? [
                {
                    icon: "tune",
                    label: "Open in settings",
                    run: () => root.openSetting(row)
                }
            ] : [
                {
                    icon: row.toggle ? "toggle_off" : "toggle_on",
                    label: row.toggle ? "Turn off" : "Turn on",
                    run: () => root.activate(row)
                },
                {
                    icon: "tune",
                    label: "Open in settings",
                    run: () => root.openSetting(row)
                }
            ];
        case "link":
            return [
                {
                    icon: "link",
                    label: "Open",
                    run: () => root.activate(row)
                },
                {
                    icon: "content_copy",
                    label: "Copy link",
                    run: () => root.leave(() => Files.copyText(root.url))
                }
            ];
        case "command":
        case "web":
            return [
                {
                    icon: row.icon,
                    label: row.kind === "command" ? row.command.label : row.label,
                    run: () => root.activate(row)
                }
            ];
        }
        return [];
    }
}
