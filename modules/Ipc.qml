pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    required property var picker

    readonly property string bootsTheService: HyprConfig.state

    function penmapStatus(): string {
        const r = PenMap.region;
        const lock = PenMap.aspectLocked ? "locked" : "free";
        const pad = PenMap.padConnected ? "pad" : "no pad";
        const mode = PenMap.followWindow ? ", follow" : "";
        return `${Math.round(r.width)}x${Math.round(r.height)} at ${Math.round(r.x)},${Math.round(r.y)} on ${PenMap.monitorName || "no monitor"} (${lock}, ${pad}${mode})`;
    }

    IpcHandler {
        target: "menu"

        function list(): string {
            const win = Shell.forScreen("");
            return win ? win.statusKeys.join("\n") : "";
        }

        function open(key: string, screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return win.openMenu(key) ? `open ${key}` : `no such menu: ${key}`;
        }

        function close(): string {
            for (const win of Shell.windows)
                win.menus.hide();
            return "closed";
        }

        function toggle(key: string, screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.menus.currentKey === key);
            if (win?.menus.currentKey === key)
                return close();
            return open(key, screen);
        }

        function current(): string {
            const win = Shell.showing(w => w.menus.currentKey);
            return win?.menus.currentKey ?? "";
        }

        function hover(): string {
            const win = Shell.showing(w => w.menus.currentKey);
            if (!win)
                return "no shell window";
            return `shell=${win.cursorOnShell} panel=${win.menus.hovered} open=[${win.menus.currentKey}] keyboard=${win.menus.needsKeyboard}`;
        }
    }

    IpcHandler {
        target: "picker"

        function open(): string {
            root.picker.show(false, false);
            return "picker";
        }

        function freeze(): string {
            root.picker.show(true, false);
            return "picker (frozen)";
        }

        function clip(): string {
            root.picker.show(false, true);
            return "picker (to clipboard)";
        }

        function freezeclip(): string {
            root.picker.show(true, true);
            return "picker (frozen, to clipboard)";
        }

        function close(): string {
            root.picker.close();
            return "closed";
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): string {
            const win = Shell.showing(w => w.launcher.open);
            if (!win)
                return "no shell window";
            win.launcher.toggle();
            return win.launcher.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.launcher.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.launcher.hide();
            return "closed";
        }

        function run(id: string): string {
            const entry = Apps.entryById(id) ?? Apps.search(id)[0];
            if (!entry)
                return `no application matches "${id}"`;
            Apps.launch(entry);
            Hypr.claimNextWindow();
            return `launched ${entry.name}`;
        }

        function scrub(fraction: string): string {
            const win = Shell.showing(w => w.launcher.open);
            if (!win)
                return "no shell window";
            win.launcher.scrub(parseFloat(fraction));
            return `scrubbed to ${fraction}`;
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): string {
            const win = Shell.showing(w => w.clipboard.open);
            if (!win)
                return "no shell window";
            win.clipboard.toggle();
            return win.clipboard.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.clipboard.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.clipboard.hide();
            return "closed";
        }

        function list(): string {
            const rows = Clipboard.entries.map((e, i) => {
                const what = Clipboard.summarise(e).replace(/\s+/g, " ").trim();
                return `${i}\t${e.pinned ? "*" : " "}\t${e.kind}\t${what.slice(0, 120)}`;
            });
            return rows.join("\n");
        }

        function use(index: string): string {
            const at = parseInt(index, 10);
            const entry = Clipboard.entries[at];
            if (!entry)
                return `no entry ${index}`;
            Clipboard.copy(entry);
            return `copied ${entry.kind}: ${Clipboard.summarise(entry).slice(0, 80)}`;
        }

        function pin(index: string): string {
            const at = parseInt(index, 10);
            const entry = Clipboard.entries[at];
            if (!entry)
                return `no entry ${index}`;
            Clipboard.setPinned(entry, !entry.pinned);
            return entry.pinned ? "let go" : "kept";
        }

        function remove(index: string): string {
            const at = parseInt(index, 10);
            const entry = Clipboard.entries[at];
            if (!entry)
                return `no entry ${index}`;
            Clipboard.remove(entry);
            return "removed";
        }

        function clear(): string {
            const before = Clipboard.entries.length;
            Clipboard.clear();
            return `cleared ${before - Clipboard.entries.length}, kept ${Clipboard.entries.length}`;
        }

        function status(): string {
            const win = Shell.showing(w => w.clipboard.open);
            const kinds = {};
            for (const e of Clipboard.entries)
                kinds[e.kind] = (kinds[e.kind] ?? 0) + 1;
            const tally = Object.keys(kinds).sort().map(k => `${k}=${kinds[k]}`).join(" ");
            return `recording=${Clipboard.recording} entries=${Clipboard.entries.length} pinned=${Clipboard.entries.filter(e => e.pinned).length} open=${win?.clipboard.open ?? false} ${tally}`;
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): string {
            const win = Shell.showing(w => w.session.open);
            if (!win)
                return "no shell window";
            win.session.toggle();
            return win.session.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.session.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.session.hide();
            return "closed";
        }
    }

    IpcHandler {
        target: "media"

        function toggle(): string {
            const win = Shell.showing(w => w.media.open);
            if (!win)
                return "no shell window";
            win.media.toggle();
            return win.media.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.media.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.media.hide();
            return "closed";
        }

        function status(): string {
            const win = Shell.showing(w => w.media.open);
            return `open=${win?.media.open ?? false} player=${Media.app || "none"} playing=${Media.playing} title="${Media.title}"`;
        }
    }

    IpcHandler {
        target: "calculator"

        function toggle(): string {
            const win = Shell.showing(w => w.calculator.open);
            if (!win)
                return "no shell window";
            win.calculator.toggle();
            return win.calculator.open ? "open" : "closed";
        }

        function open(): string {
            Shell.forScreen("")?.calculator.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.calculator.hide();
            return "closed";
        }

        function app(): string {
            const win = Shell.showing(w => w.calculator.open);
            if (!win)
                return "no shell window";
            if (win.calculator.open && win.calculator.full)
                return close();
            win.calculator.app();
            return "open";
        }

        function panel(): string {
            const win = Shell.showing(w => w.calculator.open);
            if (!win)
                return "no shell window";
            if (win.calculator.open && !win.calculator.full)
                return close();
            win.calculator.panel();
            return "open";
        }

        function status(): string {
            const win = Shell.showing(w => w.calculator.open);
            return `open=${win?.calculator.open ?? false} shape=${win?.calculator.full ? "app" : "panel"}`;
        }

        function answer(expression: string): string {
            const result = Calc.evaluate(expression);
            return result ? result.text : `not an expression: ${expression}`;
        }
    }

    IpcHandler {
        target: "tablet"

        function on(from: string): string {
            return Tablet.apply("on", from || "cli");
        }

        function off(from: string): string {
            return Tablet.apply("off", from || "cli");
        }

        function toggle(from: string): string {
            return Tablet.apply("toggle", from || "cli");
        }

        function lid(state: string, from: string): string {
            return Tablet.applyLid(state, from || "cli");
        }

        function status(): string {
            const state = Tablet.folding ? "folded" : "flat";
            const hinge = `${Tablet.known ? "known" : "assumed"}, via ${Tablet.source}`;
            const lid = `${Tablet.lidClosed ? "closed" : "open"}, ${Tablet.lidKnown ? "known" : "assumed"}, via ${Tablet.lidSource}`;

            return `${state} (hinge ${Tablet.hinge ? "on" : "off"}, ${hinge}; lid ${lid})`;
        }
    }

    IpcHandler {
        target: "keyboard"

        function toggle(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
            if (!win)
                return "no shell window";
            win.keyboard.toggle();
            return win.keyboard.open ? "open" : "closed";
        }

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return "no shell window";
            win.keyboard.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.keyboard.hide();
            return "closed";
        }

        function status(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
            if (!win)
                return "no shell window";
            return `${win.keyboard.open ? "open" : "closed"} on "${win.keyboard.page}"`;
        }

        function dock(): string {
            Tablet.setDocked(true);
            return "docked";
        }

        function float(): string {
            Tablet.setDocked(false);
            return "floating";
        }

        function page(name: string, screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.keyboard.open);
            if (!win)
                return "no shell window";
            win.keyboard.page = name;
            return `page ${name}`;
        }
    }

    IpcHandler {
        target: "hotkeys"

        function toggle(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.hotkeys.open);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.hotkeys.toggle();
            return win.hotkeys.open ? "open" : "closed";
        }

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.hotkeys.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.hotkeys.hide();
            return "closed";
        }

        function status(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.hotkeys.open);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return `open=${win.hotkeys.open} binds=${win.hotkeys.rows.length} described=${win.hotkeys.rows.length - win.hotkeys.unnamed} groups=${win.hotkeys.sections.length}`;
        }
    }

    IpcHandler {
        target: "notifications"

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notifications.pinned = true;
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.notifications.pinned = false;
            return "closed";
        }

        function toggle(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notifications.pinned = !win.notifications.pinned;
            return win.notifications.pinned ? "open" : "closed";
        }

        function clear(): string {
            Notifs.clear();
            return "cleared";
        }

        function status(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return `count=${Notifs.count} pinned=${win.notifications.pinned} expanded=${win.notifications.expanded}`;
        }

        function held(app: string): string {
            if (!app)
                return "0";
            const key = app.toLowerCase();
            const attended = e => e?.held && (e.appName ?? "").toLowerCase() === key;
            return Notifs.popups.some(attended) || Notifs.history.some(attended) ? "1" : "0";
        }
    }

    IpcHandler {
        target: "notch"

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notch.pinned = true;
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.notch.pinned = false;
            return "closed";
        }

        function toggle(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.notch.pinned = !win.notch.pinned;
            return win.notch.pinned ? "open" : "closed";
        }

        function status(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            return `pinned=${win.notch.pinned} active=${win.notch.active}`;
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): string {
            Settings.toggle();
            return Settings.open ? "open" : "closed";
        }

        function open(page: string, screen: string): string {
            if (page && !Settings.pages.some(p => p.key === page))
                return `no such page: ${page} (have: ${Settings.pages.map(p => p.key).join(", ")})`;
            if (screen && !Shell.forScreen(screen))
                return `no shell window on screen: ${screen}`;
            Settings.show(screen, page);
            if (page)
                Settings.setPage(page);
            return page ? `open at ${page}` : "open";
        }

        function close(): string {
            Settings.hide();
            return "closed";
        }

        function page(key: string): string {
            if (!key)
                return Settings.page || "no page";
            if (!Settings.pages.some(p => p.key === key))
                return `no such page: ${key} (have: ${Settings.pages.map(p => p.key).join(", ")})`;
            Settings.setPage(key);
            return `page ${key}`;
        }

        function status(): string {
            return [`open       ${Settings.open}`, `page       ${Settings.page || "-"}`, `screen     ${Settings.screenName || "-"}`].join("\n");
        }
    }

    function nudgeVolume(sign: int, count: string): string {
        if (!Audio.ready)
            return "no audio sink";
        const n = parseFloat(count);
        const steps = n > 0 ? n : 1;
        const target = Audio.quantise(Audio.volume + sign * steps * Appearance.sizes.volumeStep);
        Audio.setVolume(target);
        return `${Math.round(target * 100)}%`;
    }

    IpcHandler {
        target: "files"

        function open(path: string): string {
            Files.show(path);
            return path ? `files ${path}` : "files";
        }

        function toggle(path: string): string {
            Files.toggle(path);
            return Files.windowOpen ? "open" : "closed";
        }

        function close(): string {
            Files.hide();
            return "closed";
        }

        function status(): string {
            const shell = Files.term ? `rows=${Files.term.rows} alt=${Files.term.altActive}` : "no session";
            return `open=${Files.windowOpen} cwd=${Files.cwd} entries=${Files.entries.length} focus=${Files.focus} terminal=[${shell}] error=[${Files.error}]`;
        }
    }

    IpcHandler {
        target: "volume"

        function up(count: string): string {
            return root.nudgeVolume(1, count);
        }

        function down(count: string): string {
            return root.nudgeVolume(-1, count);
        }

        function set(pct: string): string {
            if (!Audio.ready)
                return "no audio sink";
            const n = parseFloat(pct);
            if (!isFinite(n))
                return `not a number: ${pct}`;
            const target = Audio.quantise(n / 100);
            Audio.setVolume(target);
            return `${Math.round(target * 100)}%`;
        }

        function mute(state: string): string {
            if (!Audio.ready)
                return "no audio sink";
            if (state && state !== "on" && state !== "off")
                return `mute takes on or off, not: ${state}`;
            const want = state === "on" || (state !== "off" && !Audio.muted);
            if (want !== Audio.muted)
                Audio.toggleMute();
            return want ? "muted" : "unmuted";
        }

        function status(): string {
            if (!Audio.ready)
                return "no audio sink";
            return `volume=${Math.round(Audio.volume * 100)}% muted=${Audio.muted} ceiling=${Math.round(Audio.maxVolume * 100)}%`;
        }
    }

    function roleLine(role: string): string {
        const node = Audio.roleNode(role);
        return node ? `${role} (${Audio.deviceLabel(node)})` : role;
    }

    function goRole(role: string): string {
        const landed = Audio.setOutputRole(role);
        return landed ? root.roleLine(landed) : `cannot switch to ${role}: ${Audio.roleProblem(role)}`;
    }

    IpcHandler {
        target: "output"

        function toggle(): string {
            const landed = Audio.toggleOutput();
            if (landed)
                return root.roleLine(landed);
            if (Audio.rolesCollide)
                return "speakers and headphones name the same device, so there is nowhere to toggle to";

            if (Audio.outputRole) {
                const other = Audio.outputRole === "speakers" ? "headphones" : "speakers";
                return `cannot switch to ${other}: ${Audio.roleProblem(other)}`;
            }
            return `cannot switch: speakers ${Audio.roleProblem("speakers")}; headphones ${Audio.roleProblem("headphones")}`;
        }

        function speakers(): string {
            return root.goRole("speakers");
        }

        function headphones(): string {
            return root.goRole("headphones");
        }

        function status(): string {
            const say = role => {
                const name = Audio.roleName(role);
                if (!name)
                    return "not assigned";
                const node = Audio.roleNode(role);
                return node ? `${Audio.deviceLabel(node)} · ${name}` : `${name} · not connected`;
            };

            const on = Audio.outputRole || (Audio.sink ? `neither, playing through ${Audio.deviceLabel(Audio.sink)}` : "no output device");
            const lines = [`playing     ${on}`, `speakers    ${say("speakers")}`, `headphones  ${say("headphones")}`];
            if (Audio.rolesCollide)
                lines.push("both roles name one device, so the toggle cannot move the sound");
            return lines.join("\n");
        }

        function list(): string {
            if (!Audio.sinks.length)
                return "no output devices";
            return Audio.sinks.map(n => {
                const marks = [n.name === Audio.sink?.name ? "playing" : "", n.name === Audio.speakersName ? "speakers" : "", n.name === Audio.headphonesName ? "headphones" : ""].filter(m => m);
                return `${n.name}  ${Audio.deviceLabel(n)}${marks.length ? ` [${marks.join(", ")}]` : ""}`;
            }).join("\n");
        }

        function assign(role: string, name: string): string {
            if (role !== "speakers" && role !== "headphones")
                return `assign takes speakers or headphones, not: ${role}`;
            Config.set(`audio.${role}`, name);
            if (!name)
                return `${role} unassigned`;
            const node = Audio.sinkByName(name);
            return node ? `${role} = ${Audio.deviceLabel(node)} (${name})` : `${role} = ${name}, which is not a sink that is here right now`;
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): string {
            Wallpaper.toggle();
            return Wallpaper.enabled ? "on" : "off";
        }

        function on(): string {
            Wallpaper.setEnabled(true);
            return "on";
        }

        function off(): string {
            Wallpaper.setEnabled(false);
            return "off";
        }

        function next(screen: string): string {
            return root.walkWallpaper(screen, 1);
        }

        function prev(screen: string): string {
            return root.walkWallpaper(screen, -1);
        }

        function set(path: string, screen: string): string {
            if (!path)
                return "usage: wallpaper set <path> [screen|all]";

            const where = root.resolveScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                Wallpaper.setAll(path);
                return `all screens: ${Wallpaper.nameOf(path)}`;
            }
            Wallpaper.setOn(where, path);
            return `${where}: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
        }

        function clear(screen: string): string {
            const where = root.resolveScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                Wallpaper.setAll(Wallpaper.current);
                return `all screens follow the default: ${Wallpaper.name || "-"}`;
            }
            if (!Wallpaper.hasOwn(where))
                return `${where} already follows the default`;
            Wallpaper.clearOn(where);
            return `${where} follows the default: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
        }

        function palette(): string {
            if (!Wallpaper.palette.length)
                return "no palette (nothing measured yet, or the file could not be read)";
            return Wallpaper.palette.map(c => `${c.colour} ${Math.round(c.share * 100)}%`).join("\n");
        }

        function status(): string {
            const head = `${Wallpaper.enabled ? "on" : "off"} default ${Wallpaper.kindOf(Wallpaper.current) || "?"} ${Wallpaper.nameOf(Wallpaper.current) || "(nothing set)"} ${Wallpaper.available.length} in ${Wallpaper.dir}`;

            const rows = Quickshell.screens.map(s => {
                const own = Wallpaper.hasOwn(s.name);
                const path = Wallpaper.currentOn(s.name);
                const bits = [s.name === Hypr.focusedScreen ? "*" : " ", s.name, `${Math.round(s.width * s.devicePixelRatio)}x${Math.round(s.height * s.devicePixelRatio)}`, Wallpaper.nameOf(path) || "-", own ? "own" : "default"];

                const seen = Wallpaper.previewOn(s.name);
                if (seen)
                    bits.push(`showing ${Wallpaper.nameOf(seen)}`);
                return bits;
            });

            return rows.length ? `${head}\n${root.columns(rows)}` : head;
        }

        function list(screen: string): string {
            const name = screen || Hypr.focusedScreen;
            const aspect = Wallpaper.screenAspect(name);
            if (!aspect)
                return `no such screen: ${name || "(none focused)"}`;

            const worn = Wallpaper.currentOn(name);
            const rows = Wallpaper.available.map(p => {
                const a = Wallpaper.aspectOf(p);
                return [
                    p === worn ? "*" : " ",
                    Wallpaper.fits(p, aspect) ? "fits" : "-",

                    a ? a.toFixed(2) : "?",
                    Wallpaper.nameOf(p)
                ];
            });

            const kept = rows.filter(r => r[1] === "fits").length;
            const head = `${name} ${aspect.toFixed(2)} · ${kept} of ${rows.length} fit · tolerance ${Config.values.wallpaper.fit}`;
            return rows.length ? `${head}\n${root.columns(rows)}` : head;
        }
    }

    IpcHandler {
        target: "sidebar"

        function off(screen: string): string {
            const where = root.resolveScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                const was = Quickshell.screens.every(s => !SidebarState.visibleOn(s.name));
                SidebarState.setAll(false);
                return was ? "all screens: off (was already)" : "all screens: off";
            }
            if (!SidebarState.visibleOn(where))
                return `${where} already off`;
            SidebarState.setOn(where, false);
            return `${where}: off`;
        }

        function on(screen: string): string {
            const where = root.resolveScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                const was = Quickshell.screens.every(s => SidebarState.visibleOn(s.name));
                SidebarState.setAll(true);
                return was ? "all screens: on (was already)" : "all screens: on";
            }
            if (SidebarState.visibleOn(where))
                return `${where} already on`;
            SidebarState.setOn(where, true);
            return `${where}: on`;
        }

        function toggle(screen: string): string {
            const where = root.resolveScreen(screen);
            if (!where)
                return `no such screen: ${screen}`;

            if (where === "all") {
                const next = !SidebarState.enabled;
                SidebarState.setAll(next);
                return `all screens: ${next ? "on" : "off"}`;
            }
            const next = !SidebarState.visibleOn(where);
            SidebarState.setOn(where, next);
            return `${where}: ${next ? "on" : "off"}`;
        }

        function status(): string {
            const head = `${SidebarState.enabled ? "on" : "off"} default`;
            const rows = Quickshell.screens.map(s => [
                    s.name === Hypr.focusedScreen ? "*" : " ",
                    s.name,
                    SidebarState.visibleOn(s.name) ? "on" : "off",
                    s.name in SidebarState.perScreen ? "own" : "default"
                ]);
            return rows.length ? `${head}\n${root.columns(rows)}` : head;
        }
    }

    IpcHandler {
        target: "border"

        function off(): string {
            if (!Config.values.edge.bare) {
                Config.set("edge.bare", true);
                return "border: off";
            }
            return "border already off";
        }

        function on(): string {
            if (Config.values.edge.bare) {
                Config.set("edge.bare", false);
                return "border: on";
            }
            return "border already on";
        }

        function toggle(): string {
            const next = !Config.values.edge.bare;
            Config.set("edge.bare", next);

            return `border: ${next ? "off" : "on"}`;
        }

        function status(): string {
            return Config.values.edge.bare ? "off (bare)" : "on";
        }
    }

    IpcHandler {
        target: "wallpapers"

        function toggle(screen: string): string {
            const win = screen ? Shell.forScreen(screen) : Shell.showing(w => w.wallpapers.open);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.wallpapers.toggle();
            return win.wallpapers.open ? "open" : "closed";
        }

        function open(screen: string): string {
            const win = Shell.forScreen(screen);
            if (!win)
                return screen ? `no shell window on screen: ${screen}` : "no shell window";
            win.wallpapers.show();
            return "open";
        }

        function close(): string {
            for (const win of Shell.windows)
                win.wallpapers.hide();
            return "closed";
        }

        function status(): string {
            const win = Shell.showing(w => w.wallpapers.open);
            if (!win)
                return "no shell window";
            const on = win.screen?.name ?? "";
            return `${win.wallpapers.open ? "open" : "closed"} on=${on || "?"} scope=${win.wallpapers.everywhere ? "all" : "here"} showing=${Wallpaper.shownNameOn(on) || "-"} set=${Wallpaper.nameOf(Wallpaper.currentOn(on)) || "-"} of ${Wallpaper.available.length}`;
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): string {
            Lock.lock();
            return "locked";
        }

        function status(): string {
            return Lock.active ? "locked" : "unlocked";
        }
    }

    IpcHandler {
        target: "keyring"

        function status(): string {
            return [`prompter   ${Keyring.serving ? "the shell" : Keyring.blocked ? "gcr (the shell was refused the bus name)" : "not running"}`, `asking     ${Keyring.active}`, `kind       ${Keyring.kind || "-"}`, `title      ${Keyring.title || "-"}`, `message    ${Keyring.message || "-"}`, `warning    ${Keyring.warning || "-"}`, `choice     ${Keyring.choiceLabel ? `${Keyring.choiceChosen ? "yes" : "no"}: ${Keyring.choiceLabel}` : "-"}`, `screen     ${Keyring.screenName || "-"}`].join("\n");
        }

        function refuse(): string {
            if (!Keyring.active)
                return "nothing is being asked";
            Keyring.refuse();
            return "refused";
        }

        function demo(): string {
            Keyring.demo();
            return "showing a made-up question; escape or `keyring refuse` puts it away";
        }
    }

    readonly property string clockUnread: "the clock has not read its state file yet; ask again in a moment"

    function duration(text: string): int {
        const spec = String(text ?? "").trim().toLowerCase().replace(/\s+/g, "");
        if (/^\d+(\.\d+)?$/.test(spec))
            return Math.round(parseFloat(spec) * 60);
        if (!/^(\d+(\.\d+)?[hms])+$/.test(spec))
            return 0;
        let total = 0;
        for (const part of spec.match(/\d+(\.\d+)?[hms]/g))
            total += parseFloat(part) * (part.endsWith("h") ? 3600 : part.endsWith("m") ? 60 : 1);
        return Math.round(total);
    }

    function timeOfDay(text: string): int {
        const m = String(text ?? "").trim().toLowerCase().replace(/\s+/g, "").match(/^(\d{1,2}):?(\d{2})?(am|pm)?$/);
        if (!m)
            return -1;
        let hour = Number(m[1]);
        const minute = m[2] === undefined ? 0 : Number(m[2]);
        if (m[3]) {

            if (hour < 1 || hour > 12)
                return -1;
            hour = (hour % 12) + (m[3] === "pm" ? 12 : 0);
        }
        return hour > 23 || minute > 59 ? -1 : hour * 60 + minute;
    }

    function hhmm(hour: int, minute: int): string {
        return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
    }

    readonly property var dayNames: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    function repeatDays(spec: string): var {
        const want = String(spec ?? "").trim().toLowerCase().replace(/\s+/g, "");
        const all = root.dayNames.map((name, i) => i);
        if (!want || want === "once" || want === "never")
            return [];
        if (want === "daily" || want === "everyday" || want === "all")
            return all;
        if (want === "weekdays")
            return all.slice(0, root.dayNames.indexOf("sat"));
        if (want === "weekends" || want === "weekend")
            return all.slice(root.dayNames.indexOf("sat"));
        const out = [];
        for (const part of want.split(",")) {

            const ends = part.split("-").map(word => root.dayNames.indexOf(word.slice(0, 3)));
            if (ends.length > 2 || ends.some(i => i < 0))
                return null;
            for (let i = ends[0]; ; i = (i + 1) % all.length) {
                if (!out.includes(i))
                    out.push(i);
                if (i === ends[ends.length - 1])
                    break;
            }
        }
        return out.sort((a, b) => a - b);
    }

    function dayWords(days: var): string {
        const list = Array.isArray(days) ? days : [];
        const sat = root.dayNames.indexOf("sat");
        if (list.length === 0)
            return "once";
        if (list.length === root.dayNames.length)
            return "daily";
        if (list.length === sat && list.every(d => d < sat))
            return "weekdays";
        if (list.length === root.dayNames.length - sat && list.every(d => d >= sat))
            return "weekends";
        return list.map(d => root.dayNames[d]).join(",");
    }

    function resolveScreen(screen: string): string {
        if (screen === "all")
            return "all";
        if (screen)
            return Quickshell.screens.some(s => s.name === screen) ? screen : "";

        return Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
    }

    function walkWallpaper(screen: string, delta: int): string {
        if (!Wallpaper.available.length)
            return "nothing to step to";

        const where = root.resolveScreen(screen);
        if (!where)
            return `no such screen: ${screen}`;

        if (where === "all") {
            Wallpaper.stepAll(delta);
            return `all screens: ${Wallpaper.name || "-"}`;
        }
        Wallpaper.stepOn(where, delta);
        return `${where}: ${Wallpaper.nameOf(Wallpaper.currentOn(where))}`;
    }

    function columns(rows: var): string {
        const width = [];
        for (const row of rows)
            row.forEach((cell, i) => width[i] = Math.max(width[i] ?? 0, String(cell).length));
        return rows.map(row => row.map((cell, i) => i === row.length - 1 ? String(cell) : String(cell).padEnd(width[i])).join("  ")).join("\n");
    }

    function pickTimer(handle: string, matches: var): var {
        const want = String(handle ?? "").trim();
        if (want)
            return (/^\d+$/.test(want) ? Clock.timers[Number(want) - 1] : Clock.timers.find(t => t.id === want)) ?? null;
        const at = Date.now();
        return Clock.timers.filter(matches).sort((a, b) => Clock.remainingOf(a, at) - Clock.remainingOf(b, at))[0] ?? null;
    }

    function pickAlarm(handle: string): var {
        const want = String(handle ?? "").trim();
        if (!want)
            return null;
        return (/^\d+$/.test(want) ? Clock.alarms[Number(want) - 1] : Clock.alarms.find(a => a.id === want)) ?? null;
    }

    function timerFields(timer: var, index: int, at: double): var {
        return [`${index}`, Clock.spanLabel(Clock.remainingOf(timer, at)), timer.finished ? "done" : timer.paused ? "paused" : "running", timer.label || "-", `(${timer.id})`];
    }

    function alarmFields(alarm: var, index: int, at: double): var {
        const next = Clock.nextFor(alarm, at);
        const state = Clock.ringing && Clock.ringing.id === alarm.id ? "ringing" : alarm.missed ? "missed" : alarm.armed ? "armed" : "off";

        const when = alarm.snoozedUntil > at ? `snoozed, in ${Clock.spanLabel(next - at)}` : next > 0 ? `in ${Clock.spanLabel(next - at)}` : "-";
        const action = alarm.mode === "command" ? `run: ${alarm.payload}` : alarm.mode === "cloud" ? `ask: ${alarm.payload}` : "-";
        return [`${index}`, root.hhmm(alarm.hour, alarm.minute), root.dayWords(alarm.days), state, when, alarm.label || "-", action, `(${alarm.id})`];
    }

    function armAlarm(handle: string, on: bool): string {
        if (!Clock.loaded)
            return root.clockUnread;
        const alarm = root.pickAlarm(handle);
        if (!alarm)
            return handle ? `no such alarm: ${handle}` : "which alarm? (banditshell alarm list)";
        Clock.setAlarmArmed(alarm.id, on);
        return root.columns([root.alarmFields(alarm, Clock.alarms.indexOf(alarm) + 1, Date.now())]);
    }

    function zoneKey(text: string): string {
        return String(text ?? "").trim().toLowerCase().replace(/[\s_]+/g, "_");
    }

    function zoneMatches(text: string): var {
        const want = root.zoneKey(text);
        const exact = Clock.allZones.filter(id => root.zoneKey(id) === want);
        return exact.length > 0 ? exact : Clock.allZones.filter(id => root.zoneKey(id).includes(want));
    }

    IpcHandler {
        target: "timer"

        function start(spec: string, label: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const secs = root.duration(spec);
            if (secs <= 0)
                return `not a duration: "${spec}" (10m, 90s, 1h30m, 2h, or a bare number of minutes)`;
            const id = Clock.startTimer(secs, label ?? "");

            if (!id)
                return `no room: ${Clock.timerMax} timers at a time and all of them are running`;
            const timer = Clock.timers.find(t => t.id === id);
            return root.columns([root.timerFields(timer, Clock.timers.indexOf(timer) + 1, Date.now())]);
        }

        function pause(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const timer = root.pickTimer(handle, t => !t.finished && !t.paused);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "nothing is counting";
            if (timer.finished)
                return `that one has already gone off (${timer.id})`;
            if (timer.paused)
                return `already paused, ${Clock.spanLabel(timer.left)} left (${timer.id})`;
            Clock.toggleTimer(timer.id);
            return `paused, ${Clock.spanLabel(timer.left)} left (${timer.id})`;
        }

        function resume(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const timer = root.pickTimer(handle, t => t.paused && !t.finished);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "nothing is paused";
            if (timer.finished)
                return `that one has already gone off (${timer.id})`;
            if (!timer.paused)
                return `already running, ${Clock.spanLabel(Clock.remainingOf(timer, Date.now()))} left (${timer.id})`;
            Clock.toggleTimer(timer.id);
            return `running, ${Clock.spanLabel(Clock.remainingOf(timer, Date.now()))} left (${timer.id})`;
        }

        function toggle(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const timer = root.pickTimer(handle, t => !t.finished);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "no timer to pause";
            if (timer.finished)
                return `that one has already gone off (${timer.id})`;
            return timer.paused ? resume(timer.id) : pause(timer.id);
        }

        function cancel(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;

            const timer = root.pickTimer(handle, t => t.finished) ?? root.pickTimer(handle, t => true);
            if (!timer)
                return handle ? `no such timer: ${handle}` : "no timers";
            Clock.removeTimer(timer.id);
            return `cancelled ${timer.label || Clock.spanLabel(timer.total)} (${timer.id})`;
        }

        function status(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            if (Clock.timers.length === 0)
                return `no timers (${Clock.timerMax} at a time)`;
            const at = Date.now();
            return root.columns(Clock.timers.map((timer, i) => root.timerFields(timer, i + 1, at)));
        }
    }

    IpcHandler {
        target: "alarm"

        function add(time: string, days: string, label: string, mode: string, payload: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const minutes = root.timeOfDay(time);
            if (minutes < 0)
                return `not a time: "${time}" (07:00, 7:30pm, 0700, or a bare hour)`;
            const repeat = root.repeatDays(days);
            if (repeat === null)
                return `not a repeat: "${days}" (mon,wed / mon-fri / weekdays / weekends / daily / once)`;
            const action = mode || "none";
            if (!["none", "command", "cloud"].includes(action))
                return `not an action: "${mode}" (command or cloud)`;

            if (action !== "none" && !payload)
                return `${action} needs something to ${action === "command" ? "run" : "say"}`;
            const id = Clock.addAlarm();
            if (!id)
                return `no room: ${Clock.alarmMax} alarms is the lot`;

            Clock.setAlarm(id, {
                hour: Math.floor(minutes / 60),
                minute: minutes % 60,
                days: repeat,
                label: label ?? "",
                mode: action,
                payload: payload ?? ""
            });
            const alarm = Clock.alarms.find(a => a.id === id);
            return root.columns([root.alarmFields(alarm, Clock.alarms.indexOf(alarm) + 1, Date.now())]);
        }

        function list(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            if (Clock.alarms.length === 0)
                return `no alarms (${Clock.alarmMax} is the lot)`;
            const at = Date.now();
            return root.columns(Clock.alarms.map((alarm, i) => root.alarmFields(alarm, i + 1, at)));
        }

        function remove(handle: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const alarm = root.pickAlarm(handle);
            if (!alarm)
                return handle ? `no such alarm: ${handle}` : "which alarm? (banditshell alarm list)";
            Clock.removeAlarm(alarm.id);
            return `removed ${root.hhmm(alarm.hour, alarm.minute)}${alarm.label ? ` ${alarm.label}` : ""} (${alarm.id})`;
        }

        function enable(handle: string): string {
            return root.armAlarm(handle, true);
        }

        function disable(handle: string): string {
            return root.armAlarm(handle, false);
        }

        function snooze(): string {
            if (!Clock.ringing)
                return "nothing is ringing";
            const alarm = Clock.ringing;
            Clock.snooze();
            return `snoozed ${root.hhmm(alarm.hour, alarm.minute)} for ${Clock.snoozeMinutes}m (${alarm.id})`;
        }

        function stop(): string {
            if (!Clock.ringing)
                return "nothing is ringing";
            const alarm = Clock.ringing;
            Clock.stop();

            return `stopped ${root.hhmm(alarm.hour, alarm.minute)}, ${alarm.days.length === 0 ? "disarmed" : `next ${root.dayWords(alarm.days)}`} (${alarm.id})`;
        }

        function status(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const at = Date.now();
            const armed = Clock.alarms.filter(a => a.armed);
            let soonest = null;
            for (const alarm of armed) {
                const when = Clock.nextFor(alarm, at);
                if (when > 0 && (!soonest || when < soonest.when))
                    soonest = {
                        alarm,
                        when
                    };
            }

            const ring = Clock.ringing;
            const next = soonest ? `${root.hhmm(soonest.alarm.hour, soonest.alarm.minute)} ${root.dayWords(soonest.alarm.days)}, ${soonest.alarm.snoozedUntil > at ? "snoozed, " : ""}in ${Clock.spanLabel(soonest.when - at)}` : "-";
            return [`alarms     ${Clock.alarms.length} of ${Clock.alarmMax}`, `armed      ${armed.length}`, `next       ${next}`, `ringing    ${ring ? `${root.hhmm(ring.hour, ring.minute)}${ring.label ? ` ${ring.label}` : ""}, ${Clock.spanLabel(at - Clock.ringingSince)} so far${Clock.ringingLate > 60000 ? `, late by ${Clock.spanLabel(Clock.ringingLate)}` : ""}` : "none"}`, `policy     snooze ${Clock.snoozeMinutes}m, gives up after ${Clock.ringMinutes}m, catches up within ${Clock.catchUpMinutes}m`].join("\n");
        }
    }

    IpcHandler {
        target: "zone"

        function list(): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const at = Date.now();
            const rows = [[Clock.localCity || "-", Clock.zoneTime(Clock.localOffset, at).text, "here", `(${Clock.localZone || "unknown"})`]];
            for (const zone of Clock.zones) {
                const there = Clock.zoneTime(zone.offsetMinutes, at);
                const day = there.dayDelta === 0 ? "" : there.dayDelta < 0 ? " yesterday" : " tomorrow";
                rows.push([zone.city, there.text, `${Clock.offsetLabel(zone.deltaMinutes)}${day}`, `(${zone.id})`]);
            }

            const pending = Clock.places.filter(id => !Clock.zones.some(z => z.id === id));
            const table = rows.length > 1 ? root.columns(rows) : `${root.columns(rows)}\nno places yet (banditshell zone add <place>)`;
            return pending.length > 0 ? `${table}\nmeasuring ${pending.join(", ")}` : table;
        }

        function find(text: string): string {
            const want = String(text ?? "").trim();
            if (!want)
                return "which place? (banditshell zone find <text>)";
            if (Clock.allZones.length === 0) {
                Clock.loadZoneList();
                return "reading this machine's zone list; ask again in a moment";
            }
            const near = root.zoneMatches(want);
            return near.length > 0 ? near.join("\n") : `nothing here is called that: ${want}`;
        }

        function add(place: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const want = String(place ?? "").trim();
            if (!want)
                return "which place? (banditshell zone find <text>)";
            if (Clock.allZones.length === 0) {
                Clock.loadZoneList();
                return "reading this machine's zone list; ask again in a moment";
            }
            const near = root.zoneMatches(want);
            if (near.length === 0)
                return `no such place: ${want} (banditshell zone find ${want})`;
            if (near.length > 1)
                return `${want} could be any of ${near.length} (banditshell zone find ${want})`;
            const id = near[0];

            if (id === Clock.localZone)
                return `${Clock.cityOf(id)} is this machine's own zone, which the panel draws already`;
            if (Clock.places.includes(id))
                return `already on the list: ${id}`;
            Clock.addZone(id);
            return `added ${Clock.cityOf(id)} (${id})`;
        }

        function remove(place: string): string {
            if (!Clock.loaded)
                return root.clockUnread;
            const want = root.zoneKey(place);
            if (!want)
                return "which place? (banditshell zone list)";
            const hits = Clock.places.filter(id => root.zoneKey(id) === want || root.zoneKey(Clock.cityOf(id)) === want);
            if (hits.length === 0)
                return `not on the list: ${place} (banditshell zone list)`;
            if (hits.length > 1)
                return `${place} is ${hits.length} of them; name the id (banditshell zone list)`;
            Clock.removeZone(hits[0]);
            return `removed ${Clock.cityOf(hits[0])} (${hits[0]})`;
        }
    }

    IpcHandler {
        target: "shell"

        function status(): string {
            const win = Shell.showing(w => w.launcher.open);
            return [`compositor  ${Compositor.name}`, `following   ${Appearance.follows}`, `theme       ${Themes.activeName}`, `rounding    ${Appearance.rounding.base}`, `corner      power ${Appearance.rounding.power} (compositor says ${Compositor.roundingPower})`, `tiers       ${Appearance.rounding.small} / ${Appearance.rounding.normal} / ${Appearance.rounding.large} from base ${Appearance.rounding.base}, available=${Compositor.available}`, `gap         ${Appearance.sizes.gap} outer, ${Compositor.gapsIn} inner`, `wm border   ${Compositor.borderSize}`, `window edge ${Appearance.sizes.windowRadius} (the one radius)`, `band        ${Appearance.sizes.band}`, `bar         ${Appearance.sizes.sidebarWidth}`, `apps        ${Apps.all.length} listed, ${DesktopEntries.applications.values.length} on disk`, `launcher    ${win?.launcher.open ? "open" : "closed"}, ${win?.launcher.resultCount ?? 0} results, ${Math.round(win?.launcher.drawnHeight ?? 0)}px tall`, `scroll      ${win?.launcher.scrollInfo ?? "-"}`, `screens     ${Shell.screenNames().join(", ")}`].join("\n");
        }

        function themes(): string {

            return Themes.availableNames.map(n => n === Themes.activeName ? `* ${n}` : `  ${n}`).join("\n");
        }

        function get(key: string): string {
            const v = Config.get(key);
            return v === undefined ? `no such setting: ${key}` : JSON.stringify(v);
        }

        function set(key: string, value: string): string {
            let parsed = value;
            try {
                parsed = JSON.parse(value);
            } catch (e) {}
            Config.set(key, parsed);
            return `${key} = ${JSON.stringify(parsed)}`;
        }
    }

    IpcHandler {
        target: "penmap"

        function open(): string {
            PenMap.begin();
            return "open";
        }

        function commit(): string {
            PenMap.commit();
            return "committed";
        }

        function cancel(): string {
            PenMap.cancel();
            return "cancelled";
        }

        function aspect(): string {
            PenMap.toggleAspect();
            return PenMap.aspectLocked ? "locked" : "free";
        }

        function centre(): string {
            PenMap.fitAndCentre();
            return root.penmapStatus();
        }

        function follow(): string {
            PenMap.toggleFollowWindow();
            return PenMap.followWindow ? "following" : "off";
        }

        function set(x: string, y: string, w: string, h: string): string {
            const nums = [x, y, w, h].map(Number);
            if (nums.some(isNaN))
                return "four numbers: x y w h";
            PenMap.proposeRegion(nums[0], nums[1], nums[2], nums[3]);
            PenMap.commit();
            return root.penmapStatus();
        }

        function status(): string {
            return root.penmapStatus();
        }
    }
}
