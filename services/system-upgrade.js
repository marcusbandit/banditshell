const order = ["auth", "sync", "resolve", "download", "check", "install", "hooks"];

const checks = ["checking keys in keyring", "checking package integrity", "loading package files", "checking for file conflicts", "checking available disk space"];

const stageNames = ["Download", "Verify", "Install", "Finish"];
const stageWeights = [0.45, 0.1, 0.35, 0.1];

function plan(command) {
    const words = String(command ?? "").trim().split(/\s+/).filter(w => w);
    const longs = { "--sync": "S", "--refresh": "y", "--sysupgrade": "u" };
    while (words.length > 0 && /^(sudo|doas)$/.test(words[0]))
        words.shift();
    const none = { plain: false, noconfirm: false };
    if (words.length === 0 || !/^(\/usr\/bin\/)?pacman$/.test(words[0]))
        return none;
    let letters = "";
    let noconfirm = false;
    for (const w of words.slice(1)) {
        if (w === "--noconfirm")
            noconfirm = true;
        else if (/^-[Syu]+$/.test(w))
            letters += w.slice(1);
        else if (longs[w])
            letters += longs[w];
        else
            return none;
    }
    return { plain: letters.indexOf("S") >= 0 && letters.indexOf("u") >= 0, noconfirm: noconfirm };
}

function create() {
    return {
        phase: "auth",
        carry: "",
        total: 0,
        packages: [],
        listing: false,
        verbose: false,
        sizes: { download: "", installed: "", net: "" },
        download: { done: 0, total: 0, fraction: -1, file: "", fileFraction: 0, rate: "", eta: "" },
        check: { step: 0, index: 0, total: 0 },
        install: { index: 0, total: 0, verb: "", name: "", fraction: 0 },
        hooks: { index: 0, total: 0, text: "" },
        committing: false,
        question: null,
        questions: 0,
        choices: [],
        asked: "",
        warnings: [],
        errors: [],
        refusal: "",
        detail: "",
        interrupted: false,
        declined: false,
        nothing: false,
        cr: false
    };
}

function clean(text) {
    return String(text ?? "")
        .replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "")
        .replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, "")
        .replace(/\x1b[@-Z\\-_]/g, "")
        .replace(/[\x00-\x08\x0b-\x1f\x7f]/g, "");
}

function reach(state, phase) {
    if (order.indexOf(phase) > order.indexOf(state.phase))
        state.phase = phase;
}

function keep(list, line) {
    if (list.length === 0 || list[list.length - 1] !== line)
        list.push(line);
    if (list.length > 40)
        list.splice(0, list.length - 40);
}

