const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/wifilist.js"), "utf8");
const WifiList = new Function(src + "\nreturn { band, collapse, arrange, settle, pick, secretLine, signInSecrets, signInMethods, signInRefusal, knownServer, serverDomain, filePath, outerIdentity, outerIdentityFor, innerMethods, innerMethod, innerName, signInArgs, serverCheckArgs, serverCheckSecrets, serverTrouble, serverLabel, serverMessage, serverSeenMessage, schoolCertificate, schoolFor, realmOf, trustedAuthority, checkAuthority, serverMatch, SCHOOL_CERTIFICATES, failureLabel, failureMessage, failureReason };")();

const STEPS = 4;

function network(name, signalStrength, extra) {
    return Object.assign({ name, signalStrength, connected: false, known: false }, extra);
}

function names(list) {
    return list.map(n => n.name);
}

test.describe("band", () => {
    test.it("matches the bars the menu draws", () => {
        const cases = [[0, 0], [0.004, 0], [0.01, 1], [0.25, 1], [0.26, 2], [0.5, 2], [0.51, 3], [0.75, 3], [0.76, 4], [1, 4]];
        for (const [strength, expected] of cases)
            assert.strictEqual(WifiList.band(strength, STEPS), expected, `strength ${strength}`);
    });

    test.it("treats a missing strength as no signal", () => {
        assert.strictEqual(WifiList.band(undefined, STEPS), 0);
    });
});

test.describe("collapse", () => {
    test.it("drops hidden networks", () => {
        assert.deepStrictEqual(names(WifiList.collapse([network("", 0.9), network("cafe", 0.4)])), ["cafe"]);
    });

    test.it("keeps the connected entry over a stronger one", () => {
        const on = network("mesh", 0.3, { connected: true });
        const loud = network("mesh", 0.9);
        assert.strictEqual(WifiList.collapse([loud, on])[0], on);
    });

    test.it("keeps the strongest entry otherwise", () => {
        const quiet = network("mesh", 0.3);
        const loud = network("mesh", 0.9);
        assert.strictEqual(WifiList.collapse([quiet, loud])[0], loud);
    });

    test.it("survives names that are object keys", () => {
        const list = WifiList.collapse([network("__proto__", 0.5), network("constructor", 0.5), network("toString", 0.5)]);
        assert.deepStrictEqual(names(list).sort(), ["__proto__", "constructor", "toString"]);
    });
});

test.describe("arrange", () => {
    test.it("puts the connected network first, then the known ones, then by band", () => {
        const list = [
            network("strong", 0.95),
            network("saved", 0.2, { known: true }),
            network("here", 0.1, { connected: true, known: true }),
            network("weak", 0.1)
        ];
        assert.deepStrictEqual(names(WifiList.arrange(list, STEPS)), ["here", "saved", "strong", "weak"]);
    });

    test.it("orders a band by name, not by the signal inside it", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        assert.deepStrictEqual(names(WifiList.arrange([b, a], STEPS)), ["alpha", "bravo"]);
        b.signalStrength = 0.52;
        a.signalStrength = 0.74;
        assert.deepStrictEqual(names(WifiList.arrange([b, a], STEPS)), ["alpha", "bravo"]);
    });

    test.it("moves a network when its band changes", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        b.signalStrength = 0.9;
        assert.deepStrictEqual(names(WifiList.arrange([a, b], STEPS)), ["bravo", "alpha"]);
    });

    test.it("does not depend on the order networks arrive in", () => {
        const list = [network("b", 0.5), network("a", 0.5), network("c", 0.9), network("A", 0.5)];
        const forward = names(WifiList.arrange(list, STEPS));
        const backward = names(WifiList.arrange(list.slice().reverse(), STEPS));
        assert.deepStrictEqual(forward, backward);
    });
});

