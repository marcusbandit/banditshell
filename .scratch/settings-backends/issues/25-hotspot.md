# Hotspot

Status: ready-for-agent

Rows: Connections › Hotspot and VPN › Share this connection `hotspot`, Name
`hotspotName`, Password `hotspotPass`, Band `hotspotBand`. The Connections hub
has a Hotspot tile.

## What to build

- `services/Network.qml`: `nmcli device wifi hotspot ifname <dev> ssid <name>
  password <pass> band bg|a`, and `nmcli connection down Hotspot` to stop.
- Show the number of devices on it (`iw dev <dev> station dump`).
- Wi-Fi stops joining networks while it runs (the row says so).