function nameOf(token) {
    return token.replace(/^[^\/\s]+\//, "").replace(/-[^-\s]+-[^-\s]+$/, "");
}

function listed(state, text) {
    const tokens = text.trim().split(/\s+/).filter(t => t);
    if (tokens.length === 0)
        return;
    if (state.verbose) {
        if (!/^(Old|New|Net|Download)\b/.test(tokens[0]))
            state.packages.push(tokens[0].replace(/^[^\/]+\//, ""));
        return;
    }
    for (const token of tokens)
        if (/-[^-\s]+-[^-\s]+$/.test(token))
            state.packages.push(nameOf(token));
}

function percent(text) {
    const m = /(\d{1,3})%\s*$/.exec(text);
    return m ? Math.min(100, Number(m[1])) / 100 : -1;
}

function take(state, raw) {
    const line = clean(raw).replace(/\s+$/, "");
    const t = line.trim();

    if (state.question && t.indexOf(state.asked) === 0 && state.asked) {
        state.question = null;
        state.asked = "";
        return;
    }

    if (t === "") {
        state.listing = false;
        return;
    }

    let m;

    if (state.listing && /^\s/.test(line)) {
        listed(state, line);
        return;
    }
    state.listing = false;

    if (/^:: Synchronizing package databases/.test(t)) {
        reach(state, "sync");
        return;
    }
    if (/^:: Starting full system upgrade/.test(t) || /^(resolving dependencies|looking for conflicting packages)/.test(t)) {
        reach(state, "resolve");
        return;
    }
    if (/^there is nothing to do/.test(t)) {
        state.nothing = true;
        return;
    }
    if ((m = /^Packages? \((\d+)\)\s*(.*)$/.exec(t))) {
        state.total = Number(m[1]);
        state.packages = [];
        state.verbose = /Old Version/.test(m[2]);
        state.listing = true;
        if (!state.verbose)
            listed(state, m[2]);
        return;
    }
    if ((m = /^Total Download Size:\s*(.+)$/.exec(t))) {
        state.sizes.download = m[1].trim();
        return;
    }
    if ((m = /^Total Installed Size:\s*(.+)$/.exec(t))) {
        state.sizes.installed = m[1].trim();
        return;
    }
    if ((m = /^Net Upgrade Size:\s*(.+)$/.exec(t))) {
        state.sizes.net = m[1].trim();
        return;
    }
    if (/^:: Retrieving packages/.test(t)) {
        reach(state, "download");
        return;
    }
    if (/^:: Running pre-transaction hooks/.test(t)) {
        reach(state, "install");
        state.committing = true;
        state.detail = "";
        return;
    }
    if (/^:: Processing package changes/.test(t)) {
        reach(state, "install");
        state.committing = true;
        state.detail = "";
        return;
    }
    if (/^:: Running post-transaction hooks/.test(t)) {
        reach(state, "hooks");
        state.committing = true;
        state.detail = "";
        return;
    }
    if ((m = /^:: There are (\d+) providers available for (.+):$/.exec(t))) {
        state.choices = [];
        state.detail = `Choose what provides ${m[2]}`;
        return;
    }
    if (/Interrupt signal received/.test(t)) {
        state.interrupted = true;
        return;
    }
    if ((m = /^Error executing command as another user:\s*(.+)$/.exec(t))) {
        state.refusal = m[1].trim();
        return;
    }
    if ((m = /^error:\s*(.+)$/.exec(t))) {
        keep(state.errors, m[1].trim());
        return;
    }
    if ((m = /^warning:\s*(.+)$/.exec(t))) {
        keep(state.warnings, m[1].trim());
        return;
    }
    if ((m = /^\(\s*(\d+)\/(\d+)\)\s+(installing|upgrading|reinstalling|downgrading|removing)\s+(\S+)/.exec(t))) {
        reach(state, "install");
        state.committing = true;
        const fraction = percent(t);
        state.install = {
            index: Number(m[1]),
            total: Number(m[2]),
            verb: m[3],
            name: m[4],
            fraction: fraction < 0 ? 0 : fraction
        };
        return;
    }
    if ((m = /^\(\s*(\d+)\/(\d+)\)\s+(checking keys in keyring|checking package integrity|loading package files|checking for file conflicts|checking available disk space)/.exec(t))) {
        reach(state, "check");
        state.check = { step: checks.indexOf(m[3]), index: Number(m[1]), total: Number(m[2]) };
        return;
    }
    if ((m = /^(checking keyring|checking package integrity|loading package files|checking for file conflicts|checking available disk space)\.\.\.$/.exec(t))) {
        reach(state, "check");
        const step = checks.indexOf(m[1] === "checking keyring" ? "checking keys in keyring" : m[1]);
        state.check = { step: step, index: 0, total: 0 };
        return;
    }
    if ((m = /^\s*(\d+)\)\s/.exec(line)) && /\d+\)\s+\S/.test(t)) {
        const found = [];
        const re = /(\d+)\)\s+(\S+)/g;
        let hit;
        while ((hit = re.exec(t)) !== null)
            found.push({ number: Number(hit[1]), name: hit[2] });
        state.choices = state.choices.concat(found);
        return;
    }
    if (state.phase === "hooks" || (state.phase === "install" && state.install.index === 0)) {
        if ((m = /^\(\s*(\d+)\/(\d+)\)\s+(.+?)\s*$/.exec(t))) {
            if (state.phase === "hooks")
                state.hooks = { index: Number(m[1]), total: Number(m[2]), text: m[3].replace(/\.\.\.$/, "") };
            state.detail = m[3].replace(/\.\.\.$/, "");
            return;
        }
        if ((m = /^==>\s*(.+)$/.exec(t))) {
            state.detail = m[1].trim();
            return;
        }
        return;
    }
    if (state.phase === "download") {
        if ((m = /^Total \(\s*(\d+)\/(\d+)\)(.*)$/.exec(t))) {
            const rest = m[3];
            const rate = /(\d+(?:[.,]\d+)?\s*[KMGT]?i?B\/s)/.exec(rest);
            const eta = /(\d\d:\d\d(?::\d\d)?|--:--)/.exec(rest);
            state.download.done = Number(m[1]);
            state.download.total = Number(m[2]);
            const f = percent(t);
            if (f >= 0)
                state.download.fraction = f;
            state.download.rate = rate ? rate[1].replace(/\s+/, " ") : "";
            state.download.eta = eta ? eta[1] : "";
            return;
        }
        if ((m = /^(\S+?)(?:\s+downloading\.\.\.)?$/.exec(t))) {
            state.download.file = m[1];
            state.download.fileFraction = 0;
            return;
        }
        if ((m = /^(\S+)\s+.*\[.*\]\s*\d+%$/.exec(t))) {
            const f = percent(t);
            state.download.file = m[1].replace(/\.\.\.$/, "");
            state.download.fileFraction = f < 0 ? 0 : f;
            if (f >= 1 && state.download.total === 0)
                state.download.done += 1;
            const rate = /(\d+(?:[.,]\d+)?\s*[KMGT]?i?B\/s)/.exec(t);
            if (state.download.total === 0 && rate)
                state.download.rate = rate[1].replace(/\s+/, " ");
            return;
        }
    }
}

