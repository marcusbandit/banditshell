function report(text) {
    const got = { failed: false, output: [], values: {} };
    for (const line of String(text ?? "").split("\n")) {
        if (line.startsWith("|"))
            got.output.push(line.slice(1));
        else if (line === "failed")
            got.failed = true;
        else {
            const eq = line.indexOf("=");
            if (eq > 0)
                got.values[line.slice(0, eq)] = line.slice(eq + 1).trim();
        }
    }
    return got;
}

function listedAfter(lines, at) {
    const files = [];
    for (let i = at + 1; i < lines.length && lines[i].startsWith("\t"); i++)
        files.push(lines[i].trim());
    return files;
}

function named(files) {
    if (files.length === 0)
        return "some files";
    const shown = files.slice(0, 3).join(", ");
    return files.length > 3 ? `${shown} and ${files.length - 3} more` : shown;
}

function explain(output, branch) {
    const lines = (Array.isArray(output) ? output : String(output ?? "").split("\n")).map(l => String(l).replace(/\r$/, ""));
    const text = lines.join("\n");
    const at = pattern => lines.findIndex(l => pattern.test(l));

    const edited = at(/Your local changes to the following files would be overwritten/);
    if (edited >= 0)
        return `Files edited on this computer are also changed by the update: ${named(listedAfter(lines, edited))}. Commit or move those edits away, then try again.`;

    const untracked = at(/untracked working tree files would be (overwritten|removed)/);
    if (untracked >= 0)
        return `The update brings files that already exist here: ${named(listedAfter(lines, untracked))}. Move them out of the way, then try again.`;

    if (/Not possible to fast-forward|Diverging branches/.test(text))
        return "This copy has commits of its own that GitHub does not have, so it cannot just move forward.";
    if (/index\.lock'?: File exists/.test(text))
        return "Another git command is busy in this folder. Try again when it has finished.";
    if (/^fatal: not a git repository/m.test(text))
        return "This copy has no git history, so it cannot update itself.";
    if (/^timed out$/m.test(text))
        return "GitHub took too long to answer. Try again later.";
    if (/Could not resolve host|Failed to connect|Connection timed out|Connection refused|Network is unreachable|Could not connect/.test(text))
        return "Could not reach GitHub. Check the internet connection, then refresh.";
    if (/couldn't find remote ref/.test(text))
        return `GitHub has no branch called "${branch}".`;
    if (/Repository not found|does not appear to be a git repository|Could not read from remote repository|Permission denied|Authentication failed|terminal prompts disabled|Host key verification failed/.test(text))
        return "GitHub turned the request down: the address is wrong, or this computer has no access.";

    const said = lines.filter(l => /^(fatal|error): /.test(l)).pop() ?? lines.filter(l => l.trim()).pop();
    return said ? said.replace(/^(fatal|error): /, "").trim() : "git failed without saying why.";
}

function setAside(list) {
    const files = String(list ?? "").split("\t").filter(Boolean);
    if (files.length === 0)
        return "";
    return `Your edits to ${named(files)} were in the way, so they were set aside in git stash before updating. git stash list shows them; git stash pop brings them back.`;
}

function ago(when, now) {
    const mins = Math.max(0, Math.round((now - when) / 60000));
    if (mins < 1)
        return "just now";
    if (mins < 60)
        return `${mins} min ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24)
        return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
}
