const PROFILE = "Hotspot";
const MINIMUM_PASSWORD = 8;
const MAXIMUM_PASSWORD = 63;
const BANDS = {
    "2.4 GHz": "bg",
    "5 GHz": "a"
};

function bandCode(label) {
    return BANDS[label] ?? "bg";
}

function bandLabel(code) {
    return code === "a" ? "5 GHz" : "2.4 GHz";
}

function passwordProblem(password) {
    const length = String(password ?? "").length;
    if (length === 0)
        return "";
    if (length < MINIMUM_PASSWORD)
        return `needs ${MINIMUM_PASSWORD} characters or more`;
    if (length > MAXIMUM_PASSWORD)
        return `${MAXIMUM_PASSWORD} characters at most`;
    return "";
}

function capabilities(text) {
    const found = {};
    for (const line of String(text ?? "").split("\n")) {
        const cut = line.indexOf(":");
        if (cut > 0)
            found[line.slice(0, cut)] = line.slice(cut + 1).trim() === "yes";
    }
    return {
        accessPoint: !!found["WIFI-PROPERTIES.AP"],
        fiveGigahertz: !!found["WIFI-PROPERTIES.5GHZ"]
    };
}

function blocker(facts) {
    if (!facts.hasDevice)
        return "no wi-fi adapter";
    if (facts.capabilitiesKnown && !facts.accessPoint)
        return "this adapter cannot host a hotspot";
    if (!facts.radioOn)
        return "turn wi-fi on first";
    if (facts.capabilitiesKnown && facts.band === "5 GHz" && !facts.fiveGigahertz)
        return "this adapter has no 5 GHz band";
    if (!facts.ssid)
        return "give it a name first";
    if (!facts.password && !facts.profileExists)
        return "give it a password first";
    return passwordProblem(facts.password);
}

function editCommands(profile) {
    const args = ["nmcli", "connection", "modify", "id", PROFILE, "802-11-wireless.ssid", profile.ssid, "802-11-wireless.band", bandCode(profile.band)];
    if (profile.password)
        args.push("802-11-wireless-security.psk", profile.password);
    return [args];
}

function startCommands(profile, profileExists) {
    if (!profileExists)
        return [["nmcli", "device", "wifi", "hotspot", "ifname", profile.device, "ssid", profile.ssid, "password", profile.password, "band", bandCode(profile.band)]];
    return editCommands(profile).concat([["nmcli", "--wait", "30", "connection", "up", "id", PROFILE, "ifname", profile.device]]);
}

function stopCommands() {
    return [["nmcli", "connection", "down", "id", PROFILE]];
}

function restartCommands(profile) {
    return editCommands(profile).concat([["nmcli", "connection", "down", "id", PROFILE], ["nmcli", "--wait", "30", "connection", "up", "id", PROFILE, "ifname", profile.device]]);
}

function readProfile(fields) {
    return {
        ssid: fields["802-11-wireless.ssid"] ?? "",
        band: bandLabel(fields["802-11-wireless.band"]),
        password: fields["802-11-wireless-security.psk"] ?? ""
    };
}

function countClients(text) {
    const seen = new Set();
    for (const line of String(text ?? "").split("\n")) {
        const station = line.match(/^Station ([0-9a-f]{2}(?::[0-9a-f]{2}){5})/i);
        if (station) {
            seen.add(station[1].toLowerCase());
            continue;
        }
        const neighbour = line.match(/\blladdr ([0-9a-f]{2}(?::[0-9a-f]{2}){5}) (REACHABLE|STALE|DELAY|PROBE|PERMANENT)\b/i);
        if (neighbour)
            seen.add(neighbour[1].toLowerCase());
    }
    return seen.size;
}

function clientsLabel(count) {
    return count === 1 ? "1 device" : `${count} devices`;
}

function explainFailure(message) {
    const said = String(message ?? "");
    if (/not authorized|insufficient privileges|permission denied/i.test(said))
        return "you are not allowed to start it";
    if (/no suitable device|device .* not found|no wi-?fi device|unknown device/i.test(said))
        return "there is no wi-fi adapter to use";
    if (/not supported|access point|ap mode|hotspot.*not/i.test(said))
        return "this adapter cannot host a hotspot";
    if (/timeout|timed out/i.test(said))
        return "it took too long to start";
    if (/password|psk|passphrase|wpa/i.test(said))
        return "NetworkManager did not like that password";
    return "NetworkManager would not start it";
}
