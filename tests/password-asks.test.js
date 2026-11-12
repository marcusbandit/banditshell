const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/password-asks.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Asks = new Function(src + "\nreturn { describe, callerOf, causeOf, sshTarget, pkexecRun, agentKind };")();
const SS = fs.readFileSync(path.join(ROOT, "tests/fixtures/password/ss-agent.txt"), "utf8");
const PS = fs.readFileSync(path.join(ROOT, "tests/fixtures/password/ps.txt"), "utf8");
const HOME = "/home/you";

const SSH_ASK = {
    source: "keyring",
    kind: "password",
    requester: "gcr-ssh-agent",
    title: "Unlock private key",
    message: "Enter password to unlock the private key",
    description: "An application wants access to the private key “ Enter passphrase for /home/you/.ssh/id_ed25519: ”, but it is locked",
    choiceLabel: "Automatically unlock this key whenever I’m logged in",
    home: HOME
};

test.describe("callerOf", () => {
    test.it("finds the newest program connected to the ssh agent and walks up to who started it", () => {
        const chain = Asks.callerOf(SS, PS, 4100, "gcr-ssh-agent");
        assert.deepStrictEqual(chain.map(entry => entry.pid), [5203, 5170, 5160, 5150, 5100, 1200]);
    });

    test.it("goes through pinentry to the gpg agent it was started by", () => {
        const chain = Asks.callerOf(SS, PS, 4310, "pinentry-gnome3");
        assert.strictEqual(chain[0].pid, 5401);
    });

    test.it("reads exact arguments when they are given, so an option with spaces does not hide the host", () => {
        const argv = "5090 ssh\x1f-o\x1fProxyCommand=ssh -W %h:%p jump\x1fbuild.example.com\x1f";
        const ss = "u_str ESTAB 0 0 /run/user/1000/gcr/ssh 1 * 2 users:((\"gcr-ssh-agent\",pid=4100,fd=6))\nu_str ESTAB 0 0 * 2 * 1 users:((\"ssh\",pid=5090,fd=3))";
        assert.deepStrictEqual(Asks.causeOf(Asks.callerOf(ss, PS, 4100, "gcr-ssh-agent", argv)), { who: "ssh", doing: "connect to build.example.com" });
    });

    test.it("finds nothing when the agent has no callers or no pid", () => {
        assert.deepStrictEqual(Asks.callerOf(SS, PS, 0, "gcr-ssh-agent"), []);
        assert.deepStrictEqual(Asks.callerOf("", PS, 4100, "gcr-ssh-agent"), []);
    });
});

test.describe("causeOf", () => {
    const chainFor = pid => {
        const lines = PS.split("\n");
        const table = {};
        for (const line of lines) {
            const m = line.match(/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/);
            if (m)
                table[m[1]] = { pid: +m[1], ppid: +m[2], age: +m[3], args: m[4].trim().split(/\s+/) };
        }
        const chain = [];
        for (let at = table[pid]; at && at.pid > 1; at = table[at.ppid])
            chain.push(at);
        return chain;
    };

    test.it("names a git push from a terminal with its host and repository", () => {
        assert.deepStrictEqual(Asks.causeOf(chainFor(5001)), { who: "git", doing: "push to github.com/you/project" });
    });

    test.it("names the program that ran git when it is not a terminal, and calls a pull a pull", () => {
        assert.deepStrictEqual(Asks.causeOf(chainFor(5203)), { who: "claude", doing: "pull from github.com/you/project" });
    });

    test.it("names a plain ssh login by its host", () => {
        assert.deepStrictEqual(Asks.causeOf(chainFor(5090)), { who: "ssh", doing: "connect to build.example.com" });
    });

    test.it("names a signed commit behind gpg", () => {
        assert.deepStrictEqual(Asks.causeOf(chainFor(5401)), { who: "git", doing: "sign a commit" });
    });

    test.it("looks past a login shell's dash, as tmux starts panes", () => {
        assert.deepStrictEqual(Asks.causeOf(chainFor(6011)), { who: "git", doing: "push to github.com/you/project" });
    });

    test.it("reads gpg's own arguments before the git around it", () => {
        assert.deepStrictEqual(Asks.causeOf(chainFor(6120)), { who: "git", doing: "decrypt something" });
    });

    test.it("names git signing a commit with an SSH key", () => {
        assert.deepStrictEqual(Asks.causeOf(chainFor(6210)), { who: "git", doing: "sign a commit" });
    });

    test.it("says nothing for an empty chain", () => {
        assert.strictEqual(Asks.causeOf([]), null);
    });
});