test.describe("settle", () => {
    test.it("hands back the same array when the order and members are unchanged", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        const before = WifiList.arrange([a, b], STEPS);
        a.signalStrength = 0.6;
        const after = WifiList.settle(before, WifiList.arrange([a, b], STEPS));
        assert.strictEqual(after, before);
    });

    test.it("hands back the new array when a band reorders the list", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        const before = WifiList.arrange([a, b], STEPS);
        b.signalStrength = 0.9;
        const next = WifiList.arrange([a, b], STEPS);
        assert.strictEqual(WifiList.settle(before, next), next);
    });

    test.it("hands back the new array when a network arrives or leaves", () => {
        const a = network("alpha", 0.55);
        const before = WifiList.arrange([a], STEPS);
        const grown = WifiList.arrange([a, network("bravo", 0.3)], STEPS);
        assert.strictEqual(WifiList.settle(before, grown), grown);
        const shrunk = WifiList.arrange([], STEPS);
        assert.strictEqual(WifiList.settle(grown, shrunk), shrunk);
    });

    test.it("hands back the new array when an entry is a different object under the same name", () => {
        const before = [network("alpha", 0.5)];
        const next = [network("alpha", 0.5)];
        assert.strictEqual(WifiList.settle(before, next), next);
    });

    test.it("accepts having nothing before", () => {
        const next = [network("alpha", 0.5)];
        assert.strictEqual(WifiList.settle(undefined, next), next);
    });
});

test.describe("pick", () => {
    test.it("keeps the frozen order and uses the live networks", () => {
        const a = network("alpha", 0.5);
        const b = network("bravo", 0.5);
        const picked = WifiList.pick(["bravo", "alpha"], [a, b]);
        assert.strictEqual(picked[0], b);
        assert.strictEqual(picked[1], a);
    });

    test.it("leaves out networks that went away and ignores new ones", () => {
        const picked = WifiList.pick(["alpha", "gone"], [network("alpha", 0.5), network("new", 0.9)]);
        assert.deepStrictEqual(names(picked), ["alpha"]);
    });

    test.it("follows a network that came back as a new object", () => {
        const back = network("alpha", 0.5);
        assert.strictEqual(WifiList.pick(["alpha"], [back])[0], back);
    });
});

function isSpace(character) {
    return character === " " || character === "\t" || character === "\n" || character === "\v" || character === "\f" || character === "\r";
}

function trimEnd(text) {
    let end = text.length;
    while (end > 0 && isSpace(text[end - 1]))
        end--;
    return text.slice(0, end);
}

function nmcliUnescape(text) {
    let start = 0;
    while (start < text.length && isSpace(text[start]))
        start++;
    text = text.slice(start);
    let at = text.indexOf("\\");
    if (at < 0)
        return trimEnd(text);
    let out = text.slice(0, at);
    for (;;) {
        at++;
        let character = text[at];
        if (character === undefined)
            break;
        if (character >= "0" && character <= "9") {
            let value = character.charCodeAt(0) - 48;
            at++;
            if (text[at] >= "0" && text[at] <= "7") {
                value = value * 8 + text.charCodeAt(at) - 48;
                at++;
                if (text[at] >= "0" && text[at] <= "7") {
                    value = value * 8 + text.charCodeAt(at) - 48;
                    at++;
                }
            }
            character = String.fromCharCode(value & 0xff);
        } else {
            character = { b: "\b", f: "\f", n: "\n", r: "\r", t: "\t", v: "\v" }[character] ?? character;
            at++;
        }
        out += character;
        const next = text.indexOf("\\", at);
        if (next < 0)
            return out + trimEnd(text.slice(at));
        out += text.slice(at, next);
        at = next;
    }
    return out;
}

function nmcliPasswords(contents) {
    const found = {};
    for (const raw of contents.split(/\r\n|\n|\r/)) {
        let line = raw;
        while (line && isSpace(line[0]))
            line = line.slice(1);
        if (!line || line[0] === "#")
            continue;
        const cut = line.search(/[:=]/);
        assert.ok(cut > 0, `no separator in ${JSON.stringify(line)}`);
        found[line.slice(0, cut).trim()] = nmcliUnescape(line.slice(cut + 1));
    }
    return found;
}

