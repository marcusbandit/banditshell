const CHANNELS = ["stable", "main"];

function channelOf(raw) {
    const name = String(raw ?? "").trim();
    return CHANNELS.indexOf(name) >= 0 ? name : "stable";
}

function branchFor(channel, branch) {
    const named = String(branch ?? "").trim();
    if (named !== "" && named !== "main")
        return named;
    return channelOf(channel) === "stable" ? "stable" : "main";
}

function following(head, branch) {
    return head === branch || (branch === "stable" && head === "main");
}

function haveText(version, channel, branch) {
    const followed = branchFor(channel, branch);
    const where = followed === "stable" || followed === "main" ? `on the ${followed} channel` : `following ${followed}`;
    return version ? `You have ${version}, ${where}` : `${where[0].toUpperCase()}${where.slice(1)}`;
}

function channelText(channel, branch) {
    const followed = branchFor(channel, branch);
    if (followed !== "stable" && followed !== "main")
        return `following ${followed}`;
    return `${followed} channel`;
}

function waitingHeadline(targetVersion) {
    return targetVersion ? `${targetVersion} is ready` : "A new version is ready";
}

function ownChanges(count) {
    const n = Math.max(1, Number(count) || 0);
    return n === 1 ? "1 change of your own" : `${n} changes of your own`;
}

function divergedHeadline(targetVersion, ahead) {
    return `${waitingHeadline(targetVersion)}, but this copy has ${ownChanges(ahead)}`;
}

function aheadText(ahead) {
    return `${ownChanges(ahead)} ${Number(ahead) === 1 ? "is" : "are"} not on GitHub yet`;
}

function report(text) {
    const got = { failed: false, output: [], values: {} };
    for (const line of String(text ?? "").split("\n")) {
        if (line.startsWith("|"))
            got.output.push(line.slice(1));
        else if (line === "failed")
            got.failed = true;
        else {
            const eq = line.indexOf("=");
            if (eq > 0)
                got.values[line.slice(0, eq)] = line.slice(eq + 1).trim();
        }
    }
    return got;
}

function listedAfter(lines, at) {
    const files = [];
    for (let i = at + 1; i < lines.length && lines[i].startsWith("\t"); i++)
        files.push(lines[i].trim());
    return files;
}

function named(files) {
    if (files.length === 0)
        return "some files";
    const shown = files.slice(0, 3).join(", ");
    return files.length > 3 ? `${shown} and ${files.length - 3} more` : shown;
}

