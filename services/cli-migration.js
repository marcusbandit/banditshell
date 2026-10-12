const PANELS = [
    { noun: "launcher" },
    { noun: "clipboard" },
    { noun: "session" },
    { noun: "media" },
    { noun: "calculator" },
    { noun: "keyboard" },
    { noun: "settings" },
    { noun: "notifications" },
    { noun: "notch" },
    { noun: "hotkeys" },
    { noun: "files", stillAVerb: true },
    { noun: "wallpapers", rename: "wallpaper" }
];

function panelRules() {
    const rules = [];
    for (const { noun, rename, stillAVerb } of PANELS) {
        const N = rename ?? noun;
        if (!stillAVerb)
            rules.push({
                re: new RegExp(`^${noun}$`),
                to: `toggle panel ${N}`,
                note: "a bare panel noun toggled it"
            });
        for (const verb of ["toggle", "open", "status"]) {
            rules.push({
                re: new RegExp(`^${noun} ${verb}( .*)?$`),
                to: verb === "status" ? `status panel ${N}$1` : `${verb} panel ${N}$1`,
                note: "panel surface verb goes in front of the noun"
            });
        }
        rules.push({
            re: new RegExp(`^${noun} close$`),
            to: `close panel ${N}`,
            note: "panel surface verb goes in front of the noun"
        });
    }
    return rules;
}

const RULES = [
    { re: /^panic$/, to: "close", note: "panic was already close; drop the alias" },
    { re: /^calendar$/, to: "toggle panel calendar", note: "calendar was menu sugar" },
    { re: /^clock$/, to: "toggle panel clock", note: "clock was menu sugar" },

    { re: /^menu list$/, to: "list menu", note: "the registry of menu keys" },
    { re: /^menu$/, to: "list menu", note: "bare, it listed" },
    { re: /^menu (current|hover)$/, to: "dispatch menu $1", note: "bespoke reads" },
    { re: /^menu (open|toggle)( .*)?$/, to: "$1 panel$2", note: "the key becomes the panel instance" },
    { re: /^menu close$/, to: "close panel menu", note: "the menu surface" },

    { re: /^border toggle$/, to: "toggle border", note: "boolean state" },
    { re: /^border (on|off)$/, to: "set border $1", note: "boolean state, explicit" },
    { re: /^border status$/, to: "status border", note: "state read" },
    { re: /^border$/, to: "toggle border", note: "bare, it toggled" },

    { re: /^sidebar toggle( .*)?$/, to: "toggle sidebar$1", note: "boolean state, per screen" },
    { re: /^sidebar (on|off)( .*)?$/, to: "set sidebar $1$2", note: "boolean state, explicit" },
    { re: /^sidebar status$/, to: "status sidebar", note: "state read" },

    { re: /^wallpaper toggle$/, to: "toggle wallpaper", note: "boolean state" },
    { re: /^wallpaper (on|off)$/, to: "set wallpaper $1", note: "boolean state, explicit" },
    { re: /^wallpaper status$/, to: "status wallpaper", note: "state read" },
    { re: /^wallpaper$/, to: "toggle wallpaper", note: "bare, it toggled" },
    { re: /^wallpaper list( .+)?$/, to: "list wallpaper$1", note: "registry read" },
    { re: /^wallpaper set (.+)$/, to: "set wallpaper $1", note: "value write" },
    { re: /^wallpaper (next|prev|clear|palette)( .*)?$/, to: "dispatch wallpaper $1$2", note: "actions on the picture" },

    { re: /^volume up(?: +(\d+))?$/, to: "set volume +$1", note: "relative write" },
    { re: /^volume down(?: +(\d+))?$/, to: "set volume -$1", note: "relative write" },
    { re: /^volume set (.+)$/, to: "set volume $1", note: "absolute write" },
    { re: /^volume mute (on|off)$/, to: "set volume mute $1", note: "the boolean part, explicit" },
    { re: /^volume mute$/, to: "toggle volume mute", note: "the boolean part" },
    { re: /^volume status$/, to: "status volume", note: "state read" },
    { re: /^volume$/, to: "status volume", note: "bare, it read the state" },

    { re: /^output toggle$/, to: "toggle output", note: "flip between the sinks" },
    { re: /^output (speakers|headphones)$/, to: "set output $1", note: "named sink" },
    { re: /^output assign (.+)$/, to: "set output $1", note: "role and sink, one write" },
    { re: /^output list$/, to: "list output", note: "registry read" },
    { re: /^output status$/, to: "status output", note: "state read" },
    { re: /^output$/, to: "status output", note: "bare, it read the state" },

    { re: /^tablet probe-lid$/, to: "dispatch tablet probe lid", note: "hardware ask" },
    { re: /^tablet probe$/, to: "dispatch tablet probe", note: "hardware ask" },
    { re: /^tablet lid toggle( .*)?$/, to: "toggle tablet lid$1", note: "the lid's boolean" },
    { re: /^tablet lid (closed|open)( .*)?$/, to: "set tablet lid $1$2", note: "the lid, explicit" },
    { re: /^tablet (on|off)( .*)?$/, to: "set tablet $1$2", note: "hinge state, explicit" },
    { re: /^tablet toggle( .*)?$/, to: "toggle tablet$1", note: "hinge state" },
    { re: /^tablet status$/, to: "status tablet", note: "state read" },
    { re: /^tablet$/, to: "status tablet", note: "bare, it read the state" },

    { re: /^penmap open$/, to: "open panel penmap", note: "the mapper's surface" },
    { re: /^penmap status$/, to: "status penmap", note: "state read" },
    { re: /^penmap (commit|cancel|aspect|follow)$/, to: "dispatch penmap $1", note: "bespoke actions" },
    { re: /^penmap set (.+)$/, to: "set penmap rect $1", note: "the rectangle, named" },
    { re: /^penmap$/, to: "status penmap", note: "bare, it read the state" },

    { re: /^picker (open|freeze|clip|freezeclip)$/, to: "dispatch picker $1", note: "bespoke modes" },
    { re: /^picker close$/, to: "close panel picker", note: "the surface" },
    { re: /^picker$/, to: "dispatch picker freezeclip", note: "bare, the frozen shot to the clipboard" },

    { re: /^lock$/, to: "dispatch lock", note: "an action" },
    { re: /^lock status$/, to: "status lock", note: "state read" },
    { re: /^keyring status$/, to: "status keyring", note: "state read" },
    { re: /^keyring (refuse|demo)$/, to: "dispatch keyring $1", note: "actions" },
    { re: /^keyring$/, to: "status keyring", note: "bare, it read the state" },

    { re: /^timer status$/, to: "status timer", note: "state read" },
    { re: /^timer$/, to: "status timer", note: "bare, it read the state" },
    { re: /^timer (start|pause|resume|toggle|cancel)( .*)?$/, to: "dispatch timer $1$2", note: "actions" },
    { re: /^alarm list$/, to: "list alarm", note: "registry read" },
    { re: /^alarm$/, to: "list alarm", note: "bare, it listed" },
    { re: /^alarm status$/, to: "status alarm", note: "state read" },
    { re: /^alarm (snooze|stop|enable|disable|remove|add)( .*)?$/, to: "dispatch alarm $1$2", note: "actions" },

    { re: /^zone list$/, to: "list zone", note: "registry read" },
    { re: /^zone$/, to: "list zone", note: "bare, it listed" },
    { re: /^zone (find|add|remove)( .*)?$/, to: "dispatch zone $1$2", note: "actions" },

    { re: /^themes$/, to: "list themes", note: "registry read" },
    { re: /^theme$/, to: "get theme", note: "a config read" },
    { re: /^theme (.+)$/, to: "set theme $1", note: "a config write" },

    { re: /^clipboard (use|pin|remove|clear)( .*)?$/, to: "dispatch clipboard $1$2", note: "history actions" },
    { re: /^clipboard list$/, to: "list clipboard", note: "registry read" },

    { re: /^calculator (app|panel)$/, to: "dispatch calculator $1", note: "shape picks" },
    { re: /^calculator answer (.+)$/, to: "dispatch calculator answer $1", note: "evaluate without a surface" },

    { re: /^keyboard (page|dock|float)( .*)?$/, to: "dispatch keyboard $1$2", note: "bespoke" },
    { re: /^settings (page|float)( .*)?$/, to: "dispatch settings $1$2", note: "bespoke" },

    { re: /^launcher (run|scrub)( .*)?$/, to: "dispatch launcher $1$2", note: "bespoke" },

    ...panelRules()
];