test.describe("secretLine", () => {
    const secrets = [
        "hunter2",
        "",
        " leading space",
        "trailing space ",
        "  both  ",
        "tab\there",
        "new\nline",
        "carriage\rreturn",
        "back\\slash",
        "\\n is not a newline",
        "trailing backslash\\",
        "colon:and=equals",
        "#not a comment",
        "octal \\101 stays",
        "delete\x7fcharacter",
        "zero after space 0",
        "ünïcödé ✓ 🔑"
    ];

    test.it("is one line that nmcli reads back as the same secret", () => {
        for (const secret of secrets) {
            const line = WifiList.secretLine("802-1x.password", secret);
            assert.ok(line.endsWith("\n"), JSON.stringify(secret));
            assert.ok(!/[\r\n]/.test(line.slice(0, -1)), `line break inside for ${JSON.stringify(secret)}`);
            assert.deepStrictEqual(nmcliPasswords(line), { "802-1x.password": secret }, JSON.stringify(secret));
        }
    });

    test.it("leaves an ordinary password readable", () => {
        assert.strictEqual(WifiList.secretLine("802-1x.password", "correct-horse"), "802-1x.password:correct-horse\n");
    });
});

test.describe("signInSecrets", () => {
    test.it("carries both entries nmcli asks for on a PEAP or TTLS network", () => {
        const text = WifiList.signInSecrets("peap", "s123456@dtu.dk", "hunter2");
        assert.deepStrictEqual(nmcliPasswords(text), { "802-1x.identity": "s123456@dtu.dk", "802-1x.password": "hunter2" });
    });

    test.it("keeps an identity with spaces or a backslash intact", () => {
        const text = WifiList.signInSecrets("ttls", " DOMAIN\\user ", "pass word");
        assert.deepStrictEqual(nmcliPasswords(text), { "802-1x.identity": " DOMAIN\\user ", "802-1x.password": "pass word" });
    });

    test.it("hands the key password to TLS under the name nmcli's agent asks for", () => {
        const text = WifiList.signInSecrets("tls", "s123456", "key pass");
        assert.deepStrictEqual(nmcliPasswords(text), { "802-1x.identity": "s123456", "802-1x.private-key-password": "key pass" });
    });
});

function settings(args) {
    assert.strictEqual(args.length % 2, 0);
    const out = {};
    for (let i = 0; i < args.length; i += 2) {
        assert.ok(!(args[i] in out), `${args[i]} set twice`);
        out[args[i]] = args[i + 1];
    }
    return out;
}

const PASSWORD_FORM = { method: "peap", identity: "s123456@dtu.dk", domain: "dtu.dk", authority: "" };
const TLS_FORM = { method: "tls", identity: "s123456", domain: "dtu.dk", authority: "/home/me/ca.pem", certificate: "/home/me/me.p12", key: "/home/me/me.p12", locked: true };

