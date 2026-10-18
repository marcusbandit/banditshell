#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");

const SCAN_DIRS = ["modules", "services", "components", "config", "assets", "scripts", "src", "tests", "previews"];
const SCAN_FILES = ["shell.qml", "preview.qml"];
const CODE_DIRS = ["modules", "services", "components", "config", "previews"];
const OWN_KINDS = ["qml", "services", "js", "components", "assets", "scripts", "tests", "src"];
const TOP_KEYS = ["name", "summary", "layer", "owns", "requires", "provides", "config"];
const HOST_FILES = ["modules/ShellWindow.qml", "modules/Host.qml"];
const FORBIDDEN_IN_COMPONENTS = ["Config", "Compositor"];
const BASELINE_FILE = "modules.baseline.json";
const SHOW_LIMIT = 40;

function stripCode(text, keepStrings) {
    const out = text.split("");
    const frames = [];
    let mode = "code";
    let depth = 0;
    const blank = i => {
        if (i < text.length && text[i] !== "\n")
            out[i] = " ";
    };
    for (let i = 0; i < text.length; i++) {
        const c = text[i];
        const n = text[i + 1];
        if (mode === "code") {
            if (c === "/" && n === "/") {
                mode = "line";
                blank(i);
                blank(i + 1);
                i++;
            } else if (c === "/" && n === "*") {
                mode = "block";
                blank(i);
                blank(i + 1);
                i++;
            } else if (c === '"') {
                mode = "dq";
            } else if (c === "'") {
                mode = "sq";
            } else if (c === "`") {
                mode = "tpl";
            } else if (c === "{") {
                depth++;
            } else if (c === "}") {
                if (depth === 0 && frames.length) {
                    depth = frames.pop();
                    mode = "tpl";
                } else {
                    depth--;
                }
            }
        } else if (mode === "line") {
            if (c === "\n")
                mode = "code";
            else
                blank(i);
        } else if (mode === "block") {
            if (c === "*" && n === "/") {
                blank(i);
                blank(i + 1);
                i++;
                mode = "code";
            } else {
                blank(i);
            }
        } else if (mode === "dq" || mode === "sq") {
            if (c === "\\") {
                if (!keepStrings) {
                    blank(i);
                    blank(i + 1);
                }
                i++;
            } else if (c === (mode === "dq" ? '"' : "'") || c === "\n") {
                mode = "code";
            } else if (!keepStrings) {
                blank(i);
            }
        } else if (mode === "tpl") {
            if (c === "\\") {
                if (!keepStrings) {
                    blank(i);
                    blank(i + 1);
                }
                i++;
            } else if (c === "`") {
                mode = "code";
            } else if (c === "$" && n === "{") {
                frames.push(depth);
                depth = 0;
                mode = "code";
                i++;
            } else if (!keepStrings) {
                blank(i);
            }
        }
    }
    return out.join("");
}

function lineIndex(text) {
    const starts = [0];
    for (let i = 0; i < text.length; i++)
        if (text[i] === "\n")
            starts.push(i + 1);
    return offset => {
        let low = 0;
        let high = starts.length - 1;
        while (low < high) {
            const mid = (low + high + 1) >> 1;
            if (starts[mid] <= offset)
                low = mid;
            else
                high = mid - 1;
        }
        return low + 1;
    };
}

function parseImports(code) {
    const at = lineIndex(code);
    const found = [];
    const patterns = [
        [/^[ \t]*import[ \t]+qs\.([\w.]+)/gm, "qs"],
        [/^[ \t]*import[ \t]+"([^"]+)"/gm, "relative"],
        [/^[ \t]*\.import[ \t]+"([^"]+)"/gm, "relative"]
    ];
    for (const [pattern, kind] of patterns) {
        let m;
        while ((m = pattern.exec(code)) !== null)
            found.push({ kind, target: m[1], line: at(m.index) });
    }
    return found.sort((a, b) => a.line - b.line);
}

function parseQmldir(text) {
    const out = [];
    for (const line of text.split("\n")) {
        const m = /^\s*singleton\s+(\w+)\s+\S+\s+(\S+)\s*$/.exec(line);
        if (m)
            out.push({ name: m[1], file: m[2] });
    }
    return out;
}