const ALIAS_NOUN = {
    calc: "calculator",
    osk: "keyboard",
    pen: "penmap"
};

function migrateArgs(args) {
    let normalized = String(args ?? "").trim();
    const words = normalized.split(/[ \t]+/);
    if (words[0] in ALIAS_NOUN)
        words[0] = ALIAS_NOUN[words[0]];
    normalized = words.join(" ");

    for (const rule of RULES) {
        const m = normalized.match(rule.re);
        if (m)
            return { args: normalized.replace(rule.re, rule.to).trimEnd(), note: rule.note };
    }
    return null;
}

const CMD_RE = /(^|[^A-Za-z0-9_-])(banditshell(?:[ \t]+(?:"[^"]*"|[^ \t"'&;#\r\n)]+))+)/g;

const COMMENT_LINE = /^\s*(#|--)/;

function rewriteText(text) {
    const changes = [];
    const out = String(text ?? "").split("\n").map(line => COMMENT_LINE.test(line) ? line : line.replace(CMD_RE, (whole, prefix, cmd) => {
        const args = cmd.replace(/^banditshell[ \t]+/, "");
        const hit = migrateArgs(args);
        if (!hit)
            return whole;
        changes.push({ from: cmd, to: `banditshell ${hit.args}`, note: hit.note });
        return prefix + `banditshell ${hit.args}`;
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

function main(argv) {
    const mode = argv[0];
    if (mode === "--cmd") {
        const hit = migrateArgs(argv.slice(1).join(" "));
        if (hit)
            process.stdout.write(hit.args + "\n");
        return hit ? 0 : 2;
    }

    if (mode === "--scan") {
        for (const { file, n } of scanFiles(argv.slice(1)))
            process.stdout.write(`${n}\t${file}\n`);
        return 0;
    }

    const dry = mode === "--check";
    const files = argv.slice(dry ? 1 : 0).filter(a => a !== "--write");
    if (!files.length) {
        process.stderr.write("usage: node cli-migration.js --check <file...> | --write <file...> | --scan <file...> | --cmd '<old command>'\n");
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
            fs.writeFileSync(file + ".bak", before);
            fs.writeFileSync(file, text);
        }
    }
    return found ? 0 : 2;
}

if (typeof require !== "undefined" && typeof module !== "undefined" && require.main === module)
    process.exit(main(process.argv.slice(2)));