test.describe("signInArgs", () => {
    test.it("checks a PEAP server against the system store and the server name, behind an anonymous identity", () => {
        assert.deepStrictEqual(settings(WifiList.signInArgs("wpa", PASSWORD_FORM)), {
            "connection.auth-retries": "1",
            "wifi-sec.key-mgmt": "wpa-eap",
            "wifi-sec.auth-alg": "",
            "wifi-sec.pmf": "default",
            "802-1x.eap": "peap",
            "802-1x.identity": "s123456@dtu.dk",
            "802-1x.anonymous-identity": "anonymous@dtu.dk",
            "802-1x.phase2-auth": "mschapv2",
            "802-1x.system-ca-certs": "yes",
            "802-1x.ca-cert": "",
            "802-1x.domain-suffix-match": "dtu.dk",
            "802-1x.client-cert": "",
            "802-1x.private-key": "",
            "802-1x.password": "",
            "802-1x.private-key-password": "",
            "802-1x.private-key-password-flags": "none"
        });
    });

    test.it("pairs TTLS with PAP and trusts only a picked certificate file", () => {
        const got = settings(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { method: "ttls", authority: "/home/me/dtu.pem" })));
        assert.strictEqual(got["802-1x.eap"], "ttls");
        assert.strictEqual(got["802-1x.phase2-auth"], "pap");
        assert.strictEqual(got["802-1x.system-ca-certs"], "no");
        assert.strictEqual(got["802-1x.ca-cert"], "/home/me/dtu.pem");
        assert.strictEqual(got["802-1x.domain-suffix-match"], "dtu.dk");
    });

    test.it("signs TLS in with the certificate and key, with no inner method and no outer alias", () => {
        const got = settings(WifiList.signInArgs("wpa", TLS_FORM));
        assert.strictEqual(got["802-1x.eap"], "tls");
        assert.strictEqual(got["802-1x.client-cert"], "/home/me/me.p12");
        assert.strictEqual(got["802-1x.private-key"], "/home/me/me.p12");
        assert.strictEqual(got["802-1x.phase2-auth"], "");
        assert.strictEqual(got["802-1x.anonymous-identity"], "");
        assert.strictEqual(got["802-1x.private-key-password-flags"], "none");
        assert.strictEqual(settings(WifiList.signInArgs("wpa", Object.assign({}, TLS_FORM, { locked: false })))["802-1x.private-key-password-flags"], "not-required");
    });

    test.it("uses 802.1X key management with open auth on dynamic WEP", () => {
        const got = settings(WifiList.signInArgs("wep", PASSWORD_FORM));
        assert.strictEqual(got["wifi-sec.key-mgmt"], "ieee8021x");
        assert.strictEqual(got["wifi-sec.auth-alg"], "open");
        assert.strictEqual(got["802-1x.domain-suffix-match"], "dtu.dk");
    });

    test.it("runs WPA3 Suite-B only on TLS, with protected frames required", () => {
        const got = settings(WifiList.signInArgs("suiteb", TLS_FORM));
        assert.strictEqual(got["wifi-sec.key-mgmt"], "wpa-eap-suite-b-192");
        assert.strictEqual(got["wifi-sec.pmf"], "required");
        assert.strictEqual(got["802-1x.eap"], "tls");
        assert.strictEqual(WifiList.signInArgs("suiteb", PASSWORD_FORM), null);
        assert.deepStrictEqual(WifiList.signInMethods("suiteb"), ["tls"]);
    });

    test.it("refuses LEAP and anything it does not know, with a plain reason", () => {
        assert.strictEqual(WifiList.signInArgs("leap", PASSWORD_FORM), null);
        assert.deepStrictEqual(WifiList.signInMethods("leap"), []);
        assert.match(WifiList.signInRefusal("leap"), /LEAP/);
        assert.ok(WifiList.signInRefusal(""));
        assert.strictEqual(WifiList.signInRefusal("wpa"), "");
    });

    test.it("ends a refusal as a sentence, and tells a LEAP user who to ask", () => {
        for (const kind of ["leap", "", "owe"])
            assert.match(WifiList.signInRefusal(kind), /^[A-Z].*\.$/, kind);
        assert.match(WifiList.signInRefusal("leap"), /Ask whoever runs it .*WPA2 or WPA3 Enterprise\.$/);
    });

    test.it("keeps PEAP on MSCHAPv2 and TTLS on PAP unless another inner method is picked", () => {
        assert.deepStrictEqual(WifiList.innerMethods("peap"), ["mschapv2", "gtc"]);
        assert.deepStrictEqual(WifiList.innerMethods("ttls"), ["pap", "mschapv2"]);
        assert.deepStrictEqual(WifiList.innerMethods("tls"), []);
        assert.strictEqual(settings(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { inner: "" })))["802-1x.phase2-auth"], "mschapv2");
        const ttls = settings(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { method: "ttls", inner: "mschapv2" })));
        assert.strictEqual(ttls["802-1x.eap"], "ttls");
        assert.strictEqual(ttls["802-1x.phase2-auth"], "mschapv2");
        assert.strictEqual(settings(WifiList.signInArgs("wep", Object.assign({}, PASSWORD_FORM, { inner: "gtc" })))["802-1x.phase2-auth"], "gtc");
        assert.strictEqual(WifiList.innerName("mschapv2"), "MSCHAPv2");
    });

    test.it("never sends an inner method that does not belong to the outer one", () => {
        assert.strictEqual(WifiList.innerMethod("peap", "pap"), "mschapv2");
        assert.strictEqual(WifiList.innerMethod("ttls", "gtc"), "pap");
        assert.strictEqual(WifiList.innerMethod("ttls", "pap;reboot"), "pap");
        assert.strictEqual(settings(WifiList.signInArgs("wpa", Object.assign({}, TLS_FORM, { inner: "mschapv2" })))["802-1x.phase2-auth"], "");
    });

    test.it("sends an outer identity the person typed, and anonymous@realm when they typed none", () => {
        const typed = settings(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { outer: " guest@dtu.dk " })));
        assert.strictEqual(typed["802-1x.anonymous-identity"], "guest@dtu.dk");
        assert.strictEqual(typed["802-1x.identity"], "s123456@dtu.dk");
        assert.strictEqual(settings(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { outer: "  " })))["802-1x.anonymous-identity"], "anonymous@dtu.dk");
        assert.strictEqual(settings(WifiList.signInArgs("wpa", Object.assign({}, TLS_FORM, { outer: "guest@dtu.dk" })))["802-1x.anonymous-identity"], "");
        assert.strictEqual(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { outer: "two words" })), null);
    });

    test.it("never builds a profile that would take any server", () => {
        assert.strictEqual(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { domain: "" })), null);
        assert.strictEqual(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { domain: "not a name" })), null);
        assert.strictEqual(WifiList.signInArgs("wpa", Object.assign({}, PASSWORD_FORM, { domain: "", authority: "/usr/share/ca/public-root.pem" })), null);
        assert.strictEqual(WifiList.signInArgs("wpa", Object.assign({}, TLS_FORM, { certificate: "" })), null);
    });

    test.it("keeps every secret out of the command line, for every method", () => {
        const secret = "s3cret pass;\\'\"$(x)";
        const cases = [["wpa", PASSWORD_FORM], ["wpa", Object.assign({}, PASSWORD_FORM, { method: "ttls" })], ["wpa", TLS_FORM], ["wep", PASSWORD_FORM], ["wep", TLS_FORM], ["suiteb", TLS_FORM]];
        for (const [kind, form] of cases) {
            const args = WifiList.signInArgs(kind, form);
            assert.ok(args, `${kind} ${form.method}`);
            assert.ok(args.every(a => typeof a === "string"));
            assert.ok(!args.some(a => a.includes("s3cret")), `${kind} ${form.method}`);
            assert.strictEqual(settings(args)["802-1x.password"], "");
            assert.strictEqual(settings(args)["802-1x.private-key-password"], "");
            assert.ok(WifiList.signInSecrets(form.method, form.identity, secret).includes("s3cret"));
        }
    });
});

