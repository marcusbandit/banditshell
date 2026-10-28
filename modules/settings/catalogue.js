.pragma library

const pct = v => `${Math.round(v * 100)}%`;
const placedText = (v, at) => {
    const want = Math.round(v * 100);
    const got = Math.round(at * 100);
    return at < 0 || got === want ? `${want}% from top` : `${want}% from top, moved ${got < want ? "up" : "down"} to fit`;
};
const PEN_BUTTONS_WHY = "Right click and middle click are what the stylus buttons send as they come. Erase turns the pen to its eraser for as long as the button is held. Changing them makes the shell sit between the pen and Hyprland, so a pen on its defaults is left untouched.";
const signed = v => Math.abs(v) < 0.01 ? "as is" : (v > 0 ? "+" : "") + v.toFixed(2);
const kelvin = (s, v) => {
    const top = s.neutral || 6500;
    return v ? `${Math.round(top - v / 100 * (top - s.v("warmest")))} K` : "off";
};

const FILES_SORTS = [["name", "name"], ["mtime", "date"], ["size", "size"], ["kind", "type"]];
const PANEL_SHADES = ["black", "deep", "dark", "medium", "light", "pale", "palest"];
const LIGHT_PANEL_SHADES = ["white", "palest", "pale", "light", "soft", "medium", "grey"];

function shadeWord(light, v) {
    const words = light ? LIGHT_PANEL_SHADES : PANEL_SHADES;
    return words[Math.max(0, Math.min(words.length - 1, Math.round(v) || 0))];
}
const FILES_ORDERS = {
    name: ["a to z", "z to a"],
    mtime: ["newest", "oldest"],
    size: ["biggest", "smallest"],
    kind: ["a to z", "z to a"]
};

const MODES = [
    { id: "none", name: "none", icon: "radio_button_unchecked", detail: "everything as set", set: {} },
    { id: "work", name: "work", icon: "work", detail: "quiet · alarms through", set: { dnd: true, dndAlarms: true, notifPopups: 2 } },
    { id: "play", name: "play", icon: "sports_esports", detail: "quiet · fast power", set: { dnd: true, profile: "fast", notifPopups: 1 } },
    { id: "stream", name: "stream", icon: "cast", detail: "quiet · streamer mode", set: { dnd: true, stream: true, notifPopups: 1 } },
    { id: "sleep", name: "sleep", icon: "bedtime", detail: "quiet · warm and dim", set: { dnd: true, dndAlarms: true, warmth: 70, level: 40 } }
];

const LAYOUTS = [
    { id: "dwindle", name: "dwindle", detail: "each window splits the last" },
    { id: "master", name: "master", detail: "one big, the rest stack" },
    { id: "scrolling", name: "scrolling", detail: "columns on a strip · hyprscrolling" },
    { id: "hy3", name: "hy3", detail: "i3-style groups and tabs · hy3" },
    { id: "custom", name: "add custom", detail: "your own · drawn in the layout workshop" }
];

const WIDGET_TITLES = {
    winLayouts: "Layout", via: "VIA layout", modes: "Modes", usage: "Today", recent: "Recent changes", nets: "Networks",
    devices: "Devices", volume: "Volume", apps: "Volume by app", walls: "Wallpapers", themes: "Theme", wsStyles: "Workspace style",
    chips: "Apps", folders: "Folders", overrides: "Icon overrides", startup: "Startup apps", rules: "App rules", clocks: "Other time zones",
    obs: "OBS", keys: "Keys", kbLayouts: "Layouts", battery: "Battery", update: "Updates", changes: "What’s new", about: "About",
    tunnels: "Tunnels", shortcuts: "Aliases and hotkeys", snippets: "Snippets", quicklinks: "Quicklinks"
};

const SEARCH_TITLES = {
    kbLayouts: "Layout", via: "VIA layout", modes: "Modes", usage: "Today", recent: "Recent changes", nets: "Networks",
    devices: "Devices", volume: "Volume", apps: "Volume by app", walls: "Pick a wallpaper", themes: "Theme", wsStyles: "Workspace style",
    chips: "", folders: "Folders", overrides: "Icon overrides", startup: "Startup apps", rules: "App rules", clocks: "World clocks",
    obs: "OBS", keys: "Keys", winLayouts: "Layouts", battery: "Battery", update: "Updates", changes: "What’s new", about: "About",
    tunnels: "Tunnels", shortcuts: "Aliases and hotkeys", snippets: "Snippets", quicklinks: "Quicklinks"
};

const WIDGET_WHY = {
    winLayouts: "How Hyprland tiles windows on this screen. Scrolling and hy3 are plugins and need installing first. Custom opens the layout workshop: draw regions, pick where each new window goes, and the shell writes a Lua layout and loads it into Hyprland without touching your config files.",
    via: "Pick Custom under Board, then import the .json your keyboard’s maker publishes for usevia.app. Import lists the VIA files in Downloads; Browse opens any other. The sheet then draws your exact board, split halves and odd keys included. Add a keymap saved from VIA (Save + Load, Save) and the keys you bind light up on it. Open the file to edit it into your own board; the sheet follows your edits.",
    modes: "Like a focus on a phone. Pick one and it changes a handful of settings; pick none and they go back.",
    usage: "Time with each app in front of you today, counted only while you are active.",
    recent: "Every setting you change lands here with a way back. The search field shows the same list when it is empty.",
    nets: "Click a network to join, share or forget it in the pane. The camera button reads a Wi-Fi code.",
    devices: "Click a device to connect, trust, forget or block it in the pane.",
    volume: "Scroll the speaker in the sidebar to change it from anywhere.",
    themes: "Themes come from ~/.config/theme. The theme’s shades paint the panels; its highlight colours paint everything that’s on.",
    wsStyles: "Plates stack the apps in each workspace. Map draws a bar per window. Blocks draws a square per window.",
    walls: "A new wallpaper grows out from where you clicked.",
    battery: "Charge over the last day. The dashed lines are the hold point and the warning.",
    keys: "Click a key to change it in the pane.",
    snippets: "Type a snippet's keyword or name in the launcher and press Enter to type it into the app you were in. {date}, {time} and {clipboard} fill in as it is typed; {cursor} is where the caret ends up.",
    quicklinks: "Type a keyword, a space and what to look for. {query} in the address is where it goes."
};

