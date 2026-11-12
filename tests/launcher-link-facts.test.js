const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const ROOT = path.resolve(__dirname, "..");
function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}
const Links = lib("services/link-facts.js", ["parse", "describe", "clean", "fetchable", "secret", "readPage", "resolve", "placeOf", "youtubeTime", "masked", "factsOf", "keyOf", "oembedOf", "readEmbed", "bestTitle"]);
const shown = url => ({ kind: Links.describe(url).kind, title: Links.describe(url).title });

test("a GitHub profile link reads as the profile name", () => assert.deepStrictEqual(shown("https://github.com/someone"), { kind: "GitHub profile", title: "someone" }));
test("a GitHub repository link reads as the repository", () => assert.deepStrictEqual(shown("https://github.com/someone/project"), { kind: "GitHub repository", title: "someone/project" }));
test("a GitHub issue link reads as the repository and its number", () => assert.deepStrictEqual(shown("https://github.com/someone/project/issues/12"), { kind: "GitHub issue", title: "someone/project #12" }));
test("a GitHub pull request link reads as the repository and its number", () => assert.deepStrictEqual(shown("https://github.com/someone/project/pull/3"), { kind: "GitHub pull request", title: "someone/project #3" }));
test("a GitHub file link reads as the path inside the repository", () => assert.strictEqual(shown("https://github.com/someone/project/blob/main/docs/readme.md").title, "someone/project › docs/readme.md"));
test("a GitHub tree link with no path reads as the repository on its branch", () => assert.deepStrictEqual(shown("https://github.com/someone/project/tree/main"), { kind: "GitHub repository", title: "someone/project on main" }));
test("a GitHub Actions run reads as the run number", () => assert.deepStrictEqual(shown("https://github.com/someone/project/actions/runs/777"), { kind: "GitHub Actions run", title: "someone/project run 777" }));
test("the GitHub device login page reads as a device sign-in", () => assert.strictEqual(shown("https://github.com/login/device").kind, "GitHub device login"));

test("a YouTube watch link reads as a video titled by its ID", () => assert.deepStrictEqual(shown("https://www.youtube.com/watch?v=abc123"), { kind: "YouTube video", title: "abc123" }));
test("a YouTube watch link with a start time says where it begins", () => assert.strictEqual(shown("https://www.youtube.com/watch?v=abc123&t=718").title, "abc123 at 11:58"));
test("a youtu.be link with a start time reads the time as minutes and seconds", () => assert.strictEqual(shown("https://youtu.be/abc123?t=90").title, "abc123 at 1:30"));
test("a YouTube Shorts link reads as a Short", () => assert.deepStrictEqual(shown("https://www.youtube.com/shorts/abc123"), { kind: "YouTube Short", title: "abc123" }));
test("a YouTube time written with hours, minutes and seconds reads as a clock", () => assert.strictEqual(Links.youtubeTime("1h2m3s"), "1:02:03"));

test("a Reddit post reads as its subreddit and a sentence-cased title", () => assert.deepStrictEqual(shown("https://www.reddit.com/r/sub/comments/abc/some_post_title"), { kind: "Reddit post", title: "r/sub · Some post title" }));
test("a Reddit share link reads as a share from the subreddit", () => assert.deepStrictEqual(shown("https://www.reddit.com/r/sub/s/xyz"), { kind: "Reddit share link", title: "r/sub" }));
test("a subreddit link reads as the subreddit", () => assert.deepStrictEqual(shown("https://www.reddit.com/r/sub"), { kind: "Subreddit", title: "r/sub" }));

test("a Google Doc link reads as a Google Doc", () => assert.strictEqual(shown("https://docs.google.com/document/d/abc/edit").kind, "Google Doc"));
test("a share.google link reads as a Google share link", () => assert.deepStrictEqual(shown("https://share.google/abc"), { kind: "Google share link", title: "abc" }));

test("a localhost link reads as a local server on its port", () => assert.deepStrictEqual(shown("http://localhost:4226/"), { kind: "Local server", title: "Port 4226" }));
test("a 127.0.0.1 link with a path reads as a local server", () => assert.strictEqual(shown("http://127.0.0.1:9117/api").kind, "Local server"));
test("a tailnet device link reads as the device name and port", () => assert.deepStrictEqual(shown("https://box.example-tailnet.ts.net:8787/"), { kind: "Device on your tailnet", title: "box:8787" }));
test("a single-label host reads as a device on your network", () => assert.deepStrictEqual(shown("https://printer"), { kind: "Device on your network", title: "printer" }));
test("hosts sort into tailnet, network and web places", () => assert.deepStrictEqual(["100.100.1.2", "192.168.1.20", "example.com"].map(Links.placeOf), ["tailnet", "network", "web"]));