test.describe("server names", () => {
    test.it("reads a server name the way a person types it", () => {
        assert.strictEqual(WifiList.serverDomain(" DTU.dk "), "dtu.dk");
        assert.strictEqual(WifiList.serverDomain("*.win.dtu.dk"), "win.dtu.dk");
        assert.strictEqual(WifiList.serverDomain("https://radius.school.edu/login"), "radius.school.edu");
        assert.strictEqual(WifiList.serverDomain("dtu.dk."), "dtu.dk");
    });

    test.it("turns down anything that is not a host name", () => {
        for (const text of ["", "localhost", "dtu", "a;b.dk", "a b.dk", "-x.dk", "x..dk"])
            assert.strictEqual(WifiList.serverDomain(text), "", JSON.stringify(text));
    });

    test.it("fills in a server only for a network whose server is known", () => {
        assert.strictEqual(WifiList.knownServer("DTUsecure"), "dtu.dk");
        assert.strictEqual(WifiList.knownServer("eduroam"), "");
        assert.strictEqual(WifiList.knownServer("constructor"), "");
    });

    test.it("hides the username behind anonymous@ its realm, and leaves a bare name alone", () => {
        assert.strictEqual(WifiList.outerIdentity("peap", "s123456@dtu.dk"), "anonymous@dtu.dk");
        assert.strictEqual(WifiList.outerIdentity("ttls", "a@b@uni.edu"), "anonymous@uni.edu");
        assert.strictEqual(WifiList.outerIdentity("peap", "s123456"), "");
        assert.strictEqual(WifiList.outerIdentity("peap", "s123456@"), "");
        assert.strictEqual(WifiList.outerIdentity("tls", "s123456@dtu.dk"), "");
    });

    test.it("expands a home path and turns down a relative one", () => {
        assert.strictEqual(WifiList.filePath("~/Downloads/ca.pem", "/home/me"), "/home/me/Downloads/ca.pem");
        assert.strictEqual(WifiList.filePath(" /etc/ssl/ca.pem ", "/home/me"), "/etc/ssl/ca.pem");
        assert.strictEqual(WifiList.filePath("ca.pem", "/home/me"), "");
        assert.strictEqual(WifiList.filePath("~/ca.pem", ""), "");
    });
});

