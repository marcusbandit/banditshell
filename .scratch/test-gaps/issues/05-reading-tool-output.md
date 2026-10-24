# Tests for code that reads another program's output

Status: ready-for-agent
Tier: 2

These break when a tool update changes its output, which nobody notices until
a user reports a wrong number. Capture a real output into `tests/fixtures/`
for each and test against that.

## services/CompositorSync.qml

The `hyprctl` batch parse. Test a full batch, a batch with one option missing
(#106) and a batch with an option in `custom` form. Test the niri config read
too.

## services/Network.qml

`parseQr`, `escapeQr` and `joinQr` move as they are. Test the Wi-Fi QR format
with `;`, `:`, `\` and `"` in the name and password, a hidden network and an
open one. `joinEnterprise` builds on the tested `wifilist.js`; test that a
failed sign-in removes only the profile it made.

## services/Monitors.qml

`parseMode` against real `hyprctl monitors -j` output, including a monitor
that reports no modes.

## services/PenMap.qml

`readMonitors`, `buildCandidates`, `homeFor` and `proposeRegion`. Test the
mapping on one, two and three monitors with mixed scales and a rotated one.

## modules/cheatsheet/CheatSheet.qml

`readBinds` and `sections`: test real `hyprctl binds -j` output, and that
malformed output shows an error instead of "0 binds from hyprctl".
`keyName` upper-cases for the key caps on purpose, unlike `keybind-search.js
keyLabel`, which title-cases launcher rows. Test it in a cheatsheet `.js` file
of its own. A shared key namer would have to live in core; the cheatsheet
package cannot reach into the launcher's.

## services/Media.qml

`rank`, `sourceOf` and `timeLabel`: test which player is shown when several
are open: the one playing, else the last one that played, else nothing. An
idle browser tab is never shown, even when it is the only player.

## services/SystemInfo.qml and services/Files.qml

The `/proc/stat`, `/proc/meminfo` and thermal parses, and the `lsblk` and `df`
parses in Files. Real captures, one test each.
