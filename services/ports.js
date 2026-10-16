.pragma library

var LINE = /^(?:(tcp|udp|raw|sctp)\s+)?(\S+)\s+\d+\s+\d+\s+(\S+):(\d+|\*)\s+\S+(?:\s+(.*))?$/;
var USER = /\("((?:[^"\\]|\\.)*)",pid=(\d+)/g;

function readListeners(text) {
    var byPid = {};
    var order = [];
    var strangers = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var m = LINE.exec(lines[i].trim());
        if (!m)
            continue;
        var protocol = m[1] || (m[2] === "LISTEN" ? "tcp" : "udp");
        var address = `${m[3]}:${m[4]}`;
        var where = `${protocol} ${address}`;
        var users = m[5] || "";
        var found = false;
        var user;
        USER.lastIndex = 0;
        while ((user = USER.exec(users)) !== null) {
            found = true;
            var pid = parseInt(user[2], 10);
            if (!byPid[pid]) {
                byPid[pid] = {
                    pid: pid,
                    name: user[1],
                    addresses: []
                };
                order.push(pid);
            }
            if (byPid[pid].addresses.indexOf(where) < 0)
                byPid[pid].addresses.push(where);
        }
        if (!found && strangers.indexOf(where) < 0)
            strangers.push(where);
    }
    var out = order.map(pid => byPid[pid]);
    if (strangers.length)
        out.push({
            pid: 0,
            name: "",
            addresses: strangers
        });
    return out;
}
