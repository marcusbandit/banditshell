function band(strength, steps) {
    const percent = Math.round((strength || 0) * 100);
    return Math.ceil(percent / (100 / steps));
}

function collapse(networks) {
    const best = new Map();
    for (const network of networks) {
        if (!network || !network.name)
            continue;
        const held = best.get(network.name);
        if (!held || (network.connected && !held.connected) || (!held.connected && network.signalStrength > held.signalStrength))
            best.set(network.name, network);
    }
    return Array.from(best.values());
}

function compareNames(a, b) {
    return a.localeCompare(b) || (a < b ? -1 : a > b ? 1 : 0);
}

function arrange(networks, steps) {
    return collapse(networks).map(network => ({
        network: network,
        band: band(network.signalStrength, steps)
    })).sort((a, b) => {
        if (!!a.network.connected !== !!b.network.connected)
            return a.network.connected ? -1 : 1;
        if (!!a.network.known !== !!b.network.known)
            return a.network.known ? -1 : 1;
        if (a.band !== b.band)
            return b.band - a.band;
        return compareNames(a.network.name, b.network.name);
    }).map(entry => entry.network);
}

function same(previous, next) {
    if (!previous || previous.length !== next.length)
        return false;
    for (let i = 0; i < next.length; i++) {
        if (previous[i] !== next[i])
            return false;
    }
    return true;
}

function settle(previous, next) {
    return same(previous, next) ? previous : next;
}

function pick(names, networks) {
    const byName = new Map();
    for (const network of networks)
        byName.set(network.name, network);
    const picked = [];
    for (const name of names) {
        const network = byName.get(name);
        if (network)
            picked.push(network);
    }
    return picked;
}

function escapeSecret(secret) {
    let escaped = "";
    for (let i = 0; i < secret.length; i++) {
        const character = secret[i];
        const code = secret.charCodeAt(i);
        if (character === "\\")
            escaped += "\\\\";
        else if (code <= 0x20 || code === 0x7f)
            escaped += "\\" + ("00" + code.toString(8)).slice(-3);
        else
            escaped += character;
    }
    return escaped;
}

function secretLine(property, secret) {
    return `${property}:${escapeSecret(String(secret ?? ""))}\n`;
}

const SIGN_IN_METHODS = {
    wpa: ["peap", "ttls", "tls"],
    wep: ["peap", "ttls", "tls"],
    suiteb: ["tls"]
};

const KEY_MANAGEMENT = {
    wpa: "wpa-eap",
    wep: "ieee8021x",
    suiteb: "wpa-eap-suite-b-192"
};

const INNER_METHODS = {
    peap: "mschapv2",
    ttls: "pap"
};

const KNOWN_SERVERS = {
    DTUsecure: "dtu.dk"
};

const UNMATCHABLE_SERVER = "server-check.invalid";

function signInMethods(kind) {
    return SIGN_IN_METHODS[kind] || [];
}

function signInRefusal(kind) {
    if (kind === "leap")
        return "LEAP lets anyone nearby work out the password, so this network cannot be joined from here";
    if (!KEY_MANAGEMENT[kind])
        return "this kind of sign-in cannot be joined from here yet";
    return "";
}

function knownServer(name) {
    return Object.prototype.hasOwnProperty.call(KNOWN_SERVERS, name) ? KNOWN_SERVERS[name] : "";
}