test("a .mp4 link reads as a video file", () => assert.deepStrictEqual(shown("https://example.com/clips/intro.mp4"), { kind: "Video file", title: "intro.mp4" }));
test("a .png link reads as an image file", () => assert.strictEqual(shown("https://example.com/img/logo.png").kind, "Image file"));
test("a .pdf link reads as a PDF", () => assert.strictEqual(shown("https://example.com/docs/manual.pdf").kind, "PDF"));
test("a .zip link reads as a download", () => assert.strictEqual(shown("https://example.com/files/tool.zip").kind, "Download"));
test("a plain page reads as a web page titled from its last path words", () => assert.strictEqual(shown("https://example.com/shop/hooded-wool-coat").title, "Shop › Hooded wool coat"));
test("www. is dropped from the host shown", () => assert.strictEqual(Links.describe("https://www.example.com/a").host, "example.com"));

test("tracking parameters are removed and the other parameters and fragment stay", () => assert.strictEqual(Links.clean("https://example.com/a?si=XYZ&id=3#top"), "https://example.com/a?id=3#top"));
test("a URL whose only parameters are tracking loses the question mark", () => assert.strictEqual(Links.clean("https://example.com/a?utm_source=news"), "https://example.com/a"));
test("a URL without tracking parameters comes back unchanged", () => assert.strictEqual(Links.clean("https://example.com/a?id=3"), "https://example.com/a?id=3"));

test("a link with an apikey or token parameter is secret and not fetchable", () => {
    for (const url of ["https://example.com/a?apikey=abc", "https://example.com/a?token=abc"]) {
        assert.strictEqual(Links.secret(url), true, url);
        assert.strictEqual(Links.fetchable(url), false, url);
    }
});
test("a link carrying a long random value is secret", () => {
    const url = "https://example.com/a?x=abcdefghijklmnopqrstuvwxyz012345";
    assert.strictEqual(Links.secret(url), true);
    assert.strictEqual(Links.fetchable(url), false);
});
test("a link with a username and password is secret", () => {
    assert.strictEqual(Links.secret("https://someone:pw@example.com/"), true);
    assert.strictEqual(Links.fetchable("https://someone:pw@example.com/"), false);
});
test("a plain https link is fetchable and not secret", () => {
    assert.strictEqual(Links.fetchable("https://example.com/a?id=3"), true);
    assert.strictEqual(Links.secret("https://example.com/a?id=3"), false);
});
test("an ftp link is not fetchable", () => assert.strictEqual(Links.fetchable("ftp://example.com/file"), false));

test("the Open Graph title wins over the page title", () => assert.strictEqual(Links.readPage('<title>Plain title</title><meta property="og:title" content="Open title">', "https://example.com/p").title, "Open title"));
test("the page title is the fallback and entities are decoded", () => assert.strictEqual(Links.readPage("<title>Only &amp; title &#39;x&#39;</title>", "https://example.com/p").title, "Only & title 'x'"));
test("the description comes from Open Graph, else the meta description", () => {
    assert.strictEqual(Links.readPage('<meta property="og:description" content="Open desc"><meta name="description" content="Plain desc">', "https://example.com/p").description, "Open desc");
    assert.strictEqual(Links.readPage('<meta name="description" content="Plain desc">', "https://example.com/p").description, "Plain desc");
});
test("a relative og:image resolves against the page URL", () => assert.strictEqual(Links.readPage('<meta property="og:image" content="/img/a.png">', "https://example.com/shop/item").image, "https://example.com/img/a.png"));
test("a relative icon link resolves against the page URL", () => assert.strictEqual(Links.readPage('<link rel="icon" href="/static/i.png">', "https://example.com/shop/item").icon, "https://example.com/static/i.png"));
test("a page with no icon link falls back to the favicon on its origin", () => assert.strictEqual(Links.readPage("<html></html>", "https://example.com/shop/item").icon, "https://example.com/favicon.ico"));

test("an absolute URL passes through resolve unchanged", () => assert.strictEqual(Links.resolve("https://example.com/a", "https://other.example.org/x.png"), "https://other.example.org/x.png"));
test("a protocol-relative URL takes the page's scheme", () => assert.strictEqual(Links.resolve("https://example.com/a", "//cdn.example.com/x.png"), "https://cdn.example.com/x.png"));
test("a bare relative file name resolves against the page's directory", () => assert.strictEqual(Links.resolve("https://example.com/shop/item", "pic.png"), "https://example.com/shop/pic.png"));

