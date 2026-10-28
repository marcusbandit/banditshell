const fs = require("node:fs");
const path = require("node:path");

function lexists(at) {
    try {
        fs.lstatSync(at);
        return true;
    } catch (e) {
        return false;
    }
}

function stamp(d) {
    const two = n => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}T${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())}`;
}

function trashInto(trash, paths) {
    const files = path.join(trash, "files");
    const info = path.join(trash, "info");
    fs.mkdirSync(files, { recursive: true });
    fs.mkdirSync(info, { recursive: true });
    let failed = false;
    for (const from of paths) {
        if (!lexists(from)) {
            failed = true;
            continue;
        }
        const base = path.basename(from);
        const dot = base.lastIndexOf(".");
        const stem = dot > 0 ? base.slice(0, dot) : base;
        const ext = dot > 0 ? base.slice(dot) : "";
        let name = base;
        for (let n = 2; lexists(path.join(info, `${name}.trashinfo`)) || lexists(path.join(files, name)); n++)
            name = `${stem}.${n}${ext}`;
        fs.writeFileSync(path.join(info, `${name}.trashinfo`), `[Trash Info]\nPath=${from.split("/").map(encodeURIComponent).join("/")}\nDeletionDate=${stamp(new Date())}\n`);
        fs.renameSync(from, path.join(files, name));
    }
    return failed ? 1 : 0;
}

function install(bin, trash, { fails = false } = {}) {
    fs.writeFileSync(path.join(bin, "gio"), `#!/bin/sh
${fails ? "exit 1" : ""}
[ "$1 $2" = "trash --" ] || exit 2
shift 2
TZ=${JSON.stringify(process.env.TZ ?? "")} exec ${JSON.stringify(process.execPath)} ${JSON.stringify(__filename)} ${JSON.stringify(trash)} "$@"
`);
    fs.chmodSync(path.join(bin, "gio"), 0o755);
}

function trashed(trash) {
    const info = path.join(trash, "info");
    if (!fs.existsSync(info))
        return [];
    return fs.readdirSync(info).map(file => {
        const name = file.slice(0, -".trashinfo".length);
        const at = path.join(trash, "files", name);
        const origin = /^Path=(.*)$/m.exec(fs.readFileSync(path.join(info, file), "utf8"))[1];
        return { name, path: decodeURIComponent(origin), body: lexists(at) && fs.statSync(at).isFile() ? fs.readFileSync(at, "utf8") : null };
    });
}

function age(trash, seconds) {
    const info = path.join(trash, "info");
    for (const file of fs.existsSync(info) ? fs.readdirSync(info) : []) {
        const at = path.join(info, file);
        fs.writeFileSync(at, fs.readFileSync(at, "utf8").replace(/^DeletionDate=(.*)$/m, (line, when) => `DeletionDate=${stamp(new Date(new Date(when).getTime() - seconds * 1000))}`));
    }
}

if (require.main === module)
    process.exit(trashInto(process.argv[2], process.argv.slice(3)));

module.exports = { install, trashed, age };
