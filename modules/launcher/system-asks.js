.pragma library

var BRIGHTNESS_LIST = /^(?:screen |display |monitor )?(?:brightness|backlight)$/;
var BRIGHTNESS_SET = /^(?:set )?(?:the )?(?:screen |display |monitor )?(?:brightness|backlight) (?:to )?(\d{1,3}) ?%?$/;
var BRIGHTER = /^(?:brighter|brighten(?: the screen)?|(?:brightness|backlight) up|screen brighter)$/;
var DIMMER = /^(?:dimmer|dim the screen|dim screen|(?:brightness|backlight) down|screen dimmer)$/;

var WIFI_HEAD = /^(?:wifi networks?|wi-fi networks?|wireless networks?|wifi|wi-fi|wlan|wireless)(?: (.+))?$/;
var WIFI_JOIN = /^join (.+)$/;
var WIFI_ON = /^(?:on|enable|turn on)$/;
var WIFI_OFF = /^(?:off|disable|turn off)$/;

var VPN_HEAD = /^(?:vpn|vpns|tunnel|tunnels|wireguard)(?: (.+))?$/;

var TAILSCALE_HEAD = /^(?:tailscale|tail scale)(?: (.+))?$/;
var EXIT_NODES = /^exit ?nodes?(?: (.+))?$/;
var TAILSCALE_UP = /^(?:up|on|connect|start)$/;
var TAILSCALE_DOWN = /^(?:down|off|disconnect|stop)$/;

var RECORD = /^(?:start )?(?:screen )?(?:record|recording)(?: (?:the |a |my )?(screen|display|monitor|area|region|selection|part|window))?( with (?:sound|audio))?$/;
var RECORD_SCREEN = /^(?:screen ?record(?:ing|er)?|record(?:ing)? the screen)( with (?:sound|audio))?$/;
var RECORD_STOP = /^(?:stop (?:the )?(?:screen )?record(?:ing)?|record(?:ing)? stop|end (?:the )?recording)$/;

var MODES = {
    screen: "screen",
    display: "screen",
    monitor: "screen",
    area: "area",
    region: "area",
    selection: "area",
    part: "area",
    window: "window"
};

function tidy(text) {
    return String(text || "").trim().toLowerCase().replace(/\s+/g, " ");
}

function brightnessAsk(text) {
    var t = tidy(text);
    if (BRIGHTNESS_LIST.test(t))
        return { kind: "list" };
    var m = BRIGHTNESS_SET.exec(t);
    if (m && parseInt(m[1], 10) <= 100)
        return { kind: "set", level: parseInt(m[1], 10) };
    if (BRIGHTER.test(t))
        return { kind: "step", direction: 1 };
    if (DIMMER.test(t))
        return { kind: "step", direction: -1 };
    return null;
}

function nearWord(text, words) {
    var t = tidy(text);
    if (t.length < 4)
        return false;
    for (var i = 0; i < words.length; i++) {
        if (words[i] !== t && words[i].indexOf(t) === 0)
            return true;
    }
    return false;
}

function brightnessNear(text) {
    return nearWord(text, ["brightness", "backlight", "brighter", "dimmer"]);
}

function wifiAsk(text) {
    var t = tidy(text);
    var m = WIFI_HEAD.exec(t);
    if (m) {
        var rest = m[1] || "";
        if (WIFI_ON.test(rest))
            return { name: "", power: true };
        if (WIFI_OFF.test(rest))
            return { name: "", power: false };
        return { name: rest };
    }
    m = WIFI_JOIN.exec(t);
    return m ? { name: m[1], join: true } : null;
}

function vpnAsk(text) {
    var m = VPN_HEAD.exec(tidy(text));
    return m ? { name: m[1] || "" } : null;
}

function tailscaleAsk(text) {
    var t = tidy(text);
    var m = EXIT_NODES.exec(t);
    if (m)
        return { kind: "exit", name: m[1] || "" };
    m = TAILSCALE_HEAD.exec(t);
    if (!m)
        return null;
    var rest = m[1] || "";
    if (!rest)
        return { kind: "status", name: "" };
    if (TAILSCALE_UP.test(rest))
        return { kind: "up", name: "" };
    if (TAILSCALE_DOWN.test(rest))
        return { kind: "down", name: "" };
    var exit = EXIT_NODES.exec(rest);
    if (exit)
        return { kind: "exit", name: exit[1] || "" };
    return { kind: "status", name: rest };
}

function vpnNear(text) {
    return nearWord(text, ["tailscale", "tunnels", "wireguard"]);
}

function recordAsk(text) {
    var t = tidy(text);
    if (RECORD_STOP.test(t))
        return { stop: true, mode: "", sound: false };
    var m = RECORD_SCREEN.exec(t);
    if (m)
        return { stop: false, mode: "", sound: !!m[1] };
    m = RECORD.exec(t);
    if (!m)
        return null;
    return { stop: false, mode: m[1] ? MODES[m[1]] : "", sound: !!m[2] };
}

function stopNear(text) {
    var t = tidy(text);
    return t === "stop" || t.length >= 4 && "stop recording".indexOf(t) === 0;
}

function recordNear(text) {
    return nearWord(text, ["record", "recording", "screen recording"]);
}
