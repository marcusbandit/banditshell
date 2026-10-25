const SCREENSHOT_MS = 6000;
const BLUETOOTH_MS = 3000;
const WIFI_MS = 8000;
const COPIED_MS = 900;
const COPIED_PREVIEW = 20;
const MASK = "••••••••";
const MOMENT_KINDS = ["screenshot", "privacy", "copied", "bluetooth", "wifi"];
const SCREENSHOT_ACTIONS = ["copy", "edit", "folder", "delete"];
const AUDIO_ICONS = ["headphones", "speaker"];

function momentWanted(moments, kind) {
    if (!MOMENT_KINDS.includes(kind))
        return false;
    return !moments || moments[kind] !== false;
}

function fileUrl(path) {
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
}

function baseName(path) {
    const text = String(path || "");
    return text.slice(text.lastIndexOf("/") + 1);
}

function folderOf(path) {
    const text = String(path || "");
    const at = text.lastIndexOf("/");
    return at <= 0 ? "/" : text.slice(0, at);
}

function screenshotSpec(path) {
    const file = String(path || "").trim();
    if (file === "")
        return null;
    return {
        id: "moment:screenshot",
        style: "screenshot",
        text: "Screenshot",
        detail: baseName(file),
        icon: "screenshot_region",
        until: SCREENSHOT_MS,
        priority: 40,
        pressable: true,
        source: "moments",
        data: { path: file, folder: folderOf(file), picture: fileUrl(file) },
        actions: [
            { name: "copy", label: "Copy" },
            { name: "edit", label: "Edit" },
            { name: "folder", label: "Folder" },
            { name: "delete", label: "Delete" }
        ]
    };
}

function screenshotAction(name) {
    return SCREENSHOT_ACTIONS.includes(name) ? name : "open";
}

function editorCommand(editor, path) {
    const tool = String(editor || "").trim();
    if (tool === "")
        return ["xdg-open", path];
    return ["sh", "-c", tool + " \"$1\"", "sh", path];
}

function squash(text) {
    return String(text === undefined || text === null ? "" : text).replace(/\s+/g, " ").trim();
}

function preview(text, max) {
    const flat = squash(text);
    const limit = max > 0 ? max : COPIED_PREVIEW;
    return flat.length > limit ? flat.slice(0, limit).replace(/\s+$/, "") + "\u2026" : flat;
}

function copyShape(command) {
    const parts = Array.isArray(command) ? command.map(String) : [];
    return {
        secret: parts.includes("--sensitive"),
        image: parts.some(p => /^image\//.test(p)),
        files: parts.includes("text/uri-list")
    };
}

function copiedLabel(command, input) {
    const shape = copyShape(command);
    if (shape.image)
        return "Copied: image";
    if (shape.files) {
        const count = String(input || "").split(/\r?\n/).filter(line => line.trim() !== "").length;
        return count > 1 ? `Copied: ${count} files` : "Copied: a file";
    }
    const shown = squash(input);
    if (shown === "")
        return "";
    return shape.secret ? `Copied: ${MASK}` : `Copied: ${preview(input, COPIED_PREVIEW)}`;
}

function copiedSpec(command, input) {
    const label = copiedLabel(command, input);
    if (label === "")
        return null;
    return {
        id: "moment:copied",
        style: "copied",
        text: label,
        icon: "content_copy",
        until: COPIED_MS,
        priority: 20,
        source: "moments",
        data: { secret: copyShape(command).secret }
    };
}

function audioDevice(icon) {
    return AUDIO_ICONS.includes(icon);
}

function batteryPercent(fraction, available) {
    if (!available || !isFinite(fraction) || fraction < 0)
        return -1;
    return Math.round(Math.min(1, fraction) * 100);
}

function bluetoothSpec(name, icon, battery) {
    const shown = squash(name) || "Bluetooth device";
    return {
        id: "moment:bluetooth",
        style: "bluetooth",
        text: shown,
        detail: "Connected",
        icon: icon || "bluetooth_connected",
        until: BLUETOOTH_MS,
        priority: 30,
        source: "moments",
        data: { battery: battery >= 0 ? battery : -1 }
    };
}

function wifiSpec(name, kind, message) {
    const shown = squash(name);
    if (shown === "")
        return null;
    return {
        id: "moment:wifi",
        style: "wifi",
        text: squash(message) || shown,
        icon: "wifi_off",
        until: WIFI_MS,
        priority: 45,
        pressable: true,
        source: "moments",
        data: { name: String(name), kind: String(kind || "unknown") },
        actions: [{ name: "retry", label: "Try again" }]
    };
}

function newlyConnected(before, after) {
    const had = new Set(before || []);
    return (after || []).filter(address => !had.has(address));
}