const PAGES_SOURCE = {
    wifi: {
        id: "wifi", name: "Wi-Fi", icon: "wifi", preview: "network", closed: s => !!s.networkMissing,
        status: s => s.networkMissing || (s.v("wifi") ? s.wifiState : "off"),
        groups: [
            { notice: true, away: s => !s.networkMissing, rows: [
                { n: [], kind: "w", w: "networkManager" }
            ] },
            { away: s => !!s.networkMissing, rows: [
                { n: 1, icon: "wifi", label: "Wi-Fi", k: "wifi", kind: "toggle", state: s => s.networkMissing || (s.v("wifi") ? s.wifiState : "off"), dis: s => s.networkMissing !== "",
                    why: "Turns the radio off. Ethernet keeps working." },
                { n: [2, 3, 6], kind: "w", w: "nets", kw: "networks join password forget qr share scan portal sign in" },
                { n: 4, icon: "autorenew", label: "Join on its own", k: "autoJoin", kind: "toggle", state: s => s.v("autoJoin") ? "" : "waits to be told", dis: s => !s.v("wifi"),
                    why: "Saved networks reconnect when they come in range.", kw: "auto-join known networks" },
                { n: 8, icon: "radar", label: "Keep the list fresh", k: "keepFresh", kind: "toggle", cfg: "network.keepListFresh",
                    why: "Rescans in the background so the list is current when you open it. Each scan holds the radio for a moment." }
            ] },
            { t: "Checks", away: s => !!s.networkMissing, rows: [
                { n: 7, icon: "public", label: "Check for internet", k: "netCheck", kind: "toggle", cfg: "network.checkForInternet", state: s => s.v("netCheck") ? s.reach : "", kw: "internet check",
                    why: "Pings a check server so the sidebar can tell you when a network has no way out. Off, it guesses." },
                { n: 6, icon: "login", label: "Sign-in page", k: "portalUri", kind: "text", cfg: "network.portalUri", placeholder: "the network decides", kw: "captive portal",
                    why: "Where to send you when a café or hotel network wants you to sign in. Empty lets the network say where." }
            ] }
        ]
    },
    bluetooth: {
        id: "bluetooth", name: "Bluetooth", icon: "bluetooth", preview: "device",
        status: s => s.v("bt") ? s.btConnected.join(" · ") || "nothing connected" : "off",
        groups: [
            { rows: [
                { n: 11, icon: "bluetooth", label: "Bluetooth", k: "bt", kind: "toggle", state: s => s.v("bt") ? `shows up as ${s.btName}` : "off" },
                { n: 12, icon: "visibility", label: "Visible to others", k: "btVisible", kind: "toggle", why: "Lets other devices find this one to pair. Hides again after 3 min.", dis: s => !s.v("bt"), kw: "discoverable visibility" },
                { n: 12, icon: "handshake", label: "Take pairing requests", k: "btPairable", kind: "toggle", dis: s => !s.v("bt"), kw: "pairable" }
            ] },
            { t: "Devices", rows: [
                { n: [13, 14], kind: "w", w: "devices", kw: "devices pair connect forget trusted blocked" }
            ] }
        ]
    },
    wired: {
        id: "wired", name: "Ethernet", icon: "lan", preview: "network", closed: s => !!s.networkMissing,
        status: s => s.networkMissing || (s.v("wired") ? s.wiredDetail : "off"),
        groups: [
            { notice: true, away: s => !s.networkMissing, rows: [
                { n: [], kind: "w", w: "networkManager" }
            ] },
            { away: s => !!s.networkMissing, rows: [
                { n: 5, icon: "lan", label: "Ethernet", k: "wired", kind: "toggle", state: s => s.v("wired") ? s.wiredDetail : "off", kw: "wired connection",
                    why: "The dock’s port.", layer: [
                        { n: 5, icon: "autorenew", label: "Join on its own", k: "wiredAuto", kind: "toggle", state: s => s.v("wiredAuto") ? "" : "waits to be told" },
                        { n: 5, kind: "fact", text: s => s.wiredFact }
                    ] }
            ] }
        ]
    },
    vpn: {
        id: "vpn", name: "Hotspot and VPN", icon: "vpn_lock", preview: "network", closed: s => !!s.networkMissing,
        status: s => s.networkMissing || [s.v("hotspot") ? "sharing" : "not sharing", s.vpnOn ? `vpn ${s.vpnOn}` : "no vpn"].join(" · "),
        groups: [
            { notice: true, away: s => !s.networkMissing, rows: [
                { n: [], kind: "w", w: "networkManager" }
            ] },
            { t: "Hotspot", away: s => !!s.networkMissing, rows: [
                { n: 9, icon: "wifi_tethering", label: "Share this connection", k: "hotspot", kind: "toggle", state: s => s.hotspotStatus, dis: s => s.hotspotBlocked,
                    why: "Lends your ethernet connection to other devices over Wi-Fi. Wi-Fi stops joining networks while it runs.", layer: [
                        { n: 9, icon: "badge", label: "Name", k: "hotspotName", kind: "text" },
                        { n: 9, icon: "key", label: "Password", k: "hotspotPass", kind: "secret", state: s => s.hotspotPasswordTrouble, bad: s => s.hotspotPasswordTrouble !== "" },
                        { n: 9, icon: "settings_input_antenna", label: "Band", k: "hotspotBand", kind: "seg", o: ["2.4 GHz", "5 GHz"] }
                    ] }
            ] },
            { t: "VPN", away: s => !!s.networkMissing, rows: [
                { n: 10, kind: "w", w: "tunnels", kw: "vpn wireguard openvpn tunnel add import" }
            ] }
        ]
    },
    output: {
        id: "output", name: "Output", icon: "speaker", preview: "sound",
        status: s => s.outputName,
        groups: [
            { topic: "Volume", rows: [
                { n: 17, kind: "w", w: "volume", kw: "volume mute", fmt: pct },
                { n: 15, icon: "speaker", label: "Play through", k: "output", kind: "choice", o: s => s.outputs, kw: "output device",
                    why: "Where sound goes. The speaker in the sidebar switches it too." },
                { n: 18, icon: "unfold_more", label: "Keys step by", k: "volStep", kind: "seg", o: [[0.02, "2%"], [0.05, "5%"], [0.1, "10%"]], cfg: "volume.step", kw: "volume step" },
                { n: 19, icon: "campaign", label: "Past 100%", k: "overAmp", kind: "toggle", cfg: "volume.boost", kw: "volume above 100 boost",
                    why: "Lets the slider run to 150%, louder but some sources can crackle. The bead turns accent once it passes the mark at 100%." }
            ] },
            { t: "Speakers and headphones", rows: [
                { n: 20, icon: "speaker", label: "Speakers", k: "roleSpeakers", kind: "choice", cfg: "audio.speakers", o: s => s.outputs, why: "Super + F12 flips between these two.", kw: "roles" },
                { n: 20, icon: "headphones", label: "Headphones", k: "roleHeadphones", kind: "choice", cfg: "audio.headphones", o: s => s.outputs, kw: "roles" }
            ] }
        ]
    },
    mic: {
        id: "mic", name: "Microphone", icon: "mic", preview: "sound",
        status: s => s.inputName,
        groups: [
            { rows: [
                { n: 16, icon: "mic", label: "Microphone", k: "input", kind: "choice", o: s => s.inputs, kw: "input device" },
                { n: 16, icon: "graphic_eq", label: "Input level", k: "micLevel", kind: "slider", min: 0, max: 1, step: 0.01, fmt: pct }
            ] }
        ]
    },
    mixer: {
        id: "mixer", name: "Volume by app", icon: "tune", preview: "sound",
        status: s => s.appsPlaying ? `${s.appsPlaying} playing` : "nothing playing",
        groups: [
            { rows: [
                { n: 21, kind: "w", w: "apps", kw: "per-app volume mixer", fmt: pct }
            ] }
        ]
    },
    notifications: {
        id: "notifications", name: "Notifications", icon: "notifications", preview: "notif",
        status: s => `${s.v("notifPlace") === "island" ? "in the island" : "in the corner"} · ${s.v("notifTimeout")} s · ${s.v("notifPopups")} at once`,
        groups: [
            { rows: [
                { n: [], icon: "call_to_action", label: "Show them", k: "notifPlace", kind: "seg", o: [["corner", "corner"], ["island", "island"]], cfg: "notifications.placement", kw: "notification position place island dynamic island top centre corner",
                    why: "The corner is the top right, where they always were. The island drops them from the top centre instead, where a wide screen keeps them in view. The corner still opens the history either way." },
                { n: 77, icon: "timer", label: "Stay for", k: "notifTimeout", kind: "step", min: 1, max: 30, unit: " s", cfg: "notifications.timeout", extra: { icon: "send", tip: "send a test", act: "testNotif" }, kw: "notification timeout" },
                { n: 78, icon: "stacks", label: "At once", k: "notifPopups", kind: "step", min: 1, max: 8, cfg: "notifications.maxPopups", fmt: v => `${v}`, kw: "notification popups at once" },
                { n: 79, icon: "inbox", label: "Remember", k: "notifHistory", kind: "step", min: 10, max: 500, step: 10, cfg: "notifications.maxHistory", fmt: v => `${v}`, kw: "notification history length" }
            ] },
            { t: "By app", rows: [
                { n: 81, kind: "w", w: "rules", cfg: "notifications.rules", kw: "per-app notification rules" }
            ] },
            { t: "The island", rows: [
                { n: [], icon: "download_done", label: "Downloads", k: "islandDownloads", kind: "toggle", cfg: "island.downloads", state: s => s.v("islandDownloads") ? "says when a file lands" : "says nothing", kw: "island finished downloads announce",
                    why: "Watches your downloads folder and says when a file has finished arriving. Needs inotifywait (inotify-tools)." },
                { n: [], icon: "music_note", label: "Now playing", k: "islandMusic", kind: "toggle", cfg: "island.nowPlaying", state: s => s.v("islandMusic") ? "shows a new track unless its app is in front" : "only when you go up to it", kw: "island now playing track change music song",
                    why: "When the track changes, the island shows the cover, the title and a moving equalizer for a few seconds. Pressing it opens the media card." },
                { n: [], icon: "hourglass_bottom", label: "Says it for", k: "islandGlance", kind: "step", min: 2, max: 30, unit: " s", cfg: "island.glanceSeconds", kw: "island notice glance time",
                    why: "How long a new track, a download, an update or a new kernel shows by itself. Updates and kernels then wait in the island, under the clock, until you deal with them." }
            ] }
        ]
    },
    alerts: {
        id: "alerts", name: "Alerts and media", icon: "music_note", preview: "sound",
        status: s => s.v("alerts") ? `${s.v("alertSet")} alerts` : "alerts off",
        groups: [
            { t: "Alerts", rows: [
                { n: 22, icon: "notifications_active", label: "Alert sounds", k: "alerts", kind: "toggle", cfg: "sound.alerts", state: s => s.alertsDetail, why: "Plays a sound for notifications, low battery and errors." },
                { n: 22, icon: "music_note", label: "Sound set", k: "alertSet", kind: "seg", o: ["soft", "clear", "wood"], cfg: "sound.alertSet", dis: s => !s.v("alerts") },
                { n: 22, icon: "volume_down", label: "Alert volume", k: "alertVol", kind: "slider", min: 0, max: 1, step: 0.01, fmt: pct, cfg: "sound.alertVolume", dis: s => !s.v("alerts") }
            ] },
            { t: "Media", rows: [
                { n: 82, icon: "swap_vert", label: "Wheel seeks", k: "wheelSeek", kind: "step", min: 0, max: 30, unit: " s", cfg: "media.wheelSeek", why: "How far each notch of the wheel seeks on the player. 0 turns it off.", kw: "media controls scroll to seek" },
                { n: 82, icon: "replay_5", label: "Short skip", k: "seekSmall", kind: "step", min: 1, max: 30, unit: " s", cfg: "media.seekSmall", kw: "skip lengths" },
                { n: 82, icon: "forward_30", label: "Long skip", k: "seekLarge", kind: "step", min: 5, max: 120, step: 5, unit: " s", cfg: "media.seekLarge", kw: "skip lengths" }
            ] }
        ]
    },
    screens: {
        id: "screens", name: "Screens", icon: "desktop_windows", preview: "arrange",
        status: s => s.screensOn.join(" · "),
        groups: [
            { t: s => `${s.selMon} · ${s.selMonWhat}`, rows: [
                { n: 23, icon: "drag_pan", label: "Arrangement", k: "scr:layout", kind: "fact", text: "drag a screen to line it up with your desk. it snaps to edges, corners and centres, and the arrow keys nudge it. nothing changes until you press apply.",
                    why: "Moves, resolutions, rates, scale, turns, turning a screen off and mirroring wait for Apply, then go to Hyprland's monitor lines together. A change to the picture asks you to keep it, and goes back by itself after 15 seconds if you can't. Hold ctrl while dragging to move freely; shift with the arrows moves 10 px; tab picks the next screen.", kw: "screen arrangement position monitors layout drag snap centre nudge apply" },
                { n: 29, icon: "power_settings_new", label: "Use this screen", k: "scr:on", kind: "toggle", state: s => s.onlyOn ? "the last one stays on" : "", pending: s => s.pendingNote("on"), dis: s => s.onlyOn, kw: "turn a screen off" },
                { n: 29, icon: "flip", label: "Mirror", k: "scr:mirror", kind: "choice", o: s => [["", "nothing"]].concat(s.mirrorChoices.map(m => [m, m])), pending: s => s.pendingNote("mirror"), dis: s => !s.v("scr:on"), kw: "clone duplicate screen" },
                { n: 24, icon: "aspect_ratio", label: "Resolution", k: "scr:res", kind: "choice", o: s => s.resolutions, pending: s => s.pendingNote("res"), dis: s => !s.v("scr:on") },
                { n: 25, icon: "speed", label: "Refresh rate", k: "scr:hz", kind: "choice", o: s => s.rates, pending: s => s.pendingNote("hz"), dis: s => !s.v("scr:on") },
                { n: 26, icon: "zoom_in", label: "Scale", k: "scr:scale", kind: "seg", o: [[1, "1"], [1.25, "1.25"], [1.5, "1.5"], [2, "2"]], pending: s => s.pendingNote("scale"), dis: s => !s.v("scr:on") },
                { n: 27, icon: "screen_rotation", label: "Turn", k: "scr:rot", kind: "seg", o: [[0, "0°"], [90, "90°"], [180, "180°"], [270, "270°"]], pending: s => s.pendingNote("rot"), dis: s => !s.v("scr:on"), kw: "rotation portrait" },
                { n: 28, icon: "motion_photos_auto", label: "Variable refresh", k: "scr:vrr", kind: "toggle", pending: s => s.pendingNote("vrr"), why: "Lets the screen follow a game’s frame rate. Smoother games, but some screens flicker.", dis: s => !s.v("scr:on"), kw: "vrr freesync" },
                { n: 30, icon: "grid_view", label: "Workspaces here", k: "scr:ws", kind: "choice", o: s => s.bandChoices, dis: s => !s.v("scr:on"), kw: "workspaces per screen" },
                { n: 31, icon: "side_navigation", label: "Sidebar here", k: "scr:bar", kind: "toggle", cfg: "sidebar.perScreen", dis: s => !s.v("scr:on") || !s.v("sidebar"), kw: "sidebar per screen" }
            ] }
        ]
    },
    light: {
        id: "light", name: "Light and warmth", icon: "brightness_6", preview: "arrange",
        status: s => `${Math.round(s.v("level"))}% · ${s.v("warmth") ? "warm" : "neutral"}`,
        groups: [
            { rows: [
                { n: 32, icon: "brightness_6", label: "Level", k: "level", kind: "slider", min: 5, max: 100, fmt: v => `${Math.round(v)}%`, cfg: "screen.level", kw: "brightness" },
                { n: 33, icon: "nightlight", label: "Warmth", k: "warmth", kind: "slider", min: 0, max: 100, fmtS: kelvin, cfg: "screen.warmth", kw: "night light warmth",
                    why: "Pulls blue out of every screen. All the way over it reaches the warmest point below." },
                { n: 33, icon: "thermostat", label: "Warmest point", k: "warmest", kind: "step", min: 1500, max: 4000, step: 100, unit: " K", cfg: "screen.warmest", kw: "night light" },
                { n: 34, icon: "schedule", label: "On a schedule", k: "nightSched", kind: "seg", o: ["off", "sunset", "set times"], cfg: "screen.schedule", state: s => s.scheduleDetail, kw: "night light schedule" },
                { n: 34, icon: "bedtime", label: "Warm from", k: "warmFrom", kind: "slider", min: 0, max: 1425, step: 15, fmtS: (s, v) => s.minuteText(v), cfg: "screen.warmFrom", dis: s => s.v("nightSched") !== "set times", kw: "night light schedule start" },
                { n: 34, icon: "wb_twilight", label: "Warm until", k: "warmTo", kind: "slider", min: 0, max: 1425, step: 15, fmtS: (s, v) => s.minuteText(v), cfg: "screen.warmTo", dis: s => s.v("nightSched") !== "set times", kw: "night light schedule end" }
            ] }
        ]
    },
    colour: {
        id: "colour", name: "Colour", icon: "palette", preview: "chassis",
        status: s => s.v("fromWall") ? "wallpaper" : s.v("theme"),
        groups: [
            { rows: [
                { n: [], icon: "dark_mode", label: "Light or dark", k: "scheme", kind: "seg", o: ["light", "dark", "auto"], cfg: "colour.mode", state: s => s.schemeDetail, extra: { icon: "schedule", tip: "set night light’s schedule", act: "nightSchedule" }, kw: "dark mode dark apps light mode night theme colour scheme apps appearance auto",
                    why: "Sets the shell and every app that follows the system colour scheme. Auto goes dark while night light warms the screens, on its schedule under Light and warmth. If apps drift, pick the same choice again." },
                { n: 42, kind: "w", w: "themes", kw: "theme palette" },
                { n: 43, icon: "colorize", label: "Take it from the wallpaper", k: "fromWall", kind: "toggle", cfg: "themeFromWallpaper", state: s => s.v("fromWall") ? s.wallName : "", kw: "theme from wallpaper" },
                { n: 44, icon: "format_color_fill", label: "Highlight colour", k: "accent", kind: "seg", o: [["dim", "soft"], ["mid", "normal"], ["bright", "strong"]], swatches: true, cfg: "colour.accent", kw: "accent strength dim mid bright",
                    why: "Which of the theme’s three highlight colours paints everything that’s on. Soft sits back, strong jumps out." },
                { n: 45, icon: "layers", label: "Panel shade", k: "surface", kind: "slider", min: 0, max: 6, step: 1, fmtS: (s, v) => shadeWord(s?.lightShell, v), cfg: "colour.surface", kw: "surface depth ramp background darker lighter",
                    why: "Which of the theme’s own shades paints the frame and panels. Lower is darker in a dark look and lighter in a light one." },
                { n: 46, icon: "opacity", label: "See-through", k: "surfaceAlpha", kind: "slider", min: 0, max: 0.5, step: 0.01, fmt: pct, cfg: "material.surfaceAlpha", kw: "transparency" }
            ] }
        ]
    },
    wallpaper: {
        id: "wallpaper", name: "Wallpaper", icon: "wallpaper", preview: "wallpaper",
        status: s => s.v("wallOn") ? s.wallName.toLowerCase() : "off",
        groups: [
            { rows: [
                { n: 36, icon: "wallpaper", label: "Wallpaper", k: "wallOn", kind: "toggle", cfg: "wallpaper.enabled", state: s => s.v("wallOn") ? "" : "the surface colour shows" },
                { n: 35, icon: "select_window", label: "Put it on", k: "wallTarget", kind: "seg", o: ["this screen", "everywhere"], cfg: "wallpaper.perScreen", dis: s => !s.v("wallOn"), kw: "one screen everywhere" },
                { n: [35, 37], kind: "w", w: "walls", kw: "pick wallpaper" },
                { n: 37, icon: "folder", label: "Folder", k: "wallDir", kind: "path", cfg: "wallpaper.dir", kw: "wallpaper folder" }
            ] },
            { t: "Motion", rows: [
                { n: 38, icon: "animation", label: "Play animated ones", k: "wallAnim", kind: "toggle", cfg: "wallpaper.animate", why: "Plays moving wallpapers. They pause under full-screen windows.", kw: "animated wallpapers" },
                { n: 39, icon: "volume_up", label: "Play their sound", k: "wallAudio", kind: "toggle", cfg: "wallpaper.audio", dis: s => !s.v("wallAnim"), kw: "wallpaper audio" },
                { n: 40, icon: "blur_circular", label: "Reveal", k: "wallReveal", kind: "slider", min: 0, max: 2000, step: 50, fmt: v => v ? `${v} ms` : "cut", cfg: "wallpaper.reveal", extra: { icon: "play_arrow", tip: "play it", act: "previewReveal" }, kw: "reveal animation",
                    why: "How long a new wallpaper takes to grow out from where you clicked." },
                { n: 41, icon: "crop", label: "Crop allowance", k: "wallFit", kind: "slider", min: 1, max: 2, step: 0.05, fmt: v => `${v.toFixed(2)}×`, cfg: "wallpaper.fit", kw: "wallpaper fit",
                    why: "How far a picture may be cropped to fill a screen. Shapes further off than this get bands instead." }
            ] }
        ]
    },
    type: {
        id: "type", name: "Text and icons", icon: "text_fields", preview: "chassis",
        status: s => `${s.v("font")} · ${(s.v("largerText") ? s.largerBase : s.v("fontBase")) * 2} px`,
        groups: [
            { rows: [
                { n: 47, icon: "text_fields", label: "Font", k: "font", kind: "choice", o: s => s.fonts, cfg: "font.family",
                    why: "Monocraft is drawn on a 9 px grid, so text sizes stay whole multiples of the base." },
                { n: 48, icon: "interests", label: "Icons", k: "iconFont", kind: "seg", o: [["Material Symbols Rounded", "rounded"], ["Material Symbols Outlined", "outlined"], ["Material Symbols Sharp", "sharp"]], cfg: "font.icon", kw: "icon fonts" },
                { n: 49, icon: "format_size", label: "Text size", k: "fontBase", kind: "seg", o: [[8, "16"], [9, "18"], [10, "20"]], cfg: "font.base", dis: s => s.v("largerText"), state: s => s.v("largerText") ? "set by larger text" : "",
                    why: "The small size in px. Sizes step from the base: small is twice it, normal three times, large four." },
                { n: 50, icon: "photo_size_select_small", label: "Icon size", k: "iconScale", kind: "slider", min: 0.8, max: 1.6, step: 0.05, fmt: v => `${v.toFixed(2)}×`, cfg: "font.iconScale" }
            ] }
        ]
    },
    shape: {
        id: "shape", name: "Shape and motion", icon: "rounded_corner", preview: "chassis",
        status: s => s.v("follow") ? "following hyprland" : `${s.v("rounding")} px · power ${s.v("power")}`,
        groups: [
            { rows: [
                { n: 55, icon: "sync_alt", label: "Follow Hyprland", k: "follow", kind: "toggle", cfg: "compositor.follow", state: s => s.v("follow") ? s.followDetail : "uses the values below", dis: s => s.v("bare"), kw: "compositor corners gaps",
                    why: "Reads rounding, gaps and border size from Hyprland so the frame lines up with your windows." },
                { n: 51, icon: "rounded_corner", label: "Rounding", k: "rounding", kind: "slider", min: 0, max: 30, fmt: v => `${v} px`, cfg: "rounding.base", dis: s => s.v("follow"), kw: "corner rounding" },
                { n: 51, icon: "crop_square", label: "Squareness", k: "power", kind: "slider", min: 2, max: 10, step: 0.5, fmt: v => v <= 2 ? "circle" : `power ${v}`, cfg: "rounding.power", dis: s => s.v("follow"), kw: "corner rounding squircle",
                    why: "Corners are superellipses. Power 2 is a plain circle; higher keeps the edge straight longer before it turns." },
                { n: 52, icon: "border_outer", label: "Frame", k: "border", kind: "slider", min: 0, max: 24, fmt: v => `${v} px`, cfg: "edge.border", dis: s => s.v("follow"), kw: "gaps window border band" },
                { n: 53, icon: "rounded_corner", label: "Round the screen", k: "roundOuter", kind: "toggle", cfg: "edge.roundOuter", kw: "outer screen corners" },
                { n: 53, icon: "fit_screen", label: "Edge over fullscreen", k: "fullscreenEdge", kind: "toggle", cfg: "edge.fullscreen", state: s => s.v("fullscreenEdge") ? "takes the colour of the picture" : "plain fullscreen", dis: s => s.v("bare"), kw: "fullscreen border ring film letterbox",
                    why: "Keeps the screen's rounded edge round a fullscreen window, coloured from the window's own edge so black bars stay black. Off gives the window the whole screen." },
                { n: 56, icon: "border_color", label: "Paint window borders", k: "pushBorders", kind: "toggle", cfg: "compositor.pushBorders", state: s => s.v("sourceEdits") ? "" : "needs Hyprland edits on", why: "Writes the accent to Hyprland’s window borders.", dis: s => !s.v("sourceEdits"), kw: "push theme window borders" },
                { n: 54, icon: "crop_free", label: "Bare", k: "bare", kind: "toggle", cfg: "edge.bare", kw: "bare mode",
                    why: "Drops the frame and the sidebar’s band. Panels float on their own." }
            ] },
            { t: "Motion", rows: [
                { n: 57, icon: "motion_blur", label: "Pace", k: "anim", kind: "slider", min: 80, max: 500, step: 10, fmt: v => `${v} ms`, cfg: "anim.base", dis: s => s.v("reduceMotion"), kw: "animation speed",
                    why: "The normal animation length. Fast and slow scale from it." },
                { n: 57, icon: "swipe_vertical", label: "Workspace slide", k: "workspaceSlide", kind: "slider", min: 0, max: 250, step: 10, fmt: v => v > 0 ? `${v} ms` : "off", cfg: "anim.workspaceSlide", dis: s => s.v("reduceMotion"), kw: "workspace switch animation hyprland slide",
                    why: "How long Hyprland slides the desktop when you change workspace. Off switches at once. The shell sets it live, so your Hyprland config is not edited." }
            ] }
        ]
    },
    sidebar: {
        id: "sidebar", name: "Sidebar", icon: "side_navigation", preview: "sidebar",
        status: s => s.v("sidebar") ? `${s.v("wsStyle")} · ${s.v("sidebarW")} px` : "hidden",
        groups: [
            { rows: [
                { n: 58, icon: "side_navigation", label: "Sidebar", k: "sidebar", kind: "toggle", cfg: "sidebar.enabled", keys: "shell:screen.sidebar.toggle" },
                { n: [], icon: "view_column_2", label: "Style", k: "sbStyle", kind: "seg", o: ["full", "rail"], cfg: "sidebar.style", dis: s => !s.v("sidebar"), kw: "sidebar rail simplified expand hover pips anomalies",
                    why: "Full keeps everything on show. Rail rests as workspace marks and shows a status icon only when something is unusual; point at it and it grows into the full column." },
                { n: [], icon: "schedule", label: "Clock and battery", k: "sbGlance", kind: "choice", o: [["rail", "rail bottom"], ["rail top", "rail top"], ["top", "pill at the top"], ["tabs", "tabs off the rail"], ["wide", "wider rail"], ["off", "off"]], cfg: "sidebar.glance", dis: s => s.v("sbStyle") !== "rail", kw: "clock time battery glance rest resting place where rail bottom top pill tabs wide wider",
                    why: "Where the time and the battery sit while the rail rests. At the rail's bottom or top, the time stacks over a battery level bar inside the rail. A pill hangs them from the top edge, tabs grow them out of the rail, and a wider rail makes room for them." },
                { n: 59, icon: "width", label: "Width", k: "sidebarW", kind: "slider", min: 40, max: 72, fmt: v => `${v} px`, cfg: "sidebar.width", dis: s => !s.v("sidebar") }
            ] },
            { t: "Workspaces", rows: [
                { n: 60, kind: "w", w: "wsStyles", kw: "workspace style plates map blocks" },
                { n: 61, icon: "palette", label: "App marks", k: "iconMode", kind: "seg", o: ["colour", "mono"], cfg: "sidebar.workspaces.iconMode", kw: "workspace icons",
                    why: "Plates show the apps inside each workspace. Mono tints the marks to match the text." },
                { n: 62, icon: "filter_5", label: "Always there", k: "persistent", kind: "step", min: 1, max: 10, cfg: "sidebar.workspaces.persistent", fmt: v => `${v}`, why: "Workspaces the sidebar always shows. More show up when busy.", kw: "always-shown workspaces" },
                { n: 63, icon: "stacks", label: "Special workspaces", k: "specialsShown", kind: "toggle", cfg: "sidebar.workspaces.rack", state: s => s.specialNames.join(" · ") || "none yet", kw: "scratchpad special", layer: [
                    { n: 63, kind: "w", w: "specials" }
                ] }
            ] },
            { t: "Clock and date", rows: [
                { n: [], icon: "schedule", label: "Clock when open", k: "sbClockWide", kind: "seg", o: ["stacked", "one line", "off"], cfg: "sidebar.clock.wideStyle", kw: "sidebar clock style wide open stacked one line hide",
                    why: "The clock in the open sidebar. Stacked is hours over minutes. One line turns the time on its side so it reads as 14:32." },
                { n: [], icon: "format_size", label: "Size when open", k: "sbClockWideSize", kind: "seg", o: ["large", "small"], cfg: "sidebar.clock.wideSize", dis: s => s.v("sbClockWide") === "off", kw: "sidebar clock size big small large wide open" },
                { n: [], icon: "schedule", label: "Clock at rest", k: "sbClock", kind: "seg", o: ["stacked", "one line", "off"], cfg: "sidebar.clock.style", dis: s => s.v("sbStyle") !== "rail" || !["rail", "rail top"].includes(s.v("sbGlance")), kw: "sidebar clock style rail rest compact stacked one line hide",
                    why: "The clock on the resting rail. It sits at the same height as the clock in the open sidebar, so it stays put when the rail grows. It applies when Clock and battery is rail bottom or rail top." },
                { n: [], icon: "format_size", label: "Size at rest", k: "sbClockSize", kind: "seg", o: ["small", "large"], cfg: "sidebar.clock.size", dis: s => s.v("sbStyle") !== "rail" || !["rail", "rail top"].includes(s.v("sbGlance")) || s.v("sbClock") === "off", kw: "sidebar clock size big small large rail rest compact" },
                { n: [], icon: "calendar_today", label: "Date", k: "sbDate", kind: "seg", o: [["day and month", "14 oct"], ["day", "14"], ["off", "off"]], cfg: "sidebar.clock.date", kw: "sidebar calendar date hide",
                    why: "The date under the clock. It still opens the calendar when you tap or pull it." }
            ] },
            { t: "Status", rows: [
                { n: [], icon: "sync", label: "Update button", k: "sbUpdate", kind: "seg", o: [["always", "always"], ["new", "when new"], ["never", "never"]], cfg: "sidebar.update", kw: "sidebar update button hide",
                    why: "When new keeps the sidebar clean until there is something to install. Updates stay reachable from System either way." },
                { n: [], icon: "volume_up", label: "Sound", k: "sbSound", kind: "toggle", cfg: "sidebar.status.sound", kw: "sidebar status icons" },
                { n: [], icon: "wifi", label: "Network", k: "sbNet", kind: "toggle", cfg: "sidebar.status.network", kw: "sidebar status icons" },
                { n: [], icon: "bluetooth", label: "Bluetooth", k: "sbBt", kind: "toggle", cfg: "sidebar.status.bluetooth", kw: "sidebar status icons" },
                { n: [], icon: "brightness_6", label: "Brightness", k: "sbBright", kind: "toggle", cfg: "sidebar.status.brightness", why: "Shows the screen’s brightness in the sidebar. Scroll it to change brightness.", kw: "sidebar status icons screen backlight" },
                { n: [], icon: "battery_5_bar", label: "Battery", k: "sbBatt", kind: "toggle", cfg: "sidebar.status.battery", state: s => s.hasBattery ? "" : "no battery in this machine", dis: s => !s.hasBattery, kw: "sidebar status icons" }
            ] },
            { t: "Tray", rows: [
                { n: 64, icon: "apps", label: "Tray", k: "tray", kind: "toggle", cfg: "sidebar.tray.enabled", state: s => `${s.trayCount} apps`, kw: "tray" },
                { n: 64, icon: "more_horiz", label: "Most icons", k: "trayMax", kind: "step", min: 1, max: 12, cfg: "sidebar.tray.max", fmt: v => `${v}`, why: "How many tray icons show. The rest fold away.", dis: s => !s.v("tray") }
            ] }
        ]
    },
    windows: {
        id: "windows", name: "Windows", icon: "select_window", preview: "drop",
        status: s => `${s.v("layout") === "custom" ? "custom layout" : s.v("layout")} · ${s.v("dropMode")} on drop`,
        groups: [
            { t: "Layout", rows: [
                { n: [], kind: "w", w: "winLayouts", kw: "tiling layout dwindle master scrolling hy3 custom workshop draw lua" }
            ] },
            { t: "Moving", rows: [
                { n: 66, icon: "vertical_align_top", label: "Bottom edge lifts windows", k: "edgeLift", kind: "toggle", cfg: "windows.edge", why: "Push down at the bottom edge to peek under your windows." },
                { n: 67, icon: "swap_horiz", label: "Dropping on a window", k: "dropMode", kind: "seg", o: ["move", "swap"], cfg: "windows.mode", kw: "move swap",
                    why: "Move takes the spot and nudges the other aside. Swap trades the two." },
                { n: 68, icon: "trending_flat", label: "Follow a sent window", k: "followSent", kind: "toggle", cfg: "windows.follow", state: s => s.v("followSent") ? "you go with it" : "you stay put" }
            ] },
            { t: "Panel widths", rows: [
                { n: 65, icon: "search", label: "Launcher", k: "launcherW", kind: "slider", min: 600, max: 1200, step: 20, fmt: v => `${v}`, cfg: "launcher.width", kw: "panel sizes" },
                { n: 65, icon: "content_paste", label: "Clipboard", k: "clipW", kind: "slider", min: 600, max: 1400, step: 20, fmt: v => `${v}`, cfg: "clipboard.width", kw: "panel sizes" },
                { n: 65, icon: "menu", label: "Menus", k: "menuW", kind: "slider", min: 320, max: 560, step: 10, fmt: v => `${v}`, cfg: "menu.width", kw: "panel sizes" },
                { n: 65, icon: "tune", label: "Settings", k: "settingsW", kind: "slider", min: 1040, max: 1440, step: 20, fmt: v => `${v}`, cfg: "settings.width", why: "How wide this panel opens.", kw: "panel sizes settings window" }
            ] }
        ]
    },
    launcher: {
        id: "launcher", name: "Launcher", icon: "search", preview: "launcher",
        status: s => `${s.v("concept")} · ${s.starredCount} starred`,
        groups: [
            { t: "Layout", rows: [
                { n: 69, icon: "view_agenda", label: "Concept", k: "concept", kind: "seg", o: ["list", "alphabet"], cfg: "launcher.concept", kw: "launcher layout",
                    why: "List is a plain search list. Alphabet is a thumb-sized rail of letters with favourites on a bow." },
                { n: [], icon: "vertical_align_center", label: "Position", k: "searchAt", kind: "slider", min: 0, max: 1, step: 0.01, ends: ["top", "bottom"], fmtS: (s, v) => placedText(v, s.launcherPlaced ?? -1), cfg: "launcher.list.searchAt", dis: s => s.v("concept") !== "list", kw: "launcher position height vertical move up down raise lower top centre center search bar",
                    why: "How far down the screen the middle of the search bar sits, as a share of the screen's height. When the full list would not fit below, the launcher moves up until it does." },
                { n: [], icon: "push_pin", label: "Show pinned", k: "listPinned", kind: "toggle", cfg: "launcher.list.pinned", dis: s => s.v("concept") !== "list", kw: "pinned favourites quick launch grid icons",
                    why: "Pick an app in the list and press Pin to put it here." },
                { n: [], icon: "schedule", label: "Show recents", k: "listRecents", kind: "toggle", cfg: "launcher.list.recents", dis: s => s.v("concept") !== "list", kw: "recent apps launcher icons" },
                { n: [], icon: "animation", label: "Animate preview", k: "animatePreview", kind: "toggle", cfg: "launcher.animatePreview", dis: s => s.v("concept") !== "list", kw: "preview peek card animate resize frame motion",
                    why: "The card beside the list grows and shrinks to fit the next preview instead of jumping to its size." },
                { n: 70, icon: "photo_size_select_large", label: "Icon size", k: "launcherIcon", kind: "slider", min: 18, max: 48, step: 2, fmt: v => `${v} px`, cfg: "launcher.iconSize", kw: "launcher icon size" },
                { n: 71, icon: "trending_up", label: "Habit fades over", k: "halfLife", kind: "step", min: 1, max: 60, unit: " days", cfg: "launcher.halfLifeDays", why: "Apps you use rise in the launcher. This is how long a launch keeps counting.", extra: { icon: "history", tip: "forget what it learned", act: "forgetHabit" }, kw: "app ranking by habit" }
            ] },
            { t: "Search results", rows: [
                { n: [], icon: "visibility", label: "Hidden files", k: "hiddenFiles", kind: "seg", o: ["off", ".config", "all"], cfg: "launcher.hiddenFiles", kw: "hidden files dotfiles .config search results",
                    why: "Which hidden files the launcher finds by name. .config is where most apps keep their settings." },
                { n: [], icon: "currency_exchange", label: "Currency", k: "currency", kind: "choice", o: s => s.currencies, cfg: "launcher.currency", state: s => s.ratesNote, kw: "currency money exchange rates convert",
                    why: "Typing an amount like 5 eur shows it in this currency. Rates come from the European Central Bank once a day and are kept for when you are offline." },
                { n: [], icon: "find_in_page", label: "Inside files", k: "contents", kind: "toggle", cfg: "launcher.contents", kw: "search inside files contents text ripgrep grep",
                    why: "Words you type are also looked for inside the files in your home folder, and inside .config when Hidden files lets it in. Other hidden files, node_modules, caches, Python environments, the Android SDK, images, audio, archives and anything that looks like a key are skipped. A search that takes more than 2 seconds is stopped, and the results say so." },
                { n: [], icon: "travel_explore", label: "Search engine", k: "webSearch", kind: "choice", o: [["https://duckduckgo.com/?q=%s", "DuckDuckGo"], ["https://www.google.com/search?q=%s", "Google"], ["https://www.bing.com/search?q=%s", "Bing"], ["https://search.brave.com/search?q=%s", "Brave"], ["https://www.startpage.com/do/search?q=%s", "Startpage"], ["https://www.ecosia.org/search?q=%s", "Ecosia"], ["https://kagi.com/search?q=%s", "Kagi"]], cfg: "launcher.webSearch", kw: "web search engine google duckduckgo bing" }
            ] },
            { t: "When nothing fits", rows: [
                { n: [], icon: "travel_explore", label: "Web search", k: "fallbackWeb", kind: "toggle", cfg: "launcher.fallbacks.web", kw: "fallback web search" },
                { n: [], icon: "smart_display", label: "YouTube", k: "fallbackYoutube", kind: "toggle", cfg: "launcher.fallbacks.youtube", kw: "fallback youtube video search" },
                { n: [], icon: "menu_book", label: "Wikipedia", k: "fallbackWikipedia", kind: "toggle", cfg: "launcher.fallbacks.wikipedia", kw: "fallback wikipedia" },
                { n: [], icon: "map", label: "Map", k: "fallbackMaps", kind: "toggle", cfg: "launcher.fallbacks.maps", kw: "fallback map places openstreetmap" },
                { n: [], icon: "terminal", label: "Run in a terminal", k: "fallbackTerminal", kind: "toggle", cfg: "launcher.fallbacks.terminal", kw: "fallback run command terminal shell" }
            ] },
            { t: "Typing", rows: [
                { n: [], icon: "front_hand", label: "Skin tone", k: "skinTone", kind: "choice", o: [["none", "✋ default"], ["light", "✋🏻 light"], ["medium-light", "✋🏼 medium light"], ["medium", "✋🏽 medium"], ["medium-dark", "✋🏾 medium dark"], ["dark", "✋🏿 dark"]], cfg: "launcher.typing.skinTone", kw: "emoji skin tone hands people colour",
                    why: "Emoji with people and hands come in this tone. More on an emoji row still offers every tone." },
                { n: [], icon: "content_paste_search", label: "Clipboard in search", k: "clipboardInSearch", kind: "toggle", cfg: "launcher.typing.clipboard", kw: "clipboard history search results paste",
                    why: "Words you type also find recent clipboard entries. Typing clip shows them either way." },
                { n: [], icon: "notifications", label: "Notifications in search", k: "notificationsInSearch", kind: "toggle", cfg: "launcher.typing.notifications", kw: "notification history search results messages private",
                    why: "Words you type also find the text of recent notifications. Off by default because message text on screen is private. Typing notifications shows them either way." }
            ] },
            { t: "Snippets", rows: [
                { n: [], kind: "w", w: "snippets", kw: "snippets saved text expand keyword placeholders" }
            ] },
            { t: "Quicklinks", rows: [
                { n: [], kind: "w", w: "quicklinks", kw: "quicklinks search shortcuts keywords urls youtube github wiki" }
            ] },
            { t: "Power tools", rows: [
                { n: [], icon: "terminal", label: "Scripts folder", k: "scriptsFolder", kind: "text", mono: true, cfg: "launcher.powerTools.scriptsFolder", placeholder: "~/.config/banditshell/scripts", kw: "script commands raycast scripts folder",
                    why: "Scripts in this folder show up by their file name, or by the Raycast style @raycast.title header. Type a script's name and press Enter to run it." },
                { n: [], icon: "folder_code", label: "Project folders", k: "projectFolders", kind: "text", mono: true, cfg: "launcher.powerTools.projectFolders", placeholder: "~/Projects", kw: "projects git repositories code folders",
                    why: "Git repositories in these folders, separated by commas, show up when you type their name or projects." },
                { n: [], icon: "account_tree", label: "Project depth", k: "projectDepth", kind: "step", min: 1, max: 4, cfg: "launcher.powerTools.projectDepth", fmt: v => v === 1 ? "1 level" : `${v} levels`, kw: "projects search depth" },
                { n: [], icon: "description", label: "Note folders", k: "noteFolders", kind: "text", mono: true, cfg: "launcher.powerTools.noteFolders", placeholder: "~/Obsidian", kw: "notes obsidian vaults folders",
                    why: "Obsidian vaults inside these folders are searched along with the vaults Obsidian already knows about." },
                { n: [], icon: "visibility_off", label: "Leave out vaults", k: "noteSkip", kind: "text", mono: true, cfg: "launcher.powerTools.noteSkip", placeholder: "Archive, ~/Obsidian/Work", kw: "notes obsidian vaults hide skip private exclude",
                    why: "Vaults named here, by name or folder and separated by commas, are never searched and never get new notes." },
                { n: [], icon: "note_add", label: "New notes go to", k: "noteVault", kind: "choice", o: s => s.noteVaults, cfg: "launcher.powerTools.noteVault", kw: "notes obsidian vault new note default" },
                { n: [], icon: "timer", label: "Focus round", k: "focusMinutes", kind: "step", min: 5, max: 120, step: 5, unit: " min", cfg: "launcher.powerTools.focusMinutes", kw: "pomodoro focus work minutes" },
                { n: [], icon: "coffee", label: "Break", k: "breakMinutes", kind: "step", min: 1, max: 30, unit: " min", cfg: "launcher.powerTools.breakMinutes", kw: "pomodoro short break minutes" },
                { n: [], icon: "self_improvement", label: "Long break", k: "longBreakMinutes", kind: "step", min: 5, max: 60, step: 5, unit: " min", cfg: "launcher.powerTools.longBreakMinutes", kw: "pomodoro long break minutes" },
                { n: [], icon: "coffee", label: "Rounds before a long break", k: "roundsBeforeLongBreak", kind: "step", min: 2, max: 8, cfg: "launcher.powerTools.roundsBeforeLongBreak", fmt: v => `${v}`, kw: "pomodoro rounds long break" }
            ] },
            { t: "Developer tools", rows: [
                { n: [], icon: "dns", label: "SSH hosts", k: "devOpsSsh", kind: "toggle", cfg: "launcher.devOps.ssh", kw: "ssh hosts servers remote connect terminal known_hosts",
                    why: "Type ssh for the hosts in your SSH config and known hosts, then press Enter to connect in a terminal. Private keys are never read." },
                { n: [], icon: "lan", label: "Listening ports", k: "devOpsPorts", kind: "toggle", cfg: "launcher.devOps.ports", kw: "ports listening sockets who uses port localhost server kill",
                    why: "Type ports or port 3000 to see what listens there, then quit it or open it in the browser." },
                { n: [], icon: "settings_suggest", label: "Services", k: "devOpsServices", kind: "toggle", cfg: "launcher.devOps.services", kw: "systemd services units systemctl start stop restart daemon",
                    why: "Type services, service docker or restart sshd. System services ask for your password before they change." },
                { n: [], icon: "deployed_code", label: "Containers", k: "devOpsContainers", kind: "toggle", cfg: "launcher.devOps.containers", kw: "containers podman docker logs shell exec",
                    why: "Type containers, podman or docker to start and stop containers, follow their logs or open a shell inside." },
                { n: [], icon: "mobile", label: "Phone through KDE Connect", k: "devOpsPhone", kind: "toggle", cfg: "launcher.devOps.phone", kw: "phone kde connect ring ping battery send file clipboard share link",
                    why: "Type phone, ring phone or send to phone. Works with phones already paired in KDE Connect." }
            ] },
            { t: "Utilities", rows: [
                { n: [], icon: "password", label: "Password length", k: "passwordLength", kind: "step", min: 8, max: 64, step: 4, cfg: "launcher.utilities.passwordLength", fmt: v => `${v} characters`, kw: "password generator random length uuid developer",
                    why: "Typing password makes one this long. Ask for another length with password 32, or password 20 simple for one without symbols." },
                { n: [], icon: "notifications_active", label: "Reminders without a time", k: "reminderHour", kind: "step", min: 5, max: 12, cfg: "launcher.utilities.reminderHour", fmt: v => `${v < 10 ? "0" : ""}${v}:00`, kw: "reminder default time morning tomorrow remind me",
                    why: "Remind me tomorrow to call mum rings at this hour. Tonight, this afternoon and this evening ring at 20:00, 15:00 and 19:00." }
            ] },
            { t: "Online", rows: [
                { n: [], icon: "translate", label: "Translate", k: "onlineTranslate", kind: "toggle", cfg: "launcher.online.translate", kw: "translate translation language google",
                    why: "Type hello in german, translate bonjour or tr hola. The text goes to Google Translate." },
                { n: [], icon: "language", label: "Translate into", k: "onlineTranslateTo", kind: "choice", o: [["", "System language"], ["en", "English"], ["da", "Danish"], ["de", "German"], ["fr", "French"], ["es", "Spanish"], ["it", "Italian"], ["nl", "Dutch"], ["sv", "Swedish"], ["no", "Norwegian"], ["fi", "Finnish"], ["pl", "Polish"], ["pt", "Portuguese"], ["ja", "Japanese"], ["zh-CN", "Chinese"], ["ko", "Korean"]], cfg: "launcher.online.translateTo", dis: s => !s.v("onlineTranslate"), kw: "translate target language default" },
                { n: [], icon: "menu_book", label: "Wiktionary definitions", k: "onlineDefine", kind: "toggle", cfg: "launcher.online.define", kw: "define dictionary meaning word",
                    why: "Type define and a word. The offline dictionary answers at once; this adds Wiktionary's entry beside it." },
                { n: [], icon: "package_2", label: "Packages", k: "onlinePackages", kind: "toggle", cfg: "launcher.online.packages", kw: "install package pacman aur flatpak apt dnf software",
                    why: "Type install and a name to search the system packages, the AUR and Flatpak, then install or remove from the row." },
                { n: [], icon: "book", label: "GitHub", k: "onlineGithub", kind: "toggle", cfg: "launcher.online.github", kw: "github gh repos pull requests issues notifications",
                    why: "Type gh for your repositories, open pull requests, assigned issues and notifications. Needs the gh command, signed in." },
                { n: [], icon: "bookmark", label: "Bookmarks and history", k: "onlineBrowser", kind: "toggle", cfg: "launcher.online.browser", kw: "browser bookmarks history firefox zen chromium",
                    why: "Pages from your browsers show up as you type. The list is read in the background at most every few minutes and stays on this computer." },
                { n: [], icon: "speed", label: "Speed test", k: "onlineSpeedtest", kind: "toggle", cfg: "launcher.online.speedtest", kw: "speedtest internet speed bandwidth" },
                { n: [], icon: "movie", label: "Video downloads", k: "onlineVideos", kind: "toggle", cfg: "launcher.online.videos", kw: "download video audio youtube yt-dlp",
                    why: "Paste a video link to save the video or its sound to your Downloads folder with yt-dlp." }
            ] },
            { t: "System controls", rows: [
                { n: [], icon: "brightness_medium", label: "Brightness", k: "systemBrightness", kind: "toggle", cfg: "launcher.systemControls.brightness", kw: "brightness backlight dim brighter dimmer screen monitor ddcutil",
                    why: "Type brightness for a slider per screen, brightness 40 to set them all, or brighter and dimmer. Monitors need ddcutil." },
                { n: [], icon: "brightness_low", label: "Lowest brightness", k: "systemLowestBrightness", kind: "step", min: 1, max: 30, unit: "%", cfg: "launcher.systemControls.lowestBrightness", dis: s => !s.v("systemBrightness"), kw: "brightness minimum lowest floor black" },
                { n: [], icon: "wifi", label: "Wi-Fi networks", k: "systemWifi", kind: "toggle", cfg: "launcher.systemControls.wifi", kw: "wifi wi-fi wireless networks join password",
                    why: "Type wifi to see every network in range. Joining a locked one asks for its password on the shell's own card." },
                { n: [], icon: "vpn_lock", label: "VPN and Tailscale", k: "systemVpn", kind: "toggle", cfg: "launcher.systemControls.vpn", kw: "vpn wireguard tailscale exit node tunnel",
                    why: "Type vpn for your saved VPN connections, or tailscale for its status, devices and exit nodes." },
                { n: [], icon: "screen_record", label: "Screen recording", k: "systemRecording", kind: "toggle", cfg: "launcher.systemControls.recording", kw: "record screen recording video capture wf-recorder",
                    why: "Type record screen, record area or record window. Sound is only recorded when you say record screen with sound." },
                { n: [], icon: "movie", label: "Recordings folder", k: "systemRecordingFolder", kind: "text", mono: true, cfg: "launcher.systemControls.recordingFolder", placeholder: "~/Videos/Recordings", dis: s => !s.v("systemRecording"), kw: "recordings folder videos save location" }
            ] },
            { t: "Aliases and hotkeys", rows: [
                { n: [], kind: "w", w: "shortcuts", list: "aliases", kw: "launcher aliases short names" },
                { n: [], kind: "w", w: "shortcuts", list: "hotkeys", kw: "launcher hotkeys global keys" }
            ] },
            { t: "Apps", rows: [
                { n: 72, kind: "w", w: "chips", list: "starred", kw: "starred apps favourites" },
                { n: 72, kind: "w", w: "chips", list: "hidden", kw: "hidden apps" },
                { n: 72, kind: "w", w: "folders", kw: "app folders" },
                { n: 73, kind: "w", w: "overrides", kw: "app icon overrides" }
            ] },
            { t: "AI", rows: [
                { n: [], icon: "auto_awesome", label: "Answers and rewriting", k: "aiOn", kind: "toggle", cfg: "launcher.ai.enabled", state: s => s.aiNote, kw: "ai assistant ask question answer chat llm ollama rewrite selected text grammar translate summarise",
                    why: "Type ? and a question to get an answer under the search field. Select text in any app, open the launcher and type fix, shorter, friendlier, summarise, translate or explain to work on it. Nothing is sent anywhere but the backend below." },
                { n: [], icon: "dns", label: "Backend", k: "aiBackend", kind: "choice", o: [["ollama", "Ollama"], ["openai", "OpenAI compatible"], ["anthropic", "Anthropic"]], cfg: "launcher.ai.backend", dis: s => !s.v("aiOn"), kw: "ai backend provider ollama openai anthropic claude api local",
                    why: "Ollama runs the model on this computer, so what you ask and select stays here. The other two send it to that service with your API key." },
                { n: [], icon: "neurology", label: "Model", k: "aiModel", kind: "choice", o: s => s.aiModels, cfg: "launcher.ai.model", dis: s => !s.v("aiOn"), state: s => s.aiModelNote, kw: "ai model llm qwen llama claude gpt" },
                { n: [], icon: "key", label: "API key", k: "aiKey", kind: "secret", dis: s => !s.v("aiOn") || s.v("aiBackend") === "ollama", kw: "ai api key token secret openai anthropic",
                    why: "Each backend keeps its own key, in a file only you can read in the shell's state folder, never in config.json." },
                { n: [], icon: "link", label: "Address", k: "aiAddress", kind: "text", mono: true, cfg: "launcher.ai.openaiAddress", state: s => s.aiAddressNote, dis: s => !s.v("aiOn") || s.v("aiBackend") !== "openai", kw: "ai api address url endpoint base url openrouter groq lm studio llama.cpp",
                    why: "Any server that speaks the OpenAI chat API: OpenAI, OpenRouter, Groq, LM Studio or llama.cpp. The key goes only to an https address or to this computer; a plain http server elsewhere is asked without it." }
            ] }
        ]
    },
    clipboard: {
        id: "clipboard", name: "Clipboard", icon: "content_paste", preview: "clipboard",
        status: s => s.v("clip") ? `keeping ${s.v("clipMax")}` : "off",
        groups: [
            { rows: [
                { n: 74, icon: "fiber_manual_record", label: "Record", k: "clip", kind: "toggle", cfg: "clipboard.record", keys: "shell:panel.clipboard.toggle", extra: { icon: "delete_sweep", tip: "clear it all", act: "clearClip" }, kw: "clipboard history on off" },
                { n: 75, icon: "format_list_numbered", label: "Keep", k: "clipMax", kind: "step", min: 50, max: 2000, step: 50, cfg: "clipboard.maxEntries", fmt: v => `${v}`, dis: s => !s.v("clip"), kw: "clipboard limits" },
                { n: 75, icon: "notes", label: "Longest text", k: "clipText", kind: "seg", o: [[262144, "256 KB"], [1048576, "1 MB"], [8388608, "8 MB"]], cfg: "clipboard.maxText", dis: s => !s.v("clip"), kw: "clipboard limits" },
                { n: 75, icon: "image", label: "Largest image", k: "clipBlob", kind: "seg", o: [[8388608, "8 MB"], [33554432, "32 MB"], [134217728, "128 MB"]], cfg: "clipboard.maxBlob", dis: s => !s.v("clip"), kw: "clipboard limits" }
            ] },
            { t: "Import", rows: [
                { n: 76, icon: "move_to_inbox", label: "From clipse", kind: "button", btn: s => s.clipseWaiting ? "Import" : "Done", act: "importClipse", cfg: "clipboard.importClipse", state: s => s.clipseDetail, dis: s => !s.clipseWaiting, kw: "import clipse" }
            ] }
        ]
    },
    modes: {
        id: "modes", name: "Modes", icon: "tune", preview: "modes",
        status: s => s.v("mode") !== "none" ? s.v("mode") : "none",
        groups: [
            { rows: [
                { n: [], kind: "w", w: "modes", kw: "modes focus work play stream sleep" }
            ] },
            { t: "Do not disturb", rows: [
                { n: 80, icon: "do_not_disturb_on", label: "Do not disturb", k: "dnd", kind: "toggle", cfg: "notifications.quiet", state: s => s.quietNote, kw: "dnd focus", layer: [
                    { n: 80, icon: "timer_off", label: "Ends", k: "dndUntil", kind: "choice", o: ["in an hour", "at 18:00", "tomorrow", "off by hand"], cfg: "notifications.quietUntil", state: s => s.quietEndsNote },
                    { n: 80, icon: "alarm", label: "Let alarms through", k: "dndAlarms", kind: "toggle", cfg: "notifications.letAlarms" }
                ] },
                { n: 80, icon: "bedtime", label: "Every night", k: "dndNightly", kind: "toggle", cfg: "notifications.nightly", state: s => s.nightWindow, kw: "do not disturb schedule" }
            ] }
        ]
    },
    clock: {
        id: "clock", name: "Clock", icon: "schedule", preview: "clock",
        status: s => s.nextAlarm,
        groups: [
            { t: "Alarms", rows: [
                { n: 84, icon: "snooze", label: "Snooze", k: "snooze", kind: "step", min: 1, max: 30, unit: " min", cfg: "clock.snoozeMinutes", kw: "alarms" },
                { n: 84, icon: "notifications_active", label: "Ring for", k: "ring", kind: "step", min: 1, max: 60, unit: " min", cfg: "clock.ringMinutes", kw: "alarms ring length" },
                { n: 84, icon: "update", label: "Catch up", k: "catchUp", kind: "step", min: 0, max: 240, step: 15, unit: " min", cfg: "clock.catchUpMinutes", state: s => s.v("catchUp") ? "rings late after sleep" : "missed means missed", kw: "alarms catch-up",
                    why: "If the laptop slept through an alarm, it still rings on wake when it is this late or less." },
                { n: 85, icon: "hourglass", label: "Longest timer", k: "timerMax", kind: "step", min: 1, max: 24, unit: " h", cfg: "clock.timerMax", kw: "timer limits" },
                { n: 85, icon: "alarm", label: "Most alarms", k: "alarmMax", kind: "step", min: 1, max: 20, cfg: "clock.alarmMax", fmt: v => `${v}`, kw: "alarm limits" }
            ] },
            { t: "Other time zones", rows: [
                { n: 86, kind: "w", w: "clocks", kw: "world clocks" }
            ] },
            { t: "Calendar", rows: [
                { n: 83, icon: "swipe", label: "Swiping right goes", k: "rightForward", kind: "seg", o: [[true, "forward"], [false, "back"]], cfg: "calendar.rightGoesForward", kw: "calendar scroll direction" }
            ] },
            { t: "Weather", preview: "weather", rows: [
                { n: [], icon: "partly_cloudy_day", label: "Weather", k: "weatherShow", kind: "toggle", cfg: "weather.show", state: s => s.v("weatherShow") ? "beside the clock in the island" : "off", kw: "weather temperature forecast island",
                    why: "The temperature beside the island’s clock. Pressing it opens the week ahead." },
                { n: [], icon: "location_on", label: "Place", k: "weatherPlace", kind: "text", cfg: "weather.location", placeholder: "automatic", places: true, state: s => s.weatherPlaceState, bad: s => s.weatherPlaceTrouble !== "", offer: s => placeOffer(s), dis: s => !s.v("weatherShow"), kw: "weather location town city",
                    why: "A town or city. Left empty, the weather uses your connection's location." },
                { n: [], icon: "thermostat", label: "Units", k: "weatherUnits", kind: "seg", o: [["metric", "°C"], ["imperial", "°F"]], cfg: "weather.units", dis: s => !s.v("weatherShow"), kw: "weather units celsius fahrenheit temperature",
                    why: "For the temperature in the island and the week ahead." },
                { n: [], icon: "update", label: "Refresh after", k: "weatherMinutes", kind: "step", min: 5, max: 180, step: 5, unit: " min", cfg: "weather.minutes", dis: s => !s.v("weatherShow"), kw: "weather refresh interval",
                    why: "How old a reading may get before opening the island fetches a new one." }
            ] },
            { t: "Ask", rows: [
                { n: 87, icon: "smart_toy", label: "Helper", k: "cloud", kind: "text", mono: true, cfg: "clock.cloud", kw: "clock ai helper command",
                    why: "The command the clock runs when you type a question into it. Your question goes on the end." },
                { n: 87, icon: "timer", label: "Give it", k: "cloudSeconds", kind: "step", min: 10, max: 600, step: 10, unit: " s", cfg: "clock.cloudSeconds" }
            ] }
        ]
    },
    screentime: {
        id: "screentime", name: "Screen time", icon: "hourglass_bottom", preview: "usage",
        status: s => `${s.usedLabel} of ${s.v("capHours")} h`,
        groups: [
            { t: "Today", rows: [
                { n: 88, kind: "w", w: "usage", kw: "screen time usage today" }
            ] },
            { t: "Limits", rows: [
                { n: 88, icon: "hourglass_bottom", label: "Daily cap", k: "capHours", kind: "step", min: 1, max: 16, unit: " h", cfg: "usage.capHours", state: s => `${s.usedLabel} so far`, kw: "screen time cap" },
                { n: 88, icon: "filter_b_and_w", label: "Grey at the cap", k: "greyCap", kind: "toggle", cfg: "usage.greyAtCap", why: "Drains colour once the time is up. Input still works." },
                { n: 88, icon: "self_improvement", label: "Breaks", k: "breaks", kind: "toggle", cfg: "usage.breaks", state: s => s.v("breaks") ? `a nudge every ${s.v("breakEvery")} min` : "off", layer: [
                    { n: 88, icon: "timer", label: "Every", k: "breakEvery", kind: "step", min: 15, max: 120, step: 5, unit: " min", cfg: "usage.breakEvery" }
                ] }
            ] }
        ]
    },
    keyboard: {
        id: "keyboard", name: "Keyboard", icon: "keyboard", preview: "sheet",
        status: s => s.kbLayouts.map(l => l.name).join(" · "),
        groups: [
            { rows: [
                { n: 99, kind: "w", w: "kbLayouts", kw: "keyboard layout" },
                { n: 99, icon: "keyboard_tab", label: "Repeat after", k: "kbDelay", kind: "slider", min: 150, max: 800, step: 10, fmt: v => `${v} ms`, kw: "key repeat delay" },
                { n: 99, icon: "fast_forward", label: "Repeat rate", k: "kbRate", kind: "slider", min: 10, max: 60, fmt: v => `${v}/s`, kw: "key repeat rate" }
            ] },
            { t: "Hotkey sheet", rows: [
                { n: 98, icon: "keyboard_alt", label: "Draw the board", k: "sheetBoard", kind: "toggle", cfg: "cheatsheet.board", keys: "shell:panel.hotkeys.toggle", kw: "hotkey sheet" },
                { n: 98, icon: "keyboard", label: "Board", k: "sheetKeyboard", kind: "choice", o: [["iso", "ISO"], ["ansi", "ANSI"], ["file", "Custom"]], cfg: "cheatsheet.keyboard", dis: s => !s.v("sheetBoard"), kw: "hotkey sheet keyboard via import iso ansi custom",
                    why: "ISO and ANSI are drawn from built-in layouts. Custom draws your own board from its VIA file, so the sheet matches the keyboard on your desk. Pick ISO or ANSI and the file is forgotten." },
                { n: 98, kind: "w", w: "via", kw: "via file import keyboard layout" },
                { n: 98, icon: "description", label: "Read keys from", k: "bindsFile", kind: "path", ro: true, kw: "hotkey sheet layout file" }
            ] }
        ]
    },
    shortcuts: {
        id: "shortcuts", name: "Shortcuts", icon: "keyboard_command_key", preview: "sheet",
        status: s => `${s.keyCount} keys`,
        groups: [
            { t: "Shell", rows: [
                { n: 97, kind: "w", w: "keys", set: "shell", kw: "keybinds shortcuts hotkeys" }
            ] },
            { t: "In files", rows: [
                { n: 94, kind: "w", w: "keys", set: "files", kw: "files shortcuts" }
            ] }
        ]
    },
    pointer: {
        id: "pointer", name: "Pointer", icon: "mouse", preview: "pointer",
        status: s => s.v("naturalScroll") ? "natural scroll" : "classic scroll",
        groups: [
            { rows: [
                { n: 100, icon: "mouse", label: "Mouse speed", k: "mouseSpeed", kind: "slider", min: -1, max: 1, step: 0.05, fmt: signed, kw: "mouse speed" },
                { n: 100, icon: "touchpad_mouse", label: "Touchpad speed", k: "padSpeed", kind: "slider", min: -1, max: 1, step: 0.05, fmt: signed, state: s => s.touchpads.length ? s.touchpads.map(t => t.label).join(" · ") : "no touchpad here", dis: s => !s.touchpads.length, kw: "touchpad speed" },
                { n: 100, icon: "swipe_vertical", label: "Natural scrolling", k: "naturalScroll", kind: "toggle", why: "Content follows your fingers." },
                { n: 100, icon: "touch_app", label: "Tap to click", k: "tapClick", kind: "toggle" }
            ] }
        ]
    },
    tablet: {
        id: "tablet", name: "Tablet", icon: "tablet", preview: "tablet",
        status: s => s.v("autoKeyboard") ? `board ${Math.round(s.v("boardHeight") * 100)}%` : "no board",
        groups: [
            { t: "Touch", rows: [
                { n: 101, icon: "border_left", label: "Finger-sized edges", k: "touchEdges", kind: "toggle", cfg: "control.touchEdges", why: "Wider swipe-in strips at the screen edges." },
                { n: 101, icon: "gesture", label: "Gesture feel", k: "gestureFeel", kind: "seg", o: [[0.15, "light"], [0.25, "balanced"], [0.4, "firm"]], cfg: "control.pullCommit",
                    why: "How far a pull has to travel before it commits. Light gives way at a nudge." }
            ] },
            { t: "Tablet", rows: [
                { n: 102, icon: "keyboard_hide", label: "Keyboard on fold", k: "autoKeyboard", kind: "toggle", cfg: "tablet.autoKeyboard" },
                { n: 102, icon: "vertical_align_bottom", label: "Board takes room", k: "docked", kind: "toggle", cfg: "tablet.docked", state: s => s.v("docked") ? "windows move up" : "floats over them", dis: s => !s.v("autoKeyboard") },
                { n: 102, icon: "height", label: "Board height", k: "boardHeight", kind: "slider", min: 0.25, max: 0.5, step: 0.01, fmt: pct, cfg: "tablet.height", dis: s => !s.v("autoKeyboard") },
                { n: 102, icon: "repeat", label: "Held keys repeat", k: "boardRepeat", kind: "toggle", cfg: "tablet.repeat", state: s => s.repeatDetail, dis: s => !s.v("autoKeyboard"), kw: "key repeat" }
            ] }
        ]
    },
    pen: {
        id: "pen", name: "Pen", icon: "stylus_note", preview: "pen",
        status: s => s.v("pen") ? `mapped to ${s.v("penScreen")}` : "off",
        groups: [
            { rows: [
                { n: 103, icon: "stylus", label: "Pen", k: "pen", kind: "toggle", cfg: "pen.enabled", state: s => s.v("pen") ? s.penName : "off", kw: "pen device" },
                { n: 103, icon: "monitor", label: "Maps to", k: "penScreen", kind: "seg", o: s => s.screensOn.concat(["all"]), dis: s => !s.v("pen"), kw: "pen area mapping" },
                { n: 103, icon: "aspect_ratio", label: "Keep the shape", k: "aspectLock", kind: "toggle", cfg: "pen.aspectLock", why: "Trims the pad to match the screen’s shape.", dis: s => !s.v("pen"), kw: "pen aspect lock" },
                { n: 103, icon: "radio_button_unchecked", label: "Lower button", k: "penBtn1", kind: "choice", o: ["right click", "middle click", "erase", "nothing"], cfg: "pen.lowerButton", state: s => s.penButtonNote, dis: s => !s.v("pen"), kw: "pen buttons",
                    why: PEN_BUTTONS_WHY },
                { n: 103, icon: "radio_button_checked", label: "Upper button", k: "penBtn2", kind: "choice", o: ["right click", "middle click", "erase", "nothing"], cfg: "pen.upperButton", state: s => s.penButtonNote, dis: s => !s.v("pen"), kw: "pen buttons",
                    why: PEN_BUTTONS_WHY }
            ] }
        ]
    },
    battery: {
        id: "battery", name: "Battery", icon: "battery_5_bar", preview: "battery", off: s => !s.hasBattery, away: s => !s.hasBattery,
        status: s => !s.hasBattery ? "no battery in this machine" : s.v("chargeLimit") && !s.chargeTrouble ? `${s.batteryPct}% · held at ${s.v("chargeMax")}%` : `${s.batteryPct}%`,
        groups: [
            { rows: [
                { n: 104, kind: "w", w: "battery", kw: "battery charge health history" }
            ] },
            { t: "Charging", rows: [
                { n: 106, icon: "battery_charging_80", label: "Hold the charge", k: "chargeLimit", kind: "toggle", cfg: "battery.holdCharge", state: s => s.chargeTrouble, why: "Stops charging short of full, which is kinder to the cells.", dis: s => !s.chargeSupported, kw: "charge limit" },
                { n: 106, icon: "battery_full", label: "Stop at", k: "chargeMax", kind: "slider", cfg: "battery.holdAt", min: 60, max: 100, step: 5, fmt: v => `${v}%`, dis: s => !s.v("chargeLimit") || !s.chargeSupported, kw: "charge limit" },
                { n: 107, icon: "battery_alert", label: "Warn at", k: "lowWarn", kind: "slider", cfg: "battery.warnAt", min: 5, max: 30, fmt: v => `${v}%`, kw: "low battery warning" },
                { n: 107, icon: "battery_0_bar", label: "Nearly empty", k: "lowAction", kind: "choice", cfg: "battery.nearlyEmpty", o: s => [`sleep at ${s.nearlyEmptyPercent}%`, `hibernate at ${s.nearlyEmptyPercent}%`, "nothing"], unavailable: s => s.hibernatePossible ? [] : [`hibernate at ${s.nearlyEmptyPercent}%`], state: s => s.hibernatePossible ? "" : "hibernate needs swap and a resume setup", why: "What happens when the battery is nearly empty. It warns first, then acts.", kw: "low battery" }
            ] }
        ]
    },
    powermode: {
        id: "powermode", name: "Power and lid", lidless: "Power", icon: "bolt", preview: "battery",
        status: s => s.hasLid ? `${s.v("profile")} · lid ${optionLabel(ROW_BY_KEY.lidBattery, s, s.v("lidBattery"))}` : s.v("profile"),
        groups: [
            { rows: [
                { n: 105, icon: "bolt", label: "Power mode", k: "profile", kind: "seg", o: s => s.profileChoices, state: s => s.profileTrouble, dis: s => s.profileChoices.length === 0, kw: "power profile performance" }
            ] },
            { t: "Lid", away: s => !s.hasLid, rows: [
                { n: 108, icon: "laptop", label: "On battery", k: "lidBattery", kind: "choice", cfg: "power.lid.onBattery", o: [["suspend", "sleep"], "hibernate", "lock", "nothing"], unavailable: s => s.hibernatePossible ? [] : ["hibernate"], state: s => s.hibernatePossible ? "" : "hibernate needs swap and a resume setup", kw: "lid close action sleep suspend" },
                { n: 108, icon: "power", label: "Plugged in", k: "lidPlugged", kind: "choice", cfg: "power.lid.pluggedIn", o: [["suspend", "sleep"], "lock", "nothing"], kw: "lid close action sleep suspend" },
                { n: 108, icon: "monitor", label: "With screens attached", k: "lidDocked", kind: "choice", cfg: "power.lid.docked", o: ["nothing", "lock", ["suspend", "sleep"]], kw: "lid close action docked sleep suspend" }
            ] }
        ]
    },
    lock: {
        id: "lock", name: "Lock and idle", icon: "lock", preview: "lock",
        status: s => s.idleHandled ? `${s.idleHandler} sets the timing` : s.v("idleLock") === "never" ? "never locks by itself" : `locks after ${s.v("idleLock")}`,
        groups: [
            { t: "Lock screen", rows: [
                { n: 90, icon: "blur_on", label: "Blur", k: "lockBlur", kind: "slider", min: 0, max: 1, step: 0.05, fmt: pct, cfg: "lock.blur", kw: "lock screen look" },
                { n: 90, icon: "brightness_4", label: "Dim", k: "lockDim", kind: "slider", min: 0, max: 1, step: 0.05, fmt: pct, cfg: "lock.dim", kw: "lock screen look" },
                { n: 90, icon: "filter_b_and_w", label: "Drain colour", k: "lockDesat", kind: "slider", min: 0, max: 1, step: 0.05, fmt: pct, cfg: "lock.desaturate", kw: "lock screen look" },
                { n: 90, icon: "lock", label: "Try it", kind: "button", btn: "Lock", act: "lockNow", why: "Locks the screen now. Your password brings you back." }
            ] },
            { t: "When idle", rows: [
                { n: 91, kind: "fact", text: s => idleNote(s) },
                { n: 91, icon: "lock_clock", label: "Lock after", k: "idleLock", kind: "choice", o: ["1 min", "5 min", "15 min", "never"], cfg: "idle.lock", held: s => idleHeld(s, "lock"), kw: "auto-lock idle" },
                { n: 91, icon: "monitor", label: "Screens off after", k: "idleOff", kind: "choice", o: ["5 min", "10 min", "30 min", "never"], cfg: "idle.screensOff", held: s => idleHeld(s, "screensOff"), why: "A playing video holds it off.", kw: "screen-off idle" },
                { n: 91, icon: "bedtime", label: "Sleep after", k: "idleSuspend", kind: "choice", o: ["15 min", "30 min", "1 h", "never"], cfg: "idle.sleep", held: s => idleHeld(s, "sleep"), why: "On a laptop it only counts on battery.", kw: "suspend idle" }
            ] }
        ]
    },
    defaults: {
        id: "defaults", name: "Default apps", icon: "open_in_new", preview: "defaults",
        status: s => `${s.defaultName("defBrowser")} · ${s.defaultName("defTerm")}`,
        groups: [
            { rows: [
                { n: 111, icon: "public", label: "Web", k: "defBrowser", kind: "choice", o: s => s.appsFor("defBrowser"), state: s => s.defaultNote("defBrowser"), kw: "default apps browser" },
                { n: 111, icon: "folder", label: "Files", k: "defFiles", kind: "choice", o: s => s.appsFor("defFiles"), state: s => s.defaultNote("defFiles"), kw: "default apps" },
                { n: 111, icon: "terminal", label: "Terminal", k: "defTerm", kind: "choice", o: s => s.appsFor("defTerm"), state: s => s.defaultNote("defTerm"), kw: "default apps" },
                { n: 111, icon: "mail", label: "Mail", k: "defMail", kind: "choice", o: s => s.appsFor("defMail"), state: s => s.defaultNote("defMail"), kw: "default apps" },
                { n: 111, icon: "image", label: "Pictures", k: "defImages", kind: "choice", o: s => s.appsFor("defImages"), state: s => s.defaultNote("defImages"), kw: "default apps" },
                { n: 111, icon: "movie", label: "Video", k: "defVideo", kind: "choice", o: s => s.appsFor("defVideo"), state: s => s.defaultNote("defVideo"), kw: "default apps" }
            ] }
        ]
    },
    startup: {
        id: "startup", name: "Startup apps", icon: "login", preview: "signin",
        status: s => `${s.startupOn} app${s.startupOn === 1 ? "" : "s"}`,
        groups: [
            { rows: [
                { n: 112, kind: "w", w: "startup", kw: "startup apps autostart boot login sign-in" }
            ] }
        ]
    },
    files: {
        id: "files", name: "Files", icon: "folder", preview: "files",
        status: s => `${s.v("filesView")} · ${filesSortOrder(s.v("filesSort"), s.v("filesReversed"))}${s.v("filesHidden") ? " · hidden shown" : ""}`,
        groups: [
            { rows: [
                { n: 92, icon: "view_module", label: "View", k: "filesView", kind: "seg", o: ["icons", "list"], cfg: "files.view", kw: "files app view" },
                { n: 92, icon: "sort", label: "Sort by", k: "filesSort", kind: "seg", o: FILES_SORTS, cfg: "files.sort", kw: "files sort date newest oldest size biggest name type" },
                { n: 92, icon: "swap_vert", label: "Order", k: "filesReversed", kind: "seg", o: s => filesOrders(s.v("filesSort")), cfg: "files.reversed", kw: "files sort order direction reverse oldest smallest z to a" },
                { n: 92, icon: "visibility_off", label: "Hidden files", k: "filesHidden", kind: "toggle", cfg: "files.hidden", keys: "files:hidden", kw: "files hidden" },
                { n: 92, icon: "markdown", label: "Markdown", k: "filesMarkdown", kind: "seg", o: [["rendered", "rendered"], ["raw", "source"]], cfg: "files.markdown", kw: "files previews" },
                { n: 92, icon: "zoom_in", label: "Zoom", k: "filesZoom", kind: "slider", min: 0.6, max: 2, step: 0.1, fmt: v => `${v.toFixed(1)}×`, cfg: "files.zoom", kw: "files previews" }
            ] }
        ]
    },
    terminal: {
        id: "terminal", name: "Terminal", icon: "terminal", preview: "terminal",
        status: s => `inside files · ${s.v("termColours")}`,
        groups: [
            { rows: [
                { n: [], kind: "fact", text: "BanditShell leaves your own terminal alone. These only shape the small terminal inside Files. Which terminal opens everywhere else is under Default apps." }
            ] },
            { rows: [
                { n: 93, icon: "font_download", label: "Font", k: "termFont", kind: "choice", o: s => s.monoFonts, cfg: "files.terminal.font", kw: "files terminal font" },
                { n: 93, icon: "table_rows", label: "Rows", k: "termRows", kind: "step", min: 6, max: 40, cfg: "files.terminal.rows", fmt: v => `${v}`, kw: "files terminal size" },
                { n: 93, icon: "vertical_align_top", label: "Scrollback", k: "termScroll", kind: "step", min: 1000, max: 50000, step: 1000, cfg: "files.terminal.scrollback", fmt: v => `${v}`, kw: "files terminal scrollback" },
                { n: 93, icon: "format_paint", label: "Colours", k: "termColours", kind: "seg", o: ["one dark", "theme"], cfg: "files.terminal.palette", kw: "files terminal colours" }
            ] }
        ]
    },
    capture: {
        id: "capture", name: "Capture", icon: "screenshot_region", preview: "capture",
        status: s => s.v("stream") ? "streaming" : s.v("shotEditor"),
        groups: [
            { t: "Screenshots", rows: [
                { n: 89, icon: "folder", label: "Saved to", k: "shotDir", kind: "path", cfg: "picker.dir", kw: "screenshots folder" },
                { n: 89, icon: "edit", label: "Edit with", k: "shotEditor", kind: "text", mono: true, cfg: "picker.editor", placeholder: "just save it", kw: "screenshots editor" },
                { n: 89, icon: "highlight_alt", label: "Outline", k: "outline", kind: "step", min: 0, max: 6, unit: " px", cfg: "picker.outline", why: "A line around the selection. 0 draws none.", kw: "screenshots outline" }
            ] },
            { t: "Streaming", rows: [
                { n: 95, icon: "cast", label: "Streamer mode", k: "stream", kind: "toggle", cfg: "stream.enabled", why: "Hides names, passwords and previews while you stream.", layer: [
                    { n: 95, icon: "monitor", label: "Band on", k: "streamScreen", kind: "choice", o: s => s.monitorNames, cfg: "stream.screen" },
                    { n: 95, icon: "height", label: "Band height", k: "streamHeight", kind: "slider", min: 200, max: 600, step: 20, fmt: v => `${v} px`, cfg: "stream.height" }
                ] },
                { n: 96, kind: "w", w: "obs", kw: "obs connection websocket" }
            ] }
        ]
    },
    region: {
        id: "region", name: "Language", icon: "language", preview: "region",
        status: s => `${s.languageLabel} · ${s.formatsLabel}`,
        groups: [
            { t: "Time", rows: [
                { n: 109, icon: "schedule", label: "24-hour clock", k: "clock24", kind: "toggle", cfg: "region.clock24", state: s => s.timeExample, kw: "time format" },
                { n: 109, icon: "calendar_today", label: "Dates", k: "dateFormat", kind: "choice", o: s => s.dateChoices, cfg: "region.dateFormat", kw: "date format" },
                { n: 109, icon: "my_location", label: "Zone from network", k: "autoZone", kind: "toggle", cfg: "region.autoZone", state: s => s.autoZoneDetail, kw: "time zone",
                    why: "Picks the zone nearest to where geoclue says you are when you turn this on, and sets it with timedatectl. After that it only looks again when the network changes, and suggests the new zone under Zone for you to pick; it never asks for your password on its own. It needs geoclue installed." },
                { n: 109, icon: "public", label: "Zone", k: "zone", kind: "choice", o: s => s.zoneChoices, dis: s => s.v("autoZone") && !s.zoneSuggested, state: s => s.zoneSuggested ? `the network puts you in ${s.zoneSuggested} · pick it to switch` : s.v("autoZone") ? "set from the network" : "password needed", kw: "time zone",
                    why: "Sets the system's time zone with timedatectl, which asks for your password. The shell's clocks follow it straight away." }
            ] },
            { t: "Language", rows: [
                { n: 110, icon: "translate", label: "Language", k: "lang", kind: "choice", o: s => s.languageChoices, kw: "language",
                    why: "Sets the system language with localectl, which asks for your password. It takes effect at next sign-in. The shell's own text stays English." },
                { n: 110, icon: "payments", label: "Formats", k: "region", kind: "choice", o: s => s.formatChoices, state: s => s.moneyExample, kw: "region numbers currency",
                    why: "Numbers, money, units and paper size, set with localectl, which asks for your password. They take effect at next sign-in." }
            ] }
        ]
    },
    access: {
        id: "access", name: "Accessibility", icon: "accessibility_new", preview: "chassis",
        status: s => [s.v("reduceMotion") && "less motion", s.v("largerText") && "larger text", s.v("contrast") && "more contrast"].filter(Boolean).join(" · ") || "nothing on",
        groups: [
            { rows: [
                { n: 113, icon: "animation", label: "Less motion", k: "reduceMotion", kind: "toggle", cfg: "access.lessMotion", why: "Turns off every animation. No motion at all.", kw: "accessibility reduce motion" },
                { n: 113, icon: "format_size", label: "Larger text", k: "largerText", kind: "toggle", cfg: "access.largerText", why: "Raises the base text size, so every size steps up.", kw: "accessibility larger text" },
                { n: 113, icon: "contrast", label: "More contrast", k: "contrast", kind: "toggle", cfg: "access.moreContrast", why: "Faint text gets brighter.", kw: "accessibility contrast" }
            ] }
        ]
    },
    updates: {
        id: "updates", name: "Updates", icon: "system_update_alt", preview: "about",
        status: s => s.updateStatus,
        groups: [
            { rows: [
                { n: 114, kind: "w", w: "update", kw: "updates check download restart" },
                { n: 114, icon: "alt_route", label: "Branch", k: "branch", kind: "choice", o: s => s.branches, cfg: "updates.branch", kw: "updates branch" },
                { n: 114, icon: "cloud", label: "Remote", k: "remote", kind: "text", mono: true, cfg: "updates.remote", kw: "updates remote" },
                { n: 114, icon: "update", label: "Look every", k: "updEvery", kind: "step", min: 5, max: 240, step: 5, unit: " min", cfg: "updates.interval", kw: "updates interval" }
            ] },
            { t: "The system", rows: [
                { n: [], icon: "memory", label: "New kernel", k: "kernelEvery", kind: "step", min: 0, max: 1440, step: 60, unit: " min", cfg: "packages.interval", state: s => s.v("kernelEvery") ? "the island says when Linux updates" : "never looks", kw: "kernel linux update pacman checkupdates system",
                    why: "Asks pacman what is waiting (checkupdates, from pacman-contrib) and tells you in the island when the kernel is in the list. Pressing it runs the command below in a terminal, and once the kernel is replaced the island says it wants a restart." },
                { n: [], icon: "terminal", label: "Update with", k: "upgradeCmd", kind: "text", mono: true, cfg: "packages.upgrade", kw: "system update command pacman yay paru" }
            ] }
        ]
    },
    shell: {
        id: "shell", name: "Shell", icon: "terminal", preview: "about",
        status: s => `${s.changeCount} recent changes`,
        groups: [
            { t: "Behaviour", rows: [
                { n: 115, icon: "keyboard_tab", label: "Tab completion", k: "tabComplete", kind: "toggle", why: "Tab completion for the shell’s cli." },
                { n: 116, icon: "edit_document", label: "Edit Hyprland files", k: "sourceEdits", kind: "toggle", cfg: "sourceEdits.acknowledged", state: s => s.v("sourceEdits") ? "only its own include" : "hands off", kw: "permission to edit hyprland files",
                    why: "The shell writes borders, screen layout and binds into one file it owns. Your own Hyprland files are never touched." },
                { n: [], icon: "password", label: "Ask for passwords", k: "polkitAgent", kind: "toggle", cfg: "polkit.agent", state: s => s.polkitNote, kw: "polkit password prompt authentication agent pkexec admin",
                    why: "When a program needs your password to run as admin, the shell asks in its own card. Only one program can do this at a time, so another password agent that is running, such as hyprpolkitagent, is stopped." }
            ] },
            { t: "Recent changes", rows: [
                { n: [], kind: "w", w: "recent", kw: "recent changes undo history" }
            ] },
            { t: "Do it now", rows: [
                { n: 117, icon: "refresh", label: "Reload the shell", kind: "button", btn: "Reload", act: "reload", kw: "shell actions" },
                { n: 117, icon: "rule", label: "Window rules", kind: "button", btn: "Reload", act: "rules", kw: "shell actions window rules" },
                { n: 117, icon: "sync", label: "Read Hyprland again", kind: "button", btn: "Read", act: "reread", kw: "shell actions re-read compositor" }
            ] },
            { t: "Keep a copy", rows: [
                { n: [], icon: "upload", label: "Export settings", kind: "button", btn: "Export", act: "exportCfg", why: "Saves config.json and your lists to a file.", kw: "backup export" },
                { n: [], icon: "download", label: "Restore from a file", kind: "button", btn: "Restore", act: "importCfg", why: "Reads a saved file and shows what changes first.", kw: "backup import restore" }
            ] },
            { t: "Where things live", rows: [
                { n: 118, icon: "settings", label: "Config", k: "cfgPath", kind: "path", ro: true, kw: "config file" },
                { n: 118, icon: "folder_data", label: "State", k: "statePath", kind: "path", ro: true, kw: "state folder" }
            ] }
        ]
    },
    about: {
        id: "about", name: "About", icon: "info", preview: "about",
        status: s => `BanditShell ${s.version}`,
        groups: [
            { rows: [
                { n: 119, kind: "w", w: "changes", kw: "what’s new changelog" },
                { n: [120, 121], kind: "w", w: "about", kw: "device info about version compositor source design notes" }
            ] },
            { t: "New here", rows: [
                { n: [], icon: "tour", label: "The tour", kind: "button", btn: "Show", act: "tour", why: "A few short steps over your own desktop: the launcher, the island, the rail, the hotkey sheet and Settings, each opened for real.", kw: "tour welcome guide introduction onboarding first run help start" }
            ] }
        ]
    }
};

