.pragma library

const service = "banditshell";

const stack = "auth required pam_unix.so nullok nodelay\n";

function directory(room) {
    return room ? `${room}/banditshell/pam.d` : "";
}

function file(room) {
    const folder = directory(room);
    return folder ? `${folder}/${service}` : "";
}
