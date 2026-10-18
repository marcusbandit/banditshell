const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Translation = lib("services/translation.js", ["ask", "languageCode", "languageName", "readAnswer", "keyOf", "splitKey", "pageUrl", "localeCode"]);
const Dictionary = lib("services/dictionary.js", ["ask", "waitingForWord", "readAnswer", "plain", "pageUrl"]);
const Packages = lib("services/packages.js", ["ask", "readSystem", "readAur", "readFlatpakIndex", "readFlatpakInstalled", "searchFlatpaks", "rank", "installToken", "removalOf", "pageUrl", "detailOf"]);
const Github = lib("services/github.js", ["ask", "readSummary", "matches", "ago", "numberUrl"]);
const Browsing = lib("services/browsing.js", ["ask", "hostOf", "prepare", "match"]);
const Speed = lib("services/speedtest.js", ["ask", "fresh", "readLine", "summary", "headline"]);
const Videos = lib("services/videos.js", ["videoUrl", "readProgress", "progressText", "command", "bytes", "needsSignIn", "shortError"]);

test.describe("translate", () => {
    test.it("knows languages by English name, native name and code", () => {
        assert.strictEqual(Translation.languageCode("German"), "de");
        assert.strictEqual(Translation.languageCode("deutsch"), "de");
        assert.strictEqual(Translation.languageCode("Français"), "fr");
        assert.strictEqual(Translation.languageCode("francais"), "fr");
        assert.strictEqual(Translation.languageCode("dansk"), "da");
        assert.strictEqual(Translation.languageCode("日本語"), "ja");
        assert.strictEqual(Translation.languageCode("mandarin"), "zh-CN");
        assert.strictEqual(Translation.languageCode("traditional chinese"), "zh-TW");
        assert.strictEqual(Translation.languageCode("es"), "es");
        assert.strictEqual(Translation.languageCode("klingon"), "");
    });

    test.it("names the codes Google answers with", () => {
        assert.strictEqual(Translation.languageName("en"), "English");
        assert.strictEqual(Translation.languageName("zh-CN"), "Chinese");
        assert.strictEqual(Translation.languageName("he"), "Hebrew");
        assert.strictEqual(Translation.languageName("iw"), "Hebrew");
        assert.strictEqual(Translation.languageName("pt-BR"), "Portuguese");
        assert.strictEqual(Translation.languageName("xx"), "");
        assert.strictEqual(Translation.localeCode("da_DK.UTF-8"), "da");
        assert.strictEqual(Translation.localeCode("en_DK"), "en");
    });

    test.it("reads the ways people ask for a translation", () => {
        assert.deepStrictEqual(Translation.ask("hello in german"), { text: "hello", to: "de", explicit: true });
        assert.deepStrictEqual(Translation.ask("translate bonjour"), { text: "bonjour", to: "", explicit: false });
        assert.deepStrictEqual(Translation.ask("bonjour to english"), { text: "bonjour", to: "en", explicit: true });
        assert.deepStrictEqual(Translation.ask("tr hola"), { text: "hola", to: "", explicit: false });
        assert.deepStrictEqual(Translation.ask("translate how to cook rice to french"), { text: "how to cook rice", to: "fr", explicit: true });
        assert.deepStrictEqual(Translation.ask("tr good night to de"), { text: "good night", to: "de", explicit: true });
        assert.deepStrictEqual(Translation.ask("how do you say thank you in japanese?"), { text: "thank you", to: "ja", explicit: true });
        assert.deepStrictEqual(Translation.ask("tea in traditional chinese"), { text: "tea", to: "zh-TW", explicit: true });
        assert.deepStrictEqual(Translation.ask("good morning in dansk"), { text: "good morning", to: "da", explicit: true });
    });

    test.it("leaves other questions alone", () => {
        assert.strictEqual(Translation.ask("time in tokyo"), null);
        assert.strictEqual(Translation.ask("5 usd to eur"), null);
        assert.strictEqual(Translation.ask("move to workspace 2"), null);
        assert.strictEqual(Translation.ask("10 in german"), null);
        assert.strictEqual(Translation.ask("hello to de"), null);
        assert.strictEqual(Translation.ask("in german"), null);
        assert.strictEqual(Translation.ask("translate"), null);
        assert.strictEqual(Translation.ask("tram"), null);
    });

    test.it("reads both Google answer shapes and plain trans output", () => {
        assert.deepStrictEqual(Translation.readAnswer('[[["Hallo Welt. ","Hello world.",null,null,10],["Wie geht es dir?","How are you?",null,null,10]],null,"en",null,null,null,1]'), { text: "Hallo Welt. Wie geht es dir?", from: "en" });
        assert.deepStrictEqual(Translation.readAnswer('[["Hallo","en"]]'), { text: "Hallo", from: "en" });
        assert.deepStrictEqual(Translation.readAnswer('["Good morning"]'), { text: "Good morning", from: "" });
        assert.deepStrictEqual(Translation.readAnswer("Hallo\n"), { text: "Hallo", from: "" });
        assert.strictEqual(Translation.readAnswer("<html><title>Sorry...</title>"), null);
        assert.strictEqual(Translation.readAnswer("[oops"), null);
        assert.strictEqual(Translation.readAnswer(""), null);
    });

    test.it("keys a lookup by target and text", () => {
        const key = Translation.keyOf("a|b", "de");
        assert.deepStrictEqual(Translation.splitKey(key), { to: "de", text: "a|b" });
        assert.ok(Translation.pageUrl("hi there", "de").includes("tl=de&text=hi%20there"));
    });
});

