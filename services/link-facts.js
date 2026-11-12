.pragma library

var SHAPE = /^([a-z][a-z0-9+.-]*):\/\/(?:([^@\/?#\s]*)@)?(\[[^\]]+\]|[^\/?#:\s]*)(?::(\d+))?([^?#\s]*)(?:\?([^#\s]*))?(?:#(\S*))?$/i;
var TRACKERS = /^(utm_\w+|si|src|fbclid|gclid|dclid|msclkid|igshid|igsh|ref_src|ref_url|feature|pp|mc_cid|mc_eid|_hsenc|_hsmi|spm|share_id|mibextid)$/i;
var SECRET_NAMES = /(^|[_-])(api[_-]?key|apikey|key|token|access[_-]?token|auth|password|passwd|pass|secret|sig|signature|session|sid|credential|code)$/i;
var RANDOM = /^[A-Za-z0-9_\-+\/=%.]{24,}$/;
var PLAIN_NAMES = /^(list|v|id|t|q|query|search|page|p|index|lang|hl|tab)$/i;
var ONE_TIME = /(^|[_-])(reset|verify|verification|confirm|activate|magic|token|login|signin|sign-in|auth|oauth|callback|unsubscribe|invite|accept|download)([_-]|$)/i;
var MEDIA = {
    video: /\.(mp4|webm|mov|mkv|m3u8|mpd)$/i,
    image: /\.(png|jpe?g|gif|webp|svg|avif|bmp)$/i,
    pdf: /\.pdf$/i,
    download: /\.(zip|tar|gz|xz|zst|7z|rar|deb|rpm|apk|appimage|exe|dmg|iso)$/i
};

function decode(text) {
    try {
        return decodeURIComponent(String(text).replace(/\+/g, " "));
    } catch (e) {
        return String(text);
    }
}

function parse(url) {
    var m = SHAPE.exec(String(url || "").trim());
    if (!m)
        return null;
    var params = [];
    var query = m[6] || "";
    if (query)
        query.split("&").forEach(function (pair) {
            if (!pair)
                return;
            var at = pair.indexOf("=");
            var name = decode(at < 0 ? pair : pair.slice(0, at));
            var value = at < 0 ? "" : decode(pair.slice(at + 1));
            params.push({
                name: name,
                value: value,
                tracking: TRACKERS.test(name),
                secret: SECRET_NAMES.test(name) || RANDOM.test(value) && /\d/.test(value) && !TRACKERS.test(name) && !PLAIN_NAMES.test(name)
            });
        });
    var path = m[5] || "";
    return {
        scheme: m[1].toLowerCase(),
        login: m[2] || "",
        host: (m[3] || "").toLowerCase(),
        port: m[4] || "",
        path: path,
        segments: path.split("/").filter(Boolean).map(decode),
        params: params,
        fragment: m[7] ? decode(m[7]) : ""
    };
}

function param(link, name) {
    for (var i = 0; i < link.params.length; i++)
        if (link.params[i].name === name)
            return link.params[i].value;
    return "";
}

function bareHost(host) {
    return String(host || "").replace(/^www\./, "").replace(/^m\./, "");
}

function placeOf(host) {
    var h = String(host || "").toLowerCase();
    if (h === "localhost" || /^127\./.test(h) || h === "[::1]" || h === "0.0.0.0")
        return "local";
    if (/\.ts\.net$/.test(h) || /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(h))
        return "tailnet";
    if (/^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(h) || /\.(local|lan|home|internal)$/.test(h) || h.indexOf(".") < 0)
        return "network";
    return "web";
}

function words(slug) {
    var s = decode(slug).replace(/\.[a-z0-9]{1,5}$/i, "").replace(/[-_]+/g, " ").trim();
    return s ? s.charAt(0).toUpperCase() + s.slice(1) : "";
}

function clock(seconds) {
    var n = parseInt(seconds, 10);
    if (!(n > 0))
        return "";
    var h = Math.floor(n / 3600), m = Math.floor(n % 3600 / 60), s = n % 60;
    var two = function (x) {
        return x < 10 ? "0" + x : String(x);
    };
    return h ? h + ":" + two(m) + ":" + two(s) : m + ":" + two(s);
}

function youtubeTime(value) {
    var v = String(value || "");
    if (/^\d+s?$/.test(v))
        return clock(parseInt(v, 10));
    var m = /^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/.exec(v);
    return m ? clock((+m[1] || 0) * 3600 + (+m[2] || 0) * 60 + (+m[3] || 0)) : "";
}

function github(s) {
    if (!s.length)
        return ["GitHub", "GitHub", "github"];
    if (s[0] === "login" && s[1] === "device")
        return ["GitHub device login", "Sign in a device", "github"];
    if (s.length === 1)
        return ["GitHub profile", s[0], "github"];
    var repo = s[0] + "/" + s[1];
    var kind = s[2] || "";
    if (!kind)
        return ["GitHub repository", repo, "github"];
    if ((kind === "issues" || kind === "pull" || kind === "discussions") && /^\d+$/.test(s[3] || ""))
        return [kind === "issues" ? "GitHub issue" : kind === "pull" ? "GitHub pull request" : "GitHub discussion", repo + " #" + s[3], "github"];
    if (kind === "issues" || kind === "pulls")
        return [kind === "issues" ? "GitHub issues" : "GitHub pull requests", repo, "github"];
    if (kind === "blob" || kind === "tree")
        return s.length > 4 ? [kind === "blob" ? "GitHub file" : "GitHub folder", repo + " › " + s.slice(4).join("/"), "github"] : ["GitHub repository", repo + " on " + (s[3] || "main"), "github"];
    if (kind === "commit" && s[3])
        return ["GitHub commit", repo + " " + s[3].slice(0, 7), "github"];
    if (kind === "actions" && s[3] === "runs" && s[4])
        return ["GitHub Actions run", repo + " run " + s[4], "github"];
    if (kind === "releases")
        return ["GitHub release", repo + (s[4] ? " " + s[4] : ""), "github"];
    return ["GitHub", repo + " › " + s.slice(2).join("/"), "github"];
}

function describe(url) {
    var link = parse(url);
    if (!link)
        return null;
    var host = bareHost(link.host);
    var s = link.segments;
    var last = s.length ? s[s.length - 1] : "";
    var place = placeOf(link.host);
    var out = function (kind, title, mark) {
        return {
            kind: kind,
            title: title,
            mark: mark || "",
            host: host + (link.port ? ":" + link.port : ""),
            place: place,
            link: link
        };
    };
    if (place === "local")
        return out("Local server", link.port ? "Port " + link.port + (s.length ? " › " + s.join("/") : "") : s.join("/") || host, "dns");
    if (place !== "web") {
        var device = link.host.split(".")[0];
        return out(place === "tailnet" ? "Device on your tailnet" : "Device on your network", device + (link.port ? ":" + link.port : "") + (s.length ? " › " + s.join("/") : ""), "lan");
    }
    if (host === "github.com") {
        var g = github(s);
        return out(g[0], g[1], g[2]);
    }
    if (host === "docs.github.com")
        return out("GitHub Docs", words(last) || "GitHub Docs", "menu_book");
    if (host === "youtube.com" || host === "music.youtube.com" || host === "youtu.be") {
        var at = youtubeTime(param(link, "t") || param(link, "start"));
        var later = at ? " at " + at : "";
        if (host === "youtu.be" && s[0])
            return out("YouTube video", s[0] + later, "smart_display");
        if (s[0] === "shorts" && s[1])
            return out("YouTube Short", s[1], "smart_display");
        if (s[0] === "watch" && param(link, "v"))
            return out("YouTube video", param(link, "v") + later, "smart_display");
        if (s[0] === "playlist")
            return out("YouTube playlist", param(link, "list"), "smart_display");
        if (s[0] && s[0].charAt(0) === "@")
            return out("YouTube channel", s[0], "smart_display");
        return out("YouTube", s.join("/") || "YouTube", "smart_display");
    }
    if (host === "reddit.com" || host === "old.reddit.com") {
        if (s[0] === "r" && s[1]) {
            if (s[2] === "comments")
                return out("Reddit post", "r/" + s[1] + (s[4] ? " · " + words(s[4]) : ""), "forum");
            if (s[2] === "s")
                return out("Reddit share link", "r/" + s[1], "forum");
            return out("Subreddit", "r/" + s[1], "forum");
        }
        if (s[0] === "u" || s[0] === "user")
            return out("Reddit user", "u/" + (s[1] || ""), "forum");
        return out("Reddit", s.join("/") || "Reddit", "forum");
    }
    if (/(^|\.)redd\.it$/.test(host) && MEDIA.video.test(link.path))
        return out("Reddit video", last, "movie");
    if (host === "docs.google.com") {
        var kinds = {
            document: "Google Doc",
            spreadsheets: "Google Sheet",
            presentation: "Google Slides",
            forms: "Google Form"
        };
        return out(kinds[s[0]] || "Google Docs", kinds[s[0]] ? "Shared " + kinds[s[0]].replace("Google ", "").toLowerCase() : s.join("/"), "description");
    }
    if (host === "drive.google.com")
        return out("Google Drive", "Shared file", "description");
    if (host === "share.google")
        return out("Google share link", s[0] || "Shared", "share");
    if (MEDIA.video.test(link.path))
        return out("Video file", last, "movie");
    if (MEDIA.image.test(link.path))
        return out("Image file", last, "image");
    if (MEDIA.pdf.test(link.path))
        return out("PDF", last, "picture_as_pdf");
    if (MEDIA.download.test(link.path))
        return out("Download", last, "download");
    return out("Web page", s.length ? s.map(words).filter(Boolean).slice(-2).join(" › ") : host, "language");
}

function clean(url) {
    var link = parse(url);
    if (!link || !link.params.some(function (p) {
        return p.tracking;
    }))
        return String(url || "").trim();
    var text = String(url).trim();
    var base = text.split("#")[0].split("?")[0];
    var kept = String(text.split("#")[0].split("?")[1] || "").split("&").filter(function (pair) {
        var name = decode(pair.split("=")[0]);
        return pair && !TRACKERS.test(name);
    });
    return base + (kept.length ? "?" + kept.join("&") : "") + (link.fragment ? "#" + text.split("#").slice(1).join("#") : "");
}

function fetchable(url) {
    var link = parse(url);
    return !!link && (link.scheme === "http" || link.scheme === "https") && !link.login && placeOf(link.host) === "web" && !link.params.some(function (p) {
        return p.secret;
    }) && !link.segments.some(function (segment) {
        return ONE_TIME.test(segment) || RANDOM.test(segment) && /\d/.test(segment) && segment.length >= 32;
    });
}

function secret(url) {
    var link = parse(url);
    return !!link && (!!link.login || link.params.some(function (p) {
        return p.secret;
    }));
}

function entity(text) {
    return String(text || "").replace(/&#x([0-9a-f]+);/gi, function (m, h) {
        var n = parseInt(h, 16);
        return n > 0 && n <= 0x10FFFF ? String.fromCodePoint(n) : "";
    }).replace(/&#(\d+);/g, function (m, d) {
        var n = parseInt(d, 10);
        return n > 0 && n <= 0x10FFFF ? String.fromCodePoint(n) : "";
    }).replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
}

function metaOf(html, key) {
    var tags = String(html || "").match(/<meta\b[^>]*>/gi) || [];
    for (var i = 0; i < tags.length; i++) {
        var tag = tags[i];
        var named = /\b(?:property|name)\s*=\s*["']([^"']+)["']/i.exec(tag);
        if (!named || named[1].toLowerCase() !== key)
            continue;
        var content = /\bcontent\s*=\s*"([^"]*)"|\bcontent\s*=\s*'([^']*)'/i.exec(tag);
        if (content)
            return entity(content[1] !== undefined ? content[1] : content[2]);
    }
    return "";
}

