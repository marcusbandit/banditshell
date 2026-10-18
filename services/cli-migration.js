const GENERATION = 1;

const SINK = "@DEFAULT_AUDIO_SINK@";

function percent(value) {
    return value.includes(".") ? String(Math.round(parseFloat(value) * 100)) : value;
}

function volumeTo(_, sign, amount) {
    if (!sign)
        return `wpctl set-volume -l 1 ${SINK} ${percent(amount)}%`;
    return `wpctl set-volume -l 1 ${SINK} ${amount ? percent(amount) : "5"}%${sign}`;
}

const PANEL = "(\\S+)";

const RULES = [
    { re: /^(toggle|open) panel penmap$/, to: "tablet pen edit", note: "the pen's mapper lives with the tablet" },
    { re: /^close panel penmap$/, to: "tablet pen cancel", note: "the pen's mapper lives with the tablet" },
    { re: /^status panel penmap$/, to: "tablet pen", note: "the pen's mapper lives with the tablet" },
    { re: new RegExp(`^(toggle|open|close|status) panel ${PANEL}( .*)?$`), to: "panel $2 $1$3", note: "the panel first, then what to do with it" },
    { re: /^(close|panic)$/, to: "panel close", note: "every panel away" },

    { re: /^toggle (border|sidebar)( .*)?$/, to: "screen $1 toggle$2", note: "the shell's frame is part of the screen" },
    { re: /^set (border|sidebar|stream) (.+)$/, to: "screen $1 $2", note: "the shell's frame is part of the screen" },
    { re: /^status (border|sidebar|stream)$/, to: "screen $1", note: "a bare thing says how it is" },
    { re: /^status screen$/, to: "screen", note: "a bare thing says how it is" },
    { re: /^set (brightness|temperature) (.+)$/, to: "screen $1 $2", note: "levels of the screen" },

    { re: /^toggle wallpaper$/, to: "wallpaper toggle", note: "everything about the picture starts with wallpaper" },
    { re: /^set wallpaper (on|off)$/, to: "wallpaper $1", note: "everything about the picture starts with wallpaper" },
    { re: /^set wallpaper (.+)$/, to: "wallpaper set $1", note: "everything about the picture starts with wallpaper" },
    { re: /^status wallpaper$/, to: "wallpaper", note: "a bare thing says how it is" },
    { re: /^list wallpaper( .*)?$/, to: "wallpaper list$1", note: "everything about the picture starts with wallpaper" },
    { re: /^dispatch wallpaper (.+)$/, to: "wallpaper $1", note: "everything about the picture starts with wallpaper" },

    { re: /^toggle output$/, to: "output toggle", note: "everything about the output starts with output" },
    { re: /^set output (\S+)$/, to: "output $1", note: "everything about the output starts with output" },
    { re: /^set output (\S+) (\S+)$/, to: "output assign $1 $2", note: "naming a device is assign" },
    { re: /^status output$/, to: "output", note: "a bare thing says how it is" },
    { re: /^list output$/, to: "output list", note: "everything about the output starts with output" },

    { re: /^toggle volume mute$/, to: `wpctl set-mute ${SINK} toggle`, run: true, note: "volume is wpctl's" },
    { re: /^set volume mute$/, to: `wpctl set-mute ${SINK} toggle`, run: true, note: "volume is wpctl's" },
    { re: /^set volume mute on$/, to: `wpctl set-mute ${SINK} 1`, run: true, note: "volume is wpctl's" },
    { re: /^set volume mute off$/, to: `wpctl set-mute ${SINK} 0`, run: true, note: "volume is wpctl's" },
    { re: /^set volume ([+-]?)((?:\d+(?:\.\d*)?|\.\d+)?)$/, to: volumeTo, run: true, note: "volume is wpctl's" },
    { re: /^status volume$/, to: `wpctl get-volume ${SINK}`, run: true, note: "volume is wpctl's" },

    { re: /^(dispatch lock|lock)$/, to: "loginctl lock-session", run: true, note: "locking is logind's; the shell's lock answers it" },
    { re: /^status lock$/, to: "loginctl show-session auto -p LockedHint", run: true, note: "locking is logind's; the shell's lock answers it" },

    { re: /^toggle tablet lid( .*)?$/, to: "tablet lid toggle$1", note: "everything about the tablet starts with tablet" },
    { re: /^toggle tablet( .*)?$/, to: "tablet toggle$1", note: "everything about the tablet starts with tablet" },
    { re: /^set tablet lid (closed|open)( .*)?$/, to: "tablet lid $1$2", note: "everything about the tablet starts with tablet" },
    { re: /^set tablet (?!lid )(.+)$/, to: "tablet $1", note: "everything about the tablet starts with tablet" },
    { re: /^status tablet$/, to: "tablet", note: "a bare thing says how it is" },
    { re: /^dispatch tablet probe( lid)?$/, to: "tablet probe$1", note: "everything about the tablet starts with tablet" },
    { re: /^dispatch penmap probe$/, to: "tablet probe", note: "everything about the tablet starts with tablet" },
    { re: /^set penmap rect (.+)$/, to: "tablet pen area $1", note: "the pen's mapper lives with the tablet" },
    { re: /^status penmap$/, to: "tablet pen", note: "the pen's mapper lives with the tablet" },
    { re: /^dispatch penmap (commit|cancel|aspect|centre|follow)$/, to: "tablet pen $1", note: "the pen's mapper lives with the tablet" },

    { re: /^set theme (.+)$/, to: "config theme $1", note: "settings start with config" },
    { re: /^get theme$/, to: "config theme", note: "settings start with config" },
    { re: /^list themes$/, to: "config theme list", note: "settings start with config" },
    { re: /^get (\S+)$/, to: "config get $1", note: "settings start with config" },
    { re: /^set (?!(?:border|sidebar|stream|wallpaper|volume|brightness|temperature|output|tablet|theme|penmap) )(\S+) (.+)$/, to: "config set $1 $2", note: "settings start with config" },

    { re: /^status (timer|alarm)$/, to: "clock $1", note: "a bare thing says how it is" },
    { re: /^list (alarm|zone)$/, to: "clock $1 list", note: "timers, alarms and zones live in the clock" },
    { re: /^dispatch alarm status$/, to: "clock alarm", note: "a bare thing says how it is" },
    { re: /^dispatch (timer|alarm|zone) (.+)$/, to: "clock $1 $2", note: "timers, alarms and zones live in the clock" },

    { re: /^dispatch picker open$/, to: "screenshot save", note: "the picker is screenshot" },
    { re: /^dispatch picker freeze$/, to: "screenshot save --freeze", note: "the picker is screenshot" },
    { re: /^dispatch picker clip$/, to: "screenshot copy", note: "the picker is screenshot" },
    { re: /^dispatch picker freezeclip$/, to: "screenshot copy --freeze", note: "the picker is screenshot" },
    { re: /^dispatch picker close$/, to: "panel picker close", note: "the picker closes like a panel" },
    { re: /^shot( .*)?$/, to: "screenshot full$1", note: "the whole desktop is a screenshot too" },

    { re: /^list clipboard$/, to: "panel clipboard list", note: "a panel's own actions follow its name" },
    { re: /^list menu$/, to: "dev menu list", note: "the menu registry is for working on the shell" },
    { re: /^dispatch menu (current|hover)$/, to: "dev menu $1", note: "the menu registry is for working on the shell" },
    { re: /^dispatch calculator app$/, to: "panel calculator full", note: "the calculator's shapes are full and compact" },
    { re: /^dispatch calculator panel$/, to: "panel calculator compact", note: "the calculator's shapes are full and compact" },
    { re: /^dispatch launcher scrub (.+)$/, to: "dev launcher scrub $1", note: "scrubbing is for working on the shell" },
    { re: /^dispatch keyring refuse$/, to: "dev keyring close", note: "the keyring prompt is for working on the shell" },
    { re: /^status keyring$/, to: "dev keyring status", note: "the keyring prompt is for working on the shell" },
    { re: /^dispatch keyring demo$/, to: "dev keyring demo", note: "the demo is for working on the shell" },
    { re: /^dispatch (clipboard|calculator|keyboard|settings|launcher|notifications) (.+)$/, to: "panel $1 $2", note: "a panel's own actions follow its name" },
    { re: /^files$/, to: "panel files toggle", note: "the file browser is a panel" },
    { re: /^files (toggle|open|close|status)( .*)?$/, to: "panel files $1$2", note: "the file browser is a panel" },

    { re: /^dispatch migration migrate$/, to: "doctor binds rewrite", note: "the doctor rewrites old binds" },
    { re: /^status migration$/, to: "doctor binds", note: "the doctor reports old binds" },

    { re: /^list worktree$/, to: "dev worktrees", note: "working on the shell starts with dev" },
    { re: /^(try|back|run|build|shaders|test|check)( .*)?$/, to: "dev $1$2", note: "working on the shell starts with dev" },
    { re: /^demo (.+)$/, to: "dev preview menu $1", note: "previews live under dev" },
    { re: /^gallery( .*)?$/, to: "dev preview gallery$1", note: "previews live under dev" },
    { re: /^(lock|settings|files)preview( .*)?$/, to: "dev preview $1$2", note: "previews live under dev" }
];