const DTU_ROOT_SHA256 = "ad61accf9a75deca01522ec5f6f95500c73f65c116149c09a6ac5aef410a0fe2";
const CERTIFICATES = "/home/me/.local/state/banditshell/certificates";

test.describe("school certificates", () => {
    test.it("ships DTU's root exactly as DTU published it", () => {
        const crypto = require("node:crypto");
        for (const entry of WifiList.SCHOOL_CERTIFICATES) {
            const pem = fs.readFileSync(path.join(ROOT, "assets/certificates", entry.file), "utf8");
            const der = Buffer.from(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, ""), "base64");
            assert.strictEqual(crypto.createHash("sha256").update(der).digest("hex"), entry.sha256, entry.file);
        }
        assert.strictEqual(WifiList.schoolCertificate("dtu.dk").sha256, DTU_ROOT_SHA256);
    });

    test.it("belongs to dtu.dk and every name under it", () => {
        for (const name of ["dtu.dk", "win.dtu.dk", "AIT-PISEPSN03.WIN.DTU.DK", "*.dtu.dk"])
            assert.strictEqual(WifiList.schoolCertificate(name)?.school, "DTU", name);
    });

    test.it("is never chosen for a server outside dtu.dk", () => {
        const others = ["", "dtu", "evil.com", "notdtu.dk", "evil-dtu.dk", "xdtu.dk", "dtu.dk.evil.com", "dtu.dkx", "dtu.de", "radius.uni.edu", "ku.dk", "dtu.dk;evil.com", "dtu.dk evil.com"];
        for (const domain of others) {
            assert.strictEqual(WifiList.schoolCertificate(domain), null, domain);
            const form = Object.assign({}, PASSWORD_FORM, { domain: domain, trust: "school" });
            assert.strictEqual(WifiList.trustedAuthority(form, "/home/me", CERTIFICATES), null, domain);
            for (const kind of ["wpa", "wep"]) {
                const args = WifiList.signInArgs(kind, Object.assign({}, form, { authority: WifiList.trustedAuthority(form, "/home/me", CERTIFICATES) || "" }));
                assert.ok(!args || !args.some(a => a.includes("dtu-root")), `${kind} ${domain}`);
            }
        }
    });

    test.it("is trusted alone, with the dtu.dk name check still on", () => {
        const form = Object.assign({}, PASSWORD_FORM, { domain: "dtu.dk", trust: "school" });
        const authority = WifiList.trustedAuthority(form, "/home/me", CERTIFICATES);
        assert.strictEqual(authority, `${CERTIFICATES}/dtu-root-ca-01.pem`);
        const got = settings(WifiList.signInArgs("wpa", Object.assign({}, form, { authority })));
        assert.strictEqual(got["802-1x.ca-cert"], authority);
        assert.strictEqual(got["802-1x.system-ca-certs"], "no");
        assert.strictEqual(got["802-1x.domain-suffix-match"], "dtu.dk");
    });

    test.it("lets a look-up use it only for a username at dtu.dk", () => {
        assert.strictEqual(WifiList.checkAuthority({ trust: "school", domain: "", identity: "s123456@dtu.dk" }, "/home/me", CERTIFICATES), `${CERTIFICATES}/dtu-root-ca-01.pem`);
        assert.strictEqual(WifiList.checkAuthority({ trust: "school", domain: "", identity: "me@uni.edu" }, "/home/me", CERTIFICATES), null);
        assert.strictEqual(WifiList.checkAuthority({ trust: "school", domain: "", identity: "s123456" }, "/home/me", CERTIFICATES), null);
        assert.strictEqual(WifiList.checkAuthority({ trust: "school", domain: "radius.uni.edu", identity: "s123456@dtu.dk" }, "/home/me", CERTIFICATES), null);
    });

    test.it("keeps system and picked-file trust as they were", () => {
        assert.strictEqual(WifiList.trustedAuthority({ trust: "system" }, "/home/me", CERTIFICATES), "");
        assert.strictEqual(WifiList.trustedAuthority({ trust: "file", authority: "~/ca.pem" }, "/home/me", CERTIFICATES), "/home/me/ca.pem");
        assert.strictEqual(WifiList.trustedAuthority({ trust: "file", authority: "ca.pem" }, "/home/me", CERTIFICATES), null);
    });
});

