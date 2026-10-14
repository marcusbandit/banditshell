const PROFILE = "banditshell hotspot";
const LEGACY_PROFILE = "Hotspot";
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

function oneLine(value) {
    return String(value ?? "").replace(/[\r\n]+/g, " ");
}

function newUuid() {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, mark => {
        const digit = Math.floor(Math.random() * 16);
        return (mark === "x" ? digit : (digit & 3) | 8).toString(16);
    });
}

function passwordCommand(uuid, password) {
    return {
        command: ["nmcli", "connection", "edit", "uuid", uuid],
        input: `set wifi-sec.psk ${oneLine(password)}\nsave\nquit\n`
    };
}

function editCommands(profile) {
    const commands = [["nmcli", "connection", "modify", "uuid", profile.uuid, "802-11-wireless.ssid", profile.ssid, "802-11-wireless.band", bandCode(profile.band)]];
    if (profile.password)
        commands.push(passwordCommand(profile.uuid, profile.password));
    return commands;
}

function createCommands(profile) {
    return [
        ["nmcli", "connection", "add", "type", "wifi", "con-name", PROFILE, "connection.uuid", profile.uuid, "ifname", profile.device, "ssid", profile.ssid, "connection.autoconnect", "no", "802-11-wireless.mode", "ap", "802-11-wireless.band", bandCode(profile.band), "ipv4.method", "shared", "ipv6.method", "shared", "wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.proto", "rsn", "wifi-sec.pairwise", "ccmp", "wifi-sec.group", "ccmp"],
        passwordCommand(profile.uuid, profile.password)
    ];
}

function upCommand(profile) {
    return ["nmcli", "--wait", "30", "connection", "up", "uuid", profile.uuid, "ifname", profile.device];
}

function startCommands(profile, profileExists) {
    return (profileExists ? editCommands(profile) : createCommands(profile)).concat([upCommand(profile)]);
}

function stopCommands(uuid) {
    return [["nmcli", "connection", "down", "uuid", uuid]];
}

function restartCommands(profile) {
    return editCommands(profile).concat([["nmcli", "connection", "down", "uuid", profile.uuid], upCommand(profile)]);
}

function candidates(connections) {
    return connections
        .filter(connection => connection.type === "802-11-wireless" && (connection.name === PROFILE || connection.name === LEGACY_PROFILE))
        .sort((a, b) => (a.name === PROFILE ? 0 : 1) - (b.name === PROFILE ? 0 : 1));
}

function readingCommand(uuids) {
    const script = 'for uuid in "$@"; do echo "uuid:$uuid"; nmcli -s -t -e no -f 802-11-wireless.mode,802-11-wireless.ssid,802-11-wireless.band,802-11-wireless-security.psk connection show uuid "$uuid"; done';
    return ["sh", "-c", script, "sh"].concat(uuids);
}

function readProfile(fields) {
    return {
        ssid: fields["802-11-wireless.ssid"] ?? "",
        band: bandLabel(fields["802-11-wireless.band"]),
        password: fields["802-11-wireless-security.psk"] ?? ""
    };
}

function readProfiles(text) {
    const found = [];
    let current = null;
    for (const line of String(text ?? "").split("\n")) {
        if (line.startsWith("uuid:")) {
            current = { uuid: line.slice(5).trim(), lines: [] };
            found.push(current);
        } else if (current) {
            current.lines.push(line);
        }
    }
    return found.map(entry => {
        const fields = {};
        for (const line of entry.lines) {
            const cut = line.indexOf(":");
            if (cut > 0)
                fields[line.slice(0, cut)] = line.slice(cut + 1);
        }
        return Object.assign({ uuid: entry.uuid, mode: fields["802-11-wireless.mode"] ?? "" }, readProfile(fields));
    });
}

function ownProfile(connections, profiles) {
    for (const connection of candidates(connections)) {
        const profile = profiles.find(read => read.uuid === connection.uuid);
        if (profile && profile.mode === "ap")
            return Object.assign({}, profile, { name: connection.name, active: connection.active });
    }
    return null;
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
