pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "desktop-entries.js" as Entries
import "startup-apps.js" as StartupLog

Singleton {
    id: root

    readonly property string xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string autostartDir: `${root.xdgConfig}/autostart`
    readonly property string userUnitDir: `${root.xdgConfig}/systemd/user`
    readonly property var desktops: String(Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").split(":").filter(Boolean)

    readonly property string readAutostartScript: "for f in \"$1\"/*.desktop; do [ -f \"$f\" ] || continue; printf '\\n@@@%s\\n' \"$f\"; cat \"$f\"; done"
    readonly property string launcherDir: `${root.xdgConfig}/autostart-managed`
    readonly property string readLauncherScript: "dir=$1; [ -d \"$dir\" ] || exit 0; for f in \"$dir\"/*.desktop; do [ -f \"$f\" ] || continue; printf '\\n@@@%s\\n' \"$f\"; cat \"$f\"; printf '\\n@@@override %s\\n' \"$f\"; o=\"$dir/overrides/$(basename \"$f\" .desktop).conf\"; [ -f \"$o\" ] && cat \"$o\"; done"
    readonly property string writeFileScript: "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\""
    readonly property string launchScript: "[ -n \"$XDG_RUNTIME_DIR\" ] || exit 0; signature=$1; shift; systemctl --user is-active --quiet xdg-desktop-autostart.target && exit 0; mkdir \"$XDG_RUNTIME_DIR/banditshell-autostart-$signature\" 2>/dev/null || exit 0; for command; do setsid -f sh -c \"$command\" </dev/null >/dev/null 2>&1; done"

    property var autostartFiles: []
    property var launcherFiles: []
    property var unitFiles: []
    property var unitShows: []
    property var intents: ({})
    property var writeQueue: []
    property bool sessionHandled: false
    property bool autostartRead: false
    property bool launcherRead: false
    property bool unitsRead: false

    readonly property bool sourcesRead: root.autostartRead && root.launcherRead && root.unitsRead && HyprConfig.scanned && DesktopIndex.loaded

    onSourcesReadChanged: {
        if (root.sourcesRead)
            root.launchSession();
    }
    property string unitsShown: ""

    readonly property var hyprlandRows: StartupLog.hyprlandApps(HyprConfig.files.map(f => ({
                name: f.name,
                text: HyprConfig.texts[f.path] ?? ""
            })))
    readonly property var systemdRows: StartupLog.systemdApps(root.unitFiles, root.unitShows, DesktopIndex.byProgram, root.userUnitDir)
    readonly property var autostartRows: StartupLog.autostartApps(root.autostartFiles, root.desktops, Entries.shownIn)

    readonly property var launcherRows: StartupLog.launcherEnabled(root.unitFiles) ? StartupLog.launcherApps(root.launcherFiles, `${root.launcherDir}/overrides`) : []

    function present(row: var, fields: var): var {
        return Object.assign({
            id: row.id,
            row,
            on: root.intents[row.id] ?? row.on
        }, fields);
    }

    function hyprlandEntry(row: var): var {
        const known = DesktopIndex.forCommand(row.command);
        const program = Entries.programOf(row.command);
        return root.present(row, {
            source: "hyprland",
            name: known?.name || program || row.command,
            desktopId: known?.id ?? "",
            mark: DesktopIndex.markForIcon(known?.icon ?? "", known?.id ?? program),
            note: row.wrapped ? "hyprland · after the shell" : "hyprland",
            removable: false
        });
    }

    function systemdEntry(row: var): var {
        const known = DesktopIndex.byProgram[row.program] ?? null;
        return root.present(row, {
            source: "systemd",
            name: known?.name || row.description || row.unit,
            desktopId: known?.id ?? "",
            mark: DesktopIndex.markForIcon(known?.icon ?? "", known?.id ?? row.program),
            note: "systemd",
            removable: false
        });
    }

    function autostartEntry(row: var): var {
        const base = row.file.replace(/\.desktop$/, "");
        return root.present(row, {
            source: "autostart",
            name: row.entry.name || base,
            desktopId: row.file,
            mark: DesktopIndex.markForIcon(row.entry.icon, base),
            note: row.entry.terminal ? "autostart · needs a terminal" : Config.values.startup.runAutostart ? "autostart" : "autostart · not started here yet",
            removable: true
        });
    }

    function launcherEntry(row: var): var {
        const base = row.file.replace(/\.desktop$/, "");
        const known = DesktopIndex.entryFor(row.file);
        return root.present(row, {
            source: "launcher",
            name: row.entry.name || base,
            desktopId: row.file,
            mark: DesktopIndex.markForIcon(row.entry.icon || known?.icon || "", base),
            note: row.delay ? `launcher · ${row.delay} s delay` : "launcher",
            removable: false
        });
    }

    readonly property var listed: root.hyprlandRows.map(r => root.hyprlandEntry(r)).concat(root.systemdRows.map(r => root.systemdEntry(r)), root.autostartRows.map(r => root.autostartEntry(r)), root.launcherRows.map(r => root.launcherEntry(r)))

    readonly property var duplicates: StartupLog.duplicateNotes(root.listed)

    readonly property var entries: root.listed.map(e => root.duplicates[e.id] ? Object.assign({}, e, {
            note: `${e.note} · ${root.duplicates[e.id]}`
        }) : e)

    readonly property var claimed: {
        const out = [];
        for (const entry of root.entries) {
            if (!entry.desktopId)
                continue;
            out.push(entry.desktopId);
            out.push(entry.desktopId.replace(/\.desktop$/, ""));
        }
        return out;
    }

    readonly property string summary: StartupLog.startSummary(root.entries)

    function change(request: var): void {
        if (request.add)
            return root.addApp(request.add);
        if (request.restore)
            return root.queueWrite(request.restore.path, request.restore.text);
        const entry = root.entries.find(e => e.id === request.id);
        if (!entry)
            return;
        if (request.remove)
            return root.removeApp(entry);
        root.switchApp(entry, request.on);
    }

    function needsHyprlandEdits(request: var): bool {
        const entry = root.entries.find(e => e.id === request?.id);
        return entry?.source === "hyprland";
    }

    function remember(id: string, on: bool): void {
        root.intents = Object.assign({}, root.intents, {
            [id]: on
        });
        forget.restart();
    }

    function switchApp(entry: var, on: bool): void {
        const row = entry.row;
        if (entry.source === "hyprland") {
            HyprConfig.toggleStartup(entry.id, on);
        } else if (entry.source === "systemd") {
            unitSwitch.command = ["systemctl", "--user", on ? "enable" : "disable", row.unit];
            unitSwitch.running = true;
        } else if (entry.source === "launcher") {
            root.queueWrite(row.overridePath, StartupLog.setDisabled(row.overrideText, !on));
        } else {
            root.queueWrite(row.path, Entries.setHidden(row.text, !on));
            if (on)
                root.runAutostart();
        }
        root.remember(entry.id, on);
    }

    function removeApp(entry: var): void {
        if (entry.source === "autostart")
            root.queueWrite(entry.row.path, null);
    }

    function addApp(app: var): void {
        const file = Entries.autostartName(app.id);
        if (!file)
            return;
        const known = root.entries.find(e => e.id === `autostart:${file}`);
        if (known)
            return root.switchApp(known, true);
        root.queueWrite(`${root.autostartDir}/${file}`, Entries.autostartText(app));
        root.runAutostart();
    }

    function runAutostart(): void {
        if (!Config.values.startup.runAutostart)
            Config.set("startup.runAutostart", true);
    }

    function queueWrite(path: string, text: var): void {
        root.writeQueue = root.writeQueue.concat([
            {
                path,
                text
            }
        ]);
        root.pump();
    }

    function pump(): void {
        if (fileJob.running || !root.writeQueue.length)
            return;
        const job = root.writeQueue[0];
        root.writeQueue = root.writeQueue.slice(1);
        fileJob.command = job.text === null ? ["rm", "-f", job.path] : ["sh", "-c", root.writeFileScript, "sh", job.path, job.text];
        fileJob.running = true;
    }

    function readAutostart(): void {
        autostartReader.command = ["sh", "-c", root.readAutostartScript, "sh", root.autostartDir];
        autostartReader.running = true;
    }

    function readLauncher(): void {
        launcherReader.command = ["sh", "-c", root.readLauncherScript, "sh", root.launcherDir];
        launcherReader.running = true;
    }

    function readUnits(): void {
        unitLister.running = true;
    }

    function launchSession(): void {
        if (root.sessionHandled || !HyprConfig.signature || !Config.values.startup.runAutostart)
            return;
        root.sessionHandled = true;
        const elsewhere = root.entries.filter(e => e.source !== "autostart" && e.on && e.desktopId).map(e => e.desktopId.replace(/\.desktop$/, ""));
        launcher.command = ["sh", "-c", root.launchScript, "sh", HyprConfig.signature].concat(Entries.sessionLaunches(root.autostartFiles, root.desktops, elsewhere));
        launcher.running = true;
    }

    Component.onCompleted: {
        root.readAutostart();
        root.readLauncher();
        root.readUnits();
    }

    Timer {
        interval: 30000
        running: !root.sessionHandled
        onTriggered: root.launchSession()
    }

    Timer {
        id: forget

        interval: 6000
        onTriggered: root.intents = {}
    }

    Process {
        id: autostartReader

        stdout: StdioCollector {
            onStreamFinished: {
                root.autostartFiles = Entries.parseBundle(text);
                root.autostartRead = true;
            }
        }
    }

    Process {
        id: launcherReader

        stdout: StdioCollector {
            onStreamFinished: {
                root.launcherFiles = Entries.parseBundle(text);
                root.launcherRead = true;
            }
        }
    }

    Process {
        id: fileJob

        onRunningChanged: {
            if (fileJob.running)
                return;
            root.readAutostart();
            root.readLauncher();
            root.pump();
        }
    }

    Process {
        id: launcher
    }

    Process {
        id: unitLister

        command: ["systemctl", "--user", "list-unit-files", "--type=service", "--no-legend", "--no-pager"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.unitFiles = StartupLog.parseUnitFiles(text);
                const names = StartupLog.candidateUnits(root.unitFiles);
                const key = names.join(" ");
                if (!names.length || key === root.unitsShown) {
                    root.unitsRead = true;
                    return;
                }
                root.unitsShown = key;
                unitShower.command = ["systemctl", "--user", "show", "-p", "Id", "-p", "Description", "-p", "FragmentPath", "-p", "ExecStart"].concat(names);
                unitShower.running = true;
            }
        }
    }

    Process {
        id: unitShower

        stdout: StdioCollector {
            onStreamFinished: {
                root.unitShows = StartupLog.parseUnitShow(text);
                root.unitsRead = true;
            }
        }
    }

    Process {
        id: unitSwitch

        onRunningChanged: {
            if (!unitSwitch.running)
                root.readUnits();
        }
    }
}