test.describe("serverMatch", () => {
    test.it("fills the username's school when the server is part of it", () => {
        assert.deepStrictEqual(WifiList.serverMatch("ait-pisepsn03.win.dtu.dk", "s123456@dtu.dk"), { state: "match", realm: "dtu.dk", fill: "dtu.dk" });
        assert.deepStrictEqual(WifiList.serverMatch("uni.edu", "me@Uni.edu"), { state: "match", realm: "uni.edu", fill: "uni.edu" });
    });

    test.it("flags a server outside the username's school", () => {
        for (const server of ["radius.evil.net", "evil-dtu.dk", "dtu.dk.evil.com"])
            assert.strictEqual(WifiList.serverMatch(server, "s123456@dtu.dk").state, "mismatch", server);
    });

    test.it("cannot judge without a realm or a name", () => {
        assert.strictEqual(WifiList.serverMatch("radius.uni.edu", "s123456").state, "unknown");
        assert.strictEqual(WifiList.serverMatch("", "s123456@dtu.dk").state, "none");
    });

    test.it("says plainly whether it matched", () => {
        const seen = { kind: "name", server: "radius.evil.net", authority: "R11" };
        assert.match(WifiList.serverSeenMessage(seen, "me@uni.edu"), /not part of uni\.edu.*look-alike/);
        assert.match(WifiList.serverSeenMessage(Object.assign({}, seen, { server: "radius.uni.edu" }), "me@uni.edu"), /matches uni\.edu.*filled in/);
        assert.match(WifiList.serverSeenMessage(seen, "me"), /no @school part/);
    });
});

test.describe("server check", () => {
    test.it("looks at the server with a name no certificate can carry, and nothing of the person's", () => {
        const got = settings(WifiList.serverCheckArgs("wpa", { method: "peap", identity: "s123456@dtu.dk", domain: "" }));
        assert.strictEqual(got["802-1x.domain-suffix-match"], "server-check.invalid");
        assert.strictEqual(got["802-1x.identity"], "anonymous@dtu.dk");
        assert.strictEqual(got["802-1x.anonymous-identity"], "anonymous@dtu.dk");
        assert.strictEqual(got["connection.autoconnect"], "no");
        assert.strictEqual(got["802-1x.system-ca-certs"], "yes");
        assert.ok(!Object.values(got).some(v => v.includes("s123456")));
        assert.deepStrictEqual(nmcliPasswords(WifiList.serverCheckSecrets({ identity: "s123456" })), { "802-1x.identity": "anonymous", "802-1x.password": "never-sent" });
    });

    test.it("looks up with the outer identity the person typed", () => {
        const form = { method: "ttls", identity: "s123456@dtu.dk", domain: "", outer: "eduroam@dtu.dk" };
        assert.strictEqual(settings(WifiList.serverCheckArgs("wpa", form))["802-1x.anonymous-identity"], "eduroam@dtu.dk");
        assert.deepStrictEqual(nmcliPasswords(WifiList.serverCheckSecrets(form)), { "802-1x.identity": "eduroam@dtu.dk", "802-1x.password": "never-sent" });
        assert.strictEqual(WifiList.serverCheckArgs("wpa", Object.assign({}, form, { outer: "a b" })), null);
    });

    test.it("has no check for Suite-B or LEAP", () => {
        assert.strictEqual(WifiList.serverCheckArgs("suiteb", {}), null);
        assert.strictEqual(WifiList.serverCheckArgs("leap", {}), null);
    });
});