function resolve(base, ref) {
    var r = String(ref || "").trim();
    if (!r)
        return "";
    if (/^[a-z][a-z0-9+.-]*:/i.test(r))
        return r;
    var link = parse(base);
    if (!link)
        return "";
    var origin = link.scheme + "://" + link.host + (link.port ? ":" + link.port : "");
    if (r.indexOf("//") === 0)
        return link.scheme + ":" + r;
    if (r.charAt(0) === "/")
        return origin + r;
    return origin + link.path.replace(/[^\/]*$/, "") + r;
}

function readPage(html, url) {
    var text = String(html || "").slice(0, 600000);
    var title = metaOf(text, "og:title") || metaOf(text, "twitter:title");
    if (!title) {
        var t = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(text);
        title = t ? entity(t[1]) : "";
    }
    var icons = text.match(/<link\b[^>]*>/gi) || [];
    var icon = "";
    for (var i = 0; i < icons.length && !icon; i++) {
        var rel = /\brel\s*=\s*["']([^"']+)["']/i.exec(icons[i]);
        var href = /\bhref\s*=\s*["']([^"']+)["']/i.exec(icons[i]);
        if (rel && href && /(^|\s)(icon|shortcut icon|apple-touch-icon)(\s|$)/i.test(rel[1]))
            icon = href[1];
    }
    return {
        title: title.slice(0, 200),
        description: (metaOf(text, "og:description") || metaOf(text, "description")).slice(0, 400),
        image: resolve(url, metaOf(text, "og:image") || metaOf(text, "twitter:image")),
        icon: resolve(url, icon || "/favicon.ico")
    };
}

