# Script commands

The launcher runs your own scripts from `~/.config/banditshell/scripts/`
(Settings, Launcher, Power tools, Scripts folder). Type a script's title to
run it; words typed after the title become its arguments. Typing `scripts`
lists them all, and when the folder does not exist yet, the Create a script
command row makes it and copies the two examples here into it.

## Headers

Headers are comment lines near the top of the file. The Raycast names work
as they do in Raycast:

    # @raycast.title Say
    # @raycast.mode compact
    # @raycast.icon 💬
    # @raycast.packageName Speech
    # @raycast.argument1 { "type": "text", "placeholder": "words" }

`mode` is `silent` (runs in the background and closes the launcher),
`compact` (the last line it prints shows in the row), `fullOutput` (every
line shows as a row) or `list`. Without a title the file name is used.

## List scripts

A list script returns results for the launcher to show, the way an Alfred
script filter does. Opt in with:

    # @banditshell.mode list

Type the title and some words: the launcher waits for you to stop typing,
runs the script with those words as arguments, and stops it after 5
seconds. The script prints JSON on standard output:

    {"items": [
        {"title": "Shown in the row", "subtitle": "beside it",
         "arg": "value", "icon": "🎨",
         "url": "https://example.org", "copy": "text to copy",
         "type": "file"}
    ]}

Only `title` is required. `icon` is an emoji, a Material Symbols name such
as `folder`, or an image path (relative paths start at the script's
folder). At most 50 items show. Enter on an item:

- runs the script again as `script --select <arg>` when it declares
  `# @banditshell.onSelect run`,
- otherwise opens `url`, copies `copy`, or opens `arg` as a file when
  `type` is `file`,
- and copies `arg` when none of those are set.

An item with `"valid": false` does nothing on Enter, unless it has an
`autocomplete` value: then Enter and Tab type the title followed by it,
so a script can lead into a narrower list. When the script exits with an
error or prints something that is not JSON, the first line of its error
output shows as a row.

`unicode.py` here is a complete list script: `unicode arrow` lists arrow
characters and Enter copies one.
