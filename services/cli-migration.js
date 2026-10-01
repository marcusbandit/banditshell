// THE MIGRATION MAP: the old CLI grammar rewritten into the verb-first one.
//
// The old grammar was noun-first and bespoke - one top-level verb per surface,
// each with its own tail (`volume set 50`, `wallpapers toggle`, `border on`).
// The new grammar is generic-first: VERB, then OBJECT, then args, so the
// meaning of a command reads off the front of it:
//
//     banditshell toggle panel notifications
//     banditshell set volume 50
//     banditshell dispatch clipboard use 3
//
// This file is the ONE authority on old → new, written down before anything
// consumes it, because three different things need the same answer:
//
//   - the scanner: on every shell start the user's hyprland config is searched
//     for old forms, and the sidebar's update icon offers the fix
//   - the rewriter: `node services/cli-migration.js --write <file>` applies the
//     map to a config in place (with a .bak beside it)
//   - the CLI wrapper's fallback: a bind that still speaks the old grammar is
//     rewritten through this map on the way into the IPC call, so nothing a
//     user has bound ever dies silently while the nag is on screen
//
// The rules are a table, not code paths, so the map can be READ as a list.
// First match wins; order is specific before general. A command that matches
// no rule comes back untouched - the dev verbs, the lifecycle verbs and the
// bare `get`/`set` are already generic-first and need nothing.
//
// Everything here is plain JavaScript with no QML in it, the same bargain as
// hyprgen.js: node runs it for the tests and the rewriter, Quickshell imports
// it for the scanner.

// Panels whose old form was `<noun> <surface-verb> [args]`. The rename column
// is the one place the map CHANGES A NOUN: the picker was `wallpapers` (plural,
// one letter from the picture it picks, which `wallpaper` also names). The new
// grammar names both with the one noun - `set wallpaper <path>` wears it,
// `toggle panel wallpaper` opens the picker for it.
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
    { noun: "files" },
    { noun: "wallpapers", rename: "wallpaper" }
];

// The generic panel shape, built from the table - one rule per noun so the
// rename column is applied, since a replace() template cannot map `$1` to
// different spellings for different nouns.
function panelRules() {
    const rules = [];
    for (const { noun, rename } of PANELS) {
        const N = rename ?? noun;
        for (const verb of ["toggle", "open", "status"]) {
            rules.push({
                re: new RegExp(`^${noun} ${verb}( .*)?$`),
                to: verb === "status" ? `status panel ${N}$1` : `${verb} panel ${N}$1`,
                note: "panel surface verb goes in front of the noun"
            });
        }
        // close takes no screen argument (it reaches every screen on purpose),
        // so the rule is strict - a stray argument was already an IPC arity
        // error.
        rules.push({
            re: new RegExp(`^${noun} close$`),
            to: `close panel ${N}`,
            note: "panel surface verb goes in front of the noun"
        });
    }
    return rules;
}