const CATS = [
    { id: "connections", name: "Connections", icon: "wifi",
        blurb: s => [s.networkMissing || (s.v("wifi") && s.wifiNet ? s.wifiNet : s.v("hotspot") ? "hotspot on" : "wi-fi off"), s.v("bt") ? `${s.btConnected.length} devices` : "bluetooth off", s.vpnOn ? "vpn on" : ""].filter(Boolean).join(" · "),
        tiles: [
            { k: "wifi", icon: "wifi", label: "Wi-Fi", explains: true, det: s => s.networkMissing || (s.v("wifi") ? s.wifiState : "off"), dis: s => s.networkMissing !== "" },
            { k: "bt", icon: "bluetooth", label: "Bluetooth", det: s => s.v("bt") ? "on" : "off" },
            { k: "hotspot", icon: "wifi_tethering", label: "Hotspot", explains: true, det: s => s.hotspotStatus || "off", dis: s => s.hotspotBlocked },
            { k: "vpnFirst", icon: "vpn_lock", label: "VPN", explains: true, det: s => s.vpnOn || (s.networkMissing ? "needs NetworkManager" : s.tunnelCount ? "off" : "no tunnels"), dis: s => !s.tunnelCount }
        ],
        notice: s => s.networkMissing ? "networkManager" : "",
        suggest: s => s.v("bt") && s.btNear > 0 ? { icon: "bluetooth_searching", label: `${s.btNear} devices nearby`, detail: "ready to pair", go: "bluetooth" } : null,
        subs: ["wifi", "bluetooth", "wired", "vpn"] },
    { id: "sound", name: "Sound", icon: "volume_up",
        blurb: s => (s.v("muted") ? "muted" : `${s.outputName} · ${Math.round(s.v("volume") * 100)}%`) + ` · popups ${s.v("notifTimeout")} s`,
        tiles: [
            { k: "muted", icon: "volume_off", label: "Mute" },
            { k: "overAmp", icon: "campaign", label: "Past 100%" },
            { k: "alerts", icon: "notifications_active", label: "Alert sounds" }
        ],
        suggest: s => s.v("overAmp") && s.v("volume") > 1 ? { icon: "campaign", label: "Volume is past 100%", detail: "some sources may crackle", go: "output" } : null,
        subs: ["output", "mic", "mixer", "notifications", "alerts"] },
    { id: "display", name: "Display", icon: "desktop_windows",
        blurb: s => `${s.screensOn.length} screens · ${Math.round(s.v("level"))}%${s.v("warmth") ? " · warm" : ""}`,
        tiles: [
            { k: "warm", icon: "nightlight", label: "Warmth", det: s => kelvin(s, s.v("warmth")) },
            { k: "scr:vrr", icon: "motion_photos_auto", label: "Variable refresh", det: s => s.selMon }
        ],
        suggest: s => !s.v("warmth") && s.v("nightSched") === "off" ? { icon: "nightlight", label: "Warm the screens at night", detail: "sunset to sunrise", set: ["nightSched", "sunset"] } : null,
        subs: ["screens", "light"] },
    { id: "look", name: "Look", icon: "palette",
        blurb: s => `${s.v("fromWall") ? "from the wallpaper" : s.v("theme")} · ${s.wallName.toLowerCase()}`,
        tiles: [
            { k: "fromWall", icon: "colorize", label: "From wallpaper" },
            { k: "follow", icon: "sync_alt", label: "Follow Hyprland" },
            { k: "bare", icon: "crop_free", label: "Bare" }
        ],
        suggest: s => !s.v("fromWall") ? { icon: "colorize", label: "Take colours from the wallpaper", detail: s.wallName.toLowerCase(), set: ["fromWall", true] } : null,
        subs: ["colour", "wallpaper", "type", "shape"] },
    { id: "desktop", name: "Desktop", icon: "space_dashboard", preview: "desktop",
        blurb: s => `${s.v("wsStyle")} workspaces · ${s.v("dropMode")} on drop`,
        tiles: [
            { k: "sidebar", icon: "side_navigation", label: "Sidebar" },
            { k: "tray", icon: "apps", label: "Tray" },
            { k: "clip", icon: "content_paste", label: "Clipboard" },
            { k: "edgeLift", icon: "vertical_align_top", label: "Edge lift" }
        ],
        suggest: () => null,
        subs: ["sidebar", "windows", "launcher", "clipboard"] },
    { id: "focus", name: "Focus", icon: "self_improvement",
        blurb: s => s.v("mode") !== "none" ? `${s.v("mode")} mode · cap ${s.v("capHours")} h` : s.v("dnd") ? "do not disturb" : `no mode · cap ${s.v("capHours")} h`,
        tiles: [
            { k: "dnd", icon: "do_not_disturb_on", label: "Do not disturb" },
            { k: "dndNightly", icon: "bedtime", label: "Every night" },
            { k: "breaks", icon: "self_improvement", label: "Breaks", det: s => s.v("breaks") ? `every ${s.v("breakEvery")} min` : "off" }
        ],
        suggest: s => !s.v("dndNightly") ? { icon: "bedtime", label: "Go quiet every night", detail: s.nightWindow, set: ["dndNightly", true] } : null,
        subs: ["modes", "clock", "screentime"] },
    { id: "input", name: "Input", icon: "keyboard",
        blurb: s => `${s.kbLayouts.map(l => l.code).join(" · ")} · ${s.v("pen") ? "pen on" : "pen off"}`,
        tiles: [
            { k: "naturalScroll", icon: "swipe_vertical", label: "Natural scroll" },
            { k: "tapClick", icon: "touch_app", label: "Tap to click" },
            { k: "pen", icon: "stylus", label: "Pen" },
            { k: "autoKeyboard", icon: "keyboard_hide", label: "Keyboard on fold" }
        ],
        suggest: () => null,
        subs: ["keyboard", "shortcuts", "pointer", "tablet", "pen"] },
    { id: "power", name: "Power", icon: "battery_5_bar",
        blurb: s => s.hasBattery ? `${s.batteryPct}% · ${s.v("profile")}${s.v("chargeLimit") && !s.chargeTrouble ? ` · held at ${s.v("chargeMax")}%` : ""}` : `on mains · ${s.v("profile")}`,
        tiles: [
            { k: "chargeLimit", icon: "battery_charging_80", label: "Hold charge", away: s => !s.hasBattery, dis: s => !s.hasBattery || !s.chargeSupported, det: s => !s.hasBattery ? "no battery" : s.v("chargeLimit") ? `${s.v("chargeMax")}%` : "off" },
            { k: "saver", icon: "eco", label: "Saver", dis: s => s.profileChoices.length === 0, det: s => s.v("profile") === "saver" ? "on" : "off" }
        ],
        suggest: s => s.hasBattery && !s.v("chargeLimit") && s.healthKnown ? { icon: "health_and_safety", label: `Health is at ${s.healthPct}%`, detail: "holding the charge at 80% slows that", set: ["chargeLimit", true] } : null,
        subs: ["battery", "powermode", "lock"] },
    { id: "apps", name: "Apps", icon: "apps",
        blurb: s => `${s.defaultName("defBrowser")} · ${s.defaultName("defTerm")} · ${s.startupOn} at startup`,
        tiles: [
            { k: "stream", icon: "cast", label: "Streamer mode" },
            { k: "filesHidden", icon: "visibility_off", label: "Hidden files" }
        ],
        suggest: s => !s.clipseImported && s.clipseWaiting > 0 ? { icon: "move_to_inbox", label: "Bring clipse’s history over", detail: `${s.clipseWaiting} entries waiting`, go: "clipboard" } : null,
        subs: ["defaults", "startup", "files", "terminal", "capture"] },
    { id: "system", name: "System", icon: "settings",
        blurb: s => `${s.version} · ${s.languageLabel}`,
        tiles: [
            { k: "reduceMotion", icon: "animation", label: "Less motion" },
            { k: "largerText", icon: "format_size", label: "Larger text" },
            { k: "contrast", icon: "contrast", label: "More contrast" }
        ],
        suggest: s => s.updateReady ? { icon: "system_update_alt", label: s.updateHeadline, detail: s.updateDetail, go: "updates" } : null,
        subs: ["region", "access", "updates", "shell", "about"] }
];

