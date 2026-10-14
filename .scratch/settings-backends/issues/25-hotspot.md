# Hotspot

Status: done

Rows: Connections › Hotspot and VPN › Share this connection `hotspot`, Name
`hotspotName`, Password `hotspotPass`, Band `hotspotBand`. The Connections hub
has a Hotspot tile.

## What to build

- `services/Network.qml`: `nmcli device wifi hotspot ifname <dev> ssid <name>
  password <pass> band bg|a`, and `nmcli connection down Hotspot` to stop.
- Show the number of devices on it (`iw dev <dev> station dump`).
- Wi-Fi stops joining networks while it runs (the row says so).

## Built

- `services/Hotspot.qml` owns it; the parsing and command building live in `services/hotspot.js` (tests in `tests/network.test.js`, fixtures in `tests/fixtures/network/`). `services/nmcli.js` splits terse nmcli output, `services/NetworkEvents.qml` runs `nmcli monitor` so the state stays live, and `components/CommandQueue.qml` runs nmcli commands one after another and hands back stderr.
- NetworkManager is the source of truth. The name, band and password are read back from the "Hotspot" profile (`nmcli -s`), and edits are written to it with `nmcli connection modify`. Nothing about the hotspot, the password least of all, is in config.json or settings.json; `hotspot`, `hotspotName`, `hotspotPass`, `hotspotBand` left `planDefaults`, and old planned copies (including a stored password) are dropped from settings.json on load.
- Start: no saved profile runs `nmcli device wifi hotspot ifname <dev> ssid <name> password <pass> band bg|a`; with a profile it modifies it then runs `nmcli connection up`, so repeated starts do not pile up duplicate profiles. Stop is `nmcli connection down id Hotspot`. Editing while it runs restarts it after a 1.5 s pause so the new details take hold.
- Before a profile exists, the typed name, password and band are held in the shell's memory only and used at the first start.
- The row stays off with a reason when there is no Wi-Fi device, the adapter has no AP mode (`nmcli device show`, WIFI-PROPERTIES.AP), 5 GHz is picked on an adapter without it, Wi-Fi is off, or the name or password is missing. A password under 8 characters (or over 63) shows its reason under the Password row, and the dots turn the alarm colour as the secret field does. The Connections tile carries the same detail and is disabled for the same reasons.
- Device count: `iw` is not installed on this machine, so it falls back to `ip neigh show dev <dev>` (readable without root, one device per link-layer address, live states only). The dnsmasq lease file under /var/lib/NetworkManager is root-only here, so it is not used. Refreshes every 5 s while the hotspot is on.
- The Wi-Fi page: while the hotspot runs, the network list is replaced by "wi-fi is running your hotspot" with a Stop it button, and the page status, toggle detail, tile and Connections blurb say so.

Still to check by hand: an actual start and stop with a real adapter and a phone (nothing that changes the live network was run while building), that `iw station dump` is used and counts the same where `iw` is installed, and that `nmcli -s` can read the saved password without a prompt.