function ask(state) {
    const text = clean(state.carry).replace(/\s+$/, "");
    const t = text.trim();
    let m;
    if ((m = /^(?::: )?(.*?)\s*\[(Y\/n|y\/N)\]$/.exec(t))) {
        if (!state.question || state.question.text !== m[1]) {
            state.questions += 1;
            state.question = { id: state.questions, kind: "yesno", text: m[1], yes: m[2] === "Y/n", choices: [], fallback: 0 };
            state.asked = t;
        }
        return;
    }
    if ((m = /^Enter a number \(default=(\d+)\):$/.exec(t))) {
        if (!state.question) {
            state.questions += 1;
            state.question = { id: state.questions, kind: "number", text: state.detail || "Choose one", yes: true, choices: state.choices.slice(), fallback: Number(m[1]) };
            state.asked = t;
        }
        return;
    }
}

function feed(state, chunk) {
    let text = String(chunk ?? "");
    if (state.cr && state.carry === "" && text.charAt(0) === "\n")
        text = text.slice(1);
    const joined = state.carry + text;
    if (joined.length > 0)
        state.cr = joined.charAt(joined.length - 1) === "\r";
    const parts = joined.split(/\r\n|\r|\n/);
    state.carry = parts.pop() ?? "";
    for (const part of parts)
        take(state, part);
    if (state.carry.length > 4096)
        state.carry = state.carry.slice(-4096);
    ask(state);
    return state;
}

function stageFills(state) {
    const at = order.indexOf(state.phase);
    const past = phase => at > order.indexOf(phase);
    const download = past("download") ? 1 : state.phase === "download" ? 0.1 + 0.9 * downloaded(state) : state.phase === "resolve" ? 0.1 : state.phase === "sync" ? 0.05 : 0;
    const verify = past("check") ? 1 : state.phase === "check" ? checked(state) : 0;
    const install = past("install") ? 1 : state.phase === "install" ? installed(state) : 0;
    const finish = state.phase === "hooks" && state.hooks.total > 0 ? Math.max(0, state.hooks.index - 1) / state.hooks.total : 0;
    return [download, verify, install, finish];
}

function downloaded(state) {
    const d = state.download;
    if (d.fraction >= 0)
        return d.fraction;
    const total = d.total || state.total;
    if (total > 0)
        return Math.min(1, (d.done + d.fileFraction) / total);
    return d.fileFraction;
}

function checked(state) {
    const c = state.check;
    const within = c.total > 0 ? c.index / c.total : 0;
    return Math.min(1, (Math.max(0, c.step) + within) / checks.length);
}

function installed(state) {
    const i = state.install;
    if (i.total <= 0)
        return 0;
    return Math.min(1, (i.index - 1 + i.fraction) / i.total);
}

function stages(state, finished) {
    const fills = finished ? [1, 1, 1, 1] : stageFills(state);
    return stageNames.map((name, i) => ({ name: name, fill: fills[i] }));
}

function stageIndex(state) {
    switch (state.phase) {
    case "check":
        return 1;
    case "install":
        return 2;
    case "hooks":
        return 3;
    }
    return 0;
}

function fraction(state, finished) {
    if (finished)
        return 1;
    const fills = stageFills(state);
    let sum = 0;
    for (let i = 0; i < fills.length; i++)
        sum += fills[i] * stageWeights[i];
    return Math.max(0, Math.min(1, sum));
}