const PAGES = [];
const PAGE_BY_ID = {};
const ROWS = [];
const ROW_BY_KEY = {};

function idleNote(s) {
    if (!s.idleHandled)
        return "";
    if (!s.idleRead)
        return `${s.idleHandler} sets these times.`;
    const read = s.idleTimes && Object.keys(s.idleTimes).some(k => s.idleTimes[k] !== null);
    return read ? `${s.idleHandler} sets these times. Change them in its config.` : `${s.idleHandler} sets these times. The shell cannot read them, so they are not shown.`;
}

function idleHeld(s, role) {
    if (!s.idleHandled)
        return null;
    return s.idleTime(role) || (s.idleRead ? "not shown" : "");
}

function placeOffer(s) {
    if (s.weatherPlaceTrouble === "")
        return null;
    const typed = String(s.v("weatherPlace") ?? "");
    if (!typed)
        return { text: "The weather service could not find your connection's location.", alarm: true, buttons: [] };
    const guess = s.weatherSuggestion;
    if (guess)
        return { text: `No place called "${typed}". Did you mean ${guess.text}?`, alarm: true, buttons: [[`Use ${guess.text}`, guess.text]] };
    return { text: `No place called "${typed}". Fix the spelling, or:`, alarm: true, buttons: [["Use my connection's location", ""]] };
}

