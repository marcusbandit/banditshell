const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
const Paths = new Function(read("services/wallpaper-paths.js") + "\nreturn { FORMATS, expand, kindOf, fits, within, reread, strangeOf, resolved, repairs };")();
const Library = new Function(read("services/wallpaper-library.js") + "\nreturn { shown };")();

const HOME = "/home/me";
const SHIPPED = "/usr/share/banditshell/assets/wallpapers/";
const FALLBACK = `${SHIPPED}moonrise.png`;

test.describe("expand", () => {
    test.it("expands a leading tilde to the home folder", () => {
        assert.strictEqual(Paths.expand("~", HOME, SHIPPED), HOME);
        assert.strictEqual(Paths.expand("~/Pictures/a.png", HOME, SHIPPED), "/home/me/Pictures/a.png");
    });

    test.it("expands a leading $HOME the same way", () => {
        assert.strictEqual(Paths.expand("$HOME", HOME, SHIPPED), HOME);
        assert.strictEqual(Paths.expand("$HOME/Pictures/a.png", HOME, SHIPPED), "/home/me/Pictures/a.png");
    });

    test.it("leaves a tilde or $HOME in the middle of a path alone", () => {
        assert.strictEqual(Paths.expand("/data/~/a.png", HOME, SHIPPED), "/data/~/a.png");
        assert.strictEqual(Paths.expand("/data/$HOME/a.png", HOME, SHIPPED), "/data/$HOME/a.png");
        assert.strictEqual(Paths.expand("/data/a~", HOME, SHIPPED), "/data/a~");
    });

    test.it("does not read ~user or $HOMEDIR as the home folder", () => {
        assert.strictEqual(Paths.expand("~bob/a.png", HOME, SHIPPED), "~bob/a.png");
        assert.strictEqual(Paths.expand("$HOMEDIR/a.png", HOME, SHIPPED), "$HOMEDIR/a.png");
    });

    test.it("maps shipped: onto the shipped folder", () => {
        assert.strictEqual(Paths.expand("shipped:moonrise.png", HOME, SHIPPED), FALLBACK);
    });

    test.it("keeps an absolute path and gives blank for no path", () => {
        assert.strictEqual(Paths.expand("/w/a.png", HOME, SHIPPED), "/w/a.png");
        assert.strictEqual(Paths.expand("", HOME, SHIPPED), "");
        assert.strictEqual(Paths.expand(undefined, HOME, SHIPPED), "");
    });

    test.it("inserts the home folder literally, even when it holds a dollar sign", () => {
        assert.strictEqual(Paths.expand("~/a.png", "/home/a$&b", SHIPPED), "/home/a$&b/a.png");
    });
});

test.describe("kindOf", () => {
    test.it("tells images, motion, video and audio apart by extension", () => {
        assert.strictEqual(Paths.kindOf("/w/a.png", Paths.FORMATS), "still");
        assert.strictEqual(Paths.kindOf("/w/a.gif", Paths.FORMATS), "motion");
        assert.strictEqual(Paths.kindOf("/w/a.mkv", Paths.FORMATS), "video");
        assert.strictEqual(Paths.kindOf("/w/a.opus", Paths.FORMATS), "audio");
    });

    test.it("ignores the case of the extension", () => {
        assert.strictEqual(Paths.kindOf("/w/Photo.PNG", Paths.FORMATS), "still");
        assert.strictEqual(Paths.kindOf("/w/Clip.MoV", Paths.FORMATS), "video");
    });

    test.it("gives an unknown file or a file with no extension the blank kind", () => {
        for (const file of ["/w/notes.txt", "/w/README", "/w/archive.tar.gz", "/w/photo.png.bak", "/w/trailing.", ""])
            assert.strictEqual(Paths.kindOf(file, Paths.FORMATS), "", file);
    });

    test.it("reads the extension of the file, not a dot in a folder name", () => {
        assert.strictEqual(Paths.kindOf("/w/clips.mp4/cover", Paths.FORMATS), "");
    });

    test.it("gives every listed extension its own kind", () => {
        for (const kind in Paths.FORMATS)
            for (const ext of Paths.FORMATS[kind])
                assert.strictEqual(Paths.kindOf(`/w/x.${ext}`, Paths.FORMATS), kind, ext);
    });
});

test.describe("fits", () => {
    test.it("accepts a picture whose shape is within the fit ratio of the screen", () => {
        assert.ok(Paths.fits(16 / 9, 16 / 10, 1.25));
        assert.ok(Paths.fits(1.2, 1, 1.25));
        assert.ok(Paths.fits(1 / 1.2, 1, 1.25));
    });

    test.it("refuses a picture that is too wide or too tall for the screen", () => {
        assert.ok(!Paths.fits(32 / 9, 16 / 9, 1.25));
        assert.ok(!Paths.fits(9 / 16, 16 / 9, 1.25));
        assert.ok(!Paths.fits(1.3, 1, 1.25));
    });

    test.it("takes the fit setting as the limit", () => {
        assert.ok(Paths.fits(32 / 9, 16 / 9, 2.5));
        assert.ok(!Paths.fits(32 / 9, 16 / 9, 1.5));
    });

    test.it("lets through a picture or screen whose shape is not known", () => {
        assert.ok(Paths.fits(0, 16 / 9, 1.25));
        assert.ok(Paths.fits(32 / 9, 0, 1.25));
        assert.ok(Paths.fits(0, 0, 1.25));
    });
});