function findSingletonUses(code, names) {
    if (!names.length)
        return [];
    const at = lineIndex(code);
    const ordered = [...names].sort((a, b) => b.length - a.length);
    const pattern = new RegExp(`(?<![\\w.$])(${ordered.join("|")})\\b(?!\\s*\\{)`, "g");
    const uses = [];
    let m;
    while ((m = pattern.exec(code)) !== null)
        uses.push({ name: m[1], line: at(m.index) });
    return uses;
}

function findForeignWrites(code, names) {
    if (!names.length)
        return [];
    const at = lineIndex(code);
    const ordered = [...names].sort((a, b) => b.length - a.length);
    const pattern = new RegExp(`(?<![\\w.$])(${ordered.join("|")})\\.(\\w+)[ \\t]*[-+*/]?=(?![=>])`, "g");
    const writes = [];
    let m;
    while ((m = pattern.exec(code)) !== null)
        writes.push({ name: m[1], property: m[2], line: at(m.index) });
    return writes;
}

function findConfigReads(code) {
    const at = lineIndex(code);
    const reads = [];
    const push = (key, offset) => reads.push({ key, line: at(offset) });
    const aliases = ["Config.values"];
    let m;
    const aliasPattern = /property\s+var\s+(\w+)\s*:\s*Config\.values\s*$/gm;
    while ((m = aliasPattern.exec(code)) !== null)
        aliases.push(`(?:root\\.)?${m[1]}`);
    const valuesPattern = new RegExp(`(?<![\\w.$])(?:${aliases.map(a => a === "Config.values" ? "Config\\.values" : a).join("|")})\\.([A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)*)`, "g");
    while ((m = valuesPattern.exec(code)) !== null)
        push(m[1], m.index);
    const callPattern = /(?<![\w.$])Config\.(?:get|set)\(\s*["']([\w.]+)["']/g;
    while ((m = callPattern.exec(code)) !== null)
        push(m[1], m.index);
    const catalogue = /\bcfg:\s*["']([\w.]+)["']/g;
    while ((m = catalogue.exec(code)) !== null)
        push(m[1], m.index);
    return reads;
}

function findIpcTargets(code) {
    const at = lineIndex(code);
    const targets = [];
    const pattern = /^[ \t]*target:[ \t]*"([^"\n]+)"[ \t]*$/gm;
    let m;
    while ((m = pattern.exec(code)) !== null)
        targets.push({ name: m[1], line: at(m.index) });
    return targets;
}

function findScriptUses(code) {
    const at = lineIndex(code);
    const uses = [];
    const pattern = /(?<![\w./-])(scripts\/[\w.-]+\.(?:py|sh)|bin\/bs-[a-z]+)/g;
    let m;
    while ((m = pattern.exec(code)) !== null)
        uses.push({ path: m[1], line: at(m.index) });
    return uses;
}

function findPathStrings(code) {
    const at = lineIndex(code);
    const uses = [];
    const pattern = /["'`]((?:modules|services|components|config|scripts|assets)\/[\w./-]*\w)["'`]/g;
    let m;
    while ((m = pattern.exec(code)) !== null)
        uses.push({ path: m[1], line: at(m.index) });
    return uses;
}

function namespaceOwner(key, namespaces) {
    let best = null;
    for (const entry of namespaces)
        if ((key === entry.namespace || key.startsWith(`${entry.namespace}.`)) && (!best || entry.namespace.length > best.namespace.length))
            best = entry;
    return best;
}

function readsCover(reads, key) {
    return (reads || []).some(entry => key === entry || key.startsWith(`${entry}.`));
}

function findCycles(nodes, edgesOf) {
    const index = new Map();
    const low = new Map();
    const onStack = new Set();
    const stack = [];
    const groups = [];
    let counter = 0;
    const visit = node => {
        index.set(node, counter);
        low.set(node, counter);
        counter++;
        stack.push(node);
        onStack.add(node);
        for (const next of edgesOf(node)) {
            if (!index.has(next)) {
                visit(next);
                low.set(node, Math.min(low.get(node), low.get(next)));
            } else if (onStack.has(next)) {
                low.set(node, Math.min(low.get(node), index.get(next)));
            }
        }
        if (low.get(node) === index.get(node)) {
            const group = [];
            let top;
            do {
                top = stack.pop();
                onStack.delete(top);
                group.push(top);
            } while (top !== node);
            if (group.length > 1 || edgesOf(node).includes(node))
                groups.push(group.sort());
        }
    };
    for (const node of nodes)
        if (!index.has(node))
            visit(node);
    return groups;
}

function walk(root, relative, out) {
    const full = path.join(root, relative);
    let entries;
    try {
        entries = fs.readdirSync(full, { withFileTypes: true });
    } catch {
        return;
    }
    for (const entry of entries) {
        if (entry.name.startsWith(".") || entry.name === "node_modules" || entry.name === "__pycache__" || entry.name.endsWith(".pyc"))
            continue;
        const child = relative ? `${relative}/${entry.name}` : entry.name;
        if (entry.isDirectory())
            walk(root, child, out);
        else if (entry.isFile())
            out.push(child);
    }
}

function listFiles(root) {
    const files = [];
    for (const dir of SCAN_DIRS)
        walk(root, dir, files);
    for (const file of SCAN_FILES)
        if (fs.existsSync(path.join(root, file)))
            files.push(file);
    return files.sort();
}

function manifestPaths(root) {
    const found = [];
    const modulesDir = path.join(root, "modules");
    if (fs.existsSync(modulesDir))
        for (const entry of fs.readdirSync(modulesDir, { withFileTypes: true }))
            if (entry.isDirectory() && fs.existsSync(path.join(modulesDir, entry.name, "module.json")))
                found.push(`modules/${entry.name}/module.json`);
    const packagesDir = path.join(root, "packages");
    if (fs.existsSync(packagesDir))
        for (const entry of fs.readdirSync(packagesDir, { withFileTypes: true }))
            if (entry.isFile() && entry.name.endsWith(".json"))
                found.push(`packages/${entry.name}`);
    return found.sort();
}

function expectedName(file) {
    const modulesMatch = /^modules\/([^/]+)\/module\.json$/.exec(file);
    if (modulesMatch)
        return modulesMatch[1];
    const packagesMatch = /^packages\/([^/]+)\.json$/.exec(file);
    return packagesMatch ? packagesMatch[1] : null;
}

function isStringList(value) {
    return Array.isArray(value) && value.every(item => typeof item === "string" && item.length > 0);
}

function validateManifest(manifest, file, problems) {
    const bad = message => problems.push(`R12 ${file} ${message}`);
    if (manifest === null || typeof manifest !== "object" || Array.isArray(manifest)) {
        bad("is not an object");
        return false;
    }
    for (const key of Object.keys(manifest))
        if (!TOP_KEYS.includes(key))
            bad(`has unknown field ${key}`);
    if (typeof manifest.name !== "string" || !/^[a-z][a-z0-9-]*$/.test(manifest.name))
        bad("needs a lowercase name");
    else if (manifest.name !== expectedName(file))
        bad(`names itself ${manifest.name} but its place says ${expectedName(file)}`);
    if (typeof manifest.summary !== "string" || !manifest.summary)
        bad("needs a summary");
    if (!Number.isInteger(manifest.layer) || manifest.layer < 0 || manifest.layer > 9)
        bad("needs an integer layer from 0 to 9");
    const shape = (section, allowed, required) => {
        const value = manifest[section];
        if (value === null || typeof value !== "object" || Array.isArray(value)) {
            bad(`needs a ${section} object`);
            return;
        }
        for (const key of Object.keys(value))
            if (!allowed.includes(key))
                bad(`has unknown field ${section}.${key}`);
        for (const key of allowed) {
            if (value[key] === undefined) {
                if (required.includes(key))
                    bad(`needs ${section}.${key}`);
            } else if (!isStringList(value[key])) {
                bad(`needs ${section}.${key} to be a list of strings`);
            }
        }
    };
    shape("owns", OWN_KINDS, []);
    shape("requires", ["packages", "optional"], ["packages", "optional"]);
    shape("provides", ["singletons", "ipc"], ["singletons", "ipc"]);
    shape("config", ["namespace", "reads"], ["namespace", "reads"]);
    return true;
}

function loadManifests(root) {
    const problems = [];
    const manifests = [];
    for (const file of manifestPaths(root)) {
        let parsed;
        try {
            parsed = JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
        } catch (error) {
            problems.push(`R12 ${file} is not valid JSON`);
            continue;
        }
        if (validateManifest(parsed, file, problems))
            manifests.push({ file, data: parsed });
    }
    return { manifests, problems };
}

function ownedEntries(manifest) {
    const entries = [];
    const owns = manifest.data.owns || {};
    for (const kind of OWN_KINDS)
        for (const item of owns[kind] || [])
            entries.push({ pkg: manifest.data.name, kind, path: kind === "services" ? `services/${item}.qml` : item.replace(/\/+$/, "") });
    return entries;
}

function buildOwnership(manifests, files) {
    const byPath = new Map();
    for (const manifest of manifests)
        for (const entry of ownedEntries(manifest)) {
            if (!byPath.has(entry.path))
                byPath.set(entry.path, new Set());
            byPath.get(entry.path).add(entry.pkg);
        }
    const ownersOf = file => {
        let current = file;
        while (current && current !== ".") {
            if (byPath.has(current))
                return [...byPath.get(current)].sort();
            const parent = path.posix.dirname(current);
            if (parent === current)
                break;
            current = parent;
        }
        return [];
    };
    const owner = new Map();
    const orphans = [];
    const doubles = [];
    for (const file of files) {
        const owners = ownersOf(file);
        if (owners.length === 0)
            orphans.push(file);
        else if (owners.length > 1)
            doubles.push({ file, owners });
        if (owners.length)
            owner.set(file, owners[0]);
    }
    const dirOwners = new Map();
    for (const file of files) {
        if (!owner.has(file) || !file.endsWith(".qml"))
            continue;
        const dir = path.posix.dirname(file);
        if (!dirOwners.has(dir))
            dirOwners.set(dir, new Set());
        dirOwners.get(dir).add(owner.get(file));
    }
    return { byPath, owner, orphans, doubles, dirOwners, ownersOf };
}

function resolveImport(imp, fromFile, ownership, fileSet) {
    let target;
    if (imp.kind === "qs") {
        const parts = imp.target.split(".");
        if (parts[0] === "services")
            return null;
        target = parts.join("/");
    } else {
        target = path.posix.normalize(path.posix.join(path.posix.dirname(fromFile), imp.target));
        if (target.startsWith("..") || path.posix.isAbsolute(target))
            return null;
    }
    if (fileSet.has(target)) {
        const owner = ownership.owner.get(target);
        return owner ? { target, owners: [owner] } : null;
    }
    const dir = ownership.dirOwners.get(target);
    if (dir && dir.size)
        return { target, owners: [...dir].sort() };
    const fallback = ownership.ownersOf(target);
    return fallback.length ? { target, owners: fallback } : null;
}

function readText(root, file) {
    return fs.readFileSync(path.join(root, file), "utf8");
}

function scan(root) {
    const { manifests, problems } = loadManifests(root);
    const files = listFiles(root);
    const fileSet = new Set(files);
    const ownership = buildOwnership(manifests, files);
    const packages = new Map(manifests.map(m => [m.data.name, m]));
    const names = new Set(packages.keys());

    const singletons = new Map();
    for (const file of files) {
        if (path.posix.basename(file) !== "qmldir")
            continue;
        const dir = path.posix.dirname(file);
        for (const entry of parseQmldir(readText(root, file))) {
            const qml = dir === "." ? entry.file : `${dir}/${entry.file}`;
            if (singletons.has(entry.name))
                problems.push(`R12 singleton ${entry.name} is declared in two qmldir files`);
            else
                singletons.set(entry.name, { name: entry.name, file: qml, owner: ownership.owner.get(qml) || null });
        }
    }

    const namespaces = [];
    for (const manifest of manifests)
        for (const namespace of manifest.data.config.namespace)
            namespaces.push({ namespace, pkg: manifest.data.name });

    const model = {
        root, manifests, packages, names, files, fileSet, ownership, singletons, namespaces,
        problems, edges: [], writes: [], ipc: [], componentHits: [], hostHits: [], testReads: [], texts: new Map()
    };

    const singletonNames = [...singletons.keys()];
    for (const file of files) {
        const ext = path.posix.extname(file);
        const pkg = ownership.owner.get(file);
        if (!pkg || (ext !== ".qml" && ext !== ".js"))
            continue;
        const raw = readText(root, file);
        const inTests = file.startsWith("tests/");
        const keep = stripCode(raw, true);
        const bare = stripCode(raw, false);

        if (inTests) {
            for (const use of findPathStrings(keep)) {
                const owners = ownership.ownersOf(use.path);
                for (const owner of owners)
                    if (owner !== pkg)
                        model.testReads.push({ from: pkg, to: owner, file, line: use.line, detail: use.path });
            }
            continue;
        }
        if (!CODE_DIRS.some(dir => file.startsWith(`${dir}/`)) && !SCAN_FILES.includes(file))
            continue;

        for (const imp of parseImports(keep)) {
            if (file.startsWith("components/") && imp.kind === "qs" && /^(services|modules)(\.|$)/.test(imp.target))
                model.componentHits.push({ file, line: imp.line, what: `imports qs.${imp.target.split(".").slice(0, 2).join(".")}` });
            const resolved = resolveImport(imp, file, ownership, fileSet);
            if (!resolved)
                continue;
            for (const owner of resolved.owners)
                if (owner !== pkg)
                    model.edges.push({ from: pkg, to: owner, kind: "import", file, line: imp.line, detail: imp.kind === "qs" ? `import qs.${imp.target}` : `import "${imp.target}"` });
            if (HOST_FILES.includes(file) && /^modules\//.test(resolved.target) && resolved.owners.some(o => o !== "core" && o !== pkg))
                model.hostHits.push({ file, line: imp.line, target: resolved.target });
        }

        if (ext === ".qml") {
            for (const use of findSingletonUses(bare, singletonNames)) {
                const single = singletons.get(use.name);
                if (!single.owner || single.owner === pkg)
                    continue;
                model.edges.push({ from: pkg, to: single.owner, kind: "singleton", file, line: use.line, detail: use.name, singleton: use.name });
            }
            for (const write of findForeignWrites(bare, singletonNames)) {
                const single = singletons.get(write.name);
                if (single.owner && single.owner !== pkg)
                    model.writes.push({ from: pkg, to: single.owner, file, line: write.line, detail: `${write.name}.${write.property}` });
            }
            for (const target of findIpcTargets(keep))
                model.ipc.push({ name: target.name, file, line: target.line, pkg });
            if (file.startsWith("components/"))
                for (const word of FORBIDDEN_IN_COMPONENTS) {
                    const pattern = new RegExp(`(?<![\\w.$])${word}\\b`);
                    const at = lineIndex(bare);
                    const m = pattern.exec(bare);
                    if (m)
                        model.componentHits.push({ file, line: at(m.index), what: `uses ${word}` });
                }
        }

        for (const read of findConfigReads(keep)) {
            const owner = namespaceOwner(read.key, namespaces);
            if (owner && owner.pkg === pkg)
                continue;
            model.edges.push({ from: pkg, to: owner ? owner.pkg : null, kind: "config", file, line: read.line, detail: read.key, namespace: owner ? owner.namespace : read.key.split(".")[0] });
        }

        for (const use of findScriptUses(keep)) {
            const owners = ownership.ownersOf(use.path.startsWith("bin/") ? `src/${use.path.slice(4)}.c` : use.path);
            for (const owner of owners)
                if (owner !== pkg)
                    model.edges.push({ from: pkg, to: owner, kind: "script", file, line: use.line, detail: use.path });
        }
    }
    return model;
}

function allowedTargets(model, pkg) {
    const manifest = model.packages.get(pkg);
    const set = new Set([pkg]);
    if (manifest) {
        for (const name of manifest.data.requires.packages)
            set.add(name);
        for (const name of manifest.data.requires.optional)
            set.add(name);
    }
    return set;
}

function evaluate(model) {
    const violations = new Set(model.problems);
    const warnings = new Set();
    const manifests = model.manifests;

    const seenNames = new Map();
    for (const manifest of manifests) {
        const name = manifest.data.name;
        if (seenNames.has(name))
            violations.add(`R12 ${manifest.file} repeats the package name ${name}`);
        seenNames.set(name, manifest.file);
    }

    for (const manifest of manifests) {
        const data = manifest.data;
        for (const list of ["packages", "optional"])
            for (const name of data.requires[list]) {
                if (!model.names.has(name))
                    violations.add(`R12 ${manifest.file} requires the unknown package ${name}`);
                else if (name === data.name)
                    violations.add(`R12 ${manifest.file} requires itself`);
            }
        for (const entry of ownedEntries(manifest))
            if (!model.fileSet.has(entry.path) && !model.files.some(file => file.startsWith(`${entry.path}/`)))
                violations.add(`R12 ${manifest.file} owns ${entry.path}, which does not exist`);
        for (const name of data.provides.singletons) {
            const single = model.singletons.get(name);
            if (!single)
                violations.add(`R12 ${manifest.file} provides the unknown singleton ${name}`);
            else if (single.owner !== data.name)
                violations.add(`R12 ${manifest.file} provides ${name}, which ${single.owner || "nobody"} owns`);
        }
        if (data.name === "core" && data.layer !== 0)
            violations.add(`R12 ${manifest.file} must be layer 0`);
        if (data.name !== "core" && data.layer === 0)
            violations.add(`R12 ${manifest.file} is layer 0, which belongs to core`);
    }

    const claimedIpc = new Map();
    for (const manifest of manifests)
        for (const name of manifest.data.provides.ipc) {
            if (claimedIpc.has(name))
                violations.add(`R6 ${name} is declared by both ${claimedIpc.get(name)} and ${manifest.data.name}`);
            else
                claimedIpc.set(name, manifest.data.name);
        }
    const seenTargets = new Map();
    for (const target of model.ipc) {
        if (seenTargets.has(target.name))
            violations.add(`R6 target ${target.name} is defined twice (${seenTargets.get(target.name)}, ${target.file})`);
        seenTargets.set(target.name, target.file);
        const declared = claimedIpc.get(target.name);
        if (!declared)
            violations.add(`R6 target ${target.name} in ${target.file} is declared by no package`);
        else if (declared !== target.pkg)
            violations.add(`R6 target ${target.name} lives in ${target.file} (${target.pkg}) but ${declared} declares it`);
    }
    for (const [name, pkg] of claimedIpc)
        if (!seenTargets.has(name))
            violations.add(`R6 ${pkg} declares the target ${name}, which no file defines`);

    for (const file of model.ownership.orphans)
        violations.add(`R1 ${file} is owned by no package`);
    for (const double of model.ownership.doubles)
        violations.add(`R1 ${double.file} is owned by ${double.owners.join(" and ")}`);

    const edgesOf = pkg => {
        const manifest = model.packages.get(pkg);
        return manifest ? [...manifest.data.requires.packages, ...manifest.data.requires.optional].filter(name => model.names.has(name)) : [];
    };
    for (const group of findCycles([...model.names].sort(), edgesOf))
        violations.add(`R8 requires form a cycle: ${group.join(", ")}`);
    for (const manifest of manifests)
        for (const name of edgesOf(manifest.data.name)) {
            const dependency = model.packages.get(name);
            if (dependency && manifest.data.layer <= dependency.data.layer)
                violations.add(`R8 ${manifest.data.name} (layer ${manifest.data.layer}) requires ${name} (layer ${dependency.data.layer})`);
        }

    const reported = new Set();
    for (const edge of model.edges) {
        const manifest = model.packages.get(edge.from);
        if (!manifest)
            continue;
        const allowed = allowedTargets(model, edge.from);
        if (edge.kind === "import") {
            if (!allowed.has(edge.to))
                reported.add(`R2 ${edge.file} imports ${edge.to} without requiring it`);
        } else if (edge.kind === "singleton") {
            if (!allowed.has(edge.to)) {
                reported.add(`R3 ${edge.file} uses ${edge.detail} of ${edge.to} without requiring it`);
            } else {
                const owner = model.packages.get(edge.to);
                if (owner && !owner.data.provides.singletons.includes(edge.detail))
                    reported.add(`R3 ${edge.file} uses ${edge.detail}, private to ${edge.to}`);
            }
        } else if (edge.kind === "config") {
            if (edge.to === null) {
                reported.add(`R5 ${edge.file} reads ${edge.namespace}, which no package owns`);
            } else if (edge.to !== edge.from && !readsCover(manifest.data.config.reads, edge.detail)) {
                reported.add(`R5 ${edge.file} reads ${edge.namespace} of ${edge.to}`);
            }
        } else if (edge.kind === "script") {
            if (!allowed.has(edge.to))
                warnings.add(`R7 ${edge.file} runs ${edge.detail} of ${edge.to} without requiring it`);
        }
    }
    for (const entry of reported)
        violations.add(entry);

    for (const write of model.writes)
        warnings.add(`R4 ${write.file}:${write.line} writes ${write.detail} of ${write.to}`);
    for (const read of model.testReads)
        if (!allowedTargets(model, read.from).has(read.to))
            warnings.add(`R10 ${read.file} reads ${read.detail} of ${read.to}`);

    for (const hit of model.hostHits)
        violations.add(`R11 ${hit.file} imports ${hit.target}`);
    for (const hit of model.componentHits)
        violations.add(`R9 ${hit.file} ${hit.what}`);

    return { violations: [...violations].sort(), warnings: [...warnings].sort() };
}

function readBaseline(root) {
    const file = path.join(root, BASELINE_FILE);
    if (!fs.existsSync(file))
        return [];
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    return Array.isArray(parsed.violations) ? parsed.violations : [];
}

function writeBaseline(root, violations) {
    const body = `{\n  "violations": [\n${violations.map(v => `    ${JSON.stringify(v)}`).join(",\n")}\n  ]\n}\n`;
    fs.writeFileSync(path.join(root, BASELINE_FILE), body);
}

function compare(violations, baseline) {
    const known = new Set(baseline);
    const current = new Set(violations);
    return {
        added: violations.filter(v => !known.has(v)),
        fixed: baseline.filter(v => !current.has(v))
    };
}

function packageEdges(model) {
    const table = new Map();
    for (const edge of model.edges) {
        if (edge.kind !== "import" && edge.kind !== "singleton")
            continue;
        const key = `${edge.from}\t${edge.to}`;
        if (!table.has(key))
            table.set(key, new Set());
        table.get(key).add(edge.file);
    }
    return table;
}

function renderMatrix(model) {
    const names = [...model.names].sort((a, b) => {
        const la = model.packages.get(a).data.layer;
        const lb = model.packages.get(b).data.layer;
        return la - lb || a.localeCompare(b);
    });
    const table = packageEdges(model);
    const width = Math.max(...names.map(n => n.length));
    const lines = [];
    const header = names.map((_, i) => String(i + 1).padStart(3)).join("");
    lines.push(`${"".padEnd(width + 5)}${header}`);
    names.forEach((row, r) => {
        const allowed = allowedTargets(model, row);
        const cells = names.map(column => {
            if (row === column)
                return "  -";
            const files = table.get(`${row}\t${column}`);
            if (!files)
                return allowed.has(column) ? "  o" : "  .";
            const text = String(files.size);
            return (allowed.has(column) ? text.padStart(3) : `${text}!`.padStart(3));
        });
        lines.push(`${String(r + 1).padStart(2)}  ${row.padEnd(width)} ${cells.join("")}`);
    });
    lines.push("");
    lines.push("rows depend on columns; a number is how many files of the row reach the column");
    lines.push("! not declared in requires   o declared and unused   . no dependency   - itself");
    return lines.join("\n");
}

function renderExplain(model, pkg, showAll) {
    const manifest = model.packages.get(pkg);
    if (!manifest)
        return null;
    const allowed = allowedTargets(model, pkg);
    const optional = new Set(manifest.data.requires.optional);
    const byTarget = new Map();
    for (const edge of model.edges) {
        if (edge.from !== pkg)
            continue;
        const key = edge.to === null ? "(no owner)" : edge.to;
        if (!byTarget.has(key))
            byTarget.set(key, new Map());
        const group = byTarget.get(key);
        const id = `${edge.file}\t${edge.kind}\t${edge.detail}`;
        if (group.has(id))
            group.get(id).count++;
        else
            group.set(id, { ...edge, count: 1 });
    }
    const declaredOf = key => (key === "(no owner)" ? "NOT DECLARED" : allowed.has(key) ? (optional.has(key) ? "optional" : "declared") : "NOT DECLARED");
    const lines = [];
    lines.push(`${pkg}: ${manifest.data.summary} (layer ${manifest.data.layer})`);
    lines.push(`requires ${manifest.data.requires.packages.join(", ") || "nothing"}${optional.size ? `; optional ${[...optional].join(", ")}` : ""}`);
    const keys = [...byTarget.keys()].sort((a, b) => {
        const open = x => (declaredOf(x) === "NOT DECLARED" ? 0 : 1);
        return open(a) - open(b) || byTarget.get(b).size - byTarget.get(a).size || a.localeCompare(b);
    });
    for (const key of keys) {
        const rows = [...byTarget.get(key).values()].sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line);
        lines.push("");
        lines.push(`needs ${key} (${declaredOf(key)}), ${rows.length} place${rows.length === 1 ? "" : "s"}`);
        const shown = showAll ? rows : rows.slice(0, 6);
        for (const row of shown)
            lines.push(`  ${row.file}:${row.line}  ${row.kind}  ${row.detail}${row.count > 1 ? `  (x${row.count})` : ""}`);
        if (shown.length < rows.length)
            lines.push(`  and ${rows.length - shown.length} more (--all lists every one)`);
    }
    const unused = [...allowed].filter(name => name !== pkg && !byTarget.has(name));
    if (unused.length) {
        lines.push("");
        lines.push(`declared but not used by any file: ${unused.sort().join(", ")}`);
    }
    const usedBy = new Map();
    for (const edge of model.edges)
        if (edge.to === pkg && edge.from !== pkg)
            usedBy.set(edge.from, (usedBy.get(edge.from) || 0) + 1);
    if (usedBy.size) {
        lines.push("");
        lines.push(`used by ${[...usedBy].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).map(([name, count]) => `${name} (${count})`).join(", ")}`);
    }
    return lines.join("\n");
}

function usage() {
    return [
        "usage: check-modules.js [--root <dir>] [--matrix | --explain <package> [--all] | --write-baseline | --warnings | --list]",
        "",
        "  (none)             check the module boundaries against modules.baseline.json",
        "  --matrix           package by package dependency matrix",
        "  --explain <pkg>    what a package needs, with file and line",
        "  --all              with --explain, list every reference",
        "  --warnings         also print the R4, R7 and R10 warnings",
        "  --write-baseline   record today's violations as the new baseline",
        "  --list             package names, one per line"
    ].join("\n");
}

function parseArguments(argv) {
    const options = { root: path.resolve(__dirname, ".."), mode: "check", explain: null, all: false, warnings: false };
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === "--root") {
            options.root = path.resolve(argv[++i] || "");
        } else if (arg === "--matrix") {
            options.mode = "matrix";
        } else if (arg === "--explain") {
            options.mode = "explain";
            options.explain = argv[++i] || "";
        } else if (arg === "--all") {
            options.all = true;
        } else if (arg === "--warnings") {
            options.warnings = true;
        } else if (arg === "--write-baseline") {
            options.mode = "baseline";
        } else if (arg === "--list") {
            options.mode = "list";
        } else if (arg === "-h" || arg === "--help") {
            options.mode = "help";
        } else {
            return { error: `unknown option ${arg}` };
        }
    }
    return options;
}

