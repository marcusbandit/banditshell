// WHAT A PARTICULAR FOLDER IS, as opposed to what kind of thing it is.
//
// A folder's class is always "directory", so every folder in the grid was the
// same mark in the same colour and the only thing telling them apart was the
// name underneath. That is a lot of identical blue squares for a window whose
// whole job is finding one of them.
//
// So a folder that IS something in particular says so with its own glyph, and
// keeps a small folder badge in the corner to say it is still a folder. Home is
// a house; Downloads is a downward arrow; .git is a history. The colour is
// untouched by any of this - colour means permission (see FileMark) and shape
// means identity, which is a division that survives both of them growing.
//
// Matching is BY PATH FIRST, then by name. "Documents" in your home directory is
// the XDG documents folder; "Documents" eight levels down inside a project is a
// folder somebody called Documents, and the difference is worth keeping.

// The fixed points of a filesystem. Absolute, so nothing that merely shares a
// name with one of them is mistaken for it.
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

// The XDG directories, under $HOME. Same set the sidebar offers, with the same
// glyphs, so a place in the sidebar and the folder it points at are recognisably
// the same thing.
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

// Directories that mean the same thing wherever they turn up. Mostly the
// furniture of a project, which is where a developer's file browser spends its
// time.
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
    projects: "work",
    downloads: "download"
};

// Individual files worth recognising on sight. Exact names, because these are
// conventions rather than types: a file called README is a README whatever is
// inside it.
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

// The mark for one entry, or "" when it is nothing in particular and the class
// should speak instead.
function iconFor(path, name, isDir, home) {
    if (isDir) {
        if (SYSTEM[path])
            return SYSTEM[path];

        // Under $HOME, and only there: the XDG names mean what they mean at the
        // top of a home directory and nowhere else.
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