function walk(rows, page, group, parent, out) {
    for (const r of rows) {
        r.page = page.id;
        r.group = group;
        r.parent = parent;
        r.uid = `${page.id}.${out.length}`;
        out.push(r);
        if (r.k && !ROW_BY_KEY[r.k])
            ROW_BY_KEY[r.k] = r;
        if (r.layer)
            walk(r.layer, page, group, r, out);
    }
}

for (const c of CATS) {
    c.pages = c.subs.map(id => {
        const p = PAGES_SOURCE[id];
        p.cat = c.id;
        p.preview = p.preview || c.preview;
        return p;
    });
    if (!c.preview)
        c.preview = c.pages[0].preview;
    for (const p of c.pages) {
        PAGES.push(p);
        PAGE_BY_ID[p.id] = p;
        for (const g of p.groups)
            walk(g.rows, p, g, null, ROWS);
        p.resets = ROWS.some(r => r.page === p.id && resettable(r));
    }
}

for (const g of PAGE_BY_ID.battery.groups)
    for (const r of g.rows) {
        const own = r.dis;
        r.dis = st => !st.hasBattery || !!(own && own(st));
    }

const CAT_BY_ID = {};
for (const c of CATS)
    CAT_BY_ID[c.id] = c;

function val(x, s) {
    return typeof x === "function" ? x(s) : x;
}