test("a link with a key shows the key as dots and lists it as hidden", () => {
    const url = "http://127.0.0.1:9117/api/search?apikey=abcdefabcdefabcdefabcdefabcdef12&q=Some+Show#top";
    assert.strictEqual(Links.masked(url), "http://127.0.0.1:9117/api/search?apikey=••••&q=Some+Show#top");
    assert.strictEqual(Links.masked("https://user:pass@example.com/x"), "https://••••@example.com/x");
    assert.strictEqual(Links.masked("https://example.com/a?id=3"), "https://example.com/a?id=3");
    const facts = Links.factsOf(Links.describe(url));
    assert.deepStrictEqual(facts.map(f => f.label), ["Kind", "Site", "Path", "apikey", "q", "Anchor"]);
    assert.strictEqual(facts.find(f => f.label === "apikey").value, "hidden");
    assert.strictEqual(facts.find(f => f.label === "q").value, "Some Show");
});

test("tracking parameters are named in the facts instead of listed one by one", () => {
    const facts = Links.factsOf(Links.describe("https://example.com/watch?v=abc&si=xyz&utm_source=feed"));
    assert.deepStrictEqual(facts.slice(-2), [{ label: "v", value: "abc" }, { label: "Tracking", value: "si, utm_source" }]);
    assert.strictEqual(Links.keyOf("https://example.com"), Links.keyOf("https://example.com"));
    assert.notStrictEqual(Links.keyOf("https://example.com/a"), Links.keyOf("https://example.com/b"));
});

test("a YouTube link asks YouTube's oEmbed for its title, and other links do not", () => {
    assert.match(Links.oembedOf("https://youtube.com/shorts/abc123?si=x"), /^https:\/\/www\.youtube\.com\/oembed\?format=json&url=https%3A%2F%2Fyoutube\.com%2Fshorts%2Fabc123/);
    assert.strictEqual(Links.oembedOf("https://example.com/watch?v=1"), "");
    const got = Links.readEmbed('{"title":"A video","author_name":"Someone","thumbnail_url":"https://i.example.com/t.jpg"}');
    assert.deepStrictEqual([got.title, got.description, got.image], ["A video", "by Someone", "https://i.example.com/t.jpg"]);
    assert.strictEqual(Links.readEmbed("<html>"), null);
});

test("a page title that only names the site gives way to what the link points at", () => {
    const share = Links.describe("https://www.reddit.com/r/somesub/s/abc");
    assert.strictEqual(Links.bestTitle(share, { title: "Reddit" }), "r/somesub");
    assert.strictEqual(Links.bestTitle(share, { title: "A real post title" }), "A real post title");
    assert.strictEqual(Links.bestTitle(share, null), "r/somesub");
    const video = Links.describe("https://www.youtube.com/watch?v=abc&t=90");
    assert.strictEqual(Links.bestTitle(video, { title: "Before you continue to YouTube" }), "abc at 1:30");
    assert.deepStrictEqual(Links.factsOf(video).map(f => f.label), ["Kind", "Site", "Path", "Starts at"]);
});

test("only public web pages are fetched for a preview, never local machines or one-time links", () => {
    for (const url of ["http://localhost:8080/api/reset", "http://192.168.1.20/reboot.cgi", "https://box.example-tailnet.ts.net/", "http://printer/status", "http://100.100.1.2:8000/"])
        assert.strictEqual(Links.fetchable(url), false, url);
    for (const url of ["https://accounts.example.com/reset/9f8a7b6c5d", "https://example.com/verify-email/abc", "https://example.com/a/0123456789abcdef0123456789abcdef01"])
        assert.strictEqual(Links.fetchable(url), false, url);
    assert.strictEqual(Links.fetchable("https://example.com/someone/project/issues/3"), true);
});

test("a long playlist or video id is not mistaken for a key", () => {
    const url = "https://www.youtube.com/playlist?list=PLabcdefghijklmnopqrstuvwxyz012345";
    assert.strictEqual(Links.secret(url), false);
    assert.strictEqual(Links.masked(url), url);
    assert.strictEqual(Links.fetchable(url), true);
});

test("a page title with a broken character reference reads without throwing", () => {
    assert.strictEqual(Links.readPage("<title>Bad &#x110000; and &#0; ok &#65;</title>", "https://example.com/").title, "Bad and ok A");
});

