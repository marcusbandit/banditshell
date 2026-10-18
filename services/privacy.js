const KINDS = ["camera", "screen", "mic"];
const CAMERA_APIS = ["v4l2", "libcamera"];
const IGNORED_BINARIES = ["quickshell", "qs"];
const IGNORED_MEDIA_NAMES = ["Peak detect"];

const PRESENTATION = {
    mic: { name: "Microphone", state: "Microphone on", icon: "mic", priority: 10, menu: "sound" },
    camera: { name: "Camera", state: "Camera on", icon: "videocam", priority: 30, menu: "" },
    screen: { name: "Screen", state: "Screen shared", icon: "screen_share", priority: 20, menu: "" }
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

function usageSpec(usage) {
    const look = PRESENTATION[usage.kind];
    return {
        id: `privacy:${usage.kind}`,
        kind: "privacy",
        style: "privacy",
        text: look.state,
        detail: usage.kind === "mic" ? "" : usage.apps.join(", "),
        icon: look.icon,
        priority: look.priority,
        pressable: look.menu !== "",
        source: "privacy",
        data: { privacy: usage.kind, apps: usage.apps, menu: look.menu }
    };
}

function micNews(heard, apps) {
    const known = heard || [];
    return (apps || []).some(app => !known.includes(app));
}

function micStep(heard, usage, showing) {
    const apps = usage ? usage.apps : [];
    const known = (heard || []).filter(app => apps.includes(app));
    if (!usage)
        return { post: false, announce: false, heard: [] };
    const announce = micNews(known, apps);
    const post = announce || showing;
    return { post: post, announce: announce, heard: post ? apps.slice() : known };
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

function listeners(dump) {
    let objects;
    try {
        objects = JSON.parse(dump);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(objects))
        return [];
    const props = {};
    const clients = {};
    const links = [];
    for (const object of objects) {
        const info = (object && object.info) || {};
        if (object.type === "PipeWire:Interface:Node")
            props[object.id] = info.props || {};
        else if (object.type === "PipeWire:Interface:Client")
            clients[object.id] = info.props || {};
        else if (object.type === "PipeWire:Interface:Link")
            links.push({ source: info["output-node-id"], target: info["input-node-id"], active: info.state === "active" });
    }
    const snapshot = { nodes: Object.keys(props).map(id => ({ id: Number(id), props: props[id] })), links: links };
    const out = [];
    for (const node of snapshot.nodes) {
        if (kindOfConsumer(snapshot, node) !== "mic")
            continue;
        const client = clients[node.props["client.id"]] || {};
        const source = feeds(snapshot, node).find(micSource);
        const sp = source ? source.props : {};
        out.push({
            app: appName(node),
            binary: String(client["application.process.binary"] || node.props["application.process.binary"] || ""),
            pid: Number(client["application.process.id"] || node.props["application.process.id"] || 0),
            device: String(sp["node.description"] || sp["node.nick"] || sp["node.name"] || "")
        });
    }
    return out;
}

function unitOf(cgroup) {
    const last = String(cgroup || "").trim().split("/").pop() || "";
    if (!/\.(?:service|scope)$/.test(last) || /^user@\d+\.service$/.test(last) || /^session-\w+\.scope$/.test(last))
        return "";
    const name = last.replace(/\.(?:service|scope)$/, "");
    if (!name.startsWith("app-"))
        return name;
    return name.slice(4).replace(/@.*$/, "").replace(/-\d+$/, "").replace(/^[A-Z][A-Za-z]*-/, "");
}

function shortCommand(cmdline) {
    const parts = String(cmdline || "").trim().split(/\s+/).filter(part => part !== "");
    if (parts.length === 0)
        return "";
    parts[0] = parts[0].split("/").pop();
    return parts.join(" ");
}

function named(found, table) {
    const info = {};
    for (const line of String(table || "").split("\n")) {
        const cells = line.split("\t");
        if (/^\d+$/.test(cells[0] || ""))
            info[Number(cells[0])] = { command: shortCommand(cells[1]), unit: unitOf(cells[2]) };
    }
    const out = [];
    const pids = {};
    for (const listener of found || []) {
        const known = info[listener.pid] || {};
        const name = known.unit || listener.binary || listener.app;
        let row = out.find(r => r.name === name);
        if (!row) {
            row = { name: name, command: known.command || "", device: listener.device, pid: listener.pid, processes: 0 };
            out.push(row);
            pids[name] = [];
        }
        const key = listener.pid > 0 ? listener.pid : `app:${listener.app}`;
        if (!pids[name].includes(key)) {
            pids[name].push(key);
            row.processes = pids[name].length;
        }
    }
    return out;
}
