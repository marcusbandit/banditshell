---
title: v0.3.0, the small things
date: 2026-11-07
release: v0.3.0
summary: v0.3.0 brings desktop widgets, a floating Settings window and launcher answers without an API key. It also fixes the 310 rough edges I found going through the whole shell, from the launcher and Files to the island, the clock and the sidebar.
---

Early in November I sat down with the shell and went through it screen by screen. I opened every menu, pressed every key I could think of and wrote down each thing that was off. A label cut in half. A key that did nothing. A row that said "charging" on a full battery.

That came to 310 issues, numbered #455 to #764 on GitHub. None of them is a feature. Together they decide whether the shell feels finished, so v0.3.0 is the release where I fixed them.

A few real features landed first, so they come first here.

## Two things to do after updating

The launcher's Claude answers now run through Claude Code instead of an Anthropic API key. If you used them, the launcher asks you to sign in to Claude Code the first time you ask something. The key in Settings no longer does anything for Claude (#444).

The clipboard panel searches as soon as you type. That took over the one-letter commands it used before: pin is now Ctrl+P, and Ctrl+J and Ctrl+K step down and up the list.

## New since v0.2.0

Settings is its own window now. It floats in the middle of the screen, you drag its top edge to move it, and it opens on a Home page with shortcuts to the things people change first. Every setting has a line under its name that says what it does (#435).

The desktop got widgets: the time and date, a month calendar, what is playing, the weather, processor and memory load, and quick timers. Settings, Desktop, Widgets turns each card on or off and picks the side of the screen.

![The desktop with Settings open in the middle and the widget column on the right](/images/blog-desktop.webp "Settings floating over the desktop, with the widget column on the right.")

The launcher can answer questions through Claude Code or Codex, on the plan you already pay for, with no API key to paste. Type `ask` and a question. The answer streams in, and Copy and Continue in chat sit under it (#444).

![The launcher answering a question through Claude Code](/images/blog-ask.webp "An answer from Claude Code, right in the launcher.")

Plugins can draw richer rows: taller ones, tags, a preview, or their own QML. Their results lead your searches, and Settings can move them back down (#439, #442).

## The launcher

Type `build.sh` and the launcher used to put an "Open build.sh" link above the file. It treated the name as a web address. Now it waits for the file search to answer, and the file comes first (#455).

![The launcher after typing build.sh, before on the left and after on the right](/images/blog-launcher.webp "Typing build.sh. On the right the file is the first row and the link sits below it.")

Aliases now work on rows from your snippets, scripts, SSH hosts, quicklinks and emoji, not only apps. If you give a row an alias that another row already owns, the launcher tells you who has it and does not save it (#460).

`kill` and everything in `top` ask for a second Enter before they end a process, the same way Ports does (#461). Command output keeps all forty lines and ends in an "N more lines" row, where Enter copies the lot (#464).

The rest is smaller. A row's name keeps its room and the description gives way (#459). The preview card shrinks to fit instead of vanishing on screens under 2100 pixels (#456). Ctrl+K opens the actions sheet for a row (#458).

## Files

Files got the most attention, because a file manager is where small flaws add up fastest.

Names now sort by number. `img2` comes before `img10`. Before, `img10` and `img11` jumped ahead of it (#634).

![The Files grid before on the left and after on the right, with img2 and img3 now in order](/images/blog-sorting.webp "The same folder, sorted by name. Left is before, right is after.")

A copy keeps the original modified time, so a copy and a move agree about which file is newer. A long copy shows its progress and a Stop button.

Ctrl+C and Ctrl+V work with other apps now. Copy a file in Files and paste it elsewhere, or copy one elsewhere and paste it into Files. You can also drag files in from other apps.

Drives refresh the moment you plug one in. The Open with menu lists the apps that can really open the file. Properties on a folder shows its real size instead of the 4 kB of the folder entry. Ctrl+F searches and Ctrl+H shows hidden files. A folder that no longer exists says so and offers a way out.

The terminal pane also stops swallowing keys. tmux's Ctrl+B and the Alt+arrow word jumps reach your shell again.

## The island and notifications

A notification that gets replaced with new text now pops up again. Before, the change slipped in unseen (#506).

"Remind me" survives a restart. If the reminder came due while the shell was off, it shows once when the shell starts (#507). A newer popup never pushes a critical alert off the screen (#509).

When a fullscreen window covers the island, notifications wait. Afterwards the island says how many it held and one press opens them (#513).

The island itself had a handful of quirks. Dictation no longer makes it announce "Microphone on" a second time. Timed rows pause while your pointer rests on the island. The screenshot row's Delete has an Undo that brings the file back from the trash. Labels stop at the edge of their row.

## Clock, calendar and weather

The clock menu names things now. Timers and alarms show the name you gave them, and the alarm editor has a name field. Remove a timer, an alarm or a place and an Undo bar sits at the top for six seconds.

![The clock menu with named timers, an alarm and two cities](/images/blog-clock.webp "The clock menu. Timers and alarms carry their names.")

When a list is full, the button says why. "8 timers is the most, remove one" beats a button that quietly does nothing. You can click a time field and type the digits. Adding a city takes "new york" or "hong kong" as typed.

The calendar has month buttons next to its heading. A new setting picks the first day of the week, and another turns on week numbers (#529). The desktop weather card fetches on its own, and the forecast view in the island says where its town came from.

## The sidebar and the rail

The workspace column grows for a busy workspace and shrinks again when it empties. One wheel notch moves one workspace. A click on a plate switches to it, and a short sideways drag no longer eats the click (#767).

![The rail's workspace dots before on the left and after on the right](/images/blog-rail.webp "The workspace dots on the rail. Each one now owns a slot 24 pixels tall.")

Every workspace mark owns a slot at least 24 pixels tall, so the dots are easy to hit. Tray icons name their app on hover, and the icons past your limit sit behind a "+N" slot that lists them. The update mark on the rail follows every real state, and VPN and Keep awake have marks of their own.

Hovering the folded sidebar unfolds it, its workspace marks included, and right-clicking it opens a small menu with Sidebar settings and Fold. The folded clock sits at the foot with the date under it (#794, #799).

## Wi-Fi, Bluetooth and power

Bluetooth lists every paired and nearby device, and pairing a keyboard or a phone works from the menu. It shows the code to type or the number to confirm.

You can join a hidden Wi-Fi network from the menu, from Settings and from a QR code. The Wi-Fi password field has a show button, and every password field warns you when Caps Lock is on. Forget needs a second press, so a stray click cannot drop a saved network.

The battery menu stopped fibbing. A full battery says "full". One held at its limit says "plugged in, held at 80%". If your machine has a power profile daemon, the menu has a row for saver, balanced and fast.

## Clipboard and Settings

Enter on a clipboard entry pastes it into the window you came from, terminals included. Deleting an entry has an Undo, and Ctrl+Z puts it back where it was.

Text that looks like a secret no longer lands in the history file, and unless you pin it, it drops out of the panel after five minutes.

Settings opens its list when you search while the list is folded. Holding a stepper button repeats it. A page with changed rows has a reset button in its header, and the toast that follows offers Undo.

## Trying it

The update menu offers v0.3.0 now. If you follow `main`, all of this is already on your machine.

Something still wrong? Open an [issue](https://github.com/marcusbandit/banditshell/issues).
