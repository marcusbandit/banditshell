# Launcher plugins

A plugin adds results and actions to the launcher from a program of its own,
in any language, without changing banditshell. The shell starts the program
the first time the launcher needs it, keeps it running, and talks to it over
standard input and output, one JSON message per line.

Inside the shell a plugin is one more launcher source, so its rows get
ranking, the actions menu, learned usage, aliases, hotkeys, Tab completion,
the `?` page and `banditshell panel launcher run <id>` like any built-in row.
`docs/architecture/launcher-sources.md` describes that contract.

A tool that only wants to show a row or two needs no plugin:
`banditshell launcher add` pins one, see [push.md](push.md).

A plugin runs as you, with your permissions, like a script command. There is
no sandbox, so only install plugins you would run yourself.

## The folder

    ~/.config/banditshell/plugins/<id>/
        plugin.json
        the program, and anything else it needs

The folder name is the plugin's id. Settings, Launcher, Plugins lists every
plugin found there, switches each on and off, and shows its preferences. The
shell looks for new plugins each time the launcher opens.

`examples/hello-bash` and `examples/hello-python` are two complete plugins:
copy either folder into the plugins folder, open the launcher and type
`hello world` or `greet ada`. The Python one opens all three kinds of page
from its actions menu.

## The manifest

`plugin.json`:

```json
{
  "api": 1,
  "id": "jira",
  "name": "Jira",
  "about": "Search your Jira issues",
  "icon": "bug_report",
  "exec": ["./jira-plugin"],
  "prefix": ["jira", "j"],
  "global": { "minLength": 3, "cap": 3 },
  "preferences": [
    { "key": "site", "type": "text", "title": "Jira site", "placeholder": "acme.atlassian.net" },
    { "key": "token", "type": "secret", "title": "API token" }
  ]
}
```

| field | required | meaning |
|---|---|---|
| `api` | yes | The protocol version, `1`. A plugin asking for a version the shell does not speak is listed but not started. |
| `id` | yes | Lowercase letters, digits and `-`, the same as the folder name. |
| `name` | yes | Shown in Settings and as the title of the plugin's group. |
| `about` | no | One line for Settings and the `?` page. |
| `icon` | no | A Material Symbols name, an emoji or an image path relative to the folder. Rows without an icon of their own use it. |
| `exec` | yes | The program and its arguments, as a list. A first word starting with `./` is found in the plugin's folder. It runs with the folder as its working directory and is never passed through a shell. |
| `prefix` | no | Words that send the rest of the query to this plugin alone, the way `gh` and `pkg` work. They are listed on the `?` page. |
| `global` | no | Lets the plugin add rows to plain searches. `minLength` is how many characters a query needs first, 3 by default. `cap` is how many of its rows a plain search shows at most, 3 by default and never more than 5. Without `global` the plugin only answers after its prefix. |
| `preferences` | no | Settings the plugin needs, drawn by Settings so a plugin never ships its own settings window. |

A manifest needs `prefix`, `global` or both; with neither, nothing would ever
reach the plugin.

### Preferences

| field | meaning |
|---|---|
| `key` | Letters, digits and `_`. |
| `type` | `text`, `secret` or `toggle`. |
| `title` | The row's title in Settings. |
| `placeholder` | Grey text in an empty field. |
| `default` | The value before anyone sets one. |
| `required` | `true` when the plugin cannot answer without it. Until it is set, the plugin's row asks for it instead of starting the program. |

The values reach the program as environment variables named
`BANDITSHELL_PREF_` followed by the key in capitals, so `site` arrives as
`BANDITSHELL_PREF_SITE`. A toggle is `1` or `0`. Text values and toggles
live in `config.json` under `launcher.plugins.values`, and the plugins you
switched off under `launcher.plugins.off`. A `secret` is never written there:
it is kept in `~/.local/state/banditshell/plugin-secrets.json`, a file only
you can read. Changing a preference restarts the program.

