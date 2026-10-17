const KINDS = ["camera", "screen", "mic"];
const CAMERA_APIS = ["v4l2", "libcamera"];
const IGNORED_BINARIES = ["quickshell", "qs"];
const IGNORED_MEDIA_NAMES = ["Peak detect"];

const PRESENTATION = {
    mic: { name: "Microphone", icon: "mic", priority: 10, menu: "sound" },
    camera: { name: "Camera", icon: "videocam", priority: 30, menu: "" },
    screen: { name: "Screen", icon: "screen_share", priority: 20, menu: "" }
};

function classOf(node) {
    return String((node.props || {})["media.class"] || "");
}

function appName(node) {
    const p = node.props || {};
    return String(p["application.name"] || p["node.description"] || p["application.process.binary"] || p["node.name"] || "an app");
}

function ignored(node) {
    const p = node.props || {};
    if (IGNORED_BINARIES.includes(String(p["application.process.binary"] || "")))
        return true;
    return IGNORED_MEDIA_NAMES.includes(String(p["media.name"] || ""));
}

function cameraSource(node) {
    const p = node.props || {};
    return classOf(node) === "Video/Source" && (CAMERA_APIS.includes(String(p["device.api"] || "")) || String(p["media.role"] || "") === "Camera");
}

function screenSource(node) {
    return classOf(node) === "Stream/Output/Video" || String((node.props || {})["media.role"] || "") === "Screen";
}

function micSource(node) {
    return /^Audio\/Source/.test(classOf(node));
}

function feeds(snapshot, consumer) {
    const byId = {};
    for (const n of snapshot.nodes || [])
        byId[n.id] = n;
    const out = [];
    for (const link of snapshot.links || [])
        if (link.target === consumer.id && link.active && byId[link.source])
            out.push(byId[link.source]);
    return out;
}

function kindOfConsumer(snapshot, consumer) {
    if (ignored(consumer))
        return "";
    const cls = classOf(consumer);
    const sources = feeds(snapshot, consumer);
    if (cls === "Stream/Input/Audio") {
        if (String((consumer.props || {})["stream.capture.sink"] || "") === "true")
            return "";
        return sources.some(micSource) ? "mic" : "";
    }
    if (cls === "Stream/Input/Video") {
        if (sources.some(cameraSource))
            return "camera";
        if (sources.some(screenSource))
            return "screen";
    }
    return "";
}

function usages(snapshot, quiet) {
    const hushed = quiet || {};
    const found = { mic: [], camera: [], screen: [] };
    for (const node of (snapshot && snapshot.nodes) || []) {
        const kind = kindOfConsumer(snapshot, node);
        if (kind === "" || hushed[kind])
            continue;
        const name = appName(node);
        if (!found[kind].includes(name))
            found[kind].push(name);
    }
    return KINDS.filter(k => found[k].length > 0).map(k => ({ kind: k, apps: found[k].slice().sort() }));
}

function appsLine(apps) {
    if (apps.length === 0)
        return "";
    return apps.length === 1 ? apps[0] : `${apps[0]} +${apps.length - 1}`;
}

function usageSpec(usage) {
    const look = PRESENTATION[usage.kind];
    return {
        id: `privacy:${usage.kind}`,
        kind: "privacy",
        style: "privacy",
        text: `${look.name}: ${appsLine(usage.apps)}`,
        detail: usage.apps.join(", "),
        icon: look.icon,
        priority: look.priority,
        pressable: look.menu !== "",
        source: "privacy",
        data: { privacy: usage.kind, apps: usage.apps, menu: look.menu }
    };
}

function sameUsage(a, b) {
    return a.kind === b.kind && a.apps.join("\n") === b.apps.join("\n");
}

function changes(before, after) {
    const old = before || [];
    const next = after || [];
    return {
        push: next.filter(u => !old.some(o => sameUsage(o, u))),
        end: old.filter(o => !next.some(u => u.kind === o.kind)).map(o => `privacy:${o.kind}`)
    };
}
