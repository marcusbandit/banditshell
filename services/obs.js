const ROUND = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

const START = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];

const EVENTS = 1 | 4 | 8 | 64 | 128;

const CAMERAS = ["v4l2_input", "dshow_input", "av_capture_input", "macos-avcapture", "macos-avcapture-fast"];

const SCREENS = ["pipewire-screen-capture-source", "pipewire-desktop-capture-source", "pipewire-window-capture-source", "xshm_input", "xcomposite_input", "monitor_capture", "window_capture", "game_capture", "display_capture", "screen_capture", "macos-screencapture"];

function rotate(x, n) {
    return x >>> n | x << 32 - n;
}

function sha256(bytes) {
    const hash = START.slice();
    const bits = bytes.length * 8;
    const high = Math.floor(bits / 0x100000000);
    let message = bytes + "\x80";
    while (message.length % 64 !== 56)
        message += "\x00";
    message += String.fromCharCode(high >>> 24 & 255, high >>> 16 & 255, high >>> 8 & 255, high & 255, bits >>> 24 & 255, bits >>> 16 & 255, bits >>> 8 & 255, bits & 255);

    const w = new Array(64);
    for (let block = 0; block < message.length; block += 64) {
        for (let i = 0; i < 16; i++) {
            const at = block + i * 4;
            w[i] = message.charCodeAt(at) << 24 | message.charCodeAt(at + 1) << 16 | message.charCodeAt(at + 2) << 8 | message.charCodeAt(at + 3);
        }
        for (let i = 16; i < 64; i++) {
            const s0 = rotate(w[i - 15], 7) ^ rotate(w[i - 15], 18) ^ w[i - 15] >>> 3;
            const s1 = rotate(w[i - 2], 17) ^ rotate(w[i - 2], 19) ^ w[i - 2] >>> 10;
            w[i] = w[i - 16] + s0 + w[i - 7] + s1 | 0;
        }

        let [a, b, c, d, e, f, g, h] = hash;
        for (let i = 0; i < 64; i++) {
            const t1 = h + (rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25)) + (e & f ^ ~e & g) + ROUND[i] + w[i] | 0;
            const t2 = (rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22)) + (a & b ^ a & c ^ b & c) | 0;
            h = g;
            g = f;
            f = e;
            e = d + t1 | 0;
            d = c;
            c = b;
            b = a;
            a = t1 + t2 | 0;
        }
        [a, b, c, d, e, f, g, h].forEach((v, i) => hash[i] = hash[i] + v | 0);
    }

    return hash.map(v => String.fromCharCode(v >>> 24 & 255, v >>> 16 & 255, v >>> 8 & 255, v & 255)).join("");
}

function authentication(password, salt, challenge, base64) {
    const secret = base64.encode(sha256(base64.utf8(password + salt)));
    return base64.encode(sha256(secret + challenge));
}

function identify(hello, password, base64) {
    const data = {
        rpcVersion: 1,
        eventSubscriptions: EVENTS
    };
    const auth = hello?.authentication;
    if (auth)
        data.authentication = authentication(password, auth.salt, auth.challenge, base64);
    return {
        op: 1,
        d: data
    };
}

function request(type, id, data) {
    return {
        op: 6,
        d: {
            requestType: type,
            requestId: id,
            requestData: data ?? {}
        }
    };
}

function role(kind) {
    const plain = String(kind ?? "").replace(/_v\d+$/, "");
    if (CAMERAS.includes(plain))
        return "camera";
    if (SCREENS.includes(plain))
        return "screen";
    if (/output_capture$/.test(plain))
        return "desktop";
    if (/input_capture$/.test(plain))
        return "mic";
    return "";
}

function sceneNames(scenes) {
    return (scenes ?? []).slice().sort((a, b) => b.sceneIndex - a.sceneIndex).map(s => s.sceneName);
}

function health(previous, status, now) {
    const bytes = status.outputBytes ?? 0;
    const elapsed = previous ? now - previous.at : 0;
    const total = status.outputTotalFrames ?? 0;
    const skipped = status.outputSkippedFrames ?? 0;
    return {
        at: now,
        bytes: bytes,
        kbps: previous && elapsed > 0 && bytes >= previous.bytes ? (bytes - previous.bytes) * 8 / elapsed : previous?.kbps ?? 0,
        skipped: skipped,
        dropped: total > 0 ? skipped / total : 0,
        congestion: status.outputCongestion ?? 0
    };
}

function duration(ms) {
    const total = Math.max(0, Math.floor((ms ?? 0) / 1000));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor(total % 3600 / 60);
    const seconds = String(total % 60).padStart(2, "0");
    return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${seconds}` : `${minutes}:${seconds}`;
}

function rate(kbps) {
    return kbps >= 1000 ? `${(kbps / 1000).toFixed(1)} Mb/s` : `${Math.round(kbps)} kb/s`;
}

function bracketed(host) {
    return host.includes(":") ? `[${host}]` : host;
}

function address(text) {
    const bare = String(text ?? "").trim().replace(/^wss?:\/\//, "").replace(/\/+$/, "");
    if (bare === "")
        return {host: "", port: 0};
    if (/^\d+$/.test(bare))
        return Number(bare) >= 1 && Number(bare) <= 65535 ? {host: "", port: Number(bare)} : null;
    const parts = /^(?:\[([0-9a-f:.]+)\]|([a-z0-9._-]+))(?::(\d+))?$/i.exec(bare);
    if (!parts)
        return null;
    const port = parts[3] === undefined ? 0 : Number(parts[3]);
    if (parts[3] !== undefined && (port < 1 || port > 65535))
        return null;
    return {host: parts[1] ?? parts[2], port: port};
}

function endpoint(own, server) {
    const host = own?.host ?? "";
    const port = own?.port || server?.server_port || 4455;
    return {
        url: `ws://${bracketed(host || "127.0.0.1")}:${port}`,
        label: `${bracketed(host || "localhost")}:${port}`,
        password: own?.password || server?.server_password || "",
        remote: host !== "",
        addressHere: host !== "" || !!own?.port,
        passwordHere: !!own?.password
    };
}

function savePasswordCommand(path, password) {
    if (password === "")
        return ["rm", "-f", "--", path];
    return ["sh", "-c", 'umask 077 && mkdir -p -- "$(dirname -- "$1")" && cat > "$1.new" && mv -f -- "$1.new" "$1"', "sh", path];
}

function withPassword(own, password) {
    return Object.assign({}, own ?? {}, { password: password ?? "" });
}
