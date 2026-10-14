# Default apps

Status: ready-for-agent

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
