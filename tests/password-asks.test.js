const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/password-asks.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Asks = new Function(src + "\nreturn { describe, callerOf, causeOf, sshTarget, pkexecRun };")();
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
        assert.strictEqual(told.body, "Unlocks ~/.ssh/id_ed25519 so git can push to github.com/you/project.");
        assert.strictEqual(told.placeholder, "Passphrase for id_ed25519");
        assert.match(told.hint, /not your login password/);
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
        assert.strictEqual(told.body, "banditshell needs it to uninstall Firefox.");
        assert.deepStrictEqual(told.details[0], ["Runs as root", "pacman -Rs --noconfirm firefox"]);
        assert.strictEqual(told.placeholder, "Password for you");
    });

    test.it("asks for root's password when polkit picked root", () => {
        const told = Asks.describe({ source: "polkit", user: "you", identity: { name: "unix-user:root" }, message: "Authentication is required to restart 'sshd.service'." });
        assert.strictEqual(told.secret, "The root password");
        assert.strictEqual(told.body, "A program needs it to restart 'sshd.service'.");
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
        assert.strictEqual(told.body, "An app wants a saved password from the “Work” keyring.");
    });

    test.it("asks a new keyring for a new password", () => {
        const told = Asks.describe({ source: "keyring", kind: "password", requester: "gnome-keyring-daemon", passwordNew: true, title: "New Keyring Password", message: "Choose password for new keyring", description: "An application wants to create a new keyring called “Default keyring”. Choose the password you want to use for it." });
        assert.strictEqual(told.secret, "Password for a new keyring");
        assert.strictEqual(told.body, "An app wants a new keyring, “Default keyring”, for its passwords.");
    });

    test.it("reads a GPG prompt's owner and key id from pinentry's description", () => {
        const told = Asks.describe({ source: "keyring", kind: "password", requester: "pinentry-gnome3", title: "Enter Passphrase", message: "Passphrase:", description: "Please enter the passphrase to unlock the OpenPGP secret key:\n\"Ada Example (laptop) <ada@example.com>\"\n255-bit EDDSA key, ID 0123456789ABCDEF,\ncreated 2025-01-01." });
        assert.strictEqual(told.secret, "GPG key passphrase");
        assert.strictEqual(told.body, "Unlocks Ada Example's key 89ABCDEF for gpg.");
    });

    test.it("shows a yes-or-no keyring question by its title once", () => {
        const told = Asks.describe({ source: "keyring", kind: "confirm", requester: "gnome-keyring-daemon", title: "Store passwords unencrypted?", description: "By choosing to use a blank password, your stored passwords will not be safely encrypted." });
        assert.strictEqual(told.secret, "Store passwords unencrypted?");
        assert.strictEqual(told.placeholder, "");
    });

    test.it("passes a shell request's own words through", () => {
        const told = Asks.describe({ source: "request", secret: "Wi-Fi password", body: "Joins Cafe, a WPA2 network.", placeholder: "Password for Cafe" });
        assert.strictEqual(told.secret, "Wi-Fi password");
        assert.strictEqual(told.body, "Joins Cafe, a WPA2 network.");
        assert.deepStrictEqual(told.details, []);
    });
});