test.describe("define", () => {
    test.it("finds the word being asked about", () => {
        const word = text => Dictionary.ask(text)?.explicit ? Dictionary.ask(text).word : "";
        assert.strictEqual(word("define serendipity"), "serendipity");
        assert.strictEqual(word("Define Ad Hoc"), "ad hoc");
        assert.strictEqual(word("def ephemeral"), "ephemeral");
        assert.strictEqual(word("define: \u201cephemeral\u201d"), "ephemeral");
        assert.strictEqual(word("what does ephemeral mean?"), "ephemeral");
        assert.strictEqual(word("what's the meaning of life"), "life");
        assert.strictEqual(word("meaning of well-being"), "well-being");
        assert.strictEqual(word("definition of done"), "done");
        assert.strictEqual(word("serendipity meaning"), "serendipity");
        assert.strictEqual(word("ubiquitous definition?"), "ubiquitous");
        assert.strictEqual(word("synonyms for happy"), "happy");
        assert.strictEqual(word("happy synonyms"), "happy");
        assert.strictEqual(word("dict caf\u00e9"), "caf\u00e9");
        assert.strictEqual(word("define"), "");
        assert.strictEqual(word("define 42"), "");
        assert.strictEqual(word("define a/b"), "");
        assert.strictEqual(word("defined"), "");
        assert.strictEqual(word("define one two three four five"), "");
    });

    test.it("offers a quiet lookup for a lone word", () => {
        assert.deepStrictEqual(Dictionary.ask("Serendipity"), { word: "serendipity", explicit: false });
        assert.strictEqual(Dictionary.ask("fir"), null);
        assert.strictEqual(Dictionary.ask("firefox nightly"), null);
        assert.strictEqual(Dictionary.ask("2+2"), null);
    });

    test.it("knows when the ask is waiting for its word", () => {
        assert.strictEqual(Dictionary.waitingForWord("define "), true);
        assert.strictEqual(Dictionary.waitingForWord("Define\t"), true);
        assert.strictEqual(Dictionary.waitingForWord("  meaning of  "), true);
        assert.strictEqual(Dictionary.waitingForWord("definition of "), true);
        assert.strictEqual(Dictionary.waitingForWord("define"), false);
        assert.strictEqual(Dictionary.waitingForWord("define word"), false);
        assert.strictEqual(Dictionary.waitingForWord("defined "), false);
        assert.strictEqual(Dictionary.waitingForWord("def "), true);
        assert.strictEqual(Dictionary.waitingForWord("synonyms for "), true);
        assert.strictEqual(Dictionary.waitingForWord("dict "), false);
        assert.strictEqual(Dictionary.waitingForWord("dictionary "), false);
    });

    test.it("reads Wiktionary and strips its markup", () => {
        const raw = JSON.stringify({ en: [{ partOfSpeech: "Noun", definitions: [{ definition: "The <a href=\"/wiki/x\">phenomenon</a> of finding &amp; keeping." }, { definition: "" }] }], fr: [{ partOfSpeech: "Nom", definitions: [{ definition: "autre" }] }] });
        const got = Dictionary.readAnswer(raw, "serendipity");
        assert.strictEqual(got.word, "serendipity");
        assert.deepStrictEqual(got.senses, [{ part: "noun", text: "The phenomenon of finding & keeping.", example: "" }]);
    });

    test.it("gives nothing for errors and empty answers", () => {
        assert.strictEqual(Dictionary.readAnswer('{"title":"No Definitions Found"}', "x"), null);
        assert.strictEqual(Dictionary.readAnswer("[]", "x"), null);
        assert.strictEqual(Dictionary.readAnswer("not json", "x"), null);
        assert.strictEqual(Dictionary.pageUrl("ad hoc"), "https://en.wiktionary.org/wiki/ad_hoc");
    });
});

