const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/events.js"), "utf8");
const E = new Function(src + "\nreturn { SIZE_CAP, WRITER_SCRIPT, panelsOf, activitiesOf, notificationsOf, snapshotOf, diff, line, wanted };")();

function window(screen, open = [], pinned = [], menu = "") {
    const win = { screen: { name: screen }, menus: { currentKey: menu } };
    for (const part of ["launcher", "session", "clipboard", "media", "calculator", "keyboard", "settings", "hotkeys", "wallpapers"])
        win[part] = { open: open.includes(part) };
    for (const part of ["quickControls", "notifications", "island"])
        win[part] = { pinned: pinned.includes(part) };
    return win;
}

function snapshot(over = {}) {
    return E.snapshotOf(Object.assign({
        workspace: 1,
        windows: [window("DP-1")],
        mode: "none",
        quiet: false,
        media: { title: "", artist: "", app: "", playing: false },
        activities: [],
        notifications: [],
        update: { state: "idle", behind: 0 }
    }, over));
}

test.describe("panels", () => {
    test.it("names open and pinned panels with their screen", () => {
        const found = E.panelsOf([window("DP-1", ["launcher", "wallpapers"], ["island"], "volume"), window("HDMI-A-1", ["media"])], ["files"]);
        assert.deepStrictEqual(Object.keys(found).sort(), ["files@", "island@DP-1", "launcher@DP-1", "media@HDMI-A-1", "volume@DP-1", "wallpaper@DP-1"]);
        assert.deepStrictEqual(found["wallpaper@DP-1"], { panel: "wallpaper", screen: "DP-1" });
    });

    test.it("copes with a window that has no panels yet", () => {
        assert.deepStrictEqual(E.panelsOf([{}, null], []), {});
        assert.deepStrictEqual(E.panelsOf(undefined, undefined), {});
    });
});

test.describe("diff", () => {
    test.it("says nothing without a baseline or a change", () => {
        assert.deepStrictEqual(E.diff(null, snapshot()), []);
        assert.deepStrictEqual(E.diff(snapshot(), snapshot()), []);
    });

    test.it("reports a workspace change with the one before", () => {
        assert.deepStrictEqual(E.diff(snapshot(), snapshot({ workspace: 4 })), [{ event: "workspace.changed", workspace: 4, previous: 1 }]);
    });

    test.it("reports panels opening and closing per screen", () => {
        const before = snapshot({ windows: [window("DP-1", ["launcher"])] });
        const after = snapshot({ windows: [window("DP-1", [], ["island"])] });
        assert.deepStrictEqual(E.diff(before, after), [
            { event: "panel.opened", panel: "island", screen: "DP-1" },
            { event: "panel.closed", panel: "launcher", screen: "DP-1" }
        ]);
    });

    test.it("reports the mode and quiet", () => {
        const out = E.diff(snapshot(), snapshot({ mode: "work", quiet: true }));
        assert.deepStrictEqual(out, [
            { event: "mode.changed", mode: "work", previous: "none" },
            { event: "quiet.changed", quiet: true }
        ]);
    });

    test.it("reports a new track and a play state apart", () => {
        const idle = snapshot();
        const playing = snapshot({ media: { title: "Song", artist: "Band", app: "Spotify", playing: true } });
        assert.deepStrictEqual(E.diff(idle, playing), [
            { event: "media.track", title: "Song", artist: "Band", app: "Spotify", playing: true },
            { event: "media.state", playing: true, app: "Spotify" }
        ]);
        const paused = snapshot({ media: { title: "Song", artist: "Band", app: "Spotify", playing: false } });
        assert.deepStrictEqual(E.diff(playing, paused), [{ event: "media.state", playing: false, app: "Spotify" }]);
        const gone = snapshot();
        assert.deepStrictEqual(E.diff(paused, gone), []);
    });

    test.it("follows an activity from push to end", () => {
        const pushed = snapshot({ activities: [{ id: "build", text: "Building", state: "running", progress: 0.1, touched: 1 }] });
        assert.deepStrictEqual(E.diff(snapshot(), pushed), [{ event: "activity.pushed", id: "build", text: "Building" }]);
        const moved = snapshot({ activities: [{ id: "build", text: "Building", state: "running", progress: 0.5, touched: 2 }] });
        assert.deepStrictEqual(E.diff(pushed, moved), [{ event: "activity.updated", id: "build", text: "Building", progress: 0.5 }]);
        const ended = snapshot({ activities: [{ id: "build", text: "Building", state: "ended", outcome: "done", touched: 3 }] });
        assert.deepStrictEqual(E.diff(moved, ended), [{ event: "activity.ended", id: "build", text: "Building", outcome: "done" }]);
        assert.deepStrictEqual(E.diff(ended, snapshot()), []);
        assert.deepStrictEqual(E.diff(moved, snapshot()), [{ event: "activity.ended", id: "build", text: "Building", outcome: "removed" }]);
    });

    test.it("keeps the notification text out unless asked", () => {
        const one = snapshot({ notifications: [{ id: "7", appName: "Signal", summary: "Dinner at eight?" }] });
        assert.deepStrictEqual(E.diff(snapshot(), one), [{ event: "notification.arrived", id: "7", app: "Signal" }]);
        assert.deepStrictEqual(E.diff(snapshot(), one, { notificationText: true }), [{ event: "notification.arrived", id: "7", app: "Signal", summary: "Dinner at eight?" }]);
        assert.deepStrictEqual(E.diff(one, snapshot()), [{ event: "notification.dismissed", id: "7", app: "Signal" }]);
        assert.ok(!JSON.stringify(E.diff(one, snapshot())).includes("Dinner"));
    });

    test.it("counts a notification that is leaving for good as dismissed", () => {
        const before = snapshot({ notifications: [{ id: "7", appName: "Signal", summary: "x", leaving: false }] });
        const leaving = snapshot({ notifications: [{ id: "7", appName: "Signal", summary: "x", leaving: true, forget: true }] });
        assert.deepStrictEqual(E.diff(before, leaving), [{ event: "notification.dismissed", id: "7", app: "Signal" }]);
        const expiring = snapshot({ notifications: [{ id: "7", appName: "Signal", summary: "x", leaving: true, forget: false }] });
        assert.deepStrictEqual(E.diff(before, expiring), []);
    });

    test.it("reports the update state", () => {
        assert.deepStrictEqual(E.diff(snapshot(), snapshot({ update: { state: "available", behind: 3 } })), [{ event: "update.changed", state: "available", behind: 3 }]);
    });
});

