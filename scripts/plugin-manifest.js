const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "../services/plugin-protocol.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Protocol = new Function(`${source}\nreturn { readManifest, API };`)();

function read(folder, name) {
    const file = path.join(folder, "plugin.json");
    if (!fs.existsSync(file))
        return { error: `no plugin.json in ${folder}` };
    const text = fs.readFileSync(file, "utf8");
    let own = "";
    try {
        own = typeof JSON.parse(text).id === "string" ? JSON.parse(text).id : "";
    } catch (e) {
        own = "";
    }
    return Protocol.readManifest(text, path.join(path.dirname(folder), name || own || path.basename(folder)));
}

function files(folder) {
    const out = [];
    const walk = (dir, rel) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            if (entry.name === ".git")
                continue;
            const full = path.join(dir, entry.name);
            const shown = rel ? `${rel}/${entry.name}` : entry.name;
            if (entry.isDirectory())
                walk(full, shown);
            else
                out.push(`${shown}${fs.statSync(full).mode & 0o111 ? " (runs)" : ""}`);
        }
    };
    walk(folder, "");
    return out.sort();
}

function describe(plugin, folder) {
    const lines = [
        `name      ${plugin.name}${plugin.about ? `, ${plugin.about}` : ""}`,
        `id        ${plugin.id}`,
        `runs      ${plugin.exec.map(w => w.startsWith(plugin.folder + "/") ? `./${w.slice(plugin.folder.length + 1)}` : w).join(" ")}`,
        `answers   ${[plugin.prefix.length ? `after ${plugin.prefix.join(", ")}` : "", plugin.global ? `in plain searches, at most ${plugin.global.cap === 1 ? "1 row" : `${plugin.global.cap} rows`}` : ""].filter(Boolean).join(" and ")}`
    ];
    if (plugin.preferences.length)
        lines.push(`asks for  ${plugin.preferences.map(p => `${p.title}${p.type === "secret" ? " (secret)" : ""}`).join(", ")}`);
    const listed = files(folder);
    lines.push(`files     ${listed.length > 12 ? `${listed.slice(0, 12).join(", ")} and ${listed.length - 12} more` : listed.join(", ")}`);
    return lines.join("\n");
}

function main(argv) {
    const [verb, folder, name] = argv;
    if (!verb || !folder) {
        process.stderr.write("usage: plugin-manifest.js id|show <folder> [<name>]\n");
        return 2;
    }
    const read_ = read(path.resolve(folder), name);
    if (!read_.plugin) {
        process.stderr.write(`${read_.error}\n`);
        return 1;
    }
    process.stdout.write(`${verb === "id" ? read_.plugin.id : describe(read_.plugin, path.resolve(folder))}\n`);
    return 0;
}

if (require.main === module)
    process.exitCode = main(process.argv.slice(2));

module.exports = { read, describe, files };
