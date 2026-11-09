# Launcher plugins

A plugin adds results and actions to the launcher from a program of its own,
in any language, without changing banditshell. The shell starts the program
the first time the launcher needs it, keeps it running, and talks to it over
standard input and output, one JSON message per line.

Inside the shell a plugin is one more launcher source, so its rows get
ranking, the actions menu, learned usage, aliases, hotkeys, Tab completion,
the `?` page and `banditshell panel launcher run <id>` like any built-in row.
`docs/architecture/launcher-sources.md` describes that contract.

A row can be one line or up to twelve rows tall, show a preview beside the list,
and be drawn by a QML file the plugin ships. See Tall rows, Previews and Rows
drawn in QML below.

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
from its actions menu. `examples/streaks` draws its rows and its preview in
QML and updates a row in place: type `streak` and press Enter on a habit.

## Making and sharing plugins

    banditshell plugin                       every plugin in the folder
    banditshell plugin new <name> [--bash]   a working plugin to start from
    banditshell plugin dev <folder>          run one from any folder
    banditshell plugin install <folder|git url> [--yes]

`plugin new` writes a small plugin in Python, or bash with `--bash`, that
answers under its own name: `plugin new notes`, then type `notes hello`.

`plugin dev` links a folder you are working in into the plugins folder,
restarts the plugin every time a file in it is saved, and shows its log
until you press Ctrl-C, which takes the link away again.

`plugin install` copies a plugin in from a folder or a git url. Before it
copies anything it shows where the plugin comes from, the commit for a git
url, what program it runs, when it answers, what it asks for and its
files, then asks. It never runs the plugin to find out, and it will not
replace a plugin that is already there.

The first time you open Settings, Launcher, Plugins, it explains what a
plugin can reach before it lists any.

## The manifest

`plugin.json`:

```json
{
  "api": 3,
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
| `api` | yes | The protocol version, `3`. The shell still runs plugins that say `1` or `2`, and they can use everything below too; a newer number makes an older shell, which cannot do what that version adds, refuse the plugin instead of running it wrong. A plugin asking for a version the shell does not speak is listed but not started. |
| `id` | yes | Lowercase letters, digits and `-`, the same as the folder name. |
| `name` | yes | Shown in Settings and as the title of the plugin's group. |
| `about` | no | One line for Settings and the `?` page. |
| `icon` | no | A Material Symbols name, an emoji or an image path relative to the folder. Rows without an icon of their own use it. |
| `exec` | yes | The program and its arguments, as a list. A first word starting with `./` is found in the plugin's folder. It runs with the folder as its working directory and is never passed through a shell. |
| `prefix` | no | Words that send the rest of the query to this plugin alone, the way `gh` and `pkg` work. They are listed on the `?` page. |
| `global` | no | Lets the plugin add rows to plain searches. `minLength` is how many characters a query needs first, 3 by default. `cap` is how many of its rows a plain search shows at most, 3 by default and up to 50. Without `global` the plugin only answers after its prefix. |
| `preferences` | no | Settings the plugin needs, drawn by Settings so a plugin never ships its own settings window. |
| `background` | no | `true` starts the program with the shell and keeps it running while the launcher is closed, so it can keep its rows fresh or work on its own. It is never stopped for being idle, and after a crash it starts again by itself, until three crashes in a minute switch it off. |

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
`BANDITSHELL_API`, the api its manifest asked for.

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
| `{"type":"open"}` | The launcher opened, or the program started while it is open. |
| `{"type":"close"}` | The launcher closed. A plugin that keeps rows live with `update` stops here and starts again at the next `open`. |

`seq` grows with every query. An `activate` carries the `seq` of the results
its row came from. An `activate` from inside a page also carries `"view"`, the
page's id.

### The plugin answers

| message | what the shell does |
|---|---|
| `{"type":"results","seq":12,"items":[...]}` | Shows these rows in place of the plugin's last ones. An answer for any `seq` but the newest is dropped. |
| `{"type":"update","item":{...}}` | Replaces the item with the same `id` among the rows on screen, at any time, without a new query. A download's progress or a ticked-off habit changes in place. An update for an item that is not on screen is skipped. |
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
| `answer` | `true` when the row answers the query as typed, such as a sum or a conversion. A plain search then shows it even though its title and keywords do not match the typed words. |
| `height` | How many rows tall it is, 1 to 12, 1 by default, in plain searches as after a prefix. `"auto"` lets the row's QML decide, see Rows drawn in QML. |
| `pin` | `true` puts the row at the very top of a plain search, with the launcher's own pinned answers, whatever was typed. |
| `text` | Body text under the subtitle on a row 2 or more tall, wrapped to fit. |
| `image` | A picture drawn at the start of the row: an absolute path, a path in the plugin's folder or an `https://` link. On a one-line row it takes the icon's place. |
| `tags` | Up to four short words drawn as chips at the end of the row. |
| `preview` | What the peek card beside the list shows while the row is selected. See Previews. |
| `qml` | A QML file in the plugin's folder that draws the row. See Rows drawn in QML. |
| `props` | Any JSON object, up to 64 KB, handed to the row's and the preview's QML. |

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

### Tall rows

A row with `height` 2 or more is drawn by the shell as a card: the `image`,
or the icon, large at the start, then the title, the subtitle and as many
lines of `text` as fit, with `tags` at the end. With `"height": "auto"` the
card grows to show all of its `text`.

```json
{"id": "today", "title": "2 of 3 done today", "subtitle": "Monday 02 November",
 "text": "Still to do: Stretch.", "icon": "event_available", "height": 2, "tags": ["1 to go"]}
```