function migrateArgs(args) {
    const normalized = String(args ?? "").trim().split(/[ \t]+/).join(" ");
    for (const rule of RULES) {
        if (rule.re.test(normalized))
            return { args: normalized.replace(rule.re, rule.to).trimEnd(), note: rule.note, run: rule.run === true };
    }
    return null;
}

const CMD_RE = /(^|[^A-Za-z0-9_-])(banditshell(?:[ \t]+(?!\d+[<>])(?:"[^"]*"|[^ \t"'&;#\r\n)<>|]+))+)/g;

const COMMENT_LINE = /^\s*(#|--)/;

function rewriteText(text) {
    const changes = [];
    const out = String(text ?? "").split("\n").map(line => COMMENT_LINE.test(line) ? line : line.replace(CMD_RE, (whole, prefix, cmd) => {
        const args = cmd.replace(/^banditshell[ \t]+/, "");
        const hit = migrateArgs(args);
        if (!hit)
            return whole;
        const to = hit.run ? hit.args : `banditshell ${hit.args}`;
        changes.push({ from: cmd, to, note: hit.note });
        return prefix + to;
    })).join("\n");
    return { text: out, changes };
}

function scanFiles(files) {
    const fs = require("node:fs");
    const hits = [];
    for (const file of files) {
        let text = "";
        try {
            text = fs.readFileSync(file, "utf8");
        } catch {
            continue;
        }
        const n = rewriteText(text).changes.length;
        if (n)
            hits.push({ file, n });
    }
    return hits;
}

const LUA_KEYWORDS = ["and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"];

function parseActions(text) {
    const rows = [];
    for (const line of String(text ?? "").split("\n")) {
        if (!line || line[0] === "#")
            continue;
        const [id, status, since, argv, description] = line.split("\t");
        if (!id || !argv)
            continue;
        rows.push({ id, status, since: Number(since) || 1, words: argv.split(" "), description: description ?? "" });
    }
    return rows;
}

function actionFor(words, rows) {
    let best = null;
    let tie = false;
    for (const row of rows) {
        if (row.status !== "stable" || row.words.length > words.length)
            continue;
        const captures = [];
        let fits = true;
        for (let i = 0; i < row.words.length && fits; i++) {
            const want = row.words[i];
            if (/^\$[1-9]$/.test(want))
                captures[Number(want[1]) - 1] = words[i];
            else
                fits = want === words[i];
        }
        if (!fits)
            continue;
        let at = 0;
        const segments = row.id.split(".").map(segment => segment === "*" ? captures[at++] : segment);
        if (!segments.every(segment => /^[a-z0-9_]+$/.test(segment)))
            continue;
        const found = { id: segments.join("."), length: row.words.length, stars: captures.length, args: words.slice(row.words.length) };
        if (!best || found.length > best.length || (found.length === best.length && found.stars < best.stars)) {
            best = found;
            tie = false;
        } else if (found.length === best.length && found.stars === best.stars && found.id !== best.id) {
            tie = true;
        }
    }
    return best && !tie ? best : null;
}

const SAFE_WORD = /^[A-Za-z0-9_@%+=:,.\/-]+$/;

function luaString(text) {
    return `"${String(text).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function dotted(id) {
    const segments = id.split(".");
    return segments.every(segment => /^[a-z_][a-z0-9_]*$/.test(segment) && !LUA_KEYWORDS.includes(segment));
}

function stableForm(found, run) {
    if (run)
        return `bs.run(${[luaString(found.id)].concat(found.args.map(luaString)).join(", ")})`;
    if (!found.args.length && dotted(found.id))
        return `bs.${found.id}`;
    return `bs.action(${[luaString(found.id)].concat(found.args.map(luaString)).join(", ")})`;
}

function commandWords(literal) {
    const words = literal.trim().split(/[ \t]+/);
    if (words[0] !== "banditshell" || words.length < 2 || !words.slice(1).every(word => SAFE_WORD.test(word)))
        return null;
    const rest = words.slice(1).join(" ");
    const hit = migrateArgs(rest);
    if (hit && hit.run)
        return null;
    return (hit ? hit.args : rest).split(" ");
}

const EXEC_CALL = /(hl\.dsp\.exec_cmd|hl\.exec_cmd)\(\s*(["'])((?:(?!\2)[^\\\n])*)\2\s*\)/g;

const REQUIRE_ANY = /require\s*\(?\s*["']banditshell["']/;

const REQUIRE_AS_BS = /\blocal\s+bs\s*=\s*require\s*\(?\s*["']banditshell["']\s*\)?/;

function withRequire(original, text) {
    if (REQUIRE_ANY.test(original))
        return REQUIRE_AS_BS.test(original) ? { text } : { text, unsafe: "it loads banditshell under another name" };
    if (/\bbs\b/.test(original))
        return { text, unsafe: "it already uses the name bs" };
    const lines = text.split("\n");
    let at = 0;
    while (at < lines.length && (/^\s*$/.test(lines[at]) || COMMENT_LINE.test(lines[at]) || /^#!/.test(lines[at])))
        at++;
    lines.splice(at, 0, 'local bs = require("banditshell")');
    return { text: lines.join("\n") };
}

function rewriteStable(text, rows) {
    const changes = [];
    const lines = String(text ?? "").split("\n").map(line => COMMENT_LINE.test(line) ? line : line.replace(EXEC_CALL, (whole, call, _quote, literal) => {
        const words = commandWords(literal);
        const found = words ? actionFor(words, rows) : null;
        if (!found)
            return whole;
        const to = stableForm(found, call === "hl.exec_cmd");
        changes.push({ from: whole, to, id: found.id });
        return to;
    }));
    if (!changes.length)
        return { text: String(text ?? ""), changes, skipped: "" };
    const joined = lines.join("\n");
    const needed = withRequire(String(text ?? ""), joined);
    if (needed.unsafe)
        return { text: String(text ?? ""), changes: [], skipped: needed.unsafe };
    return { text: needed.text, changes, skipped: "" };
}

function stamp(now) {
    const pad = n => String(n).padStart(2, "0");
    return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
}

function backupName(file, now, exists) {
    const base = `${file}.bak-${stamp(now)}`;
    if (!exists(base))
        return base;
    for (let n = 2; ; n++)
        if (!exists(`${base}-${n}`))
            return `${base}-${n}`;
}

function backup(file, before) {
    const fs = require("node:fs");
    const name = backupName(file, new Date(), fs.existsSync);
    fs.writeFileSync(name, before);
    return name;
}

function loadActions(argv) {
    const fs = require("node:fs");
    const path = require("node:path");
    const at = argv.indexOf("--actions");
    const file = at >= 0 ? argv[at + 1] : path.join(__dirname, "..", "api", "actions.tsv");
    if (at >= 0)
        argv.splice(at, 2);
    return parseActions(fs.readFileSync(file, "utf8"));
}

function stableMain(mode, argv) {
    const fs = require("node:fs");
    const rows = loadActions(argv);
    const files = argv.filter(a => a !== "--write");
    const write = mode === "--stable-write";
    if (!files.length) {
        process.stderr.write("usage: node cli-migration.js --stable-scan|--stable-check|--stable-write [--actions <file>] <file...>\n");
        return 2;
    }
    let found = 0;
    for (const file of files) {
        let before = "";
        try {
            before = fs.readFileSync(file, "utf8");
        } catch {
            continue;
        }
        const { text, changes, skipped } = rewriteStable(rewriteText(before).text, rows);
        if (skipped)
            process.stderr.write(`${file}: left alone, ${skipped}\n`);
        if (mode === "--stable-scan") {
            if (changes.length)
                process.stdout.write(`${changes.length}\t${file}\n`);
        } else {
            for (const c of changes)
                process.stdout.write(`${file}: ${c.from}  ->  ${c.to}\n`);
        }
        found += changes.length;
        if (write && changes.length) {
            backup(file, before);
            fs.writeFileSync(file, text);
        }
    }
    return mode === "--stable-scan" || found ? 0 : 2;
}

function main(argv) {
    const mode = argv[0];
    if (mode === "--generation") {
        process.stdout.write(`${GENERATION}\n`);
        return 0;
    }

    if (mode === "--cmd") {
        const hit = migrateArgs(argv.slice(1).join(" "));
        if (hit)
            process.stdout.write((hit.run ? "!" : "") + hit.args + "\n");
        return hit ? 0 : 2;
    }

    if (mode === "--scan") {
        for (const { file, n } of scanFiles(argv.slice(1)))
            process.stdout.write(`${n}\t${file}\n`);
        return 0;
    }

    if (mode === "--stable-scan" || mode === "--stable-check" || mode === "--stable-write")
        return stableMain(mode, argv.slice(1));

    const dry = mode === "--check";
    const files = argv.slice(dry ? 1 : 0).filter(a => a !== "--write");
    if (!files.length) {
        process.stderr.write("usage: node cli-migration.js --check <file...> | --write <file...> | --scan <file...> | --cmd '<old command>' | --stable-scan|--stable-check|--stable-write <file...>\n");
        return 2;
    }

    let found = 0;
    for (const file of files) {
        const fs = require("node:fs");
        const before = fs.readFileSync(file, "utf8");
        const { text, changes } = rewriteText(before);
        for (const c of changes)
            process.stdout.write(`${file}: ${c.from}  ->  ${c.to}\n`);
        found += changes.length;
        if (!dry && changes.length) {
            backup(file, before);
            fs.writeFileSync(file, text);
        }
    }
    return found ? 0 : 2;
}

if (typeof require !== "undefined" && typeof module !== "undefined" && require.main === module)
    process.exit(main(process.argv.slice(2)));
