.pragma library

var DIRECTORIES = ["/usr/bin", "/bin", "/usr/sbin", "/sbin", "/run/wrappers/bin", "/run/current-system/sw/bin"];
var TOOL = /^[a-z][a-z0-9-]*$/;

var PROBE = 'for tool do\n' + '    for dir in ' + DIRECTORIES.join(" ") + '; do\n' + '        if [ -f "$dir/$tool" ] && [ -x "$dir/$tool" ]; then printf "%s\\t%s\\n" "$tool" "$dir/$tool"; break; fi\n' + '    done\n' + 'done\n' + 'true\n';

function probeCommand(tools) {
    return ["sh", "-c", PROBE, "sh"].concat(tools.filter(function (t) {
        return TOOL.test(t);
    }));
}

function systemPath(path, tool) {
    var p = String(path || "");
    if (!TOOL.test(String(tool || "")) || p.indexOf("..") >= 0)
        return false;
    for (var i = 0; i < DIRECTORIES.length; i++)
        if (p === DIRECTORIES[i] + "/" + tool)
            return true;
    return false;
}

function readPaths(text) {
    var out = {};
    var all = String(text || "").split("\n");
    for (var i = 0; i < all.length; i++) {
        var fields = all[i].split("\t");
        if (fields.length === 2 && out[fields[0]] === undefined && systemPath(fields[1], fields[0]))
            out[fields[0]] = fields[1];
    }
    return out;
}

function elevated(paths, tool, args) {
    var pkexec = paths && paths.pkexec;
    var program = paths && paths[tool];
    if (!systemPath(pkexec, "pkexec") || !systemPath(program, tool))
        return null;
    return [pkexec, program].concat(args);
}