function serverDomain(text) {
    const name = String(text ?? "").trim().toLowerCase().replace(/^[a-z]+:\/\//, "").replace(/[\/:].*$/, "").replace(/^[*.]+/, "").replace(/\.+$/, "");
    return /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/.test(name) ? name : "";
}

function filePath(text, home) {
    const path = String(text ?? "").trim();
    if (path === "~" || path.startsWith("~/"))
        return home ? home + path.slice(1) : "";
    return path.startsWith("/") ? path : "";
}

function outerIdentity(method, identity) {
    if (method !== "peap" && method !== "ttls")
        return "";
    const text = String(identity ?? "");
    const realm = text.slice(text.lastIndexOf("@") + 1);
    return text.includes("@") && /^[^\s@]+$/.test(realm) ? `anonymous@${realm}` : "";
}

function signInReady(kind, form) {
    const method = form?.method;
    if (!KEY_MANAGEMENT[kind] || !signInMethods(kind).includes(method) || !form.identity)
        return false;
    if (!serverDomain(form.domain) && !form.authority)
        return false;
    return method !== "tls" || (!!form.certificate && !!form.key);
}

function signInArgs(kind, form) {
    if (!signInReady(kind, form))
        return null;
    const method = form.method;
    const tls = method === "tls";
    return ["connection.auth-retries", "1",
        "wifi-sec.key-mgmt", KEY_MANAGEMENT[kind],
        "wifi-sec.auth-alg", kind === "wep" ? "open" : "",
        "wifi-sec.pmf", kind === "suiteb" ? "required" : "default",
        "802-1x.eap", method,
        "802-1x.identity", form.identity,
        "802-1x.anonymous-identity", outerIdentity(method, form.identity),
        "802-1x.phase2-auth", INNER_METHODS[method] || "",
        "802-1x.system-ca-certs", form.authority ? "no" : "yes",
        "802-1x.ca-cert", form.authority || "",
        "802-1x.domain-suffix-match", serverDomain(form.domain),
        "802-1x.client-cert", tls ? form.certificate : "",
        "802-1x.private-key", tls ? form.key : "",
        "802-1x.password", "",
        "802-1x.private-key-password", "",
        "802-1x.private-key-password-flags", tls && !form.locked ? "not-required" : "none"];
}

function serverCheckArgs(kind, form) {
    if (kind !== "wpa" && kind !== "wep")
        return null;
    const outer = outerIdentity("peap", form?.identity) || "anonymous";
    return ["connection.autoconnect", "no",
        "connection.auth-retries", "1",
        "wifi-sec.key-mgmt", KEY_MANAGEMENT[kind],
        "wifi-sec.auth-alg", kind === "wep" ? "open" : "",
        "802-1x.eap", "peap,ttls",
        "802-1x.identity", outer,
        "802-1x.anonymous-identity", outer,
        "802-1x.phase2-auth", "mschapv2",
        "802-1x.system-ca-certs", form?.authority ? "no" : "yes",
        "802-1x.ca-cert", form?.authority || "",
        "802-1x.domain-suffix-match", UNMATCHABLE_SERVER,
        "802-1x.password", ""];
}

function serverCheckSecrets(form) {
    const outer = outerIdentity("peap", form?.identity) || "anonymous";
    return secretLine("802-1x.identity", outer) + secretLine("802-1x.password", "never-sent");
}

function signInSecrets(method, identity, password) {
    const secret = method === "tls" ? "802-1x.private-key-password" : "802-1x.password";
    return secretLine("802-1x.identity", identity) + secretLine(secret, password);
}

function commonName(subject) {
    const pattern = /(?:^|[\/,]\s*)CN=([^\/,]*)/g;
    let name = "";
    for (let found = pattern.exec(String(subject ?? "")); found; found = pattern.exec(String(subject ?? "")))
        name = found[1].trim();
    return name;
}

function troubleKind(reason, err) {
    if (reason === 9 || reason === 10 || reason === 5 || reason === 6 || /mismatch/i.test(err))
        return "name";
    if (reason === 3 || reason === 4 || /expired|not yet valid/i.test(err))
        return "expired";
    if (reason === 1 || /issuer|self.signed|untrusted|unable to get/i.test(err))
        return "untrusted";
    return "refused";
}

function serverTrouble(log) {
    let chain = [];
    let names = [];
    let trouble = null;
    for (const line of String(log ?? "").split("\n")) {
        if (line.includes("CTRL-EVENT-EAP-STARTED")) {
            chain = [];
            names = [];
            continue;
        }
        const cert = line.match(/CTRL-EVENT-EAP-PEER-CERT depth=(\d+) subject='([^']*)'/);
        if (cert) {
            chain[Number(cert[1])] = commonName(cert[2]);
            continue;
        }
        const alt = line.match(/CTRL-EVENT-EAP-PEER-ALT depth=0 DNS:(\S+)/);
        if (alt) {
            names.push(alt[1].toLowerCase());
            continue;
        }
        const failed = line.match(/CTRL-EVENT-EAP-TLS-CERT-ERROR reason=(\d+) depth=(\d+) subject='([^']*)' err='([^']*)'/);
        if (!failed)
            continue;
        const depth = Number(failed[2]);
        chain[depth] = commonName(failed[3]);
        const top = chain.filter(n => n).slice(-1)[0] || "";
        trouble = {
            kind: troubleKind(Number(failed[1]), failed[4]),
            server: names[0] || chain[0] || "",
            authority: depth > 0 || chain.length > 1 ? top : ""
        };
    }
    return trouble;
}

const SERVER_LABELS = {
    name: "server did not match",
    untrusted: "server not trusted",
    expired: "server out of date",
    refused: "server refused"
};

function serverLabel(trouble) {
    return trouble ? SERVER_LABELS[trouble.kind] || SERVER_LABELS.refused : "";
}

function serverMessage(trouble, domain) {
    if (!trouble)
        return "";
    const by = trouble.authority ? `, vouched for by ${trouble.authority}` : "";
    switch (trouble.kind) {
    case "name":
        return `The server answered as ${trouble.server || "something else"}${domain ? `, not ${domain}` : ""}${by}. Your password was not sent.`;
    case "untrusted":
        return `This computer does not trust ${trouble.authority || "the authority"}, which vouches for the server. Pick its certificate under trusted by; your school's Wi-Fi guide has it. Your password was not sent.`;
    case "expired":
        return "The server's certificate has run out of date. Your password was not sent.";
    }
    return "The server's certificate was refused. Your password was not sent.";
}

function serverSeenMessage(trouble) {
    if (!trouble)
        return "Could not see the server's name. Your school's Wi-Fi guide lists it.";
    if (trouble.kind === "name" && trouble.server)
        return `It answered as ${trouble.server}${trouble.authority ? `, vouched for by ${trouble.authority}` : ""}. Use that name if it is your school's.`;
    return serverMessage(trouble, "");
}

const JOIN_FAILURES = {
    password: "wrong password",
    timeout: "no answer",
    lost: "it went away",
    hungup: "it hung up"
};

const JOIN_REASONS = {
    password: "The password did not work",
    timeout: "The router did not answer",
    lost: "The network went out of range",
    hungup: "The router dropped the connection"
};

function failureLabel(kind) {
    return JOIN_FAILURES[kind] || "could not join";
}

function failureMessage(name, kind) {
    return `${name}: ${failureLabel(kind)}`;
}

function failureReason(kind) {
    return JOIN_REASONS[kind] || "Something went wrong while joining";
}
