.pragma library

const service = "banditshell";

const stack = "auth required pam_unix.so nullok nodelay\n";

const faceService = "banditshell-face";

const faces = ["gaze", "howdy"];

const securityDirs = [
    "/usr/lib/security",
    "/lib/security",
    "/usr/lib64/security",
    "/lib64/security",
    "/usr/lib/x86_64-linux-gnu/security",
    "/lib/x86_64-linux-gnu/security",
    "/usr/lib/aarch64-linux-gnu/security",
    "/lib/aarch64-linux-gnu/security"
];

function faceStack(chosen) {
    const known = (chosen || []).filter(face => faces.indexOf(face) >= 0);
    return known.map((face, i) => `auth ${i < known.length - 1 ? "sufficient" : "required"} pam_${face}.so\n`).join("");
}

function faceModules() {
    const paths = [];
    for (const face of faces)
        for (const dir of securityDirs)
            paths.push(`${dir}/pam_${face}.so`);
    return paths;
}

function faceOf(path) {
    const found = /\/pam_([a-z]+)\.so$/.exec(path || "");
    return found && faces.indexOf(found[1]) >= 0 ? found[1] : "";
}

function directory(room) {
    return room ? `${room}/banditshell/pam.d` : "";
}

function file(room, name) {
    const folder = directory(room);
    return folder ? `${folder}/${name || service}` : "";
}

function findFace() {
    return ["sh", "-c", 'for m in "$@"; do [ -e "$m" ] && echo "$m"; done; exit 0', "sh"].concat(faceModules());
}
