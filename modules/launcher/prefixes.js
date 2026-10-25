.pragma library

var PREFIXES = [
    { word: "~", example: "~/Downloads", about: "Browse your folders", icon: "folder_open", also: ["/"] },
    { word: "=", example: "=2^10 + 3", about: "Calculate", icon: "calculate", also: [] },
    { word: ":", example: ":fire", about: "Emoji by name", icon: "mood", also: [] },
    { word: "actions", example: "actions lock", about: "Shell actions", icon: "bolt", also: ["action"] },
    { word: "ask", example: "ask why is the sky blue", about: "Ask the assistant", icon: "auto_awesome", also: [] },
    { word: "awake", example: "awake 1h", about: "Keep the screen awake", icon: "coffee", also: ["coffee", "caffeinate"] },
    { word: "b64", example: "b64 decode aGk=", about: "Base64 encode or decode", icon: "code", also: ["base64"] },
    { word: "bandit", example: "bandit restart", about: "Run a banditshell command", icon: "terminal", also: ["banditshell"] },
    { word: "bm", example: "bm github", about: "Bookmarks and history", icon: "bookmark", also: ["bookmarks", "history"] },
    { word: "brightness", example: "brightness 60", about: "Screen brightness", icon: "brightness_medium", also: ["backlight"] },
    { word: "clip", example: "clip api key", about: "Clipboard history", icon: "content_paste", also: ["clips", "clipboard"] },
    { word: "colours", example: "colours", about: "Colours you picked", icon: "palette", also: ["pick"] },
    { word: "containers", example: "containers", about: "Podman and Docker containers", icon: "deployed_code", also: ["podman", "docker"] },
    { word: "define", example: "define serendipity", about: "Look up a word", icon: "menu_book", also: ["def", "dict"] },
    { word: "downloads", example: "downloads pdf", about: "Latest downloads", icon: "download", also: ["download"] },
    { word: "emoji", example: "emoji heart", about: "Emoji and symbols", icon: "mood", also: ["emojis", "symbols"] },
    { word: "epoch", example: "epoch 1700000000", about: "Unix time to a date", icon: "schedule", also: ["unix", "timestamp"] },
    { word: "gh", example: "gh dotfiles", about: "GitHub pull requests and issues", icon: "merge", also: ["github"] },
    { word: "json", example: "json pretty {\"a\":1}", about: "Format or check JSON", icon: "data_object", also: [] },
    { word: "jwt", example: "jwt eyJhbGciOi...", about: "Decode a token", icon: "key", also: [] },
    { word: "keys", example: "keys screenshot", about: "Keybinds", icon: "keyboard", also: ["shortcuts", "keybinds"] },
    { word: "kill", example: "kill firefox", about: "Quit a process", icon: "dangerous", also: [] },
    { word: "lorem", example: "lorem 3 sentences", about: "Copy placeholder text", icon: "notes", also: ["ipsum"] },
    { word: "note", example: "note meeting", about: "Write a new note", icon: "note_add", also: [] },
    { word: "notes", example: "notes budget", about: "Search your notes", icon: "description", also: ["vault", "obsidian"] },
    { word: "notifs", example: "notifs slack", about: "Notifications", icon: "notifications", also: ["notif", "notifications"] },
    { word: "password", example: "password 24", about: "Make a password", icon: "password", also: ["passwd", "pin"] },
    { word: "phone", example: "phone battery", about: "Paired phones", icon: "smartphone", also: ["phones"] },
    { word: "pkg", example: "pkg ripgrep", about: "Find a package to install", icon: "package_2", also: ["install", "package"] },
    { word: "pomo", example: "pomo 25 5", about: "Start a pomodoro", icon: "timer_play", also: ["pomodoro"] },
    { word: "ports", example: "ports 5432", about: "Listening ports", icon: "lan", also: ["port"] },
    { word: "projects", example: "projects banditshell", about: "Your projects", icon: "folder_code", also: ["project", "repos", "repo"] },
    { word: "random", example: "random 1 to 6", about: "Random number", icon: "casino", also: ["roll"] },
    { word: "recent", example: "recent invoice", about: "Recently used documents", icon: "history", also: [] },
    { word: "record", example: "record", about: "Record the screen", icon: "screen_record", also: ["recording"] },
    { word: "scratch", example: "scratch term", about: "Scratchpads", icon: "layers", also: ["scratchpad", "special"] },
    { word: "screenshots", example: "screenshots", about: "Latest screenshots", icon: "screenshot_monitor", also: [] },
    { word: "scripts", example: "scripts", about: "Your script commands", icon: "terminal", also: [] },
    { word: "services", example: "services pipewire", about: "systemd services", icon: "settings_applications", also: [] },
    { word: "sha256", example: "sha256 hello", about: "Hash text", icon: "tag", also: ["md5", "hash", "checksum"] },
    { word: "snip", example: "snip signature", about: "Snippets", icon: "short_text", also: ["snippet", "snippets"] },
    { word: "speedtest", example: "speedtest", about: "Test your internet speed", icon: "speed", also: [] },
    { word: "ssh", example: "ssh nemurenai", about: "Connect to a host", icon: "dns", also: [] },
    { word: "tailscale", example: "tailscale up", about: "Tailscale", icon: "vpn_lock", also: [] },
    { word: "timer", example: "timer 10 minutes", about: "Start a timer", icon: "timer", also: ["timers", "countdown"] },
    { word: "translate", example: "translate hola to english", about: "Translate text", icon: "translate", also: ["tr"] },
    { word: "tray", example: "tray discord", about: "Tray icons", icon: "widgets", also: ["systray"] },
    { word: "uuid", example: "uuid 3", about: "Make a UUID", icon: "fingerprint", also: ["guid"] },
    { word: "vpn", example: "vpn work", about: "VPN connections", icon: "vpn_key", also: ["wireguard"] },
    { word: "wc", example: "wc words hello there", about: "Count words or characters", icon: "format_list_numbered", also: ["count"] },
    { word: "wifi", example: "wifi home", about: "Wi-Fi networks", icon: "wifi", also: ["wlan", "wireless"] },
    { word: "ws", example: "ws 3", about: "Go to a workspace", icon: "space_dashboard", also: ["workspace"] }
];

var SYMBOLS = /^[^a-z0-9]$/i;

function asked(text) {
    return text === "?";
}

function heads(p) {
    return [p.word].concat(p.also);
}

function claims(text) {
    var lower = String(text || "").trim().toLowerCase();
    return lower.indexOf("?") === 0 || PREFIXES.some(p => heads(p).indexOf(lower) >= 0);
}

function guess(text, labels, closest) {
    return claims(text) ? -1 : closest(text, labels);
}

function completion(p) {
    return SYMBOLS.test(p.word) ? (p.word === "~" ? "~/" : p.word) : `${p.word} `;
}