// The Bespoke verbs - actions that are not surface state and have no generic
// verb of their own - go through `dispatch`, which carries them to the same
// IPC target with the tail untouched. A few verbs ARE generic and move out of
// their noun: `list` (a registry read), `status` (a state read), `set` (a
// value write).
const RULES = [
    // Sugar and the rescue, before anything that could shadow them.
    { re: /^panic$/, to: "close", note: "panic was already close; drop the alias" },
    { re: /^calendar$/, to: "toggle panel calendar", note: "calendar was menu sugar" },
    { re: /^clock$/, to: "toggle panel clock", note: "clock was menu sugar" },

    // menu: the menu ENGINE. open/toggle name a menu KEY, and in the new
    // grammar that key IS the panel instance - the word `menu` dissolves.
    { re: /^menu list$/, to: "list menu", note: "the registry of menu keys" },
    { re: /^menu (current|hover)$/, to: "dispatch menu $1", note: "bespoke reads" },
    { re: /^menu (open|toggle)( .*)?$/, to: "$1 panel$2", note: "the key becomes the panel instance" },
    { re: /^menu close$/, to: "close panel menu", note: "the menu surface" },

    // border: the chrome flag, a boolean - so both toggle and set.
    { re: /^border toggle$/, to: "toggle border", note: "boolean state" },
    { re: /^border (on|off)$/, to: "set border $1", note: "boolean state, explicit" },
    { re: /^border status$/, to: "status border", note: "state read" },

    // wallpaper: the WORN picture. on/off is the runner's boolean; set takes a
    // path; next/prev/clear/palette are actions, not state.
    { re: /^wallpaper toggle$/, to: "toggle wallpaper", note: "boolean state" },
    { re: /^wallpaper (on|off)$/, to: "set wallpaper $1", note: "boolean state, explicit" },
    { re: /^wallpaper status$/, to: "status wallpaper", note: "state read" },
    { re: /^wallpaper list( .+)?$/, to: "list wallpaper$1", note: "registry read" },
    { re: /^wallpaper set (.+)$/, to: "set wallpaper $1", note: "value write" },
    { re: /^wallpaper (next|prev|clear|palette)( .*)?$/, to: "dispatch wallpaper $1$2", note: "actions on the picture" },

    // volume: a NUMBER, so set (never toggle - the level is not on/off), with
    // relative +n/-n; mute is the boolean part and gets both. The bare +/-
    // (old `up`/`down` with no count) means one step of the shell's own size.
    { re: /^volume up(?: +(\d+))?$/, to: "set volume +$1", note: "relative write" },
    { re: /^volume down(?: +(\d+))?$/, to: "set volume -$1", note: "relative write" },
    { re: /^volume set (.+)$/, to: "set volume $1", note: "absolute write" },
    { re: /^volume mute (on|off)$/, to: "set volume mute $1", note: "the boolean part, explicit" },
    { re: /^volume mute$/, to: "toggle volume mute", note: "the boolean part" },
    { re: /^volume status$/, to: "status volume", note: "state read" },

    // output: the switch is a choice between two sinks - settable, and the
    // flip between them keeps its toggle.
    { re: /^output toggle$/, to: "toggle output", note: "flip between the sinks" },
    { re: /^output (speakers|headphones)$/, to: "set output $1", note: "named sink" },
    { re: /^output assign (.+)$/, to: "set output $1", note: "role and sink, one write" },
    { re: /^output list$/, to: "list output", note: "registry read" },
    { re: /^output status$/, to: "status output", note: "state read" },

    // tablet: the hinge. on/off is state (the compositor's switch binds pass
    // their caller as a second argument - kept verbatim); the lid is its own
    // boolean; probe asks hardware, which is an action.
    { re: /^tablet probe-lid$/, to: "dispatch tablet probe lid", note: "hardware ask" },
    { re: /^tablet probe$/, to: "dispatch tablet probe", note: "hardware ask" },
    { re: /^tablet lid toggle( .*)?$/, to: "toggle tablet lid$1", note: "the lid's boolean" },
    { re: /^tablet lid (closed|open)( .*)?$/, to: "set tablet lid $1$2", note: "the lid, explicit" },
    { re: /^tablet (on|off)( .*)?$/, to: "set tablet $1$2", note: "hinge state, explicit" },
    { re: /^tablet toggle( .*)?$/, to: "toggle tablet$1", note: "hinge state" },
    { re: /^tablet status$/, to: "status tablet", note: "state read" },

    // penmap: the mapper's own verbs are bespoke; its surface opens like a
    // panel and its rectangle is a value with a name.
    { re: /^penmap open$/, to: "open panel penmap", note: "the mapper's surface" },
    { re: /^penmap status$/, to: "status penmap", note: "state read" },
    { re: /^penmap (commit|cancel|aspect|follow)$/, to: "dispatch penmap $1", note: "bespoke actions" },
    { re: /^penmap set (.+)$/, to: "set penmap rect $1", note: "the rectangle, named" },

    // picker: the screenshot picker. Its modes are bespoke; its close is the
    // surface's close.
    { re: /^picker (open|freeze|clip|freezeclip)$/, to: "dispatch picker $1", note: "bespoke modes" },
    { re: /^picker close$/, to: "close panel picker", note: "the surface" },

    // lock and keyring: lock is an action with no state to read (the way back
    // is loginctl, deliberately not here); the keyring's verbs are actions
    // except the one read.
    { re: /^lock$/, to: "dispatch lock", note: "an action" },
    { re: /^lock status$/, to: "status lock", note: "state read" },
    { re: /^keyring status$/, to: "status keyring", note: "state read" },
    { re: /^keyring (refuse|demo)$/, to: "dispatch keyring $1", note: "actions" },

    // timer and alarm: countdowns are actions; their lists are registry reads.
    { re: /^timer status$/, to: "status timer", note: "state read" },
    { re: /^timer (start|pause|resume|toggle|cancel)( .*)?$/, to: "dispatch timer $1$2", note: "actions" },
    { re: /^alarm list$/, to: "list alarm", note: "registry read" },
    { re: /^alarm status$/, to: "status alarm", note: "state read" },
    { re: /^alarm (snooze|stop|enable|disable|remove|add)( .*)?$/, to: "dispatch alarm $1$2", note: "actions" },

    // zone: the registry read is generic, the edits are actions.
    { re: /^zone list$/, to: "list zone", note: "registry read" },
    { re: /^zone (find|add|remove)( .*)?$/, to: "dispatch zone $1$2", note: "actions" },

    // theme(s): the sugar folds into the generic get/set it always wrapped.
    { re: /^themes$/, to: "list themes", note: "registry read" },
    { re: /^theme$/, to: "get theme", note: "a config read" },
    { re: /^theme (.+)$/, to: "set theme $1", note: "a config write" },

    // clipboard's bespoke tail: history edits are actions, the registry read
    // is generic.
    { re: /^clipboard (use|pin|remove|clear)( .*)?$/, to: "dispatch clipboard $1$2", note: "history actions" },
    { re: /^clipboard list$/, to: "list clipboard", note: "registry read" },

    // calculator: shape picks are bespoke; answer is the no-surface route.
    { re: /^calculator (app|panel)$/, to: "dispatch calculator $1", note: "shape picks" },
    { re: /^calculator answer (.+)$/, to: "dispatch calculator answer $1", note: "evaluate without a surface" },

    // keyboard and settings: modes and pages are bespoke; open/close/toggle
    ///status fall through to the panel shape below.
    { re: /^keyboard (page|dock|float)( .*)?$/, to: "dispatch keyboard $1$2", note: "bespoke" },
    { re: /^settings (page|float)( .*)?$/, to: "dispatch settings $1$2", note: "bespoke" },

    // launcher: run and scrub steer the launcher, they are not its visibility.
    { re: /^launcher (run|scrub)( .*)?$/, to: "dispatch launcher $1$2", note: "bespoke" },

    // The generic panel shape, LAST: every plain `<noun> toggle|open|close|status`.
    ...panelRules()
];