The program also gets `BANDITSHELL_PLUGIN_ID`, `BANDITSHELL_PLUGIN_DIR` and
`BANDITSHELL_API`.

## The protocol

Every message is one line of JSON with a `type`. Lines that are not JSON, or
have a type the shell does not know, are written to the plugin's log and
skipped, so a stray `print` cannot break anything.

### The shell sends

| message | when |
|---|---|
| `{"type":"query","seq":12,"text":"login bug","prefixed":true}` | Each pause in typing. With `prefixed` true, the person typed one of the plugin's prefix words, and `text` is what follows it. With `prefixed` false, this is a plain search and `text` is the whole query. |
| `{"type":"activate","seq":12,"id":"PROJ-41","action":"open"}` | Enter on a row, or a pick in its actions menu. `id` is the item's id, `action` the id of the chosen action, empty when the item has no actions. |
| `{"type":"complete","id":"PROJ-41"}` | Tab on a row. |
| `{"type":"cancel","seq":12}` | The query moved on before the answer to `seq` came. The plugin can stop working on it. |
| `{"type":"submit","view":"new-issue","values":{...}}` | The person submitted a form page. `values` has every field's key. |

`seq` grows with every query. An `activate` carries the `seq` of the results
its row came from. An `activate` from inside a page also carries `"view"`, the
page's id.

### The plugin answers

| message | what the shell does |
|---|---|
| `{"type":"results","seq":12,"items":[...]}` | Shows these rows in place of the plugin's last ones. An answer for any `seq` but the newest is dropped. |
| `{"type":"fill","text":"jira PROJ-41 "}` | Replaces the query, the usual answer to `complete`. |
| `{"type":"view","view":{...}}` | Opens a full page in place of the list. See Pages. |
| `{"type":"effect","do":"copy","text":"..."}` | Does one thing for the plugin, so it needs neither `wl-copy` nor `xdg-open`. See Effects. |

The plugin answers every `query` with one `results`, even an empty one, so
the shell knows it is done.

### Items

```json
{
  "id": "PROJ-41",
  "title": "Login fails after password reset",
  "subtitle": "PROJ-41 · In progress",
  "icon": "bug_report",
  "keywords": ["auth", "login"],
  "open": "https://acme.atlassian.net/browse/PROJ-41",
  "actions": [
    { "id": "assign", "title": "Assign to me", "icon": "person_add" },
    { "id": "key", "title": "Copy key", "icon": "content_copy", "copy": "PROJ-41" }
  ]
}
```

| field | meaning |
|---|---|
| `id` | Unique among the plugin's items and stable across queries. Required. The row's id in the launcher is `plugin:<plugin id>:<item id>`. |
| `title` | The row's title. Required. |
| `subtitle` | The second line. |
| `icon` | A Material Symbols name, an emoji or an absolute image path. |
| `keywords` | More words a plain search matches the row on. |
| `open` | A link (`https://`, `http://`, `mailto:`, `file:///`) or an absolute file path, opened by the shell. |
| `copy` | Text the shell copies. |
| `run` | A program and its arguments, as a list, that the shell starts. Never passed through a shell. |
| `actions` | More things the row can do, each `{ "id", "title", "icon" }` and optionally its own `open`, `copy` or `run`. |

What Enter does:

1. When the item has `open`, `copy` or `run`, the shell carries it out at once
   and closes the launcher. Nothing is sent to the plugin.
2. Otherwise Enter is the first of `actions`. An action with its own `open`,
   `copy` or `run` is carried out by the shell; one without is sent to the
   plugin as `activate` with its `id`.
3. An item with neither is sent as `activate` with an empty `action`.

The actions menu lists the same choices in that order. After an `activate`
the launcher stays open until the plugin sends an effect that closes it, so a
plugin can also answer with fresh `results` or a `fill`.

Links with any other scheme, and files that are not absolute paths, are
refused and the row says so, as for list scripts.