function capital(text) {
    return text ? text.charAt(0).toUpperCase() + text.slice(1) : "";
}

function describe(state) {
    switch (state.phase) {
    case "auth":
        return "Waiting for your password";
    case "sync":
        return "Refreshing the package lists";
    case "resolve":
        return "Working out what changes";
    case "download": {
        const d = state.download;
        const total = d.total || state.total;
        const parts = [total > 0 ? `Downloading ${Math.min(d.done + 1, total)} of ${total}` : "Downloading"];
        if (d.rate)
            parts.push(d.rate);
        if (d.eta && d.eta !== "--:--" && !/^00:00/.test(d.eta))
            parts.push(`${d.eta.replace(/^00:/, "0:")} left`);
        return parts.join(" · ");
    }
    case "check":
        return capital(checks[Math.max(0, state.check.step)] ?? "checking packages");
    case "install":
        if (state.install.index > 0)
            return `${capital(state.install.verb)} ${state.install.name} · ${state.install.index} of ${state.install.total}`;
        return state.detail ? capital(state.detail) : "Getting ready to install";
    case "hooks":
        return state.detail ? capital(state.detail) : "Finishing up";
    }
    return "";
}

function brief(state) {
    switch (state.phase) {
    case "auth":
        return "Waiting for your password";
    case "sync":
    case "resolve":
        return "Preparing the update";
    case "download": {
        const total = state.download.total || state.total;
        return total > 0 ? `Downloading ${Math.min(state.download.done + 1, total)} of ${total}` : "Downloading updates";
    }
    case "check":
        return "Checking the packages";
    case "install":
        return state.install.index > 0 ? `Installing ${state.install.index} of ${state.install.total}` : "Installing";
    case "hooks":
        return "Finishing up";
    }
    return "Updating";
}

function cancellable(state) {
    return !state.committing && order.indexOf(state.phase) <= order.indexOf("download");
}

function outcome(state, code) {
    if (state.interrupted && state.committing)
        return "failed";
    if (state.interrupted || code === 130 || code === 126)
        return "cancelled";
    if (state.declined && !state.committing && code !== 0)
        return "cancelled";
    if (code === 0)
        return state.nothing ? "current" : "done";
    return "failed";
}

function explain(state, code) {
    const all = state.errors.join("\n");
    if (state.interrupted && state.committing)
        return "The update was stopped partway through installing. Run it again to finish it.";
    if (outcome(state, code) === "cancelled") {
        if (state.refusal || code === 126)
            return "The password prompt was closed, so nothing changed.";
        if (state.declined && !state.interrupted)
            return "You answered no, so pacman stopped before changing anything.";
        return "Stopped before anything was installed. Nothing changed.";
    }
    if (state.refusal)
        return "Permission to update was refused, so nothing changed.";
    if (/unable to lock database|could not lock database/.test(all))
        return "Another package manager is busy. Try again once it has finished.";
    if (/failed to synchroni[sz]e|failed retrieving file|Could not resolve host|Couldn't resolve host|Failed to connect|Connection timed out|Operation too slow/i.test(all))
        return "Could not reach the package mirrors. Check the internet connection, then try again.";
    if (/not enough free disk space|too full/i.test(all))
        return "There is not enough free disk space for the update.";
    if (/signature|unknown trust|PGP|keyring|could not be looked up remotely/i.test(all))
        return "A package signature did not check out. Updating archlinux-keyring first usually fixes this.";
    if (/conflicting files/.test(all))
        return "The update brings files that already exist on this system. The log names them.";
    if (/conflicting dependencies|unresolvable package conflicts|could not satisfy dependencies|breaks dependency/.test(all))
        return "Two packages need a choice pacman will not make on its own. Run it in a terminal to answer.";
    const last = state.errors[state.errors.length - 1];
    if (last)
        return capital(last.replace(/\.$/, "")) + ".";
    if (code < 0)
        return "The update stopped without saying why.";
    return code === 127 ? "The update could not start." : `pacman stopped with code ${code}.`;
}

function headline(state, result) {
    switch (result) {
    case "done":
        return "System updated";
    case "current":
        return "Already up to date";
    case "cancelled":
        return "Update cancelled";
    case "failed":
        return "The update stopped";
    }
    return "Updating the system";
}
