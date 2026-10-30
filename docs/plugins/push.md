# Adding rows from any tool

A tool that only wants a row in the launcher needs no plugin. It adds the row
with one command and takes it away with another:

    banditshell launcher add deploy failed "Deploy failed on main" \
        --subtitle "2 minutes ago" --icon rocket_launch --keywords "ci build" \
        --open https://ci.example.org/run/41
    banditshell launcher remove deploy failed

The row shows when someone types words from its title, its keywords or the
tool's name, in a group named after the tool. It stays until the tool removes
it, or until `--until` runs out.

## The command

    banditshell launcher add <tool> <row> <title> [options]
    banditshell launcher add <json>
    banditshell launcher remove <tool> [<row>]
    banditshell launcher list [<tool>]

`<tool>` names the tool the row belongs to, and `<row>` names the row within
it. Both are lowercase letters, digits, `.`, `-` and `_`. Adding a row under a
name the tool already used replaces it, so a tool can keep one row up to date
by adding it again. `remove` without a row takes away every row of the tool.
`list` prints the rows as JSON.

| option | what it does |
|---|---|
| `--subtitle <text>` | The row's second line. |
| `--icon <icon>` | A Material Symbols name such as `rocket_launch`, an emoji, or an absolute path to a picture. Without one, or with a name it cannot draw, the row gets an icon for what Enter does. |
| `--keywords <words>` | More words the row is found by, separated by spaces. |
| `--until <span>` | Takes the row away after a span such as `90s`, `10m`, `1h30m` or `2d`. Plain seconds work too. |
| `--open <target>` | Enter opens a link (`https://`, `http://`, `mailto:`, `file:///`) or an absolute path. |
| `--copy <text>` | Enter copies the text. |
| `--run <command>` | Enter runs a command. Everything after `--run` is the command and its arguments, so it comes last. It runs as you, without a shell. |

A row takes at most one of `--open`, `--copy` and `--run`. A row with none of
them is only there to be seen. Every row's actions menu also has Remove from
launcher.

Each tool keeps at most 50 rows; adding more drops its oldest.

## As JSON

`banditshell launcher add` also takes the whole row as one JSON object, and
the shell's IPC takes the same text, so a tool can skip the CLI:

    qs ipc call launcher add '{"tool":"deploy","id":"failed","title":"Deploy failed on main","open":"https://ci.example.org/run/41","ttl":"10m"}'
    qs ipc call launcher remove deploy failed
    qs ipc call launcher list deploy

| field | meaning |
|---|---|
| `tool`, `id`, `title` | Required, as above. |
| `subtitle`, `icon`, `keywords` | As the options. `keywords` is a list of strings or one string of words. |
| `open`, `copy` | A string each. |
| `run` | A list of strings, the program first. |
| `ttl` | Seconds, or a span like `"10m"`, until the row goes away. |

A refused row answers `refused:` and the reason, and the CLI exits with 4.

## Where rows live

The shell keeps them in `~/.local/state/banditshell/launcher-pushed-rows.json`,
grouped by tool, so they survive a restart. Write to it through the command,
never by hand: the shell only reads the file when it starts.

Rows show in searches of two characters or more, ranked like any other row
on their title, keywords and tool name, at most six per tool. They also work
with `banditshell panel launcher run pushed:<tool>:<row>`, aliases and hotkeys.
