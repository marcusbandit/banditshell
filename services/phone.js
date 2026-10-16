.pragma library

var LIST = /^(?:my\s+)?(?:phones?|kde\s?connect)$/i;
var RING = /^(?:ring|find)\s+(?:my\s+)?(\S.*)$/i;
var PING = /^ping\s+(?:my\s+)?(\S.*)$/i;
var BATTERY = /^(?:(?:my\s+)?(phone|\S+)\s+battery|battery\s+(?:of\s+|on\s+)?(?:my\s+)?(\S.*))$/i;
var FOLLOWED = /^(?:my\s+)?phone\s+(ring|ping|battery|send|share|clipboard|file|link)$/i;
var CLIPBOARD = /^send\s+(?:the\s+|my\s+)?clipboard\s+to\s+(?:my\s+)?(\S.*)$/i;
var FILE = /^send\s+(?:a\s+)?files?\s+to\s+(?:my\s+)?(\S.*)$/i;
var LINK = /^(?:send|share)\s+(?:a\s+)?(?:link|url)\s+(?:to|with)\s+(?:my\s+)?(\S.*)$/i;
var MENU = /^(?:send|share)\s+(?:to|with)\s+(?:my\s+)?(\S.*)$/i;
var PAYLOAD = /^(?:send|share)\s+(.+?)\s+(?:to|with)\s+(?:my\s+)?(\S.*)$/i;
var URL = /^(?:[a-z][a-z0-9+.-]*:\/\/\S+|www\.\S+|magnet:\S+)$/i;
var GENERIC = /^(?:phones?|devices?|tablets?|mobile|handset|kde\s?connect)$/i;
var DEVICE_ID = /^[A-Za-z0-9_-]+$/;
var TYPED = /^[a-z]{1,2}\s+/;

var READ = 'command -v kdeconnect-cli >/dev/null 2>&1 || exit 3\n' + 'prop() {\n' + '    if command -v busctl >/dev/null 2>&1; then busctl --user get-property org.kde.kdeconnect "$1" "$2" "$3" 2>/dev/null\n' + '    elif command -v qdbus6 >/dev/null 2>&1; then qdbus6 org.kde.kdeconnect "$1" org.freedesktop.DBus.Properties.Get "$2" "$3" 2>/dev/null\n' + '    elif command -v qdbus >/dev/null 2>&1; then qdbus org.kde.kdeconnect "$1" org.freedesktop.DBus.Properties.Get "$2" "$3" 2>/dev/null\n' + '    fi\n' + '}\n' + 'reach=$(kdeconnect-cli -a --id-only 2>/dev/null)\n' + 'kdeconnect-cli -l --id-name-only 2>/dev/null | while IFS= read -r line; do\n' + '    id=${line%% *}\n' + '    case $id in "" | *[!A-Za-z0-9_-]*) continue ;; esac\n' + '    name=${line#"$id"}\n' + '    name=${name# }\n' + '    path=/modules/kdeconnect/devices/$id\n' + '    reachable=0\n' + '    for seen in $reach; do [ "$seen" = "$id" ] && reachable=1; done\n' + '    paired=$(prop "$path" org.kde.kdeconnect.device isPaired)\n' + '    kind=$(prop "$path" org.kde.kdeconnect.device type)\n' + '    charge=\n' + '    charging=\n' + '    if [ "$reachable" = 1 ]; then\n' + '        charge=$(prop "$path/battery" org.kde.kdeconnect.device.battery charge)\n' + '        charging=$(prop "$path/battery" org.kde.kdeconnect.device.battery isCharging)\n' + '    fi\n' + '    printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" "$id" "$reachable" "$paired" "$kind" "$charge" "$charging" "$name"\n' + 'done\n';

function deviceWords(words) {
    var w = String(words || "").trim().replace(/^my\s+/i, "");
    return GENERIC.test(w) ? "" : w;
}

function payloadOf(text) {
    var t = String(text || "").trim();
    if (URL.test(t))
        return {
            kind: "link",
            value: /^www\./i.test(t) ? "https://" + t : t
        };
    if (/^(?:~\/|\/)\S/.test(t))
        return {
            kind: "file",
            value: t
        };
    return {
        kind: "text",
        value: t
    };
}