test.describe("packages", () => {
    test.it("finds what to search for", () => {
        assert.strictEqual(Packages.ask("install ripgrep"), "ripgrep");
        assert.strictEqual(Packages.ask("pkg firefox"), "firefox");
        assert.strictEqual(Packages.ask("package spotify"), "spotify");
        assert.strictEqual(Packages.ask("install"), "");
        assert.strictEqual(Packages.ask("installer"), "");
    });

    test.it("reads pacman with installed state and groups", () => {
        const got = Packages.readSystem([
            "@@ pacman",
            "extra/repgrep 0.17.1-1",
            "    An interactive command line replacer for ripgrep",
            "extra/ripgrep 15.2.0-1 [installed]",
            "    A search tool",
            "core/gcc 15.1.1-1 (base-devel) [installed: 15.1.0-2]",
            "    The GNU Compiler Collection"
        ].join("\n"));
        assert.deepStrictEqual(got.map(p => [p.name, p.version, p.installed, p.installedVersion, p.repo]), [
            ["repgrep", "0.17.1-1", false, "", "extra"],
            ["ripgrep", "15.2.0-1", true, "15.2.0-1", "extra"],
            ["gcc", "15.1.1-1", true, "15.1.0-2", "core"]
        ]);
        assert.strictEqual(got[0].description, "An interactive command line replacer for ripgrep");
    });

    test.it("reads apt search with its policy", () => {
        const got = Packages.readSystem([
            "@@ apt",
            "ripgrep - Recursively searches directories for a regex pattern",
            "ugrep - faster grep",
            "@@ apt-policy",
            "ripgrep:",
            "  Installed: 13.0.0-4",
            "  Candidate: 14.1.0-1",
            "ugrep:",
            "  Installed: (none)",
            "  Candidate: 3.11.2-1"
        ].join("\n"));
        assert.deepStrictEqual(got.map(p => [p.source, p.name, p.version, p.installed, p.installedVersion]), [
            ["apt", "ripgrep", "14.1.0-1", true, "13.0.0-4"],
            ["apt", "ugrep", "3.11.2-1", false, ""]
        ]);
    });

    test.it("reads dnf four and five, zypper, xbps and apk", () => {
        const dnf = Packages.readSystem("@@ dnf\n===== Name Exactly Matched: ripgrep =====\nripgrep.x86_64 : Line-oriented search tool\n Matched fields: name\n ripgrep-doc.noarch\tDocs\n@@ rpm\nripgrep 14.1.0-1.fc41\n");
        assert.deepStrictEqual(dnf.map(p => [p.name, p.installed, p.version, p.description]), [["ripgrep", true, "14.1.0-1.fc41", "Line-oriented search tool"], ["ripgrep-doc", false, "", "Docs"]]);
        const zypper = Packages.readSystem("@@ zypper\nS  | Name    | Summary          | Type\n---+---------+------------------+--------\ni+ | ripgrep | A search tool    | package\n   | ripgrep | A search tool    | srcpackage\n   | rgx     | Other            | package\n");
        assert.deepStrictEqual(zypper.map(p => [p.name, p.installed, p.description]), [["ripgrep", true, "A search tool"], ["rgx", false, "Other"]]);
        const xbps = Packages.readSystem("@@ xbps\n[*] ripgrep-14.1.0_1  Fast line-oriented search\n[-] ripgrep-all-0.10.6_1 ripgrep for everything\n");
        assert.deepStrictEqual(xbps.map(p => [p.name, p.version, p.installed]), [["ripgrep", "14.1.0_1", true], ["ripgrep-all", "0.10.6_1", false]]);
        const apk = Packages.readSystem("@@ apk\nripgrep-14.1.0-r0 - Fast search\nripgrep-doc-14.1.0-r0 - Docs\n@@ apk-installed\nripgrep\n");
        assert.deepStrictEqual(apk.map(p => [p.name, p.version, p.installed]), [["ripgrep", "14.1.0-r0", true], ["ripgrep-doc", "14.1.0-r0", false]]);
        assert.strictEqual(Packages.readSystem(""), null);
    });

    test.it("reads the AUR and marks what is already built", () => {
        const got = Packages.readAur(`@@ foreign\nparu 2.0.4-1\n@@ aur\n${JSON.stringify({ resultcount: 2, type: "search", results: [{ Name: "paru", Version: "2.1.0-1", Description: "AUR helper", Popularity: 30 }, { Name: "paru-bin", Version: "2.1.0-1", Description: "binary", Popularity: 5 }] })}`);
        assert.deepStrictEqual(got.map(p => [p.name, p.installed, p.installedVersion]), [["paru", true, "2.0.4-1"], ["paru-bin", false, ""]]);
        assert.deepStrictEqual(Packages.readAur(`@@ aur\n{"type":"error","error":"Too many package results."}`), []);
        assert.strictEqual(Packages.readAur("@@ aur\n"), null);
    });

    test.it("searches the Flatpak index and knows what is installed", () => {
        const index = Packages.readFlatpakIndex(JSON.stringify({ apps: [
            { id: "com.spotify.Client", name: "Spotify", summary: "Music", version: "1.2", remote: "flathub", installation: "system", icon: "/x/spotify.png" },
            { id: "org.mozilla.firefox", name: "Firefox", summary: "Browser", version: "158.0", remote: "flathub", installation: "system" }
        ] }));
        const installed = Packages.readFlatpakInstalled("org.mozilla.firefox\t157.0\tuser\n");
        assert.deepStrictEqual(Packages.searchFlatpaks(index, "spot", installed).map(p => [p.name, p.title, p.installed]), [["com.spotify.Client", "Spotify", false]]);
        assert.deepStrictEqual(Packages.searchFlatpaks(index, "firefox", installed).map(p => [p.name, p.installed, p.installedVersion, p.installation]), [["org.mozilla.firefox", true, "157.0", "user"]]);
        assert.deepStrictEqual(Packages.removalOf(Packages.searchFlatpaks(index, "firefox", installed)[0]), { how: "flatpak-user", package: "org.mozilla.firefox" });
        assert.strictEqual(Packages.searchFlatpaks(index, "spot", installed)[0].installation, "system");
        assert.deepStrictEqual(Packages.searchFlatpaks(index, "", installed), []);
    });

    test.it("ranks exact names first, then the system over Flatpak over the AUR", () => {
        const make = (source, name, extra) => Object.assign({ source, name, title: name, version: "1", description: "", installed: false, popularity: 0 }, extra || {});
        const got = Packages.rank([
            [make("pacman", "ripgrep-all"), make("pacman", "repgrep", { description: "for ripgrep" })],
            [make("aur", "ripgrep", { popularity: 3 }), make("aur", "ripgrep-git", { popularity: 9 })],
            [make("flatpak", "io.github.ripgrep", { title: "ripgrep" })]
        ], "ripgrep");
        assert.deepStrictEqual(got.map(p => `${p.source}:${p.name}`), ["flatpak:io.github.ripgrep", "aur:ripgrep", "pacman:ripgrep-all", "aur:ripgrep-git", "pacman:repgrep"]);
    });

    test.it("names the install, the removal and the page", () => {
        const flat = { source: "flatpak", name: "com.spotify.Client", repo: "flathub", installation: "user" };
        assert.strictEqual(Packages.installToken(flat), "flatpak:user/flathub/com.spotify.Client");
        assert.deepStrictEqual(Packages.removalOf(flat), { how: "flatpak-user", package: "com.spotify.Client" });
        assert.strictEqual(Packages.pageUrl(flat), "https://flathub.org/apps/com.spotify.Client");
        assert.strictEqual(Packages.installToken({ source: "aur", name: "paru" }), "aur:paru");
        assert.deepStrictEqual(Packages.removalOf({ source: "aur", name: "paru" }), { how: "pacman", package: "paru" });
        assert.strictEqual(Packages.pageUrl({ source: "aur", name: "paru" }), "https://aur.archlinux.org/packages/paru");
        assert.strictEqual(Packages.pageUrl({ source: "apt", name: "ripgrep" }), "https://repology.org/project/ripgrep/versions");
    });

    test.it("shows source, version and installed state as detail", () => {
        assert.strictEqual(Packages.detailOf({ source: "pacman", version: "15.2.0-1", installed: true, installedVersion: "15.2.0-1", description: "A search tool" }), "pacman 15.2.0-1 · installed · A search tool");
        assert.strictEqual(Packages.detailOf({ source: "aur", version: "2.1.0-1", installed: true, installedVersion: "2.0.4-1", description: "" }), "AUR 2.0.4-1 to 2.1.0-1 · installed");
        assert.strictEqual(Packages.detailOf({ source: "flatpak", version: "", installed: false, description: "Music" }), "Flatpak · Music");
    });
});