test.describe("line", () => {
    test.it("writes the event name first, then the time, as one JSON line", () => {
        const text = E.line({ event: "panel.opened", panel: "launcher", screen: "DP-1" }, 1234);
        assert.strictEqual(text, '{"event":"panel.opened","time":1234,"panel":"launcher","screen":"DP-1"}\n');
        assert.deepStrictEqual(JSON.parse(text), { event: "panel.opened", time: 1234, panel: "launcher", screen: "DP-1" });
    });

    test.it("keeps a line to one line whatever the text holds", () => {
        const text = E.line({ event: "notification.arrived", id: "1", app: 'a"b\nc' }, 1);
        assert.strictEqual(text.split("\n").length, 2);
        assert.strictEqual(JSON.parse(text).app, 'a"b\nc');
    });

    test.it("cuts a long summary", () => {
        const long = "x".repeat(500);
        const snap = snapshot({ notifications: [{ id: "1", appName: "A", summary: long }] });
        assert.strictEqual(snap.notifications["1"].summary.length, 200);
    });
});

test.describe("wanted", () => {
    test.it("matches a name or its group, and everything on an empty filter", () => {
        assert.ok(E.wanted("", "panel.opened"));
        assert.ok(E.wanted("panel", "panel.opened"));
        assert.ok(E.wanted("media,panel.closed", "panel.closed"));
        assert.ok(!E.wanted("panel.closed", "panel.opened"));
        assert.ok(!E.wanted("pane", "panel.opened"));
        assert.ok(E.wanted("quiet", "quiet.changed"));
    });
});

test.describe("the writer script", () => {
    function run(lines, env, cap) {
        const runtime = fs.mkdtempSync(path.join(os.tmpdir(), "events-"));
        const result = spawnSync("sh", ["-c", E.WRITER_SCRIPT, "sh", String(cap ?? E.SIZE_CAP)], { input: lines, encoding: "utf8", env: Object.assign({ PATH: process.env.PATH, XDG_RUNTIME_DIR: runtime }, env) });
        return { runtime, dir: path.join(runtime, "banditshell"), result };
    }

    test.it("appends each line to events.jsonl in a private folder", () => {
        const { dir, runtime, result } = run("a\nb\n");
        assert.strictEqual(result.status, 0);
        assert.strictEqual(fs.readFileSync(path.join(dir, "events.jsonl"), "utf8"), "a\nb\n");
        assert.strictEqual(fs.statSync(path.join(dir, "events.jsonl")).mode & 0o777, 0o600);
        fs.rmSync(runtime, { recursive: true });
    });

    test.it("rotates to events.jsonl.1 once the cap is passed", () => {
        const lines = Array.from({ length: 10 }, (_, i) => `line-number-${i}`).join("\n") + "\n";
        const { dir, runtime } = run(lines, {}, 40);
        const rotated = fs.readFileSync(path.join(dir, "events.jsonl.1"), "utf8");
        assert.ok(rotated.includes("line-number-"));
        const kept = fs.existsSync(path.join(dir, "events.jsonl")) ? fs.readFileSync(path.join(dir, "events.jsonl"), "utf8") : "";
        assert.ok(kept.length <= 40 + 15);
        fs.rmSync(runtime, { recursive: true });
    });

    test.it("rotates a file that is already past the cap when it starts", () => {
        const runtime = fs.mkdtempSync(path.join(os.tmpdir(), "events-"));
        const dir = path.join(runtime, "banditshell");
        fs.mkdirSync(dir);
        fs.writeFileSync(path.join(dir, "events.jsonl"), "old".repeat(30));
        spawnSync("sh", ["-c", E.WRITER_SCRIPT, "sh", "20"], { input: "new\n", encoding: "utf8", env: { PATH: process.env.PATH, XDG_RUNTIME_DIR: runtime } });
        assert.strictEqual(fs.readFileSync(path.join(dir, "events.jsonl.1"), "utf8"), "old".repeat(30));
        assert.strictEqual(fs.readFileSync(path.join(dir, "events.jsonl"), "utf8"), "new\n");
        fs.rmSync(runtime, { recursive: true });
    });
});
