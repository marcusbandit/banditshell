.pragma library

var NOISE = ["node_modules", ".cache", ".git", ".npm", ".cargo", ".rustup", ".gradle", ".m2", ".var", ".steam", ".local/share/Steam", ".local/share/Trash", ".mozilla", ".pki", ".nv", ".venv", "venv", "__pycache__", ".tox", ".mypy_cache", ".pytest_cache"];

var APP_NOISE = ["Cache", "Code Cache", "GPUCache", "CacheStorage", "Service Worker", "IndexedDB", "blob_storage", "Local Storage", "Session Storage", "Crashpad", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache", "GrShaderCache", "ShaderCache", "WebStorage", "Partitions", "CachedData", "workspaceStorage", "History", "logs"];

var GREP_NOISE = NOISE.concat(["miniforge", "miniforge3", "miniconda3", "anaconda3", "mambaforge", "Android/Sdk", "site-packages", ".venv", "venv"]);

var BINARY_TYPES = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "icns", "tiff", "heic", "avif", "psd", "xcf", "mp3", "flac", "wav", "ogg", "opus", "m4a", "aac", "mp4", "mkv", "webm", "mov", "avi", "zip", "tar", "gz", "xz", "bz2", "zst", "7z", "rar", "iso", "img", "jar", "apk", "aab", "so", "o", "a", "dll", "exe", "bin", "class", "pyc", "woff", "woff2", "ttf", "otf", "eot", "pdf", "sqlite", "db", "wasm", "blend", "fbx"];

function excluding(flag, names, prefix) {
    return names.reduce((out, n) => out.concat([flag, prefix + n]), []);
}

function configSearched(hidden) {
    return hidden === ".config" || hidden === "all";
}

function findCommands(o, text) {
    var base = ["nice", "-n", "10", o.fd, "--fixed-strings", "--ignore-case"].concat(o.ignoring ? ["--no-global-ignore-file"] : ["--no-ignore-vcs"], ["--type", "f", "--type", "d", "--max-results", String(o.limit)], text.indexOf("/") >= 0 ? ["--full-path"] : [], excluding("--exclude", NOISE, ""));
    var out = [base.concat(o.hidden === "all" ? ["--hidden", "--exclude", "/.config"] : [], ["--", text, o.home])];
    if (configSearched(o.hidden))
        out.push(base.concat(excluding("--exclude", APP_NOISE, ""), ["--", text, o.configDir]));
    return out;
}

function grepCommands(o, within) {
    var base = ["nice", "-n", "19", "rg", "--fixed-strings", "--smart-case", "--max-count", "1", "--line-number", "--with-filename", "--no-heading", "--color", "never", "--max-filesize", "1M", "--max-columns", "240", "--max-columns-preview"];
    if (within)
        return [base.concat(["--file", "-", "--"], within)];
    var walk = base.concat(["--threads", "2", "--glob", `!*.{${BINARY_TYPES.join(",")}}`]);
    var out = [walk.concat(excluding("--glob", GREP_NOISE, "!"), ["--file", "-", "--", o.home])];
    if (configSearched(o.hidden))
        out.push(walk.concat(["--no-ignore-vcs"], excluding("--glob", NOISE.concat(APP_NOISE), "!"), ["--file", "-", "--", o.configDir]));
    return out;
}