### Effects

| effect | what happens |
|---|---|
| `{"type":"effect","do":"copy","text":"..."}` | Copies the text and closes the launcher. |
| `{"type":"effect","do":"open","target":"https://..."}` | Opens a link or an absolute path, as for `open` on an item, and closes the launcher. |
| `{"type":"effect","do":"notify","title":"Assigned","body":"PROJ-41 is yours"}` | Posts a notification. The launcher stays open. |
| `{"type":"effect","do":"close"}` | Closes the launcher. |

## Pages

A plugin opens a page by answering an `activate` or a `submit` with a `view`.
A page fills the launcher the way the dictionary's word page does; Escape goes
back to the results. There is one level: a new `view` replaces the page, and a
`view` with the id of the page on screen updates it in place. A `view` that
does not answer something the person did is skipped.

Every page has `kind`, `id` and `title`, and may have `actions`, shown as
buttons along its foot with the same fields as an item's actions. Tab steps
through them and Enter runs the one picked. An action without its own
`open`, `copy` or `run` is sent as an `activate` whose `id` is the page's id,
or on a list page the selected row's id, with `"view"` set to the page.

`detail` shows text and facts. Enter is its first action, or an `activate`
with the page's id when it has none.

```json
{"kind": "detail", "id": "PROJ-41", "title": "PROJ-41", "text": "Login fails after a reset.",
 "facts": [{"label": "Status", "value": "In progress"}]}
```

`list` is a nested list with its own filter field. The shell filters it with
its own matcher, so typing never waits on the plugin. Enter on a row works as
for results, with the page's id added to the `activate`.

```json
{"kind": "list", "id": "comments", "title": "Comments on PROJ-41", "placeholder": "Filter comments",
 "items": [{"id": "c1", "title": "Seen it on staging too", "copy": "Seen it on staging too"}]}
```

`form` has fields and a submit button. Tab moves between fields, Space flips a
toggle, Left and Right pick a choice, and Enter submits. A field marked
`required` that is empty stops the submit and says so.

```json
{"kind": "form", "id": "new-issue", "title": "New issue", "submit": "Create",
 "fields": [
   {"key": "summary", "type": "text", "title": "Summary", "required": true},
   {"key": "kind", "type": "choice", "title": "Type", "choices": [{"value": "bug", "title": "Bug"}, {"value": "task", "title": "Task"}]},
   {"key": "urgent", "type": "toggle", "title": "Urgent"},
   {"key": "token", "type": "secret", "title": "One-time code"}
 ]}
```

A field's `value` sets where it starts. The plugin then gets
`{"type":"submit","view":"new-issue","values":{"summary":"...","kind":"bug","urgent":false,"token":"..."}}`
and usually answers with an effect or another page.

## Ranking

- After its prefix, the plugin's own order stands.
- In a plain search the shell ranks plugin rows itself, on `title` and
  `keywords`, with the same matcher as apps, and shows at most `global.cap` of
  them. Like file search results, they rank below the launcher's own best
  matches, so a plugin cannot push itself to the top.
- Rows that arrive after the built-in ones join below the selected row. A late
  answer never moves the selection.

## When things go wrong

A broken plugin costs one row, never the shell.

- A query with no answer after 2 seconds is cancelled and shows nothing from
  the plugin.
- A program that exits is started again on the next query, waiting a little
  longer after each crash. After three crashes in a minute the plugin is
  switched off, and one row says so with a button that opens its log.
  Switching it off and on again in Settings gives it a fresh start.
- Standard error goes to `~/.local/state/banditshell/plugins/<id>.log`.
- After 10 minutes without a query the program is stopped. The next query
  starts it again.

## Plugins draw nothing

Every row and page is drawn by the launcher's own components from the items a
plugin sends. A plugin looks like the rest of the shell without trying, and it
cannot slow down or crash the desktop, whatever language it is written in.