// Old spellings of a noun, normalised before the rules run. These were always
// aliases, not verbs of their own, and none of them appear in the new grammar.
const ALIAS_NOUN = {
    calc: "calculator",
    osk: "keyboard",
    pen: "penmap"
};

// `to` is a replace() template, so `$1`-style groups just work; a trailing
// space from a group that did not participate is trimmed at the end.
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
    return null; // nothing to migrate; the command is already current
}

// A command span inside a config line: `banditshell` followed by its argument
// tokens. A token is a quoted string (the calculator's `answer "2+3*4"`) or a
// run of characters that cannot end the command - quotes, and the bind
// grammar's own punctuation: `&` chains a second command, `;` separates,
// `#` comments, `)` closes exec_cmd's call, and a newline ends the line.
const CMD_RE = /(^|[^A-Za-z0-9_-])(banditshell(?:[ \t]+(?:"[^"]*"|[^ \t"'&;#\r\n)]+))+)/g;

function rewriteText(text) {
    const changes = [];
    const out = String(text ?? "").replace(CMD_RE, (whole, prefix, cmd) => {
        const args = cmd.replace(/^banditshell[ \t]+/, "");
        const hit = migrateArgs(args);
        if (!hit)
            return whole; // already current, or a verb the map does not touch
        changes.push({ from: cmd, to: `banditshell ${hit.args}`, note: hit.note });
        return prefix + `banditshell ${hit.args}`;
    });
    return { text: out, changes };
}

// Hand the rewriter its own command line, so the bash wrapper's fallback can
// ask the map for one answer without sourcing JavaScript:
//     node services/cli-migration.js --cmd 'wallpapers toggle'
// prints the new form, or nothing when there is nothing to do.
function main(argv) {
    const mode = argv[0];
    if (mode === "--cmd") {
        const hit = migrateArgs(argv.slice(1).join(" "));
        if (hit)
            process.stdout.write(hit.args + "\n");
        return hit ? 0 : 2;
    }

    const dry = mode === "--check";
    const files = argv.slice(dry ? 1 : 0).filter(a => a !== "--write");
    if (!files.length) {
        process.stderr.write("usage: node cli-migration.js --check <file...> | --write <file...> | --cmd '<old command>'\n");
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
    return found ? 0 : 2; // script-friendly: 0 means "there is something to migrate"
}

if (typeof require !== "undefined" && typeof module !== "undefined" && require.main === module)
    process.exit(main(process.argv.slice(2)));