test.describe("sshTarget", () => {
    test.it("skips options with values, joined or apart, and reads user and host", () => {
        assert.deepStrictEqual(Asks.sshTarget(["ssh", "-p", "22", "-oBatchMode=yes", "-i", "k", "-v", "me@host.example", "ls", "-la"]), { user: "me", host: "host.example", command: ["ls", "-la"] });
    });

    test.it("reads an ssh:// destination", () => {
        assert.strictEqual(Asks.sshTarget(["ssh", "ssh://git@git.example.com:2222/x.git"]).host, "git.example.com");
    });
});

test.describe("describe", () => {
    test.it("asks for the SSH key's passphrase, names the key by its path and who waits on it, and keeps gcr's words for later", () => {
        const told = Asks.describe(Object.assign({ cause: { who: "git", doing: "push to github.com/you/project" } }, SSH_ASK));
        assert.strictEqual(told.secret, "SSH key passphrase");
        assert.deepStrictEqual(told.facts, [["Key", "~/.ssh/id_ed25519"], ["Asked by", "git, to push to github.com/you/project"]]);
        assert.strictEqual(told.placeholder, "Passphrase");
        assert.match(told.hint, /Not your login password/);
        assert.strictEqual(told.choice, "Unlock it on its own whenever I'm logged in");
        assert.ok(told.details.some(([label, text]) => label === "Their words" && text.includes("Enter passphrase for")));
    });

    test.it("says a wrong passphrase was wrong in the card's own words", () => {
        assert.strictEqual(Asks.describe(Object.assign({}, SSH_ASK, { warning: "The unlock password was incorrect" })).warning, "That passphrase did not work. Try again.");
    });

    test.it("asks for the user's own password for polkit and names the command that runs as root", () => {
        const told = Asks.describe({
            source: "polkit",
            user: "you",
            identity: { name: "unix-user:you" },
            actionId: "org.freedesktop.policykit.exec",
            message: "Authentication is needed to run `/usr/bin/pacman -Rs --noconfirm firefox' as the super user",
            label: "Uninstall Firefox"
        });
        assert.strictEqual(told.secret, "Your sudo password");
        assert.deepStrictEqual(told.facts, [["Account", "you"], ["Asked by", "banditshell, to uninstall Firefox"], ["As root", "pacman -Rs --noconfirm firefox"]]);
        assert.strictEqual(told.placeholder, "Password");
    });

    test.it("names what PAM asks for when it is not a password", () => {
        const told = Asks.describe({ source: "polkit", user: "you", identity: { name: "you" }, inputPrompt: "Verification code: ", message: "Authentication is required to restart 'sshd.service'." });
        assert.strictEqual(told.secret, "Verification code");
        assert.strictEqual(told.placeholder, "Verification code");
    });

    test.it("reads pkexec's other user by login name", () => {
        const told = Asks.describe({ source: "polkit", user: "you", identity: { name: "you" }, message: "Authentication is needed to run `/usr/bin/id' as user Joe Bloggs (joe)" });
        assert.deepStrictEqual(told.facts[1], ["As joe", "id"]);
    });

    test.it("asks for root's password when polkit picked root", () => {
        const told = Asks.describe({ source: "polkit", user: "you", identity: { name: "unix-user:root" }, message: "Authentication is required to restart 'sshd.service'." });
        assert.strictEqual(told.secret, "The root password");
        assert.deepStrictEqual(told.facts[1], ["Wants to", "restart 'sshd.service'"]);
    });

    test.it("tells a face-unlock login why the login keyring is still locked", () => {
        const told = Asks.describe({ source: "keyring", kind: "password", requester: "gnome-keyring-daemon", title: "Unlock Login Keyring", message: "Authentication required", description: "The login keyring did not get unlocked when you logged into your computer." });
        assert.strictEqual(told.secret, "Login keyring password");
        assert.match(told.hint, /Face unlock/);
    });

    test.it("asks for the old password when the login password moved on", () => {
        const told = Asks.describe({ source: "keyring", kind: "password", requester: "gnome-keyring-daemon", title: "Unlock Login Keyring", description: "The password you use to log in to your computer no longer matches that of your login keyring." });
        assert.strictEqual(told.placeholder, "Old login password");
    });

    test.it("names another keyring by the name in quotes", () => {
        const told = Asks.describe({ source: "keyring", kind: "password", requester: "gnome-keyring-daemon", title: "Unlock Keyring", message: "Unlock password for: Work", description: "An application wants access to the keyring “Work”, but it is locked" });
        assert.strictEqual(told.secret, "Keyring password");
        assert.deepStrictEqual(told.facts[0], ["Keyring", "Work"]);
    });

    test.it("asks a new keyring for a new password", () => {
        const told = Asks.describe({ source: "keyring", kind: "password", requester: "gnome-keyring-daemon", passwordNew: true, title: "New Keyring Password", message: "Choose password for new keyring", description: "An application wants to create a new keyring called “Default keyring”. Choose the password you want to use for it." });
        assert.strictEqual(told.secret, "Password for a new keyring");
        assert.deepStrictEqual(told.facts[0], ["Keyring", "Default keyring, new"]);
    });

    test.it("reads a GPG prompt's owner and key id from pinentry's description", () => {
        const told = Asks.describe({ source: "keyring", kind: "password", requester: "pinentry-gnome3", title: "Enter Passphrase", message: "Passphrase:", description: "Please enter the passphrase to unlock the OpenPGP secret key:\n\"Ada Example (laptop) <ada@example.com>\"\n255-bit EDDSA key, ID 0123456789ABCDEF,\ncreated 2025-01-01." });
        assert.strictEqual(told.secret, "GPG key passphrase");
        assert.deepStrictEqual(told.facts, [["Key", "Ada Example, 89ABCDEF"], ["Asked by", "gpg"]]);
    });

    test.it("shows a yes-or-no pinentry question as a question, not a passphrase", () => {
        const told = Asks.describe({ source: "keyring", kind: "confirm", requester: "pinentry-gnome3", title: "Enter Passphrase", description: "An ssh process requested the use of key\nSHA256:abc\nDo you want to allow this?" });
        assert.strictEqual(told.secret, "An ssh process requested the use of key");
        assert.strictEqual(told.placeholder, "");
    });

    test.it("gives a smartcard its own PIN card and a gpg --passwd its new passphrase", () => {
        assert.strictEqual(Asks.describe({ source: "keyring", kind: "password", requester: "pinentry-gnome3", message: "PIN", description: "Please unlock the card\n\nNumber: 0006 12345678" }).secret, "Card PIN");
        assert.strictEqual(Asks.describe({ source: "keyring", kind: "password", requester: "pinentry-gnome3", passwordNew: true, description: "Please enter the new passphrase" }).secret, "New GPG passphrase");
    });

    test.it("traces only the real agents, never an askpass that happens to say ssh", () => {
        assert.strictEqual(Asks.agentKind("gcr-ssh-agent"), "ssh");
        assert.strictEqual(Asks.agentKind("pinentry-gnome3"), "gpg");
        assert.strictEqual(Asks.agentKind("seahorse-ssh-askpass"), "");
    });

    test.it("shows a yes-or-no keyring question by its title once", () => {
        const told = Asks.describe({ source: "keyring", kind: "confirm", requester: "gnome-keyring-daemon", title: "Store passwords unencrypted?", description: "By choosing to use a blank password, your stored passwords will not be safely encrypted." });
        assert.strictEqual(told.secret, "Store passwords unencrypted?");
        assert.strictEqual(told.placeholder, "");
    });

    test.it("passes a shell request's own words through", () => {
        const told = Asks.describe({ source: "request", secret: "Wi-Fi password", facts: [["Network", "Cafe"]], placeholder: "Password for Cafe" });
        assert.strictEqual(told.secret, "Wi-Fi password");
        assert.deepStrictEqual(told.facts, [["Network", "Cafe"]]);
        assert.deepStrictEqual(told.details, []);
    });
});