function pair(x) {
    return x !== null && typeof x === "object" && typeof x.length === "number";
}

function options(row, s) {
    const list = val(row.o, s) || [];
    const out = [];
    for (let i = 0; i < list.length; i++) {
        const x = list[i];
        out.push(pair(x) ? [x[0], x[1]] : [x, x]);
    }
    return out;
}

function same(a, b) {
    return String(a) === String(b);
}

function resettable(row) {
    return !!row?.k && !!row.cfg && !row.ro && !row.k.startsWith("scr:") && row.kind !== "secret" && row.kind !== "button";
}

function changed(value, fallback) {
    if (value === undefined || fallback === undefined)
        return false;
    if (typeof value === "number" && typeof fallback === "number")
        return Math.abs(value - fallback) > 1e-6;
    if (typeof value === "object" || typeof fallback === "object")
        return JSON.stringify(value) !== JSON.stringify(fallback);
    return !same(value, fallback);
}

function optionLabel(row, s, v) {
    const hit = options(row, s).find(o => same(o[0], v));
    return hit ? hit[1] : v;
}

function format(row, v, s) {
    if (row.fmtS)
        return row.fmtS(s, v);
    if (row.fmt)
        return row.fmt(v);
    return `${v}${row.unit === undefined ? "" : row.unit}`;
}

