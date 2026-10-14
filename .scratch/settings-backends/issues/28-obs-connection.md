# OBS connection fields

Status: needs-triage

Rows: Apps › Capture › OBS › Address, Password. They show what OBS's
obs-websocket config holds and cannot be edited, because the shell reads OBS's
own file.

## What to build

- Decide whether the shell may write OBS's `plugin_config/obs-websocket/config.json`
  (only while OBS is closed), or keep its own override for host, port and
  password in config.
