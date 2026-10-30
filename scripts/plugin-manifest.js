const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "../services/plugin-protocol.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Protocol = new Function(`${source}\nreturn { readManifest, API };`)();

function read(folder) {
    const file = path.join(folder, "plugin.json");
    if (!fs.existsSync(file))
        return { error: `no plugin.json in ${folder}` };
    return Protocol.readManifest(fs.readFileSync(file, "utf8"), folder, true);
}

function files(folder) {
    const out = [];
    const walk = (dir, rel) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            if (entry.name === ".git")
                continue;
            const full = path.join(dir, entry.name);
            const shown = rel ? `${rel}/${entry.name}` : entry.name;
            const stat = fs.lstatSync(full);
            if (stat.isSymbolicLink()) {
                const target = fs.readlinkSync(full);
                const inside = path.resolve(path.dirname(full), target).startsWith(folder + path.sep);
                out.push({ name: `${shown} -> ${target}`, leaves: !inside });
            } else if (stat.isDirectory())
                walk(full, shown);
            else
                out.push({ name: `${shown}${stat.mode & 0o111 ? " (runs)" : ""}`, leaves: false });
        }
    };
    walk(folder, "");
    return out.sort((a, b) => a.name.localeCompare(b.name));
}

function leaving(folder) {
    return files(folder).filter(f => f.leaves).map(f => f.name);
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
    const listed = files(folder).map(f => f.name);
    lines.push(`files     ${listed.length > 12 ? `${listed.slice(0, 12).join(", ")} and ${listed.length - 12} more` : listed.join(", ")}`);
    return lines.join("\n");
}

function main(argv) {
    const [verb, folder] = argv;
    if (!["id", "show", "links"].includes(verb) || !folder) {
        process.stderr.write("usage: plugin-manifest.js id|show|links <folder>\n");
        return 2;
    }
    const where = path.resolve(folder);
    if (verb === "links") {
        const out = leaving(where);
        if (out.length)
            process.stdout.write(`${out.join("\n")}\n`);
        return out.length ? 1 : 0;
    }
    const found = read(where);
    if (!found.plugin) {
        process.stderr.write(`${found.error}\n`);
        return 1;
    }
    process.stdout.write(`${verb === "id" ? found.plugin.id : describe(found.plugin, where)}\n`);
    return 0;
}

if (require.main === module)
    process.exitCode = main(process.argv.slice(2));

module.exports = { read, describe, files, leaving };