A tall row keeps its actions in the actions menu instead of drawing them as
buttons, so nothing moves under the pointer.

`height`, `image`, `text`, `tags`, `preview` and `qml` shape rows the same
way in the results and on a list page.

### Previews

`preview` fills the peek card beside the list while the row is selected,
when the screen has room for it.

| preview | what the card shows |
|---|---|
| `"Some text"` or `{"text": "..."}` | The text, its first 32 lines. |
| `{"image": "..."}` | A picture: an absolute path, a path in the plugin's folder or an `https://` link. |
| `{"file": "/abs/path"}` | The file the way the launcher previews files: the start of a text file, a picture, or a folder's listing. |
| `{"qml": "Preview.qml"}` | A QML file in the plugin's folder, drawn like a row's QML. Its `implicitWidth` and `implicitHeight` size the card. |

## Rows drawn in QML

When `qml` names a file in the plugin's folder, that file draws the row
inside the launcher's own row: the shell still draws the selection, handles
the click and the keys, and runs the actions. The file's root item declares
`property var row`, and the shell sets it to an object with:

| member | what it is |
|---|---|
| `row.item` | The item as the shell read it: `title`, `subtitle`, `icon`, `actions` and the rest. |
| `row.props` | The item's `props`. |
| `row.selected` | True while the row is selected. |
| `row.preview` | True when the file is drawing the peek card rather than a row. |
| `row.act(id)` | Runs one of the item's actions, the way the actions menu does. With no id it does what Enter does. An id that is not among `actions` is sent to the plugin as an `activate`, so a button in the QML can ask for anything. On a list page the `activate` carries the page's `view` id. |
| `row.copy(text)`, `row.open(target)` | Copy and close, or open a link or absolute path and close. |
| `row.fill(text)` | Replace the query. |
| `row.close()` | Close the launcher. |

While its row is selected, the file can take keys: give the root item a
`function claimKey(event)` that returns `true` for the keys it handled.
It is asked about Left, Right, Enter and any key held with Ctrl or Alt,
before the launcher acts on them; `event.key`, `event.modifiers` and
`event.text` say which. Typing, Escape and moving between rows stay with
the launcher.

The file is given the row's full width and `height` times the row pitch, and
is clipped to it. With `"height": "auto"` the file's own `implicitHeight`
sets the row's height instead, from one row to twelve, and the row follows it
when it changes. It can import the shell's own modules, `qs.config` for
`Appearance` (colours, type, spacing, rounding) and `qs.components` for
`StyledText`, `Icon`, `SquircleRect` and the rest, so a plugin's rows can
look like the shell's. Those modules change with the shell; a plugin that
leans on more than the basics may need to follow them.

```qml
import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var row: null

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.row?.item.title ?? ""
        color: root.row?.selected ? Appearance.colour.text : Appearance.colour.textDim
    }
}
```

The shell compiles each file once, in the background, and draws the row
plainly from `title` and `subtitle` until it is ready. A file that does not
compile leaves its rows plain and writes the error to the plugin's log.
`banditshell plugin dev` reloads the QML along with the program each time a
file is saved. The path must stay inside the plugin's folder; anything else is
refused and logged.

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
its own matcher, so typing never waits on the plugin. Its items take every
field a result does, so they can be tall, carry tags and a preview, and be
drawn in QML. Enter on a row works as for results, with the page's id added to
the `activate`.

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
- In a plain search the shell matches plugin rows itself, on `title` and
  `keywords`, with the same matcher as apps, and shows at most `global.cap` of
  them. A row marked `answer` skips the match.
- You installed a plugin on purpose, so by default its matching rows lead a
  plain search, above apps, commands and settings. Only the launcher's pinned
  answers, such as a sum or a link, stay above them. Settings, Launcher,
  Plugin results changes that: `mixed` ranks plugin rows by how well they
  match, ahead of built-in rows that match as well, and `last` keeps them
  below the launcher's own rows. The setting is `launcher.plugins.rank`.
- While the next answer is on its way, the rows from the last one stay on
  screen, filtered by what is typed now, so the list does not flicker on
  every key. Rows marked `pin` or `answer` belong to the query they
  answered and leave with it.
- Once the list has been on screen for a moment, a late answer never moves
  the selection: plugin rows that arrive after it join above or below, and
  Enter still runs the row that was highlighted. The next key you type
  selects the top row again.

## When things go wrong

A broken plugin costs one row, never the shell.

- A query with no answer after 2 seconds is cancelled and shows nothing from
  the plugin.
- A program that exits is started again on the next query, waiting a little
  longer after each crash. After three crashes in a minute the plugin is
  switched off, and one row says so with a button that opens its log.
  Switching it off and on again in Settings gives it a fresh start.
- Standard error goes to `~/.local/state/banditshell/plugins/<id>.log`.
- A QML file that does not compile, or names a path outside the plugin, is
  logged there once, and its rows are drawn plainly.
- After 10 minutes without a query the program is stopped. The next query
  starts it again. A `background` program is never stopped this way, and
  after a crash it starts again by itself after the same wait.

## What runs where

The program runs on its own, so a slow or crashing program costs its rows and
never the shell. A plugin that ships no QML is drawn entirely by the
launcher's own components and looks like the rest of the shell without trying.

QML is different: it runs inside the shell itself. A QML file that loops
forever freezes the shell until the plugin is removed, and one that reads
files or the network does so as the shell. `banditshell plugin install` lists
every QML file a plugin ships before it asks, and Settings, Launcher, Plugins
switches a plugin off like any other.