test.describe("github", () => {
    test.it("reads what is asked", () => {
        assert.deepStrictEqual(Github.ask("gh"), { filter: "", number: 0, kind: "" });
        assert.deepStrictEqual(Github.ask("GitHub Bandit"), { filter: "bandit", number: 0, kind: "" });
        assert.deepStrictEqual(Github.ask("pr 17"), { filter: "", number: 17, kind: "pull" });
        assert.deepStrictEqual(Github.ask("issue #4"), { filter: "", number: 4, kind: "issue" });
        assert.strictEqual(Github.ask("ghost"), null);
        assert.strictEqual(Github.ask("print"), null);
    });

    test.it("reads the summary, newest repos first", () => {
        const got = Github.readSummary(JSON.stringify({
            repos: [{ nameWithOwner: "me/old", pushedAt: "2026-01-01T00:00:00Z" }, { nameWithOwner: "me/new", pushedAt: "2026-10-01T00:00:00Z", isPrivate: true }],
            pulls: [{ number: 19, title: "Smart launcher", repository: { nameWithOwner: "me/new" }, url: "u", isDraft: true }],
            issues: [],
            notifications: 24
        }));
        assert.deepStrictEqual(got.repos.map(r => [r.short, r.private]), [["new", true], ["old", false]]);
        assert.deepStrictEqual([got.pulls[0].short, got.pulls[0].draft, got.pulls[0].pull], ["new", true, true]);
        assert.strictEqual(got.notifications, 24);
        assert.strictEqual(Github.readSummary("{}"), null);
        assert.strictEqual(Github.readSummary(""), null);
    });

    test.it("filters by words and says how long ago", () => {
        const items = [{ short: "skema", name: "me/skema", description: "bandit schedule" }, { short: "banditshell", name: "me/banditshell", description: "shell" }, { short: "other", name: "me/other", description: "" }];
        assert.deepStrictEqual(Github.matches(items, "bandit", ["short", "name", "description"]).map(i => i.name), ["me/banditshell", "me/skema"]);
        assert.deepStrictEqual(Github.matches(items, "", ["name"]).map(i => i.short), ["skema", "banditshell", "other"]);
        const now = Date.parse("2026-10-16T12:00:00Z");
        assert.strictEqual(Github.ago(now - 5 * 60000, now), "5 min ago");
        assert.strictEqual(Github.ago(now - 3 * 3600000, now), "3 h ago");
        assert.strictEqual(Github.ago(now - 26 * 3600000, now), "yesterday");
        assert.strictEqual(Github.numberUrl("me/x", "pull", 17), "https://github.com/me/x/pull/17");
    });
});

