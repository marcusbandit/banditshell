.pragma library

const SHELLS = ["sh", "bash", "zsh", "fish", "dash", "ksh", "nu", "xonsh", "elvish", "env", "timeout", "nice", "nohup", "setsid", "script", "stdbuf", "systemd-run", "uv", "npx"];

const TERMINALS = ["kitty", "foot", "footclient", "alacritty", "wezterm-gui", "wezterm", "ghostty", "konsole", "gnome-terminal-server", "xterm", "st", "urxvt", "terminator", "tilix", "rio", "warp"];

const INTERPRETERS = ["node", "bun", "deno", "python", "python3", "ruby", "perl"];

const SSH_TAKES_VALUE = "BbcDEeFIiJLlmOoPpQRSWw";

const GIT_TAKES_VALUE = ["-C", "-c", "--exec-path", "--git-dir", "--work-tree", "--namespace", "--config-env", "--super-prefix"];

const KNOWN_ACTIONS = [
    ["org.freedesktop.policykit.exec", "Run a command as root"],
    ["org.freedesktop.systemd1.manage-units", "Start, stop or restart a system service"],
    ["org.freedesktop.systemd1.manage-unit-files", "Turn a system service on or off"],
    ["org.freedesktop.systemd1.reload-daemon", "Reload the system services"],
    ["org.freedesktop.login1.", "Power off, restart or change the session"],
    ["org.freedesktop.udisks2.", "Mount or change a drive"],
    ["org.freedesktop.NetworkManager.", "Change the network settings"],
    ["org.freedesktop.packagekit.", "Install or update software"],
    ["org.freedesktop.Flatpak.", "Install or update Flatpak apps"],
    ["org.freedesktop.timedate1.", "Change the date and time"],
    ["org.freedesktop.hostname1.", "Change this computer's name"],
    ["org.freedesktop.locale1.", "Change the system language or keyboard"],
    ["org.freedesktop.accounts.", "Change a user account"],
    ["org.freedesktop.fwupd.", "Update device firmware"],
    ["org.freedesktop.bolt.", "Allow a Thunderbolt device"]
];

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
        return `pushing to ${place}`;
    case "pull":
        return `pulling from ${place}`;
    case "fetch":
    case "remote":
        return `fetching from ${place}`;
    case "clone":
        return `cloning ${place}`;
    case "ls-remote":
        return `checking ${place}`;
    case "submodule":
        return `updating submodules from ${place}`;
    default:
        return push ? `pushing to ${place}` : `fetching from ${place}`;
    }
}

function causeOf(chain) {
    if (!chain || !chain.length)
        return "";
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
            const origin = originOf(chain, top);
            return `${origin || "git"} is ${gitPhrase(verb, service?.push ?? verb === "push", place)}`;
        }
        const wrapperAt = sshAt + 1 < chain.length && ["scp", "sftp", "rsync", "sshfs"].includes(programOf(chain[sshAt + 1])) ? sshAt + 1 : -1;
        if (wrapperAt >= 0) {
            const tool = programOf(chain[wrapperAt]);
            const origin = originOf(chain, wrapperAt);
            const phrase = tool === "rsync" ? `syncing files with ${host}` : tool === "sshfs" ? `mounting ${host}` : `copying files with ${host}`;
            return `${origin || tool} is ${phrase}`;
        }
        const origin = originOf(chain, sshAt);
        return `${origin || "ssh"} is connecting to ${host}`;
    }
    const first = programOf(chain[0]);
    if (first === "ssh-add")
        return "ssh-add is adding the key to the agent";
    if (first === "gpg" || first === "gpg2") {
        const gitAt = chain.findIndex(entry => programOf(entry) === "git");
        const args = chain[0].args;
        if (gitAt >= 0) {
            const top = outermost(chain, gitAt, entry => programOf(entry) === "git");
            const verb = gitVerb(chain[top].args);
            const origin = originOf(chain, top);
            const what = verb === "tag" ? "a tag" : "a commit";
            return `${origin || "git"} is signing ${what}`;
        }
        const origin = originOf(chain, 0);
        const decrypt = args.some(arg => arg === "-d" || arg === "--decrypt");
        const sign = args.some(arg => /^--(clear|detach-)?sign$/.test(arg) || /^-[a-zA-Z]*s[a-zA-Z]*$/.test(arg));
        const phrase = decrypt ? "decrypting something" : sign ? "signing something" : "using the key";
        return `${origin || "gpg"} is ${phrase}`;
    }
    const origin = originOf(chain, 0);
    return `${origin || first} is using the key`;
}

function commandOf(chain) {
    return chain && chain.length ? chain[0].args.join(" ") : "";
}

function identityName(identity) {
    return String(identity?.name ?? "").replace(/^unix-(user|group):/, "");
}