function show(row, v, s) {
    if (row.kind === "toggle")
        return v ? "on" : "off";
    if (row.o)
        return String(optionLabel(row, s, v));
    return format(row, v, s);
}

function seeThrough(alpha) {
    return Math.round((1 - alpha) * 1000) / 1000;
}

function loggedSeeThrough(v) {
    return typeof v === "number" && v > 0.5 ? seeThrough(v) : v;
}

function filesFoldersNote(sort) {
    return sort === "size" ? "folders by name" : "folders on top";
}

function filesOrders(sort) {
    const words = FILES_ORDERS[sort] ?? FILES_ORDERS.name;
    return [[false, words[0]], [true, words[1]]];
}

function filesSortOrder(v, reversed) {
    if (!FILES_ORDERS[v])
        return `by ${v}`;
    const word = FILES_ORDERS[v][reversed ? 1 : 0];
    return v === "name" ? word : v === "kind" ? `types ${word}` : `${word} first`;
}

function labelOf(row) {
    if (typeof row.label === "string")
        return row.label;
    if (row.kind === "w")
        return WIDGET_TITLES[row.w] || "";
    return "";
}

function present(item, s) {
    return !item || typeof item.away !== "function" || !item.away(s);
}

function nameOf(page, s) {
    return page && page.lidless && !s.hasLid ? page.lidless : page ? page.name : "";
}

