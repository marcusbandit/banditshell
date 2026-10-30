# Launcher sources

The launcher builds a few groups itself: apps, commands, settings, windows,
devices, processes, files, the clock and the `bandit` command line. Every
other row comes from a source. A source is a `QtObject` that reads what was typed and answers with
groups of rows. `LauncherSearch` merges the groups of every source, ranks them
and carries out what the person picks. Ranking, the actions menu, learned
usage, aliases, hotkeys, Tab completion, the `?` page and
`banditshell panel launcher run <id>` all go through the members below, so a
new source gets every one of them by filling in this contract.

`tests/launcher-source-contract.test.js` holds the same list. It fails when a
source misses a required member, when `LauncherSearch` starts reading a member
this page does not describe, or when two sources claim the same kind.

## Where sources come from

`LauncherSearch.builtIn` lists the sources that ship with the shell, one
object per source, each handed `search`, the `LauncherSearch` it belongs to.
`LauncherSearch.sources` is that list followed by the sources added while the
shell runs.

To add one at runtime, register a `Component` with the `LauncherSources`
singleton:

```qml
LauncherSources.add("plugin:jira", pluginSource, { plugin: manifest })
LauncherSources.remove("plugin:jira")
```

Every `LauncherSearch` makes its own object from the component, passing the
given properties and its own `search`, and destroys it on `remove`. There is
more than one `LauncherSearch`, so anything that must exist once, such as a
plugin's process, lives in a singleton the source reads. Adding under an id
that is already there replaces the old source. A source added this way cannot
take a kind another source owns, and its `caps` only fill in group keys
nobody else capped; the launcher refuses it with a warning in the log
instead. The launcher itself never learns where a source came from.

## Members

`search` is the one member every source has. A source that shows rows of its
own also needs the four marked rows, together. A source can be all optional
members instead: `WorkshopSource` only adds commands.

| member | required | type | what the launcher does with it |
|---|---|---|---|
| `search` | yes | `required property var` | Set by the launcher. The source reads the query and calls back through it, see below. |
| `kinds` | rows | list of strings | The row kinds this source owns. A row whose `kind` is listed here is routed back to this source for Enter, the actions menu and Tab. Kinds are unique across all sources. |
| `groups` | rows | list of groups | The rows to show for the current query, see Groups. |
| `activate(row)` | rows | function | Enter on one of its rows. |
| `actionsFor(row)` | rows | function | The actions menu for one of its rows: a list of actions, the first one being what Enter does. |
| `intent` | no | bool | True when the query is clearly meant for this source, such as a prefix word. Content search and the closest-match guess stand down while any source has intent. |
| `alone` | no | bool | True when this source takes the whole list, like the `?` page. Only its groups show. |
| `caps` | no | object | Row limits per group key, merged over the launcher's own. A group with no cap shows every row. |
| `commands` | no | list of commands | Commands added to the Commands group, in the shape of the launcher's own (`id`, `icon`, `label`, `words`, `run`). |
| `prefixes` | no | list | Entries for the `?` page: `section`, `word`, `example`, `about`, `icon`, `also`. |
| `phrases` | no | list | Tab completion for phrases: `head` is the typed start, `picks` the words that can follow it. |
| `rowById(id)` | no | function | Rebuilds a row from its key without a query. Rows a source can rebuild can be run by id, get aliases and get hotkeys. |
| `complete(row)` | no | function | Tab on one of its rows. Returns true when it handled it, usually by retyping the query through `search.retype`. |
| `confirmActionsFor(row)` | no | function | The choices shown while one of its rows is armed and waiting for a second Enter. The launcher adds Cancel. |
| `listsWifi` | no | bool | True while this source shows networks itself, so the plain search leaves them out. |

## Groups

A group is `{ key, title, items, note }`. `items` are rows. The launcher drops
empty groups, sorts the rest by their best row's score and keeps the order of
rows inside a group as the source gave it, after learned usage lifts rows the
person picks often. A group with more than one row shown gets a header with
its `title`, and `note` is added to that header.

## Rows

| field | meaning |
|---|---|
| `key` | Stable and unique. It is the row's id for `run <id>`, aliases, hotkeys and learned usage. Prefix it with the kind, as in `script:hello.sh`. |
| `kind` | One of the source's `kinds`. |
| `label` | The row's title. |
| `detail` | The second line, or an empty string. |
| `icon` | A Material Symbols name. |
| `glyph` | An emoji or short text drawn in place of the icon. |
| `iconSource` | An image drawn in place of the icon. |
| `score` | Where the row ranks. `Infinity` pins it to the top; for typed words use the scale in `services/ranking.js` (4 exact, 3 prefix, 2 word start, 1 anywhere). |
| `faded` | Draws the row dimmed, for rows still waiting on something. |
| `toggle` | A bool that draws a switch at the end of the row. |
| `slider` | A slider drawn in the row. |
| `peekPath`, `peekText`, `peekImage`, `peekColour` | What the peek card beside the list shows for the row. |

A source may put anything else it needs on its rows, such as the object the
row stands for. The launcher passes the row back unchanged.

## What a source may use from search

| member | what it is |
|---|---|
| `text`, `query` | The query trimmed, and as typed. |
| `started` | True once the person has typed anything since the launcher opened. |
| `active` | False while the launcher is closed. |
| `screenName` | The screen the launcher is on. |
| `armed` | The key of the row waiting for a second Enter, or an empty string. A source arms a row by setting it. |
| `leave(fn)` | Close the launcher, then run `fn`. |
| `launch(fn)` | Close the launcher, run `fn` and let the next window that opens take focus. |
| `retype(text)` | Replace the query. |
| `copyText(text)` | Copy and close. |
| `present(view)`, `presents` | Open a full page in place of the list, where the launcher supports it. |
| `inquire(row)` | Ask the launcher to take a line of text for a row, the way the notification reply does. |
| `windowTarget()` | The window the launcher's window commands act on. |