test.describe("bookmarks and history", () => {
    const places = Browsing.prepare({ places: [
        { url: "https://www.github.com/marcusbandit", title: "marcusbandit", bookmark: true, visits: 3 },
        { url: "https://news.ycombinator.com/", title: "Hacker News", visits: 400, last: 5 },
        { url: "https://example.com/hacker", title: "", visits: 1 },
        { url: "https://docs.python.org/3/library/sqlite3.html", title: "sqlite3: DB-API", visits: 2 }
    ] });

    test.it("prepares titles and hosts", () => {
        assert.strictEqual(places[0].host, "github.com");
        assert.strictEqual(places[2].title, "example.com");
        assert.strictEqual(Browsing.hostOf("http://user@Sub.Example.org:8080/x"), "sub.example.org");
    });

    test.it("matches word starts, keeps weak history matches out", () => {
        assert.deepStrictEqual(Browsing.match(places, Browsing.ask("hack"), 5).map(m => m.place.title), ["Hacker News"]);
        assert.deepStrictEqual(Browsing.match(places, Browsing.ask("bandit"), 5).map(m => m.place.title), ["marcusbandit"]);
        assert.deepStrictEqual(Browsing.match(places, Browsing.ask("sqlite"), 5).map(m => m.place.host), ["docs.python.org"]);
    });

    test.it("shows one row for pages that share a title and host", () => {
        const same = Browsing.prepare({ places: [
            { url: "https://www.youtube.com/", title: "YouTube", visits: 40 },
            { url: "https://www.youtube.com/?app=desktop", title: "YouTube", visits: 2 },
            { url: "https://www.youtube.com/feed", title: "YouTube", bookmark: true }
        ] });
        assert.deepStrictEqual(Browsing.match(same, Browsing.ask("youtube"), 5).map(m => [m.place.url, m.place.bookmark]), [["https://www.youtube.com/", false], ["https://www.youtube.com/feed", true]]);
    });

    test.it("narrows to bookmarks or history when asked", () => {
        assert.deepStrictEqual(Browsing.ask("bookmarks git"), { term: "git", only: "bookmarks" });
        assert.deepStrictEqual(Browsing.match(places, Browsing.ask("bm"), 5).map(m => m.place.title), ["marcusbandit"]);
        assert.deepStrictEqual(Browsing.match(places, Browsing.ask("history hacker"), 5).map(m => m.place.title), ["Hacker News"]);
    });
});

