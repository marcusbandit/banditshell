const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/moments.js"), "utf8");
const M = new Function(src + "\nreturn { SCREENSHOT_MS, BLUETOOTH_MS, COPIED_MS, momentWanted, fileUrl, screenshotSpec, screenshotAction, editorCommand, preview, copyShape, copiedLabel, copiedSpec, audioDevice, batteryPercent, bluetoothSpec, wifiSpec, undoSpec, hushDone, newlyConnected };")();
const act = fs.readFileSync(path.join(ROOT, "services/activities.js"), "utf8");
const A = new Function(act + "\nreturn { push, itemOf, sweep };")();

test.describe("moment switches", () => {
    test.it("wants every kind unless its switch is off", () => {
        const all = { screenshot: true, privacy: true, copied: true, bluetooth: true, wifi: true };
        for (const kind of ["screenshot", "privacy", "copied", "bluetooth", "wifi"])
            assert.strictEqual(M.momentWanted(all, kind), true);
        assert.strictEqual(M.momentWanted(Object.assign({}, all, { copied: false }), "copied"), false);
        assert.strictEqual(M.momentWanted(Object.assign({}, all, { copied: false }), "screenshot"), true);
        assert.strictEqual(M.momentWanted(undefined, "copied"), true);
        assert.strictEqual(M.momentWanted(all, "nothing"), false);
    });
});

test.describe("screenshot", () => {
    test.it("shows the picture with four actions for six seconds", () => {
        const spec = M.screenshotSpec("/home/me/Pictures/shot one.png");
        assert.strictEqual(spec.until, 6000);
        assert.strictEqual(spec.data.picture, "file:///home/me/Pictures/shot%20one.png");
        assert.strictEqual(spec.data.folder, "/home/me/Pictures");
        assert.strictEqual(spec.detail, "shot one.png");
        assert.deepStrictEqual(spec.actions.map(a => a.name), ["copy", "edit", "folder", "delete"]);
        assert.strictEqual(spec.pressable, true);
    });

    test.it("is a valid activity and the registry accepts it", () => {
        const out = A.push([], M.screenshotSpec("/tmp/a.png"), 1000);
        assert.ok(!out.error, out.error);
        const item = A.itemOf(out.entry);
        assert.strictEqual(item.style, "screenshot");
        assert.strictEqual(item.pressable, true);
        assert.strictEqual(item.actions.length, 4);
        assert.strictEqual(A.sweep(out.list, 1000 + 5900).length, 1);
        assert.strictEqual(A.sweep(out.list, 1000 + 6100).length, 0);
    });

    test.it("posts nothing without a path", () => {
        assert.strictEqual(M.screenshotSpec(""), null);
        assert.strictEqual(M.screenshotSpec(undefined), null);
    });

    test.it("maps an action name, and any other press opens the picture", () => {
        assert.strictEqual(M.screenshotAction("delete"), "delete");
        assert.strictEqual(M.screenshotAction("folder"), "folder");
        assert.strictEqual(M.screenshotAction(""), "open");
        assert.strictEqual(M.screenshotAction(undefined), "open");
        assert.strictEqual(M.screenshotAction("rm"), "open");
    });

    test.it("hands the editor the path as an argument, never inside the command text", () => {
        assert.deepStrictEqual(M.editorCommand("swappy -f", "/a b/c.png"), ["sh", "-c", "swappy -f \"$1\"", "sh", "/a b/c.png"]);
        assert.deepStrictEqual(M.editorCommand("", "/a.png"), ["xdg-open", "/a.png"]);
    });
});

test.describe("copied", () => {
    test.it("keeps the first twenty characters of a copied text", () => {
        const label = M.copiedLabel(["wl-copy", "-n"], "the quick brown fox jumps over the lazy dog");
        assert.strictEqual(label, "Copied: the quick brown fox\u2026");
    });

    test.it("cuts at twenty characters exactly", () => {
        assert.strictEqual(M.preview("abcdefghijklmnopqrstuvwxyz", 20), "abcdefghijklmnopqrst…");
        assert.strictEqual(M.preview("abcdefghijklmnopqrst", 20), "abcdefghijklmnopqrst");
    });

    test.it("flattens whitespace so a copied block fits one line", () => {
        assert.strictEqual(M.preview("  one\n\n two\tthree  ", 20), "one two three");
    });

    test.it("masks text copied as sensitive", () => {
        const label = M.copiedLabel(["wl-copy", "--sensitive", "-n"], "hunter2-correct-horse");
        assert.ok(!label.includes("hunter"));
        assert.strictEqual(label, "Copied: ••••••••");
        assert.strictEqual(M.copiedSpec(["wl-copy", "--sensitive", "-n"], "x").data.secret, true);
        assert.strictEqual(M.copiedSpec(["wl-copy", "-n"], "x").data.secret, false);
    });

    test.it("names images and files instead of showing their bytes", () => {
        assert.strictEqual(M.copiedLabel(["sh", "-c", "exec wl-copy -t \"$1\" < \"$2\"", "sh", "image/png", "/a.png"], ""), "Copied: image");
        assert.strictEqual(M.copiedLabel(["wl-copy", "-t", "text/uri-list"], "file:///a\r\nfile:///b"), "Copied: 2 files");
        assert.strictEqual(M.copiedLabel(["wl-copy", "-t", "text/uri-list"], "file:///a"), "Copied: a file");
    });

    test.it("says nothing for an empty copy", () => {
        assert.strictEqual(M.copiedSpec(["wl-copy", "-n"], "   "), null);
    });

    test.it("is a short lived activity", () => {
        const out = A.push([], M.copiedSpec(["wl-copy", "-n"], "hello"), 0);
        assert.ok(!out.error, out.error);
        assert.strictEqual(M.COPIED_MS <= 1000, true);
        assert.strictEqual(A.sweep(out.list, M.COPIED_MS + 1).length, 0);
    });
});