function run(argv, write) {
    const options = parseArguments(argv);
    if (options.error) {
        write(`check-modules.js: ${options.error}\n${usage()}`, true);
        return 2;
    }
    if (options.mode === "help") {
        write(usage());
        return 0;
    }
    const model = scan(options.root);
    if (options.mode === "list") {
        write([...model.names].sort().join("\n"));
        return 0;
    }
    if (options.mode === "matrix") {
        write(renderMatrix(model));
        return 0;
    }
    if (options.mode === "explain") {
        const text = renderExplain(model, options.explain, options.all);
        if (text === null) {
            write(`check-modules.js: no package ${options.explain || "(none given)"}; packages are ${[...model.names].sort().join(", ")}`, true);
            return 2;
        }
        write(text);
        return 0;
    }
    const result = evaluate(model);
    if (options.mode === "baseline") {
        writeBaseline(options.root, result.violations);
        write(`wrote ${BASELINE_FILE} with ${result.violations.length} violations`);
        return 0;
    }
    const baseline = readBaseline(options.root);
    const { added, fixed } = compare(result.violations, baseline);
    if (options.warnings)
        for (const warning of result.warnings)
            write(`warning ${warning}`);
    write(`modules: ${model.names.size} packages, ${model.files.length} files, ${result.violations.length} violations known, ${result.warnings.length} warnings`);
    if (fixed.length)
        write(`${fixed.length} baseline entries are fixed; run check-modules.js --write-baseline to drop them`);
    if (added.length) {
        write(`${added.length} new violations:`, true);
        for (const violation of added.slice(0, SHOW_LIMIT))
            write(`  ${violation}`, true);
        if (added.length > SHOW_LIMIT)
            write(`  and ${added.length - SHOW_LIMIT} more`, true);
        write("fix them, or run check-modules.js --explain <package> to see what it reaches for", true);
        return 1;
    }
    write("no new violations");
    return 0;
}

module.exports = {
    stripCode, lineIndex, parseImports, parseQmldir, findSingletonUses, findForeignWrites, findConfigReads,
    findIpcTargets, findScriptUses, findPathStrings, namespaceOwner, readsCover, findCycles, validateManifest,
    buildOwnership, scan, evaluate, compare, renderMatrix, renderExplain, run
};

if (require.main === module) {
    const write = (text, error) => (error ? process.stderr : process.stdout).write(`${text}\n`);
    process.exit(run(process.argv.slice(2), write));
}
