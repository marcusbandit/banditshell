# VPN tunnels

Status: ready-for-agent

Rows: Connections › Hotspot and VPN › Tunnels (switch per tunnel),
Add a tunnel (Import). The panel already lists NetworkManager's vpn and wireguard
connections, read-only.

## What to build

- Switches: `nmcli connection up|down <name>`, and read the active state live.
- Import: `nmcli connection import type wireguard|openvpn file <path>`, from a
  path field (the layer shell has no file dialog).
- The VPN tile on the Connections hub drives the first tunnel.