function actionTitle(actionId) {
    for (const [prefix, title] of KNOWN_ACTIONS)
        if (actionId === prefix || (prefix.endsWith(".") && String(actionId ?? "").startsWith(prefix)))
            return title;
    return "";
}

function pkexecRun(message) {
    const match = String(message ?? "").match(/run [`'‘"](.+?)['’"] as (?:the super user|user (\S+?))\.?$/);
    if (!match)
        return null;
    const words = match[1].split(/\s+/);
    words[0] = basename(words[0]);
    return {
        command: words.join(" "),
        as: match[2] ?? "root"
    };
}

function polkitReason(message) {
    const text = String(message ?? "");
    const rest = text.replace(/^Authentication is (?:required|needed) (?:in order )?to /i, "").replace(/\.$/, "");
    return rest === text ? text : `A program wants to ${rest}`;
}

function keyringName(name) {
    return /keyring$/i.test(name) ? `“${name}”` : `the “${name}” keyring`;
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

function describePolkit(ask) {
    const who = identityName(ask.identity) || ask.user || "";
    const self = !ask.identity || who === ask.user || (!!ask.user && ask.identity.displayName === ask.user);
    const root = who === "root";
    const run = pkexecRun(ask.message);
    const doing = ask.label ? `banditshell wants to ${lowerFirst(ask.label)}` : run ? `A program wants to run a command as ${run.as}` : polkitReason(ask.message) || actionTitle(ask.actionId) || "A program wants to act as an administrator";
    const details = [];
    if (ask.actionId)
        details.push(["Polkit action", ask.actionId]);
    if (ask.message)
        details.push(["Polkit says", ask.message]);
    if (ask.identity?.isGroup)
        details.push(["Any member of", who]);
    return {
        family: "admin",
        glyph: "admin_panel_settings",
        secret: root ? "The root password" : self ? "Your sudo password" : `${who}'s password`,
        owner: root ? "the root account's own password, not yours" : self ? (who ? `for ${who}, the account you log in with` : "for the account you log in with") : `${who} is an administrator on this computer`,
        reason: doing,
        command: run?.command ?? "",
        commandAs: run?.as ?? "",
        hint: root ? "Asked for root because polkit is set up that way here." : "",
        placeholder: root ? "Root password" : who ? `Password for ${who}` : "Your password",
        warning: wrong(ask.warning, "password"),
        noun: "password",
        details: details
    };
}

function describeSshKey(ask, path) {
    const shown = tilde(path, ask.home);
    const name = basename(path) || "this key";
    const details = [["Asked by", ask.requester || "the ssh agent"]];
    if (ask.command)
        details.push(["Waiting", ask.command]);
    return {
        family: "ssh",
        glyph: "vpn_key",
        secret: "SSH key passphrase",
        owner: path ? shown : "a key the ssh agent holds",
        reason: ask.cause || "A program wants to sign in with this key over ssh",
        hint: "Set when the key was made. It is not your login password.",
        placeholder: `Passphrase for ${name}`,
        warning: wrong(ask.warning, "passphrase"),
        noun: "passphrase",
        details: details
    };
}

function describeGpg(ask) {
    const text = ask.description ?? "";
    const sshKey = text.match(/passphrase for the ssh key\s+(\S+)\s*\(([^)]*)\)/i);
    if (sshKey)
        return Object.assign(describeSshKey(ask, ""), {
            owner: sshKey[2] || sshKey[1],
            placeholder: `Passphrase for ${sshKey[2] || "this key"}`
        });
    const fresh = /new key|protect/i.test(text) && !/unlock/i.test(text);
    const uid = (text.match(/"([^"]+)"/) ?? [])[1] ?? "";
    const person = uid.replace(/\s*<[^>]*>\s*/, "").replace(/\s*\([^)]*\)\s*/, "").trim();
    const id = (text.match(/ID\s+([0-9A-F]{8,40})/i) ?? [])[1] ?? "";
    const owner = [person ? `${person}'s key` : "", id ? id.slice(-8) : ""].filter(Boolean).join(", ");
    const details = [["Asked by", ask.requester || "pinentry"]];
    if (ask.command)
        details.push(["Waiting", ask.command]);
    return {
        family: "gpg",
        glyph: "signature",
        secret: fresh ? "New GPG passphrase" : "GPG key passphrase",
        owner: owner || "a key in your GPG keyring",
        reason: ask.cause || (fresh ? "gpg is protecting a new key" : "gpg wants to use your key"),
        hint: fresh ? "Choose one. You type it whenever the key is used." : "Set when the key was made. It is not your login password.",
        placeholder: fresh ? "New passphrase" : "GPG passphrase",
        warning: wrong(ask.warning, "passphrase"),
        noun: "passphrase",
        details: details
    };
}