function ask(text) {
    var t = String(text || "").trim();
    var m;
    if (LIST.test(t))
        return {
            action: "list",
            device: "",
            generic: true
        };
    if ((m = FOLLOWED.exec(t))) {
        var word = m[1].toLowerCase();
        return {
            action: word === "share" ? "send" : word,
            device: "",
            generic: true
        };
    }
    if ((m = CLIPBOARD.exec(t)))
        return made("clipboard", m[1]);
    if ((m = FILE.exec(t)))
        return made("file", m[1]);
    if ((m = LINK.exec(t)))
        return made("link", m[1]);
    if ((m = MENU.exec(t)))
        return made("send", m[1]);
    if ((m = PAYLOAD.exec(t))) {
        var asked = made("share", m[2]);
        asked.payload = payloadOf(m[1]);
        return asked;
    }
    if ((m = BATTERY.exec(t)))
        return made("battery", m[1] || m[2]);
    if ((m = RING.exec(t)))
        return made("ring", m[1]);
    if ((m = PING.exec(t)))
        return made("ping", m[1]);
    return null;
}

function made(action, words) {
    var device = deviceWords(words);
    return {
        action: action,
        device: device,
        generic: !device
    };
}

function readCommand() {
    return ["sh", "-c", READ];
}

function plain(raw) {
    var t = String(raw || "").trim().replace(TYPED, "");
    if (t.length >= 2 && t.charAt(0) === "\"" && t.charAt(t.length - 1) === "\"")
        t = t.slice(1, -1).replace(/\\(.)/g, "$1");
    return t;
}

function readDevices(text) {
    var out = [];
    var all = String(text || "").split("\n");
    for (var i = 0; i < all.length; i++) {
        var fields = all[i].split("\t");
        if (fields.length < 7 || !DEVICE_ID.test(fields[0]))
            continue;
        var reachable = fields[1] === "1";
        var pairedText = plain(fields[2]);
        var paired = pairedText === "true" || pairedText === "" && reachable;
        if (!paired)
            continue;
        var charge = parseInt(plain(fields[4]), 10);
        out.push({
            id: fields[0],
            reachable: reachable,
            type: plain(fields[3]) || "phone",
            charge: isNaN(charge) || charge < 0 ? -1 : Math.min(100, charge),
            charging: plain(fields[5]) === "true",
            name: fields.slice(6).join("\t").trim() || fields[0]
        });
    }
    return out.sort(function (a, b) {
        return (b.reachable ? 1 : 0) - (a.reachable ? 1 : 0);
    });
}

function matching(devices, asked, place) {
    if (!asked)
        return [];
    if (asked.generic)
        return devices.slice();
    return devices.filter(function (d) {
        return place(d.name, asked.device) >= 2 || place(d.type, asked.device) >= 3;
    });
}

function iconOf(device) {
    return device.type === "tablet" ? "tablet" : device.type === "laptop" ? "laptop_chromebook" : device.type === "desktop" ? "computer" : device.type === "tv" ? "tv" : "mobile";
}

function batteryText(device) {
    if (device.charge < 0)
        return "";
    return device.charge + "%" + (device.charging ? " · charging" : "");
}

function detailOf(device) {
    if (!device.reachable)
        return "not reachable";
    return [device.type === "phone" ? "" : device.type, batteryText(device)].filter(Boolean).join(" · ");
}

function validId(id) {
    return DEVICE_ID.test(String(id || ""));
}

function expandPath(path, home) {
    return String(path || "").replace(/^~(?=\/)/, home);
}

function shareable(payload) {
    if (!payload || !payload.value)
        return false;
    if (payload.kind === "link")
        return URL.test(payload.value);
    if (payload.kind === "file")
        return payload.value.charAt(0) === "/" && payload.value.indexOf("\n") < 0;
    return payload.kind === "text";
}

function commandFor(id, action, payload) {
    if (!validId(id))
        return null;
    var device = "--device=" + id;
    switch (action) {
    case "ring":
        return ["kdeconnect-cli", "--ring", device];
    case "ping":
        return ["kdeconnect-cli", "--ping", device];
    case "clipboard":
        return ["kdeconnect-cli", "--send-clipboard", device];
    case "share":
        if (!shareable(payload))
            return null;
        return payload.kind === "text" ? ["kdeconnect-cli", "--share-text=" + payload.value, device] : ["kdeconnect-cli", "--share=" + payload.value, device];
    }
    return null;
}

function baseName(path) {
    var parts = String(path || "").split("/").filter(Boolean);
    return parts.length ? parts[parts.length - 1] : String(path || "");
}

function shortened(text, most) {
    var t = String(text || "").replace(/\s+/g, " ").trim();
    return t.length > most ? t.slice(0, most - 1).trim() + "…" : t;
}

function payloadLabel(payload) {
    if (payload.kind === "file")
        return baseName(payload.value);
    return shortened(payload.value, 48);
}