test.describe("speedtest", () => {
    test.it("knows when it is asked for", () => {
        assert.ok(Speed.ask("speedtest"));
        assert.ok(Speed.ask("speed test"));
        assert.ok(Speed.ask("test my internet"));
        assert.ok(!Speed.ask("speedtest now please"));
    });

    test.it("follows speedtest-cli line by line", () => {
        let s = Speed.fresh();
        for (const line of ["Retrieving speedtest.net configuration...", "Testing from Telia (1.2.3.4)...", "Selecting best server based on ping...", "Hosted by GlobalConnect (Copenhagen) [3.21 km]: 12.873 ms", "Testing download speed................................................................................"])
            s = Speed.readLine(s, line);
        assert.strictEqual(s.phase, "download");
        assert.strictEqual(s.server, "GlobalConnect (Copenhagen)");
        assert.strictEqual(Speed.summary(s), "ping 13 ms");
        s = Speed.readLine(s, "Download: 412.34 Mbit/s");
        s = Speed.readLine(s, "Testing upload speed......");
        assert.strictEqual(s.phase, "upload");
        s = Speed.readLine(s, "Upload: 38.21 Mbit/s");
        assert.strictEqual(s.phase, "done");
        assert.strictEqual(Speed.summary(s), "ping 13 ms · down 412 Mbit/s · up 38.2 Mbit/s");
        assert.strictEqual(Speed.headline(s), "412 down · 38.2 up");
        assert.strictEqual(Speed.readLine(Speed.fresh(), "Cannot retrieve speedtest configuration").failed, "Cannot retrieve speedtest configuration");
    });
});

