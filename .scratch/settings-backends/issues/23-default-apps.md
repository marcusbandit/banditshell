# Default apps

Status: done

Rows: Apps › Default apps › Web `defBrowser`, Files `defFiles`, Terminal
`defTerm`, Mail `defMail`, Pictures `defImages`, Video `defVideo`. The choices
are a stand-in list today.

## What to build

- Offer the installed apps that handle each type (desktop entries by MIME and
  category).
- Read and write with `xdg-mime query default` / `xdg-mime default` for
  `x-scheme-handler/http(s)`, `inode/directory`, `x-scheme-handler/mailto`,
  `image/*`, `video/*`; the terminal is `xdg-terminal-exec` or the shell's own
  launcher setting.
- The preview's app icons and colours should come from the desktop entries.

## Built

`services/DefaultApps.qml` reads and writes the six defaults; `services/DesktopIndex.qml` reads every installed desktop entry once (name, icon, Exec, MimeType, Categories) with one `awk` pass; `desktop-entries.js` and `default-apps.js` hold the parsing and are tested in node (`tests/desktop-entries.test.js`, `tests/default-apps.test.js`, fixtures in `tests/fixtures/apps`).

- Groups: web is `x-scheme-handler/http` and `https`, files `inode/directory`, mail `x-scheme-handler/mailto`, pictures png, jpeg, webp and gif, video mp4, webm and mkv. A write runs `xdg-mime default` for every type in the group, one at a time (a second write waits for the first, since they edit the same mimeapps.list).
- A row shows the app most of the group's types agree on. When types disagree the row's detail names the strays, like "webp in Zen Browser · gif in Feh".
- Offered apps: entries that declare at least half of the group's types (so one-type Krita entries stay out), hidden-from-menu handlers included, because imv is one and is the user's pictures default. The current default is always offered. The terminal offers the TerminalEmulator category without hidden entries.
- Terminal: the shell has no terminal setting of its own, so there was nothing to keep in step. With `xdg-terminal-exec` installed the choice goes to the top of `~/.config/xdg-terminals.list`; without it (this machine) it is `x-scheme-handler/terminal` through xdg-mime, which is what already says kitty here.
- The values moved out of `planDefaults` into `v()` and `write()`. The old stand-in values are not carried over: "firefox" and "loupe" were never real choices, and applying them would change the user's system silently.
- The preview shows the app's real mark through `DesktopIndex.markFor` (AppIcons, then the entry's own icon, then the category glyph). A desktop entry has no colour, so the tile takes the accent.

Still to check by a person: the Super+Return bind in Hyprland is a hard-coded `foot` in `lua/binds.lua`, so the terminal row does not change it. Icon art was not checked headless: offscreen has no icon theme, so marks fell back to glyphs.
