# OBS connection fields

Status: done

Rows: Apps › Capture › OBS › Address, Password. They show what OBS's
obs-websocket config holds and cannot be edited, because the shell reads OBS's
own file.

## What to build

- Decide whether the shell may write OBS's `plugin_config/obs-websocket/config.json`
  (only while OBS is closed), or keep its own override for host, port and
  password in config.

## Built

Decision: the shell never writes OBS's own file. A new `obs` object in config
(`host`, `port`, `password`, all empty or 0 by default) overrides what is read
from obs-websocket's config; empty means "read from OBS", as before.
`services/obs.js` has `address()` (parses `host`, `host:port`, `[::1]:port`,
`ws://` forms, a bare port, or empty to clear) and `endpoint()` (merges the
override with OBS's file and says where each part came from). `Obs.qml` connects
to that endpoint, reconnects when the url or password changes, and no longer
needs OBS's local file to say the server is on when a host is set here.

In the widget, Address is a text field and Password a secret field; details say
"from obs" or "set here · clear it to follow obs". A bad address says why in a
toast and puts the field back. The password commits on enter or when the field
loses focus, not on every key. The export strips `obs.password` (see ticket 27).

To check by hand: connect to a real OBS on another machine, and see the
"refused" state clear after typing the right password.
