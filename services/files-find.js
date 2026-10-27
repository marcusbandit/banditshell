.pragma library

const LEAST = 2;
const LIMIT = 1000;

const SKIP_NAMES = ["node_modules", ".git", ".hg", ".svn", ".cache", "__pycache__", ".venv", ".tox", ".mypy_cache", ".pytest_cache", ".gradle", ".next", ".direnv"];

const SKIP_PATHS = [".local/share/Trash", ".local/share/Steam", ".steam", ".var", ".npm", ".cargo", ".rustup", ".m2", ".mozilla", ".pki", ".nv", ".ssh", ".gnupg", ".password-store", ".local/share/keyrings", ".local/share/containers", ".local/share/flatpak", ".wine"];

function joinPath(dir, name) {
    return dir.endsWith("/") ? dir + name : `${dir}/${name}`;
}

function within(path, root) {
    if (!path || !root)
        return false;
    if (root === "/")
        return path.length > 1;
    return path.startsWith(root.endsWith("/") ? root : `${root}/`);
}

function searchable(query) {
    const q = query.trim();
    return q.length >= LEAST && !q.includes("/");
}

function command(helper, query, home, cwd, options) {
    if (!searchable(query))
        return null;
    const words = ["nice", "-n", "10", helper, "--find", "--limit", String(options.limit ?? LIMIT)];
    if (options.hidden)
        words.push("--hidden");
    if (options.deep)
        words.push("--deep");
    else {
        for (const name of SKIP_NAMES)
            words.push("--skip", name);
        for (const rel of SKIP_PATHS)
            words.push("--skip-path", joinPath(home, rel));
    }
    if (within(cwd, home))
        words.push("--first", cwd);
    return words.concat(["--", query.trim(), home]);
}

function parse(line) {
    let value;
    try {
        value = JSON.parse(line);
    } catch (e) {
        return null;
    }
    if (!value || typeof value !== "object")
        return null;
    if (value.done === true)
        return {done: true, scanned: Number(value.scanned) || 0, capped: value.capped === true};
    if (typeof value.name === "string" && typeof value.dir === "string" && value.name !== "") {
        value.key = joinPath(value.dir, value.name);
        return {entry: value};
    }
    if (typeof value.scanned === "number")
        return {scanned: value.scanned};
    return null;
}

function place(dir, home) {
    if (dir === home)
        return "~";
    return within(dir, home) ? `~/${dir.slice(home.length).replace(/^\/+/, "")}` : dir;
}

function named(entries, query) {
    const q = query.trim().toLowerCase();
    return entries.filter(e => e.name.toLowerCase().includes(q));
}

function narrows(before, after) {
    return searchable(before) && after.trim().toLowerCase().includes(before.trim().toLowerCase());
}

function without(entries, paths) {
    if (paths.length === 0)
        return entries;
    return entries.filter(e => !paths.some(p => e.key === p || within(e.key, p)));
}

function merged(fresh, provisional) {
    if (provisional.length === 0)
        return fresh;
    const seen = new Set(fresh.map(e => e.key));
    return fresh.concat(provisional.filter(e => !seen.has(e.key)));
}

function grouped(local, found, cwd, order) {
    const below = [];
    const elsewhere = [];
    for (const entry of found) {
        if (entry.dir === cwd)
            continue;
        (within(entry.dir, cwd) ? below : elsewhere).push(entry);
    }
    return order(local).concat(order(below), order(elsewhere));
}
