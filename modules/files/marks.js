var SYSTEM = {
    "/": "hard_drive_2",
    "/home": "group",
    "/root": "admin_panel_settings",
    "/etc": "tune",
    "/usr": "apps",
    "/var": "database",
    "/tmp": "schedule",
    "/opt": "extension",
    "/boot": "memory",
    "/dev": "cable",
    "/proc": "memory",
    "/sys": "settings",
    "/srv": "dns",
    "/mnt": "hard_drive",
    "/media": "hard_drive",
    "/run": "sync"
};

var HOME_DIRS = {
    "": "home",
    Desktop: "desktop_windows",
    Documents: "description",
    Downloads: "download",
    Pictures: "image",
    Music: "music_note",
    Videos: "movie",
    Public: "public",
    Templates: "note_stack"
};

var FOLDERS = {
    ".git": "history",
    ".github": "integration_instructions",
    ".config": "tune",
    ".cache": "schedule",
    ".local": "person",
    ".ssh": "key",
    ".gnupg": "security",
    ".steam": "sports_esports",
    ".trash": "delete",
    "node_modules": "inventory_2",
    ".venv": "science",
    "venv": "science",
    "__pycache__": "schedule",
    build: "construction",
    dist: "inventory_2",
    target: "construction",
    src: "code",
    lib: "layers",
    bin: "terminal",
    docs: "menu_book",
    doc: "menu_book",
    test: "science",
    tests: "science",
    assets: "palette",
    icons: "palette",
    images: "image",
    fonts: "text_fields",
    scripts: "terminal",
    config: "tune",
    modules: "widgets",
    components: "widgets",
    services: "dns",
    themes: "palette",
    wallpapers: "image",
    backup: "save",
    backups: "save",
    games: "sports_esports",
    projects: "work"
};

var FILES = {
    "readme": "menu_book",
    "readme.md": "menu_book",
    "readme.txt": "menu_book",
    "license": "balance",
    "licence": "balance",
    "copying": "balance",
    "makefile": "construction",
    "cmakelists.txt": "construction",
    "dockerfile": "deployed_code",
    "package.json": "inventory_2",
    "cargo.toml": "inventory_2",
    "pyproject.toml": "inventory_2",
    ".gitignore": "history",
    ".gitmodules": "history",
    ".env": "key",
    "shell.qml": "widgets",
    "design.md": "menu_book",
    "claude.md": "smart_toy",
    "agents.md": "smart_toy"
};

function iconFor(path, name, isDir, home) {
    if (isDir) {
        if (SYSTEM[path])
            return SYSTEM[path];

        if (home && path === home)
            return HOME_DIRS[""];
        if (home && path.lastIndexOf(home + "/", 0) === 0) {
            const rest = path.slice(home.length + 1);
            if (HOME_DIRS[rest])
                return HOME_DIRS[rest];
        }

        return FOLDERS[name] ?? FOLDERS[name.toLowerCase()] ?? "";
    }

    return FILES[name.toLowerCase()] ?? "";
}