test.describe("serverTrouble", () => {
    const log = fs.readFileSync(path.join(ROOT, "tests/fixtures/network/wpa-supplicant-certificates.txt"), "utf8");
    const attempts = log.split(/(?=wlp7s0: CTRL-EVENT-EAP-STARTED)/);

    test.it("names who vouched for a server this computer does not trust", () => {
        const trouble = WifiList.serverTrouble(attempts[1]);
        assert.deepStrictEqual(trouble, { kind: "untrusted", server: "", authority: "Afdelingen for IT Service Issuing CA 03" });
        assert.strictEqual(WifiList.serverLabel(trouble), "server not trusted");
        assert.match(WifiList.serverMessage(trouble, "dtu.dk"), /does not trust the chain the server sent, which ends at Afdelingen for IT Service Issuing CA 03\. Under More, set trust to a file.*not sent/);
    });

    test.it("reads the name a server answered as, from the last attempt only", () => {
        const trouble = WifiList.serverTrouble(log);
        assert.deepStrictEqual(trouble, { kind: "name", server: "ait-pisepsn01.win.dtu.dk", authority: "DTU ROOT CA 01" });
        assert.strictEqual(WifiList.serverLabel(trouble), "server did not match");
        assert.strictEqual(WifiList.serverMessage(trouble, "school.edu"), "The server answered as ait-pisepsn01.win.dtu.dk, not school.edu, vouched for by DTU ROOT CA 01. Your password was not sent.");
        assert.match(WifiList.serverSeenMessage(trouble), /^It answered as ait-pisepsn01\.win\.dtu\.dk/);
    });

    test.it("prefers the name in the certificate's alternative names", () => {
        const trouble = WifiList.serverTrouble("x: CTRL-EVENT-EAP-PEER-ALT depth=0 DNS:Radius.Uni.edu\nx: CTRL-EVENT-EAP-TLS-CERT-ERROR reason=9 depth=0 subject='/CN=rad1' err='Domain suffix mismatch'");
        assert.strictEqual(trouble.server, "radius.uni.edu");
    });

    test.it("finds nothing in a log with no certificate trouble, or none at all", () => {
        assert.strictEqual(WifiList.serverTrouble(attempts[0]), null);
        assert.strictEqual(WifiList.serverTrouble(""), null);
        assert.strictEqual(WifiList.serverLabel(null), "");
        assert.match(WifiList.serverSeenMessage(null), /Could not see/);
    });

    test.it("forgets a certificate error once a later attempt starts", () => {
        assert.strictEqual(WifiList.serverTrouble(attempts[1] + "wlp7s0: CTRL-EVENT-EAP-STARTED EAP authentication started\nwlp7s0: CTRL-EVENT-EAP-FAILURE EAP authentication failed\n"), null);
    });

    test.it("reads only the adapter that was signing in", () => {
        assert.strictEqual(WifiList.serverTrouble(attempts[1].replace(/wlp7s0:/g, "wlan1:"), "wlp7s0"), null);
        assert.strictEqual(WifiList.serverTrouble(log, "wlp7s0").kind, "name");
    });

    test.it("offers no name when the certificate's name is not a host name", () => {
        const trouble = WifiList.serverTrouble("x: CTRL-EVENT-EAP-TLS-CERT-ERROR reason=9 depth=0 subject='/CN=RADIUS Server' err='Domain suffix mismatch'");
        assert.strictEqual(trouble.server, "");
        assert.match(WifiList.serverSeenMessage(trouble), /no name this form can use/);
    });

    test.it("tells an expired certificate apart", () => {
        const trouble = WifiList.serverTrouble("x: CTRL-EVENT-EAP-TLS-CERT-ERROR reason=4 depth=0 subject='/CN=r.uni.edu' err='certificate has expired'");
        assert.strictEqual(trouble.kind, "expired");
    });
});

test.describe("join failures", () => {
    test.it("names the network and the cause in plain words", () => {
        assert.strictEqual(WifiList.failureMessage("Cafe", "timeout"), "Cafe: no answer");
        assert.strictEqual(WifiList.failureMessage("Cafe", "password"), "Cafe: wrong password");
        assert.strictEqual(WifiList.failureMessage("Cafe", "lost"), "Cafe: it went away");
    });

    test.it("keeps the short row labels the menu shows", () => {
        assert.strictEqual(WifiList.failureLabel("password"), "wrong password");
        assert.strictEqual(WifiList.failureLabel("timeout"), "no answer");
        assert.strictEqual(WifiList.failureLabel("hungup"), "it hung up");
    });

    test.it("explains the cause in a sentence for the island's view", () => {
        assert.strictEqual(WifiList.failureReason("timeout"), "The router did not answer");
        assert.strictEqual(WifiList.failureReason("password"), "The password did not work");
        assert.strictEqual(WifiList.failureReason("nonsense"), "Something went wrong while joining");
    });

    test.it("falls back to a general cause for a reason it does not know", () => {
        assert.strictEqual(WifiList.failureLabel("nonsense"), "could not join");
        assert.strictEqual(WifiList.failureMessage("Cafe", undefined), "Cafe: could not join");
    });
});
