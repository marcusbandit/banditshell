# Events

`banditshell events` prints one JSON line for each thing that happens in the shell, from the moment you
start it. A bar, a script or a status widget can follow the shell with it instead of polling.

```
banditshell events                         every event
banditshell events --filter panel,media    only these names and their groups
```

`--filter` takes event names (`panel.opened`) or groups (`panel`, which means every `panel.*`), separated by commas.
Exit codes are the CLI's: 3 when the shell is not running, 2 for a bad filter.

## How it works

The shell appends each line to `$XDG_RUNTIME_DIR/banditshell/events.jsonl` (mode 600, on tmpfs, gone at logout).
At 256 KiB the file moves to `events.jsonl.1` and a new one starts, so the stream never grows past about half a
megabyte. `banditshell events` is `tail -n 0 -F` on that file, with the filter applied, so it sees only events from
the moment it starts and survives the rotation. Anything can read the file directly:

```
tail -n 0 -F "$XDG_RUNTIME_DIR/banditshell/events.jsonl"
```

The shell takes a first look at its own state once it has loaded the config, the saved mode and the notification
history, and reports changes from then on. Nothing is replayed for what was already true at startup.

## Line format

One object per line. `event` comes first, then `time` (milliseconds since the epoch), then the fields below.
Strings are cut at 200 characters.

| event | fields | when |
|---|---|---|
| `workspace.changed` | `workspace`, `previous` | the focused workspace id changes |
| `panel.opened` | `panel`, `screen` | a panel or menu opens, or a pinned one is pinned, on a screen |
| `panel.closed` | `panel`, `screen` | the same, closing |
| `mode.changed` | `mode`, `previous` | a mode is entered or left (`none` is no mode) |
| `quiet.changed` | `quiet` | notifications become quiet (true) or stop being quiet (false), also at the ends of the nightly window |
| `media.track` | `title`, `artist`, `app`, `playing` | the player the shell follows starts a different track |
| `media.state` | `playing`, `app` | play or pause |
| `activity.pushed` | `id`, `text` | an activity appears in the island registry |
| `activity.updated` | `id`, `text`, `progress` | an activity is updated or pushed again; `progress` is 0 to 1, or -1 when unknown |
| `activity.ended` | `id`, `text`, `outcome` | an activity ends; `outcome` is `done`, `failed`, `cancelled` or `removed` |
| `notification.arrived` | `id`, `app`, and `summary` when `events.notificationText` is true | a notification enters the history |
| `notification.dismissed` | `id`, `app` | it leaves the history |
| `update.changed` | `state`, `behind` | the update state or the number of commits behind changes |

Panel names are the ones `banditshell panel` lists: `launcher`, `session`, `clipboard`, `media`, `calculator`,
`keyboard`, `settings`, `hotkeys`, `wallpaper`, `quickcontrols`, `notifications`, `island`, `files` and the name of
whichever menu is open (`volume`, `network`, and so on). `screen` is the output name, or empty for the file browser,
which belongs to no screen. Only activities pushed through `banditshell island` and the registry are reported, not
the timers and alarms the island also shows.

## Privacy

Notification text is private. By default a notification event carries the app name and an id, never the summary.
Set `events.notificationText` to `true` in `config.json` to add `summary`. The body is never written.

## Examples

```
banditshell events --filter workspace | while read -r line; do
    echo "$line" | jq -r .workspace
done

banditshell events --filter media.track | jq -r '"\(.artist) - \(.title)"'
```
