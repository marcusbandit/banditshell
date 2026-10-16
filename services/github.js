.pragma library

var ASK = /^(?:gh|github)(?:\s+(.*))?$/i;
var PULL = /^(?:pr|pull request|pull)\s+#?(\d{1,7})$/i;
var ISSUE = /^issue\s+#?(\d{1,7})$/i;
var WORDY = /[a-z0-9]/;

function ask(input) {
    var text = String(input || "").trim();
    var pull = PULL.exec(text);
    if (pull)
        return {
            filter: "",
            number: parseInt(pull[1], 10),
            kind: "pull"
        };
    var issue = ISSUE.exec(text);
    if (issue)
        return {
            filter: "",
            number: parseInt(issue[1], 10),
            kind: "issue"
        };
    var hit = ASK.exec(text);
    return hit ? {
        filter: (hit[1] || "").trim().toLowerCase(),
        number: 0,
        kind: ""
    } : null;
}

function list(value) {
    return Array.isArray(value) ? value : [];
}

function readSummary(raw) {
    var data;
    try {
        data = JSON.parse(String(raw || ""));
    } catch (e) {
        return null;
    }
    if (!data || !Array.isArray(data.repos))
        return null;
    return {
        repos: list(data.repos).map(function (r) {
            return {
                name: r.nameWithOwner || "",
                short: String(r.nameWithOwner || "").split("/").pop(),
                description: r.description || "",
                url: r.url || "",
                private: !!r.isPrivate,
                fork: !!r.isFork,
                pushed: Date.parse(r.pushedAt || "") || 0
            };
        }).sort(function (a, b) {
            return b.pushed - a.pushed;
        }),
        pulls: list(data.pulls).map(function (p) {
            return issueOf(p, true);
        }),
        issues: list(data.issues).map(function (p) {
            return issueOf(p, false);
        }),
        notifications: typeof data.notifications === "number" ? data.notifications : -1
    };
}

function issueOf(p, pull) {
    var repo = p.repository && (p.repository.nameWithOwner || p.repository.name) || "";
    return {
        number: p.number || 0,
        title: p.title || "",
        repo: repo,
        short: repo.split("/").pop(),
        url: p.url || "",
        draft: !!p.isDraft,
        pull: pull,
        updated: Date.parse(p.updatedAt || "") || 0
    };
}

function placeIn(hay, want) {
    if (!want)
        return 1;
    var text = String(hay || "").toLowerCase();
    var at = text.indexOf(want);
    if (at < 0)
        return -1;
    if (at === 0)
        return 3;
    while (at > 0) {
        if (!WORDY.test(text.charAt(at - 1)))
            return 2;
        at = text.indexOf(want, at + 1);
    }
    return 1;
}

function matches(items, filter, fields) {
    if (!filter)
        return items.slice();
    return items.map(function (item, index) {
        var best = -1;
        fields.forEach(function (f, i) {
            var place = placeIn(item[f], filter);
            if (place > 0)
                best = Math.max(best, place - i * 0.5);
        });
        return {
            item: item,
            score: best,
            index: index
        };
    }).filter(function (x) {
        return x.score > 0;
    }).sort(function (a, b) {
        return b.score - a.score || a.index - b.index;
    }).map(function (x) {
        return x.item;
    });
}

function ago(then, now) {
    var minutes = Math.max(0, Math.round((now - then) / 60000));
    if (minutes < 1)
        return "just now";
    if (minutes < 60)
        return minutes + " min ago";
    var hours = Math.round(minutes / 60);
    if (hours < 24)
        return hours + " h ago";
    var days = Math.round(hours / 24);
    if (days < 60)
        return days === 1 ? "yesterday" : days + " days ago";
    return Math.round(days / 30) + " months ago";
}

function numberUrl(repo, kind, number) {
    return "https://github.com/" + repo + (kind === "issue" ? "/issues/" : "/pull/") + number;
}
