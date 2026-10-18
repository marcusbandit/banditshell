import QtQuick
import Quickshell
import qs.services
import "../../../services/github.js" as Hub

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["github"]

    readonly property var asked: GitHub.enabled ? Hub.ask(root.search.text) : null

    onAskedChanged: if (root.asked)
        GitHub.wake()

    readonly property bool intent: !!root.asked

    readonly property var caps: ({
            github: 14
        })

    readonly property var groups: [
        {
            key: "github",
            title: "GitHub",
            items: root.rows
        }
    ]

    function row(key: string, label: string, detail: string, icon: string, url: string, extra: var): var {
        return Object.assign({
            key: `github:${key}`,
            kind: "github",
            label: label,
            detail: detail,
            icon: icon,
            url: url,
            score: 10
        }, extra ?? {});
    }

    function pullDetail(item: var): string {
        return [`${item.short} #${item.number}`, item.draft ? "draft" : "", Hub.ago(item.updated, Date.now())].filter(Boolean).join(" · ");
    }

    readonly property var rows: {
        const asked = root.asked;
        if (!asked)
            return [];
        if (GitHub.state === "missing")
            return [root.row("install", GitHub.installing === "trying" ? "Installing the GitHub CLI" : "Install the GitHub CLI", "", "download", "", {
                    setup: "install"
                })];
        if (GitHub.state === "signedout")
            return [root.row("signin", "Sign in to GitHub", "", "login", "", {
                    setup: "signin"
                })];
        const summary = GitHub.summary;
        if (!summary)
            return GitHub.loading ? [root.row("loading", "Loading GitHub", "", "sync", "", {
                    waiting: true
                })] : [];
        const out = [];
        let rank = 0;
        const push = item => {
            out.push(Object.assign(item, {
                score: 10 - rank * 0.01
            }));
            rank += 1;
        };
        if (asked.number) {
            const exact = (asked.kind === "issue" ? summary.issues : summary.pulls).filter(p => p.number === asked.number);
            exact.forEach(p => push(root.row(`${asked.kind}:${p.repo}#${p.number}`, p.title, root.pullDetail(p), asked.kind === "issue" ? "bug_report" : "merge", p.url)));
            summary.repos.slice(0, 3).filter(r => !exact.some(p => p.repo === r.name)).forEach(r => push(root.row(`${asked.kind}:${r.name}#${asked.number}`, `${asked.kind === "issue" ? "Issue" : "Pull request"} ${asked.number} in ${r.short}`, r.name, asked.kind === "issue" ? "bug_report" : "merge", Hub.numberUrl(r.name, asked.kind, asked.number))));
            return out;
        }
        const filter = asked.filter;
        if (!filter && summary.notifications >= 0)
            push(root.row("notifications", summary.notifications === 0 ? "No notifications" : summary.notifications >= 50 ? "50 or more notifications" : summary.notifications === 1 ? "1 notification" : `${summary.notifications} notifications`, "", "notifications", "https://github.com/notifications"));
        Hub.matches(summary.pulls, filter, ["title", "short"]).forEach(p => push(root.row(`pull:${p.url}`, p.title, root.pullDetail(p), "merge", p.url)));
        Hub.matches(summary.issues, filter, ["title", "short"]).forEach(p => push(root.row(`issue:${p.url}`, p.title, root.pullDetail(p), "bug_report", p.url)));
        Hub.matches(summary.repos, filter, ["short", "name", "description"]).slice(0, 10).forEach(r => push(root.row(`repo:${r.name}`, r.short, [r.private ? "private" : "public", Hub.ago(r.pushed, Date.now()), r.description].filter(Boolean).join(" · "), r.fork ? "fork_right" : "book", r.url, {
                repo: r
            })));
        return out;
    }

    function open(url: string): void {
        if (url)
            root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
    }

    function activate(row: var): void {
        if (row.waiting)
            return;
        if (row.setup === "install") {
            GitHub.installCli();
            return;
        }
        if (row.setup === "signin") {
            root.search.leave(() => GitHub.signIn());
            return;
        }
        root.open(row.url);
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        if (row.setup)
            return [
                {
                    icon: row.icon,
                    label: row.label,
                    run: () => root.activate(row)
                }
            ];
        const open = {
            icon: "open_in_new",
            label: "Open on GitHub",
            short: "Open",
            run: () => root.open(row.url)
        };
        if (row.repo) {
            const repo = row.repo;
            return [open,
                {
                    icon: "content_copy",
                    label: "Copy clone URL",
                    short: "Clone URL",
                    run: () => root.search.leave(() => System.copyText(`${repo.url}.git`))
                },
                {
                    icon: "merge",
                    label: "Pull requests",
                    short: "Pulls",
                    run: () => root.open(`${repo.url}/pulls`)
                }
            ];
        }
        return [open,
            {
                icon: "content_copy",
                label: "Copy link",
                run: () => {
                    const url = row.url;
                    root.search.leave(() => System.copyText(url));
                }
            }
        ];
    }
}
