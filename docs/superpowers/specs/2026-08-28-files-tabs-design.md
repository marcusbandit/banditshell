# The file browser, part two: tabs, panes, and a terminal that follows them

> Agreed 2026-08-28 by interview. This is the design, not the plan. Nothing in
> here has been built.

The browser works: it lists, previews, selects, drags, renames, deletes and has a
real shell in it. What it does not have is the thing that makes a file manager a
place you work rather than a place you look — two folders at once, and a terminal
that knows which one you mean.

Everything below is sequenced behind that, because tabs change what "the current
directory" and "the session" mean, and every feature written against the
single-session model would have to be written twice.

---

## 1. The model: tabs, panes, windows, tmux

**A tab is a place you are. A pane is a view onto one.** A tab holds one or more
panes; a pane has its own directory, its own selection, its own history and its
own shell.

The mapping to tmux is the whole design:

```
browser tab   <->  tmux window
browser pane  <->  tmux pane      (vertical splits only, for now)
```

**Eager, and both ways.** A new browser tab creates its tmux window at once and
switches tmux to it, whether or not the terminal panel is visible — the panel
being hidden does not mean the session is not running. A window created from
inside tmux (`C-Space c`) grows a browser tab to match.

Two-way is the expensive choice and it was made deliberately: the alternative is
a browser that ignores half of what you do to the thing it is showing you. The
cost is reconciliation, and the rule that keeps it safe is the one this project
already uses twice - act only on what is provably ours.

Closing a tmux window closes its browser tab, and closing a browser tab kills its
tmux window. Confirmed, not assumed.

### Splitting

A split is made by right-clicking, or by dragging from a pane's upper-right
corner the way Blender does it. It stays inside the current tab and creates a
tmux pane in that tab's window.

**Both panes start on the same directory** and are free to diverge. A **Link**
button at the top ties them back together: linked panes always show the same
directory, and may still differ in sort and view mode. Dragging works between
panes whatever they are showing, including when they are showing the same folder
- there is no reason to forbid it and a rule that fires only sometimes is worse
than no rule.

Horizontal splits are deliberately out of scope. Later, if ever.

### Which shell the terminal shows

The focused pane's. That is the whole of it, and it is why this rework comes
first: "the shell owns the directory" becomes a per-pane fact, and every command
the browser generates has to go to the right one.

---

## 2. tmux

**A soft dependency.** With tmux, the terminal follows your tabs. Without it, the
browser still has tabs and each still gets its own shell - you lose the mapping,
not the window. A file browser that will not open on a minimal box is not a file
browser. The installer offers to install tmux, defaulting to yes on Enter.

### Adoption

Your `.zshrc` starts tmux inside our pty. We take that session over rather than
starting a second one beside it - but only when it is provably fresh:

1. Is tmux running, started by the shell we spawned?
2. Is it EMPTY - one pane, nothing running in it, nothing typed, a name that is
   the automatic numeric one rather than a name somebody chose?

Empty means it is ours whether it was created or attached, because there is
nothing in it to lose. Not empty means somebody's work: **detach and create our
own.** All of this happens when the browser opens, before the terminal is ever
reached, so the answer is settled before it matters.

Adopted or created, the session is renamed to something we control.

### When the session dies underneath us

Killing a tmux window closes its browser tab; killing a pane closes its browser
pane. Whatever tmux focuses next is what the browser follows, so the redirection
handles itself.

**Killing the whole session does not kill the browser.** It starts a fresh
session and lands you in the home directory - the window is not a view of a
particular shell, it is a file browser that has one.

### Ending it

**Closing the browser kills the session, and everything in it.** No survival
across closes: a new open is a new session. Two conditions guard the kill, both
required - we created or adopted it, *and* no other client is attached.

A "prompt before terminating tmux" toggle exists and defaults to **off**. Once
the session is one we named and own, a confirmation is a dialogue with yourself.

### Showing and hiding the panel

**It slides. It is not squashed.** The panel keeps its height and is clipped as
it moves; the terminal's row count never changes while it animates. Resizing the
grid mid-animation makes the shell re-flow its output, which mangles anything
formatted in columns and looks jarring on the way past.

---

## 3. File operations

### Collisions

Checked BEFORE anything runs, against the destination listing the browser
already has, and asked in the browser's own dialog: **Overwrite / Keep both /
Skip / Cancel**, with an apply-to-all for multi-file operations.

Not `mv -i`. That prompt appears in the terminal panel, which may be shut, and
a drop onto a folder with a same-named file wedges the shell invisibly with
every later command queued behind it. This was a real bug, found by testing it.

### Progress, and which tool does the work

