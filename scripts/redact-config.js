#!/usr/bin/env node
"use strict";

const fs = require("node:fs");

const SECRET_WORDS = ["token", "tokens", "key", "keys", "secret", "secrets", "password", "passwords", "passwd", "passphrase", "cookie", "cookies", "credential", "credentials", "apikey", "auth", "bearer"];

function wordsOf(name) {
    return String(name)
        .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
        .toLowerCase()
        .split(/[^a-z0-9]+/)
        .filter(word => word);
}

function isSecret(name) {
    return wordsOf(name).some(word => SECRET_WORDS.includes(word) || word.endsWith("apikey"));
}

function redact(value) {
    if (Array.isArray(value))
        return value.map(redact);
    if (value && typeof value === "object") {
        const out = {};
        for (const name of Object.keys(value))
            if (!isSecret(name))
                out[name] = redact(value[name]);
        return out;
    }
    return value;
}

function main(argv) {
    const file = argv[0];
    let parsed;
    try {
        parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (error) {
        process.stdout.write(error.code === "ENOENT" ? "no config file\n" : "config file does not parse\n");
        return 0;
    }
    process.stdout.write(JSON.stringify(redact(parsed), null, 2) + "\n");
    return 0;
}

if (require.main === module)
    process.exit(main(process.argv.slice(2)));

module.exports = { isSecret, redact };