test.describe("bluetooth", () => {
    test.it("only audio devices have a moment", () => {
        assert.strictEqual(M.audioDevice("headphones"), true);
        assert.strictEqual(M.audioDevice("speaker"), true);
        assert.strictEqual(M.audioDevice("keyboard"), false);
        assert.strictEqual(M.audioDevice("bluetooth"), false);
    });

    test.it("turns a battery fraction into a percent, or nothing", () => {
        assert.strictEqual(M.batteryPercent(0.8, true), 80);
        assert.strictEqual(M.batteryPercent(1.2, true), 100);
        assert.strictEqual(M.batteryPercent(0.8, false), -1);
        assert.strictEqual(M.batteryPercent(NaN, true), -1);
    });

    test.it("names the device and lasts three seconds", () => {
        const spec = M.bluetoothSpec("WH-1000XM5", "headphones", 64);
        assert.strictEqual(spec.text, "WH-1000XM5");
        assert.strictEqual(spec.until, 3000);
        assert.strictEqual(spec.data.battery, 64);
        assert.strictEqual(M.bluetoothSpec("", "headphones", -1).text, "Bluetooth device");
        assert.ok(!A.push([], spec, 0).error);
    });

    test.it("finds only the addresses that were not connected before", () => {
        assert.deepStrictEqual(M.newlyConnected(["a"], ["a", "b"]), ["b"]);
        assert.deepStrictEqual(M.newlyConnected(["a", "b"], ["a"]), []);
        assert.deepStrictEqual(M.newlyConnected(undefined, ["a"]), ["a"]);
    });
});

test.describe("wifi", () => {
    test.it("says Wi-Fi failed, with the network and cause as detail and Try again", () => {
        const spec = M.wifiSpec("Cafe", "timeout", "Cafe: no answer");
        assert.strictEqual(spec.text, "Wi-Fi failed");
        assert.strictEqual(spec.detail, "Cafe: no answer");
        assert.strictEqual(spec.icon, "signal_wifi_bad");
        assert.deepStrictEqual(spec.data, { name: "Cafe", kind: "timeout" });
        assert.deepStrictEqual(spec.actions, [{ name: "retry", label: "Try again" }]);
    });

    test.it("waits until it is seen instead of timing out", () => {
        const pushed = A.push([], M.wifiSpec("Cafe", "timeout", "Cafe: no answer"), 0);
        assert.ok(!pushed.error);
        assert.strictEqual(A.sweep(pushed.list, 24 * 60 * 60 * 1000).length, 1);
    });

    test.it("falls back to the network name without a message", () => {
        assert.strictEqual(M.wifiSpec("Cafe", "timeout", "").detail, "Cafe");
    });

    test.it("retries the network by its exact name, spaces and all", () => {
        assert.strictEqual(M.wifiSpec("Cafe  5G ", "lost", "x").data.name, "Cafe  5G ");
    });

    test.it("posts nothing for a network without a name", () => {
        assert.strictEqual(M.wifiSpec("  ", "timeout", "x"), null);
    });
});

test.describe("undo", () => {
    test.it("names the app for one card and counts notifications for more", () => {
        assert.strictEqual(M.undoSpec(["Discord"]).text, "Discord dismissed");
        assert.strictEqual(M.undoSpec(["", "Discord", "Signal"]).text, "3 notifications cleared");
        assert.deepStrictEqual(M.undoSpec(["a", "b"]).actions, [{ name: "undo", label: "Undo" }]);
    });

    test.it("carries the one card so the row can show its app's mark", () => {
        const card = { appName: "Signal" };
        assert.strictEqual(M.undoSpec(["Signal"], card).data.entry, card);
        assert.strictEqual(M.undoSpec(["Signal", "Discord"], card).data.entry, null);
        assert.strictEqual(M.undoSpec(["Signal", "Discord"], card).icon, "notifications");
    });

    test.it("falls back to Notification and shortens a long app name", () => {
        assert.strictEqual(M.undoSpec([""]).text, "Notification dismissed");
        assert.ok(M.undoSpec(["A Very Long Application Name Indeed"]).text.length <= 32);
    });

    test.it("is a valid activity that the service ends, not a timeout", () => {
        const pushed = A.push([], M.undoSpec(["Discord", "Signal"]), 0);
        assert.ok(!pushed.error, pushed.error);
        assert.strictEqual(A.sweep(pushed.list, 60 * 60 * 1000).length, 1);
    });

    test.it("says when a reminded or muted app comes back", () => {
        assert.strictEqual(M.undoSpec(["Discord"], null, M.hushDone("snooze", "01:30")).text, "Discord hidden until 01:30");
        assert.strictEqual(M.undoSpec(["Discord"], null, M.hushDone("mute", "07:30")).text, "Discord muted until 07:30");
        assert.strictEqual(M.undoSpec(["Discord"], null, M.hushDone("mute", "")).text, "Discord muted until I unmute");
        assert.strictEqual(M.undoSpec(["Discord"], null, M.hushDone("unmute", "")).text, "Discord unmuted");
        assert.deepStrictEqual(M.undoSpec(["Discord"], null, "muted").actions, [{ name: "undo", label: "Undo" }]);
    });

    test.it("posts nothing when the shelf is empty", () => {
        assert.strictEqual(M.undoSpec([]), null);
    });
});
