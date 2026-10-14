pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "catalogue.js" as Catalogue
import "restore.js" as Restore

Singleton {
    id: root

    function world(): var {
        return {
            defaults: Config.defaults,
            opaque: Config.opaque,
            current: Config.values,
            configBacked: SettingsState.configBacked,
            planDefaults: SettingsState.planDefaults,
            planned: SettingsState.planned,
            servicePaths: {
                theme: "theme"
            },
            fits: (path, value) => Config.accepts(path, value) && (path !== "theme" || Themes.availableNames.includes(value)),
            transformWrite: (key, value) => {
                const transform = SettingsState.transforms[key];
                return transform ? transform.write(value) : value;
            },
            hasRow: key => !!SettingsState.rowOf(key),
            rowValue: key => SettingsState.v(key)
        };
    }

    function examine(text: string): var {
        const read = Restore.read(text);
        if (read.why)
            return {
                why: read.why,
                changes: [],
                skipped: []
            };
        return Object.assign({
            why: ""
        }, Restore.diff(read.file, root.world()));
    }

    function inRowTerms(change: var, value: var): var {
        const transform = change.route === "config" ? SettingsState.transforms[change.key] : null;
        return transform ? transform.read(value) : value;
    }

    function describe(change: var): var {
        const row = change.key ? SettingsState.rowOf(change.key) : null;
        const say = value => value !== null && typeof value === "object" ? Restore.phrase(value) : row ? SettingsState.shown(row, value) : Restore.phrase(value);
        const label = (row ? Catalogue.labelOf(row) : "") || change.path || change.key;
        return {
            icon: row?.icon || "tune",
            label,
            detail: `${say(root.inRowTerms(change, change.from))} → ${say(root.inRowTerms(change, change.to))}`
        };
    }

    function loggable(change: var): bool {
        if (!change.key || !SettingsState.rowOf(change.key))
            return false;
        const from = root.inRowTerms(change, change.from);
        const to = root.inRowTerms(change, change.to);
        return (from === null || typeof from !== "object") && (to === null || typeof to !== "object");
    }

    function apply(changes: var): int {
        const pairs = [];
        const planned = Object.assign({}, SettingsState.planned);
        const settings = [];
        const was = {
            config: [],
            planned: {},
            settings: {}
        };
        const now = {
            config: [],
            planned: {},
            settings: {}
        };
        let grouped = 0;
        const logged = [];

        for (const change of changes) {
            if (root.loggable(change)) {
                logged.push({
                    key: change.key,
                    from: root.inRowTerms(change, change.from),
                    to: root.inRowTerms(change, change.to)
                });
            } else {
                grouped++;
                if (change.route === "config") {
                    was.config.push([change.path, change.from]);
                    now.config.push([change.path, change.to]);
                } else if (change.route === "planned") {
                    was.planned[change.key] = change.from;
                    now.planned[change.key] = change.to;
                } else {
                    was.settings[change.key] = change.from;
                    now.settings[change.key] = change.to;
                }
            }
            if (change.route === "config")
                pairs.push([change.path, change.to]);
            else if (change.route === "planned")
                planned[change.key] = change.to;
            else
                settings.push(change);
        }

        if (pairs.length)
            Config.setMany(pairs);
        SettingsState.planned = planned;

        SettingsState.muteLog = true;
        for (const change of settings)
            SettingsState.set(change.key, change.to);
        SettingsState.muteLog = false;

        for (const entry of logged)
            SettingsState.log(entry.key, SettingsState.rowOf(entry.key), entry.from, entry.to);

        if (grouped) {
            const list = SettingsState.changes.slice();
            list.unshift({
                k: "restore",
                label: "Restored settings",
                page: "shell",
                from: "as they were",
                to: `${grouped} from a file`,
                old: was,
                v: now,
                t: Date.now()
            });
            SettingsState.changes = list.slice(0, 30);
        }
        SettingsState.save();
        return changes.length;
    }

    function putBack(snapshot: var): void {
        if (snapshot.config?.length)
            Config.setMany(snapshot.config);
        const planned = Object.assign({}, SettingsState.planned, snapshot.planned ?? {});
        SettingsState.planned = planned;
        SettingsState.muteLog = true;
        for (const key of Object.keys(snapshot.settings ?? {}))
            SettingsState.set(key, snapshot.settings[key]);
        SettingsState.muteLog = false;
        SettingsState.save();
    }
}