test.describe("video downloads", () => {
    test.it("recognises video pages and nothing else", () => {
        assert.strictEqual(Videos.videoUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ").host, "youtube.com");
        assert.strictEqual(Videos.videoUrl("https://youtu.be/dQw4w9WgXcQ").host, "youtu.be");
        assert.strictEqual(Videos.videoUrl("https://m.youtube.com/shorts/abcdefg").host, "youtube.com");
        assert.strictEqual(Videos.videoUrl("https://vimeo.com/76979871").host, "vimeo.com");
        assert.strictEqual(Videos.videoUrl("https://x.com/someone/status/1234567890").host, "x.com");
        assert.ok(Videos.videoUrl("https://soundcloud.com/artist/track").audioOnly);
        assert.strictEqual(Videos.videoUrl("https://www.youtube.com/"), null);
        assert.strictEqual(Videos.videoUrl("https://www.youtube.com/playlist?list=PL1"), null);
        assert.strictEqual(Videos.videoUrl("https://github.com/marcusbandit"), null);
        assert.strictEqual(Videos.videoUrl("youtube.com/watch?v=x"), null);
        assert.strictEqual(Videos.videoUrl("watch this https://youtu.be/abcdefg"), null);
    });

    test.it("reads progress lines and writes them for a person", () => {
        const p = Videos.readProgress("@@progress downloading 52428800 104857600 NA 3145728 62");
        assert.deepStrictEqual(p, { status: "downloading", done: 52428800, total: 104857600, speed: 3145728, eta: 62 });
        assert.strictEqual(Videos.progressText(p), "50% · 3.1 MB/s · 1:02 left");
        const estimated = Videos.readProgress("@@progress downloading 1000 NA 4000 NA NA");
        assert.strictEqual(Videos.progressText(estimated), "25%");
        assert.strictEqual(Videos.readProgress("[download] 50%"), null);
        assert.strictEqual(Videos.bytes(1500000000), "1.5 GB");
    });

    test.it("builds the yt-dlp command", () => {
        const video = Videos.command("https://youtu.be/x", false, "/home/me/Downloads", true);
        assert.deepStrictEqual(video.slice(-2), ["--", "https://youtu.be/x"]);
        assert.ok(video.includes("--no-playlist"));
        assert.ok(!video.includes("-x"));
        assert.ok(Videos.command("u", true, "/d", true).includes("-x"));
        assert.deepStrictEqual(Videos.command("u", true, "/d", false).slice(-4, -2), ["-f", "bestaudio"]);
        assert.deepStrictEqual(Videos.command("u", false, "/d", true, "firefox:/p").slice(-4, -2), ["--cookies-from-browser", "firefox:/p"]);
    });

    test.it("knows when a site wants the browser's sign-in", () => {
        assert.ok(Videos.needsSignIn("[youtube] x: Sign in to confirm you\u2019re not a bot. Use --cookies-from-browser"));
        assert.ok(!Videos.needsSignIn("Unable to download webpage: HTTP Error 404"));
        assert.strictEqual(Videos.shortError("ERROR: [youtube] jNQXAC9IVRw: Sign in to confirm you are not a bot. Use --cookies-from-browser or --cookies"), "Sign in to confirm you are not a bot");
        assert.strictEqual(Videos.shortError("ERROR: Unsupported URL: https://x.test/a"), "Unsupported URL: https://x.test/a");
    });
});