function describeKeyring(ask) {
    const title = ask.title ?? "";
    const message = ask.message ?? "";
    const description = ask.description ?? "";
    const details = [["Asked by", ask.requester || "the keyring"]];
    const name = quoted(description) || quoted(message);
    if (ask.requester === "gcr-ssh-agent" || /ssh/.test(ask.requester ?? "")) {
        const path = (description.match(/passphrase for (?:key )?['"]?(\S+?)['"]?:/) ?? [])[1] ?? "";
        return describeSshKey(ask, path);
    }
    if (/^pinentry/.test(ask.requester ?? ""))
        return describeGpg(ask);
    if (ask.kind === "confirm")
        return {
            family: "keyring",
            glyph: "lock_open",
            secret: title || "Allow this?",
            owner: "",
            reason: description || message,
            hint: "",
            placeholder: "",
            warning: ask.warning ?? "",
            noun: "",
            details: details
        };
    if (/login keyring/i.test(title)) {
        const changed = /no longer matches/i.test(description);
        return {
            family: "keyring",
            glyph: "key",
            secret: "Login keyring password",
            owner: "the keyring that holds your saved passwords",
            reason: "An app wants a saved password, and the keyring is still locked",
            hint: changed ? "Your login password changed after this keyring was made. Type the old one." : "Usually your login password. Face unlock and auto-login leave this keyring locked.",
            placeholder: changed ? "Old login password" : "Login keyring password",
            warning: wrong(ask.warning, "password"),
            noun: "password",
            details: details
        };
    }
    if (ask.passwordNew || /new keyring|new password/i.test(title)) {
        return {
            family: "keyring",
            glyph: "key",
            secret: /change/i.test(title) ? "New keyring password" : "Password for a new keyring",
            owner: name ? keyringName(name) : "a new keyring",
            reason: /change/i.test(title + description) ? "An app wants to change this keyring's password" : "An app wants somewhere safe to keep its passwords",
            hint: "Choose one. You type it whenever this keyring is locked.",
            placeholder: "New password",
            warning: ask.warning ?? "",
            noun: "password",
            details: details
        };
    }
    if (/change/i.test(title)) {
        return {
            family: "keyring",
            glyph: "key",
            secret: "Current keyring password",
            owner: name ? keyringName(name) : "a keyring",
            reason: "An app wants to change this keyring's password",
            hint: "The password it has now, before the change.",
            placeholder: "Current password",
            warning: wrong(ask.warning, "password"),
            noun: "password",
            details: details
        };
    }
    if (/unlock keyring/i.test(title) || /keyring/i.test(description)) {
        return {
            family: "keyring",
            glyph: "key",
            secret: "Keyring password",
            owner: name ? keyringName(name) : "a keyring",
            reason: "An app wants a saved password from it",
            hint: name === "login" ? "Usually your login password." : "The password chosen when this keyring was made.",
            placeholder: name ? `Password for “${name}”` : "Keyring password",
            warning: wrong(ask.warning, "password"),
            noun: "password",
            details: details
        };
    }
    if (/unlock (private key|certificate|public key)/i.test(title)) {
        const what = (title.match(/unlock (.+)$/i) ?? [])[1] ?? "key";
        return {
            family: "keyring",
            glyph: "encrypted",
            secret: `${upperFirst(what)} password`,
            owner: name || `a ${what} in your keyring`,
            reason: `An app wants to use this ${what}`,
            hint: `Set when the ${what} was stored. It is not always your login password.`,
            placeholder: `Password for the ${what}`,
            warning: wrong(ask.warning, "password"),
            noun: "password",
            details: details
        };
    }
    return {
        family: "other",
        glyph: "password",
        secret: title || "Password",
        owner: message,
        reason: description,
        hint: "",
        placeholder: "Password",
        warning: ask.warning ?? "",
        noun: "password",
        details: details
    };
}

function describeRequest(ask) {
    return {
        family: ask.family || "wifi",
        glyph: ask.glyph || "wifi_password",
        secret: ask.secret || ask.title || "Password",
        owner: ask.owner || "",
        reason: ask.reason || ask.message || "",
        hint: ask.hint || "",
        placeholder: ask.placeholder || "Password",
        warning: ask.warning ?? "",
        noun: "password",
        details: []
    };
}

function describe(ask) {
    const told = ask.source === "polkit" ? describePolkit(ask) : ask.source === "request" ? describeRequest(ask) : describeKeyring(ask);
    const original = [ask.title, ask.message, ask.description].filter(text => text && !told.details.some(([, said]) => said === text));
    if (ask.source !== "request" && original.length)
        told.details.push(["Their words", original.join("\n")]);
    told.choice = rememberLabel(ask.choiceLabel);
    return told;
}