function whyOf(row, s) {
    return row.why || (row.kind === "w" ? WIDGET_WHY[row.w] || "" : "") || "";
}

function numbers(row) {
    return [].concat(row.n === undefined ? [] : row.n);
}

const INDEX = [];

for (const p of PAGES) {
    const visit = (rows, g) => {
        for (const r of rows) {
            const label = typeof r.label === "string" ? r.label : r.kind === "w" ? SEARCH_TITLES[r.w] || "" : "";
            if (label || r.kw)
                INDEX.push({
                    row: r,
                    page: p,
                    group: g,
                    label: label || r.kw.split(" ")[0],
                    nums: numbers(r),
                    hay: `${label} ${r.kw || ""} ${typeof g.t === "string" ? g.t : ""} ${r.cfg || ""} ${p.name}`.toLowerCase(),
                    flat: ` ${label} ${r.kw || ""} `.toLowerCase().replace(/[^a-z0-9\s]/g, "").replace(/\s+/g, " ")
                });
            if (r.layer)
                visit(r.layer, g);
        }
    };
    for (const g of p.groups)
        visit(g.rows, g);
}

function search(query) {
    const q = String(query || "").trim().toLowerCase();
    if (!q)
        return [];
    const num = /^#?(\d{1,3})$/.exec(q);
    let hits;
    if (num)
        hits = INDEX.filter(x => x.nums.indexOf(+num[1]) >= 0);
    else {
        const words = q.split(/\s+/).filter(w => /[a-z0-9]/.test(w));
        const flat = w => w.replace(/[^a-z0-9]+/g, " ").trim();
        hits = words.length ? INDEX.filter(x => words.every(w => x.hay.indexOf(w) >= 0 || x.flat.indexOf(flat(w)) >= 0)) : [];
        const lead = x => x.label.toLowerCase().indexOf(q) === 0 ? 1 : 0;
        hits = hits.map((x, i) => ({ x: x, i: i })).sort((a, b) => lead(b.x) - lead(a.x) || a.i - b.i).map(e => e.x);
    }
    return hits.filter((x, i, a) => a.findIndex(y => y.label === x.label && y.page === x.page && y.group === x.group && y.row.parent === x.row.parent) === i).slice(0, 12);
}

const PROPER_WORDS = ["Bluetooth", "Ethernet", "Wikipedia", "Wiktionary"];

function inSentence(label) {
    const first = label.split(" ")[0];
    return /^[A-Z][a-z’'-]*$/.test(first) && PROPER_WORDS.indexOf(first) < 0 ? label.charAt(0).toLowerCase() + label.slice(1) : label;
}

function hitTitle(hit, s) {
    const g = hit.group;
    const context = (hit.row.parent && labelOf(hit.row.parent)) || (typeof g.t === "string" && g.t) || g.topic || nameOf(hit.page, s);
    if (!context || ` ${hit.label.toLowerCase()} `.indexOf(` ${context.toLowerCase()} `) >= 0)
        return hit.label;
    return `${context}: ${inSentence(hit.label)}`;
}

function queryWords(query) {
    const q = String(query || "").trim().toLowerCase();
    return /^#?\d{1,3}$/.test(q) ? [] : q.split(/\s+/).filter(Boolean);
}

function hitWhy(hit, query, shown) {
    const seen = String(shown).toLowerCase();
    const pool = `${hit.row.kw || ""} ${hit.row.cfg || ""} ${typeof hit.group.t === "string" ? hit.group.t : ""}`.split(/\s+/).filter(Boolean);
    const out = [];
    for (const w of queryWords(query)) {
        if (seen.indexOf(w) >= 0)
            continue;
        const word = pool.find(t => t.toLowerCase().indexOf(w) >= 0);
        if (word && out.indexOf(word) < 0)
            out.push(word);
    }
    return out.join(" ");
}

function escaped(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function marked(text, query, colour) {
    const t = String(text);
    const low = t.toLowerCase();
    if (low.length !== t.length)
        return escaped(t);
    const on = [];
    for (let i = 0; i < t.length; i++)
        on.push(false);
    for (const w of queryWords(query))
        for (let i = low.indexOf(w); i >= 0; i = low.indexOf(w, i + 1))
            for (let j = i; j < i + w.length; j++)
                on[j] = true;
    let out = "";
    let i = 0;
    while (i < t.length) {
        let j = i;
        while (j < t.length && on[j] === on[i])
            j++;
        const part = escaped(t.slice(i, j));
        out += on[i] ? `<font color="${colour}">${part}</font>` : part;
        i = j;
    }
    return out;
}

function hitIndexOf(hits, openUid) {
    return Math.max(0, hits.findIndex(h => h.row.uid === openUid));
}

function hitIsOpen(hits, index, openUid, currentPage) {
    const h = hits[index];
    return !!h && h.row.uid === openUid && h.page.id === currentPage;
}

function hitToOpen(hits, index, openUid, currentPage, back) {
    if (!hitIsOpen(hits, index, openUid, currentPage) || hits.length < 2)
        return index;
    return (index + (back ? hits.length - 1 : 1)) % hits.length;
}

const ALIASES = {
    network: "wifi", ethernet: "wired", hotspot: "vpn", sound: "output", audio: "output", microphone: "mic", monitors: "screens", display: "screens",
    brightness: "light", theme: "colour", font: "type", appearance: "colour", general: "windows", keybinds: "shortcuts", hotkeys: "shortcuts",
    device: "about", developer: "shell", cli: "shell", power: "powermode", idle: "lock", language: "region"
};

function everyHit() {
    return INDEX;
}

function hitFor(pageId, key) {
    return INDEX.find(x => x.page.id === pageId && (x.row.k ?? x.label) === key) || null;
}

function resolve(name) {
    const key = String(name || "");
    if (CAT_BY_ID[key])
        return { cat: key, page: "", row: null };
    if (PAGE_BY_ID[key])
        return { cat: PAGE_BY_ID[key].cat, page: key, row: null };
    const alias = ALIASES[key];
    if (alias)
        return resolve(alias);
    const row = ROW_BY_KEY[key] || ROWS.find(r => r.cfg === key);
    if (row)
        return { cat: PAGE_BY_ID[row.page].cat, page: row.page, row: row };
    return null;
}


function pagesCovered(page) {
    const rows = [];
    const visit = list => {
        for (const r of list) {
            rows.push(r);
            if (r.layer)
                visit(r.layer);
        }
    };
    for (const g of page.groups)
        visit(g.rows);
    const nums = new Set();
    for (const r of rows)
        for (const n of numbers(r))
            nums.add(n);
    return { settings: nums.size };
}

function rowCount(cat) {
    let n = 0;
    for (const p of cat.pages)
        for (const g of p.groups)
            n += g.notice ? 0 : g.rows.length;
    return n;
}

function step(row, v, delta) {
    const s = row.step === undefined ? 1 : row.step;
    return Math.min(row.max, Math.max(row.min, +(v + s * delta).toFixed(4)));
}

function nearest(row, v) {
    const s = row.step === undefined ? 1 : row.step;
    const n = Math.round((v - row.min) / s) * s + row.min;
    return Math.min(row.max, Math.max(row.min, +n.toFixed(4)));
}

function dwindleRects(n) {
    const out = [{ x: 0, y: 0, w: 100, h: 100 }];
    for (let i = 1; i < n; i++) {
        const r = out[i - 1];
        const vertical = i % 2 === 1;
        const g = 2;
        const a = vertical ? { x: r.x, y: r.y, w: r.w / 2 - g / 2, h: r.h } : { x: r.x, y: r.y, w: r.w, h: r.h / 2 - g / 2 };
        const b = vertical ? { x: r.x + r.w / 2 + g / 2, y: r.y, w: r.w / 2 - g / 2, h: r.h } : { x: r.x, y: r.y + r.h / 2 + g / 2, w: r.w, h: r.h / 2 - g / 2 };
        out[i - 1] = a;
        out.push(b);
    }
    return out;
}

const RAIL_LETTERS = "#abcdefghijklmnopqrstuvwxyz".split("");
const THUMB_PATH = [[null, 0, 700], ["a", 220, 600], ["d", 260, 550], ["f", 200, 650], ["k", 300, 550], ["o", 260, 500], ["s", 260, 650], [null, 0, 900]];

function alphabetThumbAt(ms) {
    const total = THUMB_PATH.reduce((a, p) => a + p[1] + p[2], 0);
    let t = ms % total;
    let prev = RAIL_LETTERS.indexOf("a");
    const ease = x => x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
    for (const p of THUMB_PATH) {
        const to = p[0] ? RAIL_LETTERS.indexOf(p[0]) : null;
        if (t < p[1])
            return to === null ? null : prev + (to - prev) * ease(t / p[1]);
        t -= p[1];
        if (t < p[2])
            return to;
        t -= p[2];
        if (to !== null)
            prev = to;
    }
    return null;
}

function bowAt(index, pos, bow, spread) {
    if (pos === null)
        return 0;
    const d = Math.abs(index - pos);
    return d < spread ? Math.pow(Math.cos(Math.PI / 2 * d / spread), 2) : 0;
}

const CLIP_POOL = ["git push --force-with-lease", "https://wiki.hypr.land/Configuring/", "~/.config/banditshell/config.json", "image · 1280 × 820", "qs -c banditshell", "meet at the climbing gym at 7?",
    "hyprctl dispatch workspace 3", "#7fb3d4", "ssh bandit@fjordhuset.local", "https://usevia.app", "image · 412 × 236", "sudo pacman -Syu"];

const OPENS = [
    { k: "defBrowser", what: "a link", thing: "git.example.org/shell", icon: "link" },
    { k: "defFiles", what: "a folder", thing: "~/Projects", icon: "folder" },
    { k: "defTerm", what: "a terminal", thing: "open a shell here", icon: "terminal" },
    { k: "defMail", what: "an email", thing: "mailto:ida@fjord.dk", icon: "mail" },
    { k: "defImages", what: "a picture", thing: "shaded_landscape.png", icon: "image" },
    { k: "defVideo", what: "a video", thing: "climbing.mp4", icon: "movie" }
];

const ZONES = {
    tray: "tray", trayMax: "tray", wsStyles: "workspaces", iconMode: "workspaces", persistent: "workspaces", specialsShown: "workspaces",
    sbClock: "clock", sbClockSize: "clock", sbClockWide: "clock", sbClockWideSize: "clock", sbDate: "clock", sbUpdate: "update", sbSound: "status", sbNet: "status", sbBt: "status", sbBright: "status", sbBatt: "status"
};

function zoneOf(row) {
    if (!row)
        return "";
    return ZONES[row.k] || ZONES[row.w] || "";
}
