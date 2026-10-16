.pragma library

var URL_PARTS = /^(https?):\/\/(?:[^@\/\s]*@)?([^\/:?#\s]+)(?::\d+)?([^?#\s]*)(\?[^#\s]*)?/i;

var SITES = [
    [/(^|\.)youtube\.com$/, /^\/(?:watch|shorts\/|live\/|embed\/|v\/)/],
    [/^youtu\.be$/, /^\/[\w-]{6,}/],
    [/(^|\.)vimeo\.com$/, /^\/(?:\d+|channels\/[^\/]+\/\d+|[^\/]+\/review\/\d+)/],
    [/(^|\.)twitch\.tv$/, /^\/(?:videos\/\d+|[^\/]+\/clip\/)/],
    [/^clips\.twitch\.tv$/, /^\/./],
    [/(^|\.)dailymotion\.com$/, /^\/video\//],
    [/^dai\.ly$/, /^\/./],
    [/(^|\.)tiktok\.com$/, /^\/@[^\/]+\/video\/\d+/],
    [/(^|\.)instagram\.com$/, /^\/(?:reels?|p|tv)\/[\w-]+/],
    [/^(?:www\.|mobile\.)?(?:twitter|x)\.com$/, /^\/[^\/]+\/status\/\d+/],
    [/(^|\.)reddit\.com$/, /^\/r\/[^\/]+\/comments\//],
    [/^v\.redd\.it$/, /^\/./],
    [/(^|\.)soundcloud\.com$/, /^\/[^\/]+\/[^\/]+/],
    [/\.bandcamp\.com$/, /^\/(?:track|album)\//],
    [/(^|\.)facebook\.com$/, /^\/(?:watch|reel\/|[^\/]+\/videos\/)/],
    [/^fb\.watch$/, /^\/./],
    [/(^|\.)bilibili\.com$/, /^\/video\//],
    [/^streamable\.com$/, /^\/\w+/],
    [/^rumble\.com$/, /^\/v[\w-]+/],
    [/(^|\.)nicovideo\.jp$/, /^\/watch\//],
    [/^odysee\.com$/, /^\/@/],
    [/(^|\.)ted\.com$/, /^\/talks\//],
    [/^bsky\.app$/, /^\/profile\/[^\/]+\/post\//],
    [/(^|\.)mixcloud\.com$/, /^\/[^\/]+\/[^\/]+/],
    [/^archive\.org$/, /^\/details\//],
    [/^kick\.com$/, /^\/[^\/]+\/(?:videos|clips)\//]
];

var AUDIO_SITES = /(^|\.)(?:soundcloud\.com|bandcamp\.com|mixcloud\.com)$/;
var SPACE = /\s/;
var PREFIX = /^(?:www|m|mobile)\./;
var SIGN_IN = /sign in|not a bot|cookies|login required|age.restricted|private video|members.only/i;
var ERROR_HEAD = /^(?:ERROR:\s*)?(?:\[[^\]]+\]\s*)?(?:[\w-]+:\s+)?/;
var SENTENCE_END = /[.!?](?:\s|$)/;
var PROGRESS = /^@@progress (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)/;

function videoUrl(input) {
    var text = String(input || "").trim();
    if (!text || SPACE.test(text))
        return null;
    var hit = URL_PARTS.exec(text);
    if (!hit)
        return null;
    var host = hit[2].toLowerCase();
    var path = hit[3] || "/";
    for (var i = 0; i < SITES.length; i++) {
        if (SITES[i][0].test(host) && SITES[i][1].test(path))
            return {
                url: text,
                host: host.replace(PREFIX, ""),
                audioOnly: AUDIO_SITES.test(host)
            };
    }
    return null;
}

function number(text) {
    var n = parseFloat(text);
    return isFinite(n) ? n : -1;
}

function readProgress(line) {
    var hit = PROGRESS.exec(String(line || ""));
    if (!hit)
        return null;
    var total = number(hit[3]);
    return {
        status: hit[1],
        done: number(hit[2]),
        total: total > 0 ? total : number(hit[4]),
        speed: number(hit[5]),
        eta: number(hit[6])
    };
}

function bytes(n) {
    if (n < 0)
        return "";
    var units = ["B", "KB", "MB", "GB", "TB"];
    var at = 0;
    while (n >= 1000 && at < units.length - 1) {
        n /= 1000;
        at++;
    }
    return (at && n < 10 ? n.toFixed(1) : String(Math.round(n))) + " " + units[at];
}

function span(seconds) {
    if (seconds < 0)
        return "";
    var s = Math.round(seconds);
    var h = Math.floor(s / 3600);
    var m = Math.floor(s % 3600 / 60);
    var rest = s % 60;
    var two = function (n) {
        return (n < 10 ? "0" : "") + n;
    };
    return h ? h + ":" + two(m) + ":" + two(rest) : m + ":" + two(rest);
}

function progressText(progress) {
    if (!progress)
        return "";
    var out = [];
    if (progress.total > 0 && progress.done >= 0)
        out.push(Math.min(100, Math.floor(progress.done / progress.total * 100)) + "%");
    else if (progress.done >= 0)
        out.push(bytes(progress.done));
    if (progress.speed > 0)
        out.push(bytes(progress.speed) + "/s");
    if (progress.eta >= 0 && progress.status !== "finished")
        out.push(span(progress.eta) + " left");
    return out.join(" · ");
}

function progressTemplate() {
    return "download:@@progress %(progress.status)s %(progress.downloaded_bytes)s %(progress.total_bytes)s %(progress.total_bytes_estimate)s %(progress.speed)s %(progress.eta)s";
}

function shortError(line) {
    var text = String(line || "").trim().replace(ERROR_HEAD, "");
    var end = SENTENCE_END.exec(text);
    return end ? text.slice(0, end.index) : text;
}

function needsSignIn(complaint) {
    return SIGN_IN.test(String(complaint || ""));
}

function command(url, audio, folder, ffmpeg, cookies) {
    var out = ["yt-dlp", "--newline", "--no-playlist", "--no-colors", "--progress", "--progress-template", progressTemplate(), "--print", "before_dl:@@title %(title)s", "--print", "after_move:@@file %(filepath)s", "-P", folder, "-o", "%(title).180B [%(id)s].%(ext)s"];
    if (audio)
        out = out.concat(ffmpeg ? ["-x"] : ["-f", "bestaudio"]);
    if (cookies)
        out = out.concat(["--cookies-from-browser", cookies]);
    return out.concat(["--", url]);
}
