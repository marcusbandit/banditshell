# VPN tunnels

Status: done

Rows: Connections › Hotspot and VPN › Tunnels (switch per tunnel),
Add a tunnel (Import). The panel already lists NetworkManager's vpn and wireguard
connections, read-only.

## What to build

- Switches: `nmcli connection up|down <name>`, and read the active state live.
- Import: `nmcli connection import type wireguard|openvpn file <path>`, from a
  path field (the layer shell has no file dialog).
- The VPN tile on the Connections hub drives the first tunnel.

## Built

- `services/Tunnels.qml` lists NetworkManager's `vpn` and `wireguard` connections with their live state, and switches them with `nmcli connection up|down uuid <uuid>` (by uuid so two tunnels with one name stay apart). Parsing and commands are in `services/tunnels.js`, tested in `tests/network.test.js`. Switches queue one at a time, show "connecting" or "disconnecting" while they run, and a failure shows in plain words under the tunnel until the next try. State refreshes on `nmcli monitor` events through `services/NetworkEvents.qml`.
- Import lives in the Tunnels widget, as an "Add a tunnel" row with a path field and an Import button (a `~` path works). The type comes from the extension: `.conf` is wireguard, `.ovpn` is openvpn, anything else is refused before nmcli is called. Failures are reported in plain words under the row, and a success clears the field and drops a toast. The separate catalogue button row and `vpnImport` action in SettingsActions are gone; `later` stays because other rows use it.
- `tunnels` left `planDefaults`; a planned list in an old settings.json is dropped on load. `tunnelCount` and `vpnOn` read the live list.
- The VPN tile on the Connections hub reads "any tunnel is on". Turning it on brings up the first tunnel; turning it off takes down every tunnel that is up, so it can never claim "on" with nothing it can switch off.

Still to check by hand: a real import of a `.conf` and an `.ovpn`, a real up and down, and the wording of the nmcli error patterns (written from nmcli's documented messages, not captured, since nothing that changes the network was run). OpenVPN tunnels that need a password cannot ask for one from here, and say so.