**Anything the GUI does uses rsync.** Not a threshold, not a prompt, not a
measurement - a drag, a paste or a menu copy is always
`rsync --info=progress2`, which means it always has a real percentage and always
survives being interrupted. `cp` is what YOU type when you want `cp`; it is not
what the interface reaches for.

**With one exception, and it is not a preference.** A move inside one filesystem
is a rename: the kernel changes one directory entry and no data is touched, which
is why dragging a 40GB folder across your home directory is instant. rsync cannot
do that - it would copy every byte and delete the original, turning an
instantaneous operation into a twenty-minute one. So:

- **Copy** - always rsync.
- **Move, same filesystem** - `mv`. Instant, and there is no progress to report
  because there is no work to do.
- **Move, across filesystems** - rsync with `--remove-source-files`. A cross-device
  move is a copy-and-delete however it is spelled, and there rsync's progress and
  its resumability are worth having.

Same-filesystem is decided by comparing the device id of the source and the
destination, which the lister already has to hand.

### Undo

One level, on Ctrl+Z. Undoable: **moves, renames, permission changes, copies and
paste-after-cut** - everything with an exact inverse.

Deletion is a policy, not a mechanism:

- Trash or permanent delete is a **config toggle**.
- Undoing a permanent delete is impossible, and says so: *"the last delete cannot
  be undone - the file is gone. Turn on the trash in settings to keep deleted
  files."*
- Switching the toggle to permanent while a bin exists prompts to empty it.
- Deleting occasionally reminds you the bin is still there and offers to empty
  it.

---

## 4. The sidebar

Two sections: **Pins** and **Drives**. No "Places" - the XDG directories ship as
ordinary pins you can unpin like any other.

Seeded on the **absolute first run** and never again. The pin list lives in its
own file, which records what is pinned; after that, changes to the shipped
defaults do nothing on their own. Settings keeps two actions: **append the
defaults** (leaves your pins alone) and **reset to defaults**.

Any folder can be pinned from its context menu. Drives keep their fill bars.

---

## 5. Search

`/` searches the current folder. `//` searches recursively, **within the current
folder only**. A toggle in the field shows which one is live, so you cannot be
searching recursively without knowing it.

Recursive search shells out to `fd`, which respects `.gitignore` - worth knowing,
because a search inside a repository will skip `node_modules` by default.

---

## 6. Tests

`node --test` over `tests/*.test.js`, run by a `banditshell test` verb. No
dependencies; node is already required by nothing else here, so this adds one
tool the machine already has.

In scope from the start: `components/vt.js`, `components/base64.js`,
`modules/files/marks.js`, and the sort comparator and `humanSize` / `humanTime` /
`humanMode` helpers - which must first be **pulled out of `Files.qml` into plain
JavaScript**, because logic that cannot be reached without a running compositor
is logic that never gets tested.

This is a standing rule for the project, not a one-off: pure logic goes in `.js`
where it can be tested, and QML keeps the drawing. It goes in `CLAUDE.md` and
`DESIGN.md`.

A UI smoke test comes later, if hand-verification keeps missing regressions. Four
of the bugs in the last session were regressions in code already verified by
hand.

---

## 7. Smaller, agreed

- **Thumbnail cache.** Currently every folder re-decodes every picture.
- **Sortable columns** in list view, and the view controls (icons/list, sort,
  hidden) as **buttons in the top bar** rather than chords only.
- **Image preview** gains zoom and step-to-next.
- **Git status colouring** inside a repository, behind a settings toggle.
- **Drag-out** exports the whole selection, as `text/uri-list` plus
  newline-joined paths as `text/plain`. To be tested against Dolphin, kitty and
  a browser upload field before it is called done.

## 8. Prepared for, not built

- **Open with…** - a chooser rather than bare `xdg-open`. The menu entry and the
  service call get a seam; the chooser itself waits.
- Horizontal splits.
- Tab reordering.

---

## 9. The wire, so both halves can be built at once

`src/bs-pty.c` grows three frames, and the QML is written against them rather
than against a running helper:

```
out   t <base64>   the tmux session this pty is using, once it is settled
      w <base64>   the window list, as "id\tname\tactive" lines, when it changes
in    k            kill the session (used on close)
```

The adoption dance - is tmux running, is it empty, adopt or start our own,
rename - happens inside the helper when the pty starts, and `t` is how the
browser learns the answer. `w` is what makes the mapping two-way: the browser
mirrors that list rather than polling tmux itself.

---

*Decisions taken by me where they were delegated: the collision dialog's shape
and the test runner. The rsync exception for same-filesystem moves is mine and is
a correction rather than a choice - say so if you would rather have it uniform.*