test.describe("folder membership", () => {
    test.it("counts a path inside the folder, with or without a trailing slash", () => {
        assert.ok(Paths.within("/w/sea.png", "/w"));
        assert.ok(Paths.within("/w/sea.png", "/w/"));
        assert.ok(Paths.within("/w/sub/sea.png", "/w//"));
    });

    test.it("does not count a folder whose name only starts the same way, or no folder at all", () => {
        assert.ok(!Paths.within("/w2/sea.png", "/w"));
        assert.ok(!Paths.within("/w/sea.png", ""));
    });
});

test.describe("reread", () => {
    const listedSea = { want: "/w/sea.png", verified: "", missing: "", available: ["/w/sea.png", FALLBACK] };

    test.it("checks a wallpaper picked from the folder on disk once the folder stops listing it", () => {
        assert.deepStrictEqual(Paths.reread(listedSea, "/w", [FALLBACK]), { missing: "", verified: "/w/sea.png", recheck: "/w/sea.png" });
    });

    test.it("checks a wallpaper found by probing once the folder stops listing it", () => {
        const state = { want: "/w/sea.png", verified: "/w/sea.png", missing: "", available: [FALLBACK] };
        assert.strictEqual(Paths.reread(state, "/w/", [FALLBACK]).recheck, "/w/sea.png");
    });

    test.it("leaves a wallpaper the folder still lists alone", () => {
        assert.deepStrictEqual(Paths.reread(listedSea, "/w", ["/w/sea.png", FALLBACK]), { missing: "", verified: "", recheck: "" });
    });

    test.it("never checks a wallpaper that is not the one on screen", () => {
        const state = { want: "/w/new.png", verified: "/w/old.png", missing: "/w/new.png", available: [FALLBACK] };
        assert.deepStrictEqual(Paths.reread(state, "/w", [FALLBACK]), { missing: "/w/new.png", verified: "/w/old.png", recheck: "" });
    });

    test.it("forgets a missing wallpaper once the folder lists it again", () => {
        const state = { want: "/w/sea.png", verified: "", missing: "/w/sea.png", available: [FALLBACK] };
        assert.deepStrictEqual(Paths.reread(state, "/w", ["/w/sea.png", FALLBACK]), { missing: "", verified: "", recheck: "" });
    });

    test.it("never checks a wallpaper that lives outside the folder", () => {
        const state = { want: "/wild/sea.png", verified: "/wild/sea.png", missing: "", available: [FALLBACK] };
        assert.strictEqual(Paths.reread(state, "/w", [FALLBACK]).recheck, "");
    });

    test.it("keeps the wallpaper on screen while the check runs, then falls back if it is gone", () => {
        const seen = Paths.reread(listedSea, "/w", [FALLBACK]);
        const after = { ready: true, unreadable: false, want: "/w/sea.png", verified: seen.verified, available: [FALLBACK], fallback: FALLBACK };
        assert.strictEqual(Library.shown(Object.assign({}, after, { missing: seen.missing })), "/w/sea.png");
        assert.strictEqual(Library.shown(Object.assign({}, after, { missing: seen.recheck })), FALLBACK);
    });
});

test.describe("strangeOf", () => {
    test.it("picks the configured paths that the folder does not list", () => {
        const strange = Paths.strangeOf(["/old/a.png", "/w/b.png", "/old/c.png"], ["/w/b.png", FALLBACK], {}, {});
        assert.deepStrictEqual(strange, ["/old/a.png", "/old/c.png"]);
    });

    test.it("skips paths already resolved or asked before, blanks and repeats", () => {
        const strange = Paths.strangeOf(["/old/a.png", "", "/old/a.png", "/old/c.png", "/old/d.png"], ["/w/b.png"], { "/old/c.png": "/w/c.png" }, { "/old/d.png": true });
        assert.deepStrictEqual(strange, ["/old/a.png"]);
    });
});

test.describe("resolved", () => {
    test.it("matches each configured path to the listed wallpaper it really points at", () => {
        const text = ["/data/walls/a.png", "/gone/b.png", "/data/walls/a.png", "/data/walls/b.png"].join("\n");
        assert.deepStrictEqual(Paths.resolved(["/old/a.png", "/old/b.png"], ["/w/a.png", "/w/b.png"], text), { "/old/a.png": "/w/a.png" });
    });

    test.it("gives nothing back when the answer does not line up with the question", () => {
        assert.strictEqual(Paths.resolved(["/old/a.png"], ["/w/a.png", FALLBACK], "/data/walls/a.png\n"), null);
    });
});

test.describe("repairs", () => {
    const ALIASES = { "/home/me/old/a.png": "/w/a.png", "/home/me/old/b.png": "/w/b.png" };

    test.it("moves the configured wallpaper to where its file now lives", () => {
        assert.deepStrictEqual(Paths.repairs(["/home/me/old/a.png"], ALIASES, "~/old/a.png", {}, HOME, SHIPPED), [["wallpaper.current", "/w/a.png"]]);
    });

    test.it("writes nothing for a configured path this pass did not resolve", () => {
        assert.deepStrictEqual(Paths.repairs([], ALIASES, "/home/me/old/a.png", {}, HOME, SHIPPED), []);
    });

    test.it("moves only the screens resolved in this pass and keeps the rest as typed", () => {
        const pairs = Paths.repairs(["/home/me/old/b.png"], ALIASES, "/w/c.png", { "DP-1": "~/old/b.png", "DP-2": "~/old/a.png" }, HOME, SHIPPED);
        assert.deepStrictEqual(pairs, [["wallpaper.perScreen", { "DP-1": "/w/b.png", "DP-2": "~/old/a.png" }]]);
    });

    test.it("writes nothing when no resolved path has an alias", () => {
        assert.deepStrictEqual(Paths.repairs(["/home/me/gone.png"], ALIASES, "/w/c.png", { "DP-1": "/w/d.png" }, HOME, SHIPPED), []);
    });
});
