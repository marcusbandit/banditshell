.pragma library

var VIEWS = {
    cpu: "cpu",
    processor: "cpu",
    "cpu usage": "cpu",
    memory: "memory",
    ram: "memory",
    "memory usage": "memory",
    swap: "memory",
    disk: "disk",
    disks: "disk",
    storage: "disk",
    "disk space": "disk",
    "disk usage": "disk",
    "free space": "disk",
    top: "top",
    "top processes": "top",
    "busy processes": "top",
    system: "system",
    "system monitor": "system",
    "system info": "system",
    sysinfo: "system",
    "activity monitor": "system",
    "task manager": "system",
    stats: "system",
    uptime: "uptime"
};

var SPACES = /\s+/g;

var PSEUDO = ["tmpfs", "devtmpfs", "efivarfs", "squashfs", "overlay", "ramfs", "proc", "sysfs", "cgroup", "cgroup2", "nsfs", "autofs", "debugfs", "tracefs", "securityfs", "pstore", "bpf", "configfs", "fusectl", "mqueue", "hugetlbfs", "binfmt_misc", "fuse.portal", "fuse.gvfsd-fuse", "fuse.xdg-document-portal"];

var SAMPLE = `getconf CLK_TCK; getconf PAGESIZE; cut -d' ' -f1 /proc/uptime
echo ---
for d in /proc/[0-9]*; do [ -O "$d" ] && echo "\${d#/proc/}"; done
echo ---
cat /proc/[0-9]*/stat 2>/dev/null`;

function monitorAsk(text) {
    var t = String(text || "").trim().toLowerCase().replace(SPACES, " ");
    return VIEWS[t] || "";
}

function readSample(text) {
    var parts = String(text || "").split("\n---\n");
    if (parts.length < 3)
        return null;
    var head = parts[0].split("\n");
    var own = {};
    parts[1].split("\n").forEach(p => {
        if (p)
            own[p.trim()] = true;
    });
    var processes = {};
    var lines = parts.slice(2).join("\n").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var open = line.indexOf(" (");
        var close = line.lastIndexOf(")");
        if (open < 0 || close < open)
            continue;
        var pid = line.slice(0, open);
        var fields = line.slice(close + 2).split(" ");
        if (fields.length < 22)
            continue;
        processes[pid] = {
            pid: Number(pid),
            name: line.slice(open + 2, close),
            ticks: Number(fields[11]) + Number(fields[12]),
            pages: Number(fields[21]) || 0
        };
    }
    return {
        ticksPerSecond: Number(head[0]) || 100,
        pageSize: Number(head[1]) || 4096,
        uptime: Number(head[2]) || 0,
        own: own,
        processes: processes
    };
}

function topProcesses(before, after, count) {
    if (!before || !after || after.uptime <= before.uptime)
        return [];
    var elapsed = after.uptime - before.uptime;
    var out = [];
    for (var pid in after.processes) {
        var now = after.processes[pid];
        var was = before.processes[pid];
        if (!was || was.name !== now.name || now.pages <= 0)
            continue;
        out.push({
            pid: now.pid,
            name: now.name,
            cpu: Math.max(0, (now.ticks - was.ticks) / after.ticksPerSecond / elapsed * 100),
            memory: now.pages * after.pageSize,
            own: !!after.own[pid]
        });
    }
    out.sort((a, b) => b.cpu - a.cpu || b.memory - a.memory);
    return out.slice(0, count || 5);
}

function readDisks(text) {
    var lines = String(text || "").split("\n").slice(1);
    var byDevice = {};
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var m = /^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+\S+\s+(.+)$/.exec(lines[i]);
        if (!m || PSEUDO.indexOf(m[2]) >= 0 || Number(m[3]) <= 0)
            continue;
        var disk = {
            device: m[1],
            type: m[2],
            size: Number(m[3]) * 1024,
            used: Number(m[4]) * 1024,
            available: Number(m[5]) * 1024,
            mount: m[6]
        };
        disk.fraction = disk.used + disk.available > 0 ? disk.used / (disk.used + disk.available) : 0;
        var known = byDevice[disk.device];
        if (known) {
            if (disk.mount.length < known.mount.length)
                Object.assign(known, disk);
            continue;
        }
        byDevice[disk.device] = disk;
        out.push(disk);
    }
    return out.sort((a, b) => a.mount < b.mount ? -1 : a.mount > b.mount ? 1 : 0);
}

function bytesText(bytes) {
    var units = ["B", "KB", "MB", "GB", "TB", "PB"];
    var n = Math.max(0, Number(bytes) || 0);
    var u = 0;
    while (n >= 1024 && u < units.length - 1) {
        n /= 1024;
        u++;
    }
    return `${u >= 3 && n < 100 ? n.toFixed(1) : Math.round(n)} ${units[u]}`;
}

function percentText(fraction) {
    return `${Math.round(Math.max(0, Math.min(1, fraction)) * 100)}%`;
}

function uptimeText(seconds) {
    var s = Math.max(0, Math.floor(seconds));
    var days = Math.floor(s / 86400);
    var hours = Math.floor(s % 86400 / 3600);
    var minutes = Math.floor(s % 3600 / 60);
    if (days)
        return `${days} ${days === 1 ? "day" : "days"} ${hours} h`;
    if (hours)
        return `${hours} h ${minutes} min`;
    return `${minutes} min`;
}

function cpuText(value) {
    return value >= 10 ? `${Math.round(value)}%` : `${value.toFixed(1)}%`;
}