function masked(url) {
    var text = String(url || "").trim();
    var link = parse(text);
    if (!link || !secret(text))
        return text;
    var out = text.replace(/\/\/[^@\/?#\s]*@/, "//••••@");
    var parts = out.split("#");
    var head = parts[0].split("?");
    if (head.length < 2)
        return out;
    head[1] = head[1].split("&").map(function (pair) {
        var at = pair.indexOf("=");
        if (at < 0)
            return pair;
        var name = decode(pair.slice(0, at));
        var value = decode(pair.slice(at + 1));
        return SECRET_NAMES.test(name) || RANDOM.test(value) && !TRACKERS.test(name) ? pair.slice(0, at) + "=••••" : pair;
    }).join("&");
    parts[0] = head.join("?");
    return parts.join("#");
}

function factsOf(info) {
    if (!info)
        return [];
    var out = [
        {
            label: "Kind",
            value: info.kind
        },
        {
            label: "Site",
            value: info.host
        }
    ];
    if (info.link.segments.length)
        out.push({
            label: "Path",
            value: "/" + info.link.segments.join("/")
        });
    var tube = info.kind.indexOf("YouTube") === 0;
    info.link.params.forEach(function (p) {
        if (p.tracking)
            return;
        if (tube && (p.name === "t" || p.name === "start") && youtubeTime(p.value))
            out.push({
                label: "Starts at",
                value: youtubeTime(p.value)
            });
        else if (!(tube && p.name === "v"))
            out.push({
                label: p.name || "?",
                value: p.secret ? "hidden" : p.value || "empty"
            });
    });
    var dropped = info.link.params.filter(function (p) {
        return p.tracking;
    }).map(function (p) {
        return p.name;
    });
    if (dropped.length)
        out.push({
            label: "Tracking",
            value: dropped.join(", ")
        });
    if (info.link.fragment)
        out.push({
            label: "Anchor",
            value: info.link.fragment
        });
    return out.slice(0, 6);
}

function keyOf(url) {
    var h = 5381;
    var s = String(url || "");
    for (var i = 0; i < s.length; i++)
        h = (h * 33 + s.charCodeAt(i)) >>> 0;
    return h.toString(16);
}

function oembedOf(url) {
    var info = describe(url);
    if (!info || info.kind.indexOf("YouTube") !== 0)
        return "";
    return "https://www.youtube.com/oembed?format=json&url=" + encodeURIComponent(String(url).trim());
}

function readEmbed(json) {
    try {
        var data = JSON.parse(String(json || ""));
        return {
            title: String(data.title || "").slice(0, 200),
            description: data.author_name ? "by " + data.author_name : "",
            image: String(data.thumbnail_url || ""),
            icon: "https://www.youtube.com/favicon.ico"
        };
    } catch (e) {
        return null;
    }
}

function bestTitle(info, page) {
    var title = String(page && page.title || "").trim();
    if (!info)
        return title;
    if (!title)
        return info.title;
    var plain = title.toLowerCase().replace(/[^a-z0-9]+/g, "");
    var site = info.host.split(":")[0].split(".");
    var generic = site.some(function (part) {
        return part.length > 2 && part.toLowerCase() === plain;
    }) || ["home", "homepage", "index", "untitled", "loading", "redirecting", "justamoment", "beforeyoucontinuetoyoutube", "pleasewait"].indexOf(plain) >= 0;
    return generic ? info.title : title;
}