function explain(output, branch) {
    const lines = (Array.isArray(output) ? output : String(output ?? "").split("\n")).map(l => String(l).replace(/\r$/, ""));
    const text = lines.join("\n");
    const at = pattern => lines.findIndex(l => pattern.test(l));

    const edited = at(/Your local changes to the following files would be overwritten/);
    if (edited >= 0)
        return `Files edited on this computer are also changed by the update: ${named(listedAfter(lines, edited))}. Commit or move those edits away, then try again.`;

    const untracked = at(/untracked working tree files would be (overwritten|removed)/);
    if (untracked >= 0)
        return `The update brings files that already exist here: ${named(listedAfter(lines, untracked))}. Move them out of the way, then try again.`;

    if (/Not possible to fast-forward|Diverging branches/.test(text))
        return "This copy has commits of its own that GitHub does not have, so it cannot just move forward.";
    if (/index\.lock'?: File exists/.test(text))
        return "Another git command is busy in this folder. Try again when it has finished.";
    if (/^fatal: not a git repository/m.test(text))
        return "This copy has no git history, so it cannot update itself.";
    if (/^timed out$/m.test(text))
        return "GitHub took too long to answer. Try again later.";
    if (/Could not resolve host|Failed to connect|Connection timed out|Connection refused|Network is unreachable|Could not connect/.test(text))
        return "Could not reach GitHub. Check the internet connection, then refresh.";
    if (/couldn't find remote ref/.test(text) && branch === "stable")
        return "There is no release on GitHub yet, so nothing is waiting. This copy stays as it is until the first one.";
    if (/couldn't find remote ref/.test(text))
        return `GitHub has no branch called "${branch}".`;
    if (/Repository not found|does not appear to be a git repository|Could not read from remote repository|Permission denied|Authentication failed|terminal prompts disabled|Host key verification failed/.test(text))
        return "GitHub turned the request down: the address is wrong, or this computer has no access.";

    const said = lines.filter(l => /^(fatal|error): /.test(l)).pop() ?? lines.filter(l => l.trim()).pop();
    return said ? said.replace(/^(fatal|error): /, "").trim() : "git failed without saying why.";
}

function setAside(list) {
    const files = String(list ?? "").split("\t").filter(Boolean);
    if (files.length === 0)
        return "";
    return `Your edits to ${named(files)} were in the way, so they were set aside in git stash before updating. git stash list shows them; git stash pop brings them back.`;
}

function ago(when, now) {
    const mins = Math.max(0, Math.round((now - when) / 60000));
    if (mins < 1)
        return "just now";
    if (mins < 60)
        return `${mins} min ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24)
        return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
}

function nameStatus(text) {
    const files = [];
    for (const line of String(text ?? "").split("\n")) {
        const parts = line.replace(/\r$/, "").split("\t");
        if (parts.length < 2 || !parts[0].trim())
            continue;
        const code = parts[0].trim()[0];
        if (code === "R" && parts.length >= 3) {
            files.push({ status: "D", path: parts[1] });
            files.push({ status: "A", path: parts[2] });
        } else if (code === "C" && parts.length >= 3) {
            files.push({ status: "A", path: parts[2] });
        } else {
            files.push({ status: code, path: parts[1] });
        }
    }
    return files;
}

function actionRows(text) {
    const rows = {};
    for (const line of String(text ?? "").split("\n")) {
        if (!line.trim() || line.startsWith("#"))
            continue;
        const cols = line.split("\t");
        if (cols.length >= 2)
            rows[cols[0].trim()] = cols[1].trim();
    }
    return rows;
}

function removedActions(beforeText, afterText) {
    const before = actionRows(beforeText);
    const after = actionRows(afterText);
    return Object.keys(before).filter(id => after[id] === "removed" ? before[id] !== "removed" : !(id in after) && before[id] !== "removed");
}

function stepNames(text) {
    const names = [];
    const pattern = /^ {4}add_step[ \t]+([A-Za-z0-9_.@+-]+)/gm;
    const source = String(text ?? "");
    let hit = pattern.exec(source);
    while (hit !== null) {
        names.push(hit[1]);
        hit = pattern.exec(source);
    }
    return names;
}

function addedSteps(beforeText, afterText) {
    const before = stepNames(beforeText);
    return stepNames(afterText).filter(name => before.indexOf(name) < 0);
}

function stepProbes(text) {
    const probes = {};
    const pattern = /^ {4}add_step[ \t]+([A-Za-z0-9_.@+-]+)[ \t]+"([^"\\$`]*)"/gm;
    const source = String(text ?? "");
    let hit = pattern.exec(source);
    while (hit !== null) {
        probes[hit[1]] = hit[2];
        hit = pattern.exec(source);
    }
    return probes;
}

function plainProbe(probe) {
    const parts = String(probe ?? "").trim().split(/\s+(&&|\|\|)\s+/);
    const names = [];
    const ops = [];
    for (let i = 0; i < parts.length; i++) {
        if (i % 2 === 1) {
            ops.push(parts[i]);
            continue;
        }
        const hit = /^command -v ([A-Za-z0-9_.+-]+)$/.exec(parts[i]);
        if (!hit)
            return null;
        names.push(hit[1]);
    }
    if (ops.some(op => op !== ops[0]))
        return null;
    return { any: ops[0] === "||", names: names };
}

function presentSteps(beforeText, afterText, has) {
    const probes = stepProbes(afterText);
    return addedSteps(beforeText, afterText).filter(name => {
        const plain = plainProbe(probes[name]);
        return plain !== null && (plain.any ? plain.names.some(has) : plain.names.every(has));
    });
}

function strings(list) {
    return Array.isArray(list) ? list.filter(s => typeof s === "string" && s.trim()).map(s => s.trim()) : [];
}

function impactOf(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    return {
        restart: raw.restart === true,
        cli: raw.cli === true,
        binds: strings(raw.binds),
        deps: strings(raw.deps)
    };
}

function logEntries(text) {
    let doc;
    try {
        doc = JSON.parse(String(text ?? ""));
    } catch (e) {
        return [];
    }
    const list = Array.isArray(doc) ? doc : Array.isArray(doc?.entries) ? doc.entries : [];
    const out = [];
    for (const raw of list) {
        if (!raw || typeof raw !== "object" || typeof raw.id !== "string" || !raw.id.trim())
            continue;
        const changes = [];
        for (const c of Array.isArray(raw.changes) ? raw.changes : []) {
            if (c && typeof c.text === "string" && c.text.trim())
                changes.push({
                    type: typeof c.type === "string" ? c.type : "",
                    severity: c.severity === "major" ? "major" : "minor",
                    text: c.text.trim()
                });
        }
        out.push({
            id: raw.id.trim(),
            date: typeof raw.date === "string" ? raw.date.trim() : "",
            example: raw.example === true,
            changes: changes,
            impact: impactOf(raw.impact)
        });
    }
    return out;
}

function incomingEntries(beforeText, afterText) {
    const known = {};
    for (const e of logEntries(beforeText))
        known[e.id] = true;
    return logEntries(afterText).filter(e => !e.example && e.changes.length > 0 && !known[e.id]);
}

function unique(list) {
    const out = [];
    for (const item of list)
        if (out.indexOf(item) < 0)
            out.push(item);
    return out;
}

function classify(input) {
    const given = input ?? {};
    const files = nameStatus(given.nameStatus);
    const paths = files.map(f => f.path);
    const noted = (Array.isArray(given.entries) ? given.entries : []).map(e => e.impact).filter(i => i);
    const lines = value => Array.isArray(value) ? value : String(value ?? "").split("\n").filter(l => l);

    const reasons = [];
    if (paths.some(p => p === "qmldir" || p.endsWith("/qmldir")))
        reasons.push("qmldir changed");
    if (files.some(f => /\.qml$/.test(f.path) && (f.status === "A" || f.status === "D")))
        reasons.push("a QML file was added or removed");
    if (paths.indexOf("shell.qml") >= 0)
        reasons.push("shell.qml changed");
    if (noted.some(i => i.restart) && reasons.length === 0)
        reasons.push("the notes for this version say so");

    const runs = files.some(f => /\.(qml|js|qsb|frag|vert)$/.test(f.path) && !/^(tests|docs)\//.test(f.path));
    const restart = reasons.length > 0;
    const apiRemoved = removedActions(given.actionsBefore, given.actionsAfter);
    const untracked = lines(given.untracked);
    const present = Array.isArray(given.present) ? given.present : [];

    return {
        files: files.length,
        commits: Number(given.commits) || 0,
        notes: (Array.isArray(given.entries) ? given.entries : []).reduce((n, e) => n + (Array.isArray(e?.changes) ? e.changes.length : 0), 0),
        kind: restart ? "restart" : runs ? "reload" : "none",
        restart: restart,
        restartReasons: reasons,
        cli: paths.some(p => /^(cli|api|lua)\//.test(p)) || noted.some(i => i.cli),
        api: paths.indexOf("api/actions.tsv") >= 0,
        apiRemoved: apiRemoved,
        helpers: paths.some(p => /^src\/.*\.(c|h)$/.test(p)),
        shaders: paths.some(p => /\.(frag|vert)$/.test(p)),
        deps: unique(addedSteps(given.installBefore, given.installAfter).filter(name => present.indexOf(name) < 0).concat(...noted.map(i => i.deps))),
        binds: unique([].concat(...noted.map(i => i.binds))),
        config: paths.indexOf("config/Config.qml") >= 0,
        dirty: lines(given.dirty).filter(p => paths.indexOf(p) >= 0),
        blocked: files.filter(f => f.status === "A" && untracked.indexOf(f.path) >= 0).map(f => f.path)
    };
}

function plural(n, one, many) {
    return `${n} ${n === 1 ? one : many}`;
}

function listed(items) {
    if (items.length <= 1)
        return items.join("");
    return `${items.slice(0, -1).join(", ")} and ${items[items.length - 1]}`;
}

function summary(c) {
    const count = c.notes > 0 ? c.notes : c.commits > 0 ? c.commits : c.files;
    if (count === 0)
        return "no changes";
    return [plural(count, "change", "changes"), c.kind === "restart" ? "restart needed" : "no restart needed", ...extras(c)].join(", ");
}

function details(c) {
    const parts = extras(c);
    const count = c.commits > 0 ? c.commits : c.files;
    if (c.notes === 0 && count > 0)
        parts.unshift(plural(count, "change", "changes"));
    const text = parts.join(", ");
    return text ? `${text[0].toUpperCase()}${text.slice(1)}` : "";
}

function extras(c) {
    const parts = [];
    if (c.cli)
        parts.push("commands changed");
    if (c.apiRemoved.length > 0)
        parts.push(`${plural(c.apiRemoved.length, "command", "commands")} removed`);
    if (c.binds.length > 0)
        parts.push(`${plural(c.binds.length, "bind", "binds")} affected`);
    if (c.helpers)
        parts.push("helpers rebuild");
    if (c.shaders)
        parts.push("shaders changed");
    if (c.deps.length > 0)
        parts.push(`needs ${listed(c.deps)}`);
    if (c.config)
        parts.push("settings defaults changed");
    if (c.dirty.length > 0)
        parts.push(`${plural(c.dirty.length, "of your edits is", "of your edits are")} in the way`);
    if (c.blocked.length > 0)
        parts.push(`${plural(c.blocked.length, "file is", "files are")} in the way`);
    return parts;
}

function button(c) {
    return c.restart ? "Update and restart" : "Update";
}

function parseCheck(text) {
    try {
        const doc = JSON.parse(String(text ?? ""));
        return doc && typeof doc === "object" ? doc : null;
    } catch (e) {
        return null;
    }
}

function phaseOf(line) {
    const doc = parseCheck(line);
    return doc && typeof doc.phase === "string" ? doc : null;
}

function byHand(result) {
    return !!result && result.ok === false && result.hand === true;
}

function outcomeText(result, running) {
    if (!result)
        return "";
    const from = result.fromLabel || String(result.from ?? "").slice(0, 7);
    const to = result.toLabel || String(result.to ?? "").slice(0, 7);
    if (result.ok)
        return `Updated to ${to}.`;
    if (byHand(result)) {
        const skipped = `Updates skip ${to} until a newer version arrives.`;
        if (!running || running === from)
            return skipped;
        return `Went back to ${from}, but the shell still runs ${running}. Run banditshell restart to start ${from}. ${skipped}`;
    }
    const why = result.why ? ` ${result.why}.` : "";
    return `Update ${to} did not start, so you are back on ${from}.${why} It will be tried again when a newer version arrives.`;
}

function reportContext(result, running) {
    const clipped = sha => String(sha ?? "").slice(0, 7);
    const named = (label, sha) => !label || label === clipped(sha) ? clipped(sha) : `${label} (${clipped(sha)})`;
    const back = result?.fromLabel || clipped(result?.from);
    const current = !running || running === back ? named(back, result?.from) : running;
    return ["Went back in the update menu.", `Skipped: ${named(result?.toLabel, result?.to)}`, `Current: ${current}`].join("\n");
}

function reportWords(words) {
    return String(words ?? "").split("\n").map(line => line.replace(/\s+/g, " ").trim()).join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

function reportScript(quote, cli, words, context) {
    const said = reportWords(words);
    const together = `${said || "(no words were given)"}\n\n${context}`;
    return `if grep -qF -e '[--context <text>]' ${quote(cli)}; then bash ${quote(cli)} triage --context ${quote(context)} -- ${quote(said)}; else bash ${quote(cli)} triage ${quote(together)}; fi; printf '\\n%s' 'Press Enter to close. '; read -r reply`;
}

function lineValues(lines) {
    const values = {};
    for (const line of String(lines ?? "").split("\n")) {
        const eq = line.indexOf("=");
        if (eq > 0)
            values[line.slice(0, eq)] = line.slice(eq + 1);
    }
    return values;
}

function assess(facts, has) {
    const meta = lineValues(facts.meta);
    const entries = incomingEntries(facts.whatsnewBefore, facts.whatsnewAfter);
    const c = classify({
        nameStatus: facts.nameStatus,
        dirty: facts.dirty,
        untracked: facts.untracked,
        actionsBefore: facts.actionsBefore,
        actionsAfter: facts.actionsAfter,
        installBefore: facts.installBefore,
        installAfter: facts.installAfter,
        present: typeof has === "function" ? presentSteps(facts.installBefore, facts.installAfter, has) : [],
        entries: entries,
        commits: Number(meta.behind) || 0
    });
    return Object.assign({}, meta, {
        behind: Number(meta.behind) || 0,
        ahead: Number(meta.ahead) || 0,
        skipped: meta.skipped === "1",
        checkedAt: Number(meta.checkedAt) || 0,
        class: c,
        summary: summary(c),
        details: details(c),
        button: button(c),
        entries: entries
    });
}

function waitingText(report) {
    const out = [`${report.targetVersion ? `${report.targetVersion} is` : "update"} waiting: ${report.summary}`];
    for (const entry of report.entries) {
        out.push(`  ${entry.id}`);
        for (const change of entry.changes.slice(0, 6))
            out.push(`    - ${change.text}`);
        if (entry.changes.length > 6)
            out.push(`    and ${entry.changes.length - 6} more`);
    }
    if (report.class.dirty.length > 0)
        out.push(`  your edits to ${named(report.class.dirty)} will be set aside in git stash`);
    out.push("run: banditshell update apply");
    return out.join("\n");
}

function readFacts(dir) {
    const fs = require("node:fs");
    const read = name => {
        try {
            return fs.readFileSync(`${dir}/${name}`, "utf8");
        } catch (e) {
            return "";
        }
    };
    return {
        meta: read("meta"),
        nameStatus: read("name-status"),
        dirty: read("dirty"),
        untracked: read("untracked"),
        actionsBefore: read("actions.before"),
        actionsAfter: read("actions.after"),
        installBefore: read("install.before"),
        installAfter: read("install.after"),
        whatsnewBefore: read("whatsnew.before"),
        whatsnewAfter: read("whatsnew.after")
    };
}

function linesOf(report) {
    const c = report.class;
    return [
        `kind=${c.kind}`,
        `restart=${c.restart ? 1 : 0}`,
        `cli=${c.cli ? 1 : 0}`,
        `helpers=${c.helpers ? 1 : 0}`,
        `files=${c.files}`,
        `deps=${c.deps.join(" ")}`,
        `dirty=${c.dirty.join("\t")}`,
        `blocked=${c.blocked.join("\t")}`,
        `button=${report.button}`,
        `summary=${report.summary}`
    ].join("\n");
}

function onPath(path) {
    const fs = require("node:fs");
    const dirs = String(path ?? "").split(":").filter(dir => dir.startsWith("/"));
    return name => dirs.some(dir => {
        try {
            fs.accessSync(`${dir}/${name}`, fs.constants.X_OK);
            return fs.statSync(`${dir}/${name}`).isFile();
        } catch (e) {
            return false;
        }
    });
}

function main(argv) {
    const mode = argv[0];
    if (mode === "report") {
        const report = assess(readFacts(argv[1]), onPath(process.env.PATH));
        const form = argv[2] ?? "--json";
        if (form === "--lines")
            process.stdout.write(linesOf(report) + "\n");
        else if (form === "--text")
            process.stdout.write(waitingText(report) + "\n");
        else
            process.stdout.write(JSON.stringify(report) + "\n");
        return 0;
    }
    if (mode === "notes") {
        const fs = require("node:fs");
        const read = file => {
            try {
                return fs.readFileSync(file, "utf8");
            } catch (e) {
                return "";
            }
        };
        const before = read(argv[1]);
        process.stdout.write(JSON.stringify(logEntries(before).length > 0 ? incomingEntries(before, read(argv[2])) : []) + "\n");
        return 0;
    }
    if (mode === "explain") {
        const input = require("node:fs").readFileSync(0, "utf8");
        process.stdout.write(explain(input.split("\n"), argv[1] ?? "main") + "\n");
        return 0;
    }
    process.stderr.write("usage: node update.js report <facts-dir> [--json|--lines|--text] | notes <before> <after> | explain <branch>\n");
    return 2;
}

if (typeof require !== "undefined" && typeof module !== "undefined" && require.main === module)
    process.exit(main(process.argv.slice(2)));
