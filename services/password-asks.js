.pragma library

const SHELLS = ["sh", "bash", "zsh", "fish", "dash", "ksh", "nu", "xonsh", "elvish", "env", "timeout", "nice", "nohup", "setsid", "script", "stdbuf", "systemd-run", "uv", "npx"];

const TERMINALS = ["kitty", "foot", "footclient", "alacritty", "wezterm-gui", "wezterm", "ghostty", "konsole", "gnome-terminal-server", "xterm", "st", "urxvt", "terminator", "tilix", "rio", "warp"];

const INTERPRETERS = ["node", "bun", "deno", "python", "python3", "ruby", "perl"];

const SSH_TAKES_VALUE = "BbcDEeFIiJLlmOoPpQRSWw";

const GIT_TAKES_VALUE = ["-C", "-c", "--exec-path", "--git-dir", "--work-tree", "--namespace", "--config-env", "--super-prefix"];

function basename(path) {
    const text = String(path ?? "");
    return text.slice(text.lastIndexOf("/") + 1);
}

function unquote(text) {
    return String(text ?? "").replace(/^[\s'"“”‘’]+|[\s'"“”‘’]+$/g, "");
}

function lowerFirst(text) {
    return text ? text.charAt(0).toLowerCase() + text.slice(1) : "";
}

function upperFirst(text) {
    return text ? text.charAt(0).toUpperCase() + text.slice(1) : "";
}

function tilde(path, home) {
    if (home && (path === home || path.startsWith(home + "/")))
        return "~" + path.slice(home.length);
    return path;
}

function quoted(text) {
    const match = String(text ?? "").match(/[“"]\s*([^”"]+?)\s*[”"]/);
    return match ? match[1] : "";
}

function programOf(entry) {
    const args = entry?.args ?? [];
    const first = basename(args[0] ?? "");
    if (INTERPRETERS.includes(first.replace(/[\d.]+$/, "")) && args[1] && !args[1].startsWith("-"))
        return basename(args[1]);
    if (first.endsWith(":"))
        return first.slice(0, -1);
    return first;
}

function parseProcesses(text) {
    const table = {};
    for (const line of String(text ?? "").split("\n")) {
        const match = line.match(/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/);
        if (!match)
            continue;
        table[match[1]] = {
            pid: Number(match[1]),
            ppid: Number(match[2]),
            age: Number(match[3]),
            args: match[4].trim().split(/\s+/)
        };
    }
    return table;
}

function parseSockets(text) {
    const rows = [];
    for (const line of String(text ?? "").split("\n")) {
        const fields = line.trim().split(/\s+/);
        if (fields.length < 8 || !fields[0].startsWith("u_"))
            continue;
        const pids = [];
        const pattern = /pid=(\d+)/g;
        for (let match = pattern.exec(line); match; match = pattern.exec(line))
            pids.push(Number(match[1]));
        rows.push({
            path: fields[4],
            inode: fields[5],
            peer: fields[7],
            pids: pids
        });
    }
    return rows;
}

function descends(pid, ancestor, table) {
    let at = table[pid];
    for (let step = 0; at && step < 64; step++) {
        if (at.ppid === ancestor)
            return true;
        at = table[at.ppid];
    }
    return false;
}

function chainOf(pid, table) {
    const chain = [];
    let at = table[pid];
    while (at && at.pid > 1 && chain.length < 12) {
        chain.push(at);
        at = table[at.ppid];
    }
    return chain;
}

function agentOf(requesterPid, requester, table) {
    if (/^pinentry/.test(requester ?? ""))
        return table[requesterPid]?.ppid ?? 0;
    return requesterPid;
}

function callerOf(socketText, processText, requesterPid, requester) {
    const table = parseProcesses(processText);
    const agent = agentOf(requesterPid, requester, table);
    if (!(agent > 0))
        return [];
    const rows = parseSockets(socketText);
    const served = new Set(rows.filter(row => row.path !== "*" && row.pids.includes(agent)).map(row => row.peer));
    const clients = [];
    for (const row of rows) {
        if (!served.has(row.inode))
            continue;
        for (const pid of row.pids)
            if (pid !== agent && pid !== requesterPid && !descends(pid, agent, table) && table[pid] && !clients.includes(pid))
                clients.push(pid);
    }
    clients.sort((a, b) => table[a].age - table[b].age);
    return clients.length ? chainOf(clients[0], table) : [];
}

function sshTarget(args) {
    let index = 1;
    let user = "";
    while (index < args.length) {
        const arg = args[index];
        if (arg === "--") {
            index += 1;
            break;
        }
        if (!arg.startsWith("-") || arg === "-")
            break;
        let skip = 1;
        for (let at = 1; at < arg.length; at++) {
            if (!SSH_TAKES_VALUE.includes(arg[at]))
                continue;
            const value = at === arg.length - 1 ? args[index + 1] : arg.slice(at + 1);
            if (at === arg.length - 1)
                skip = 2;
            if (arg[at] === "l")
                user = value ?? "";
            break;
        }
        index += skip;
    }
    let destination = args[index] ?? "";
    const url = destination.match(/^ssh:\/\/(?:([^@/]+)@)?([^:/]+)(?::\d+)?(\/.*)?$/);
    if (url)
        return {
            user: url[1] ?? user,
            host: url[2],
            command: args.slice(index + 1)
        };
    const at = destination.lastIndexOf("@");
    if (at >= 0) {
        user = destination.slice(0, at);
        destination = destination.slice(at + 1);
    }
    return {
        user: user,
        host: destination,
        command: args.slice(index + 1)
    };
}

function gitService(command) {
    const words = command.length === 1 ? command[0].split(/\s+/) : command;
    let service = words[0] ?? "";
    let rest = words.slice(1);
    if (service === "git" && rest.length) {
        service = "git-" + rest[0];
        rest = rest.slice(1);
    }
    if (!["git-receive-pack", "git-upload-pack", "git-upload-archive"].includes(service))
        return null;
    const path = unquote(rest.join(" ")).replace(/^~?\/+/, "").replace(/\.git\/?$/, "");
    return {
        push: service === "git-receive-pack",
        path: path
    };
}

function gitVerb(args) {
    for (let index = 1; index < args.length; index++) {
        const arg = args[index];
        if (GIT_TAKES_VALUE.includes(arg)) {
            index += 1;
            continue;
        }
        if (arg.startsWith("-"))
            continue;
        return arg;
    }
    return "";
}

function outermost(chain, from, test) {
    let index = from;
    while (index + 1 < chain.length && test(chain[index + 1]))
        index += 1;
    return index;
}

function originOf(chain, from) {
    for (let index = from + 1; index < chain.length; index++) {
        const name = programOf(chain[index]);
        if (SHELLS.includes(name) || name === "git" || name === "ssh")
            continue;
        if (TERMINALS.includes(name) || name === "tmux" || name === "systemd" || name === "sshd" || name === "init")
            return "";
        if (name === "qs" || name === "quickshell")
            return "banditshell";
        return name;
    }
    return "";
}

function gitPhrase(verb, push, place) {
    switch (verb) {
    case "push":
        return `push to ${place}`;
    case "pull":
        return `pull from ${place}`;
    case "fetch":
    case "remote":
        return `fetch from ${place}`;
    case "clone":
        return `clone ${place}`;
    case "ls-remote":
        return `check ${place}`;
    case "submodule":
        return `update submodules from ${place}`;
    default:
        return push ? `push to ${place}` : `fetch from ${place}`;
    }
}

function causeOf(chain) {
    if (!chain || !chain.length)
        return null;
    const sshAt = chain.findIndex(entry => programOf(entry) === "ssh");
    if (sshAt >= 0) {
        const target = sshTarget(chain[sshAt].args);
        const service = gitService(target.command);
        const gitAt = chain.findIndex((entry, index) => index > sshAt && programOf(entry) === "git");
        const host = target.host || "a server";
        if (service || gitAt >= 0) {
            const top = gitAt >= 0 ? outermost(chain, gitAt, entry => programOf(entry) === "git") : sshAt;
            const verb = gitAt >= 0 ? gitVerb(chain[top].args) : "";
            const place = service?.path ? `${host}/${service.path}` : host;
            return {
                who: originOf(chain, top) || "git",
                doing: gitPhrase(verb, service?.push ?? verb === "push", place)
            };
        }
        const wrapperAt = sshAt + 1 < chain.length && ["scp", "sftp", "rsync", "sshfs"].includes(programOf(chain[sshAt + 1])) ? sshAt + 1 : -1;
        if (wrapperAt >= 0) {
            const tool = programOf(chain[wrapperAt]);
            return {
                who: originOf(chain, wrapperAt) || tool,
                doing: tool === "rsync" ? `sync files with ${host}` : tool === "sshfs" ? `mount ${host}` : `copy files with ${host}`
            };
        }
        return {
            who: originOf(chain, sshAt) || "ssh",
            doing: `connect to ${host}`
        };
    }
    const first = programOf(chain[0]);
    if (first === "ssh-add")
        return {
            who: "ssh-add",
            doing: "load it into the agent"
        };
    if (first === "gpg" || first === "gpg2") {
        const gitAt = chain.findIndex(entry => programOf(entry) === "git");
        const args = chain[0].args;
        if (gitAt >= 0) {
            const top = outermost(chain, gitAt, entry => programOf(entry) === "git");
            return {
                who: originOf(chain, top) || "git",
                doing: gitVerb(chain[top].args) === "tag" ? "sign a tag" : "sign a commit"
            };
        }
        const decrypt = args.some(arg => arg === "-d" || arg === "--decrypt");
        const sign = args.some(arg => /^--(clear|detach-)?sign$/.test(arg) || /^-[a-zA-Z]*s[a-zA-Z]*$/.test(arg));
        return {
            who: originOf(chain, 0) || "gpg",
            doing: decrypt ? "decrypt something" : sign ? "sign something" : "use it"
        };
    }
    return {
        who: originOf(chain, 0) || first,
        doing: "use it"
    };
}

function commandOf(chain) {
    return chain && chain.length ? chain[0].args.join(" ") : "";
}

function identityName(identity) {
    return String(identity?.name ?? "").replace(/^unix-(user|group):/, "");
}

function pkexecRun(message) {
    const match = String(message ?? "").match(/run [`'‘"](.+?)['’"] as (?:the super user|user (\S+?))\.?$/);
    if (!match)
        return null;
    const words = match[1].split(/\s+/);
    words[0] = basename(words[0]);
    return {
        command: words.join(" "),
        program: words[0],
        as: match[2] ?? "root"
    };
}

function polkitNeed(message) {
    const text = String(message ?? "");
    const rest = text.replace(/^Authentication is (?:required|needed) (?:in order )?to /i, "").replace(/\.$/, "");
    return rest === text ? "" : rest;
}

function wrong(warning, noun) {
    if (/incorrect|did not work|invalid|wrong/i.test(warning ?? ""))
        return `That ${noun} did not work. Try again.`;
    return warning ?? "";
}

function rememberLabel(label) {
    if (/automatically unlock/i.test(label ?? ""))
        return "Unlock it on its own whenever I'm logged in";
    return label ?? "";
}

function keyringName(name) {
    return /keyring$/i.test(name) ? `“${name}”` : `the “${name}” keyring`;
}

function askedBy(cause, fallback) {
    return cause ? `${cause.who}, to ${cause.doing}` : fallback;
}

function card(fields) {
    return Object.assign({
        family: "keyring",
        glyph: "password",
        secret: "Password",
        facts: [],
        hint: "",
        placeholder: "Password",
        warning: "",
        details: []
    }, fields);
}

function describePolkit(ask) {
    const who = identityName(ask.identity) || ask.user || "";
    const self = !ask.identity || who === ask.user || (!!ask.user && ask.identity.displayName === ask.user);
    const root = who === "root";
    const run = pkexecRun(ask.message);
    const need = polkitNeed(ask.message);
    const facts = [];
    if (who)
        facts.push(["Account", who]);
    if (ask.label)
        facts.push(["Asked by", `banditshell, to ${lowerFirst(ask.label)}`]);
    else if (need && !run)
        facts.push(["Wants to", need]);
    if (run)
        facts.push([`As ${run.as}`, run.command]);
    if (!ask.label && !need && !run && ask.message)
        facts.push(["Wants to", ask.message]);
    const details = [];
    if (ask.actionId)
        details.push(["Polkit action", ask.actionId]);
    if (ask.message)
        details.push(["Polkit says", ask.message]);
    return card({
        family: "admin",
        glyph: "admin_panel_settings",
        secret: root ? "The root password" : self ? "Your sudo password" : `${who}'s password`,
        facts: facts,
        hint: root ? "This computer asks for root's password here, not yours." : self ? "" : `${who} is an administrator on this computer.`,
        placeholder: "Password",
        warning: wrong(ask.warning, "password"),
        details: details
    });
}

function waiting(ask) {
    const details = [["Prompt from", ask.requester || "an agent"]];
    if (ask.command)
        details.push(["Command waiting", ask.command]);
    return details;
}

function describeSshKey(ask, path, label) {
    const shown = path ? tilde(path, ask.home) : label;
    return card({
        family: "ssh",
        glyph: "vpn_key",
        secret: "SSH key passphrase",
        facts: [["Key", shown || "a key the ssh agent holds"], ["Asked by", askedBy(ask.cause, "a program signing in over ssh")]],
        hint: "Not your login password. It was set when the key was made.",
        placeholder: "Passphrase",
        warning: wrong(ask.warning, "passphrase"),
        details: waiting(ask)
    });
}

function describeGpg(ask) {
    const text = ask.description ?? "";
    const sshKey = text.match(/passphrase for the ssh key\s+(\S+)\s*\(([^)]*)\)/i);
    if (sshKey)
        return describeSshKey(ask, "", sshKey[2] || sshKey[1]);
    const fresh = /new key|protect/i.test(text) && !/unlock/i.test(text);
    const uid = (text.match(/"([^"]+)"/) ?? [])[1] ?? "";
    const person = uid.replace(/\s*<[^>]*>\s*/, "").replace(/\s*\([^)]*\)\s*/, "").trim();
    const id = ((text.match(/ID\s+([0-9A-F]{8,40})/i) ?? [])[1] ?? "").slice(-8);
    const key = [person, id].filter(Boolean).join(", ");
    return card({
        family: "gpg",
        glyph: "signature",
        secret: fresh ? "New GPG passphrase" : "GPG key passphrase",
        facts: [["Key", fresh ? "a new GPG key" : key || "your GPG key"], ["Asked by", askedBy(ask.cause, "gpg")]],
        hint: fresh ? "Choose one. You type it whenever the key is used." : "Not your login password. It was set when the key was made.",
        placeholder: fresh ? "New passphrase" : "Passphrase",
        warning: wrong(ask.warning, "passphrase"),
        details: waiting(ask)
    });
}

function describeKeyring(ask) {
    const title = ask.title ?? "";
    const message = ask.message ?? "";
    const description = ask.description ?? "";
    const details = [["Prompt from", ask.requester || "the keyring"]];
    const name = quoted(description) || quoted(message);
    const app = "an app that wants a saved password";
    if (/ssh/.test(ask.requester ?? "")) {
        const path = (description.match(/passphrase for (?:key )?['"]?(\S+?)['"]?:/) ?? [])[1] ?? "";
        return describeSshKey(ask, path, "");
    }
    if (/^pinentry/.test(ask.requester ?? ""))
        return describeGpg(ask);
    if (ask.kind === "confirm")
        return card({
            glyph: "lock_open",
            secret: title || "Allow this?",
            hint: description || message,
            placeholder: "",
            warning: ask.warning ?? "",
            details: details
        });
    if (/login keyring/i.test(title)) {
        const changed = /no longer matches/i.test(description);
        return card({
            secret: "Login keyring password",
            facts: [["Keyring", "login"], ["Asked by", app]],
            hint: changed ? "Your login password changed after this keyring was made. Type the old one." : "Usually your login password. Face unlock leaves it locked.",
            placeholder: changed ? "Old login password" : "Password",
            warning: wrong(ask.warning, "password"),
            details: details
        });
    }
    if (/unlock (private key|certificate|public key)/i.test(title)) {
        const what = (title.match(/unlock (.+)$/i) ?? [])[1] ?? "key";
        return card({
            glyph: "encrypted",
            secret: `${upperFirst(what)} password`,
            facts: [[upperFirst(what.split(" ").pop()), name || `a ${what} in your keyring`], ["Asked by", "an app that wants to use it"]],
            hint: `Set when the ${what} was stored.`,
            placeholder: "Password",
            warning: wrong(ask.warning, "password"),
            details: details
        });
    }
    if (ask.passwordNew || /new keyring|new password/i.test(title)) {
        const changing = /change/i.test(title + description);
        return card({
            secret: changing ? "New keyring password" : "Password for a new keyring",
            facts: [["Keyring", name ? (changing ? name : `${name}, new`) : "a new keyring"], ["Asked by", changing ? "an app changing its password" : "an app that wants somewhere to keep passwords"]],
            hint: "Choose one. You type it whenever this keyring is locked.",
            placeholder: "New password",
            warning: ask.warning ?? "",
            details: details
        });
    }
    if (/change/i.test(title))
        return card({
            secret: "Current keyring password",
            facts: [["Keyring", name || "a keyring"], ["Asked by", "an app changing its password"]],
            hint: "The password it has now, before the change.",
            placeholder: "Current password",
            warning: wrong(ask.warning, "password"),
            details: details
        });
    if (/unlock keyring/i.test(title) || /keyring/i.test(description))
        return card({
            secret: "Keyring password",
            facts: [["Keyring", name || "a locked keyring"], ["Asked by", app]],
            hint: name === "login" ? "Usually your login password." : "The password chosen when this keyring was made.",
            placeholder: "Password",
            warning: wrong(ask.warning, "password"),
            details: details
        });
    return card({
        family: "other",
        secret: title || "Password",
        hint: [message, description].filter(Boolean).join(" "),
        warning: ask.warning ?? "",
        details: details
    });
}

function describeRequest(ask) {
    return card({
        family: ask.family || "wifi",
        glyph: ask.glyph || "wifi_password",
        secret: ask.secret || ask.title || "Password",
        facts: ask.facts || [],
        hint: ask.hint || "",
        placeholder: ask.placeholder || "Password",
        warning: ask.warning ?? ""
    });
}

function describe(ask) {
    const told = ask.source === "polkit" ? describePolkit(ask) : ask.source === "request" ? describeRequest(ask) : describeKeyring(ask);
    const original = [ask.title, ask.message, ask.description].filter(text => text && !told.details.some(([, said]) => said === text));
    if (ask.source === "keyring" && original.length)
        told.details.push(["Their words", original.join("\n")]);
    told.choice = rememberLabel(ask.choiceLabel);
    return told;
}
