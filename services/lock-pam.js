.pragma library

const service = "banditshell";

const stack = "auth required pam_unix.so nullok nodelay\n";

const faceService = "banditshell-face";

const faceStack = "auth required pam_howdy.so\n";

const faceModules = [
    "/usr/lib/security/pam_howdy.so",
    "/lib/security/pam_howdy.so",
    "/usr/lib64/security/pam_howdy.so",
    "/lib64/security/pam_howdy.so",
    "/usr/lib/x86_64-linux-gnu/security/pam_howdy.so",
    "/lib/x86_64-linux-gnu/security/pam_howdy.so",
    "/usr/lib/aarch64-linux-gnu/security/pam_howdy.so",
    "/lib/aarch64-linux-gnu/security/pam_howdy.so"
];

function directory(room) {
    return room ? `${room}/banditshell/pam.d` : "";
}

function file(room, name) {
    const folder = directory(room);
    return folder ? `${folder}/${name || service}` : "";
}

function findFace() {
    return ["sh", "-c", 'for m in "$@"; do [ -e "$m" ] && exit 0; done; exit 1', "sh"].concat(faceModules);
}
