.pragma library

const pct = v => `${Math.round(v * 100)}%`;
const signed = v => Math.abs(v) < 0.01 ? "as is" : (v > 0 ? "+" : "") + v.toFixed(2);
const kelvin = (s, v) => {
    const top = s.neutral || 6500;
    return v ? `${Math.round(top - v / 100 * (top - s.v("warmest")))} K` : "off";
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
    { id: "custom", name: "add custom", detail: "your own · still being worked out" }
];

const WIDGET_TITLES = {
    winLayouts: "Layout", via: "VIA layout", modes: "Modes", usage: "Today", recent: "Recent changes", nets: "Networks",
    devices: "Devices", volume: "Volume", apps: "Volume by app", walls: "Wallpapers", themes: "Theme", wsStyles: "Workspace style",
    chips: "Apps", folders: "Folders", overrides: "Icon overrides", startup: "Startup apps", rules: "App rules", clocks: "Places",
    obs: "OBS", keys: "Keys", kbLayouts: "Layouts", battery: "Battery", update: "Updates", changes: "What’s new", about: "About",
    tunnels: "Tunnels"
};

const SEARCH_TITLES = {
    kbLayouts: "Layout", via: "VIA layout", modes: "Modes", usage: "Today", recent: "Recent changes", nets: "Networks",
    devices: "Devices", volume: "Volume", apps: "Volume by app", walls: "Pick a wallpaper", themes: "Theme", wsStyles: "Workspace style",
    chips: "", folders: "Folders", overrides: "Icon overrides", startup: "Startup apps", rules: "App rules", clocks: "World clocks",
    obs: "OBS", keys: "Keys", winLayouts: "Layouts", battery: "Battery", update: "Updates", changes: "What’s new", about: "About",
    tunnels: "Tunnels"
};

const WIDGET_WHY = {
    winLayouts: "How Hyprland tiles windows on this screen. Scrolling and hy3 are plugins and need installing first. Custom is for your own layout; how it plugs in is still being worked out.",
    via: "Import the .json your keyboard’s maker publishes for VIA. The sheet then draws your exact board, split halves and odd keys included.",
    modes: "Like a focus on a phone. Pick one and it changes a handful of settings; pick none and they go back.",
    usage: "Time with each app in front of you today, counted only while you are active.",
    recent: "Every setting you change lands here with a way back. The search field shows the same list when it is empty.",
    nets: "Click a network to join, share or forget it in the pane. The camera button reads a Wi-Fi code.",
    devices: "Click a device to connect, trust, forget or block it in the pane.",
    volume: "Scroll the speaker in the sidebar to change it from anywhere.",
    themes: "Themes come from ~/.config/theme. The ramp paints surfaces; the accents paint everything that’s on.",
    wsStyles: "Plates stack the apps in each workspace. Map draws a bar per window. Blocks draws a square per window.",
    walls: "A new wallpaper grows out from where you clicked.",
    battery: "Charge over the last day. The dashed lines are the hold point and the warning.",
    keys: "Click a key to change it in the pane."
};

const PAGES_SOURCE = {
    wifi: {
        id: "wifi", name: "Wi-Fi", icon: "wifi", preview: "network",
        status: s => s.v("wifi") ? s.wifiNet || "not connected" : "off",
        groups: [
            { rows: [
                { n: 1, icon: "wifi", label: "Wi-Fi", k: "wifi", kind: "toggle", detail: s => s.v("wifi") ? (s.wifiNet || "not connected") : "off",
                    why: "Turns the radio off. Ethernet keeps working." },
                { n: [2, 3, 6], kind: "w", w: "nets", kw: "networks join password forget qr share scan portal sign in" },
                { n: 4, icon: "autorenew", label: "Join on its own", k: "autoJoin", kind: "toggle", detail: s => s.v("autoJoin") ? "" : "waits to be told", dis: s => !s.v("wifi"),
                    why: "Saved networks reconnect when they come in range.", kw: "auto-join known networks" },
                { n: 8, icon: "radar", label: "Keep the list fresh", k: "keepFresh", kind: "toggle", cfg: "network.keepListFresh", detail: "pauses for a moment",
                    why: "Rescans in the background so the list is current when you open it. Each scan holds the radio for a moment." }
            ] },
            { t: "Checks", rows: [
                { n: 7, icon: "public", label: "Check for internet", k: "netCheck", kind: "toggle", cfg: "network.checkForInternet", detail: s => s.v("netCheck") ? s.reach : "otherwise it guesses", kw: "internet check",
                    why: "Pings a check server so the sidebar can tell you when a network has no way out." },
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
                { n: 11, icon: "bluetooth", label: "Bluetooth", k: "bt", kind: "toggle", detail: s => s.v("bt") ? `shows up as ${s.btName}` : "off" },
                { n: 12, icon: "visibility", label: "Visible to others", k: "btVisible", kind: "toggle", detail: "hides again after 3 min", dis: s => !s.v("bt"), kw: "discoverable visibility" },
                { n: 12, icon: "handshake", label: "Take pairing requests", k: "btPairable", kind: "toggle", dis: s => !s.v("bt"), kw: "pairable" }
            ] },
            { t: "Devices", rows: [
                { n: [13, 14], kind: "w", w: "devices", kw: "devices pair connect forget trusted blocked" }
            ] }
        ]
    },
    wired: {
        id: "wired", name: "Ethernet", icon: "lan", preview: "network",
        status: s => s.v("wired") ? s.wiredDetail : "off",
        groups: [
            { rows: [
                { n: 5, icon: "lan", label: "Ethernet", k: "wired", kind: "toggle", detail: s => s.v("wired") ? s.wiredDetail : "off", kw: "wired connection",
                    why: "The dock’s port.", layer: [
                        { n: 5, icon: "autorenew", label: "Join on its own", k: "wiredAuto", kind: "toggle", detail: s => s.v("wiredAuto") ? "" : "waits to be told" },
                        { n: 5, kind: "fact", text: s => s.wiredFact }
                    ] }
            ] }
        ]
    },
    vpn: {
        id: "vpn", name: "Hotspot and VPN", icon: "vpn_lock", preview: "network",
        status: s => [s.v("hotspot") ? "sharing" : "not sharing", s.vpnOn ? `vpn ${s.vpnOn}` : "no vpn"].join(" · "),
        groups: [
            { t: "Hotspot", rows: [
                { n: 9, isNew: true, icon: "wifi_tethering", label: "Share this connection", k: "hotspot", kind: "toggle", detail: s => s.v("hotspot") ? "on · 0 devices" : "over Wi-Fi",
                    why: "Lends your ethernet connection to other devices over Wi-Fi. Wi-Fi stops joining networks while it runs.", layer: [
                        { n: 9, isNew: true, icon: "badge", label: "Name", k: "hotspotName", kind: "text" },
                        { n: 9, isNew: true, icon: "key", label: "Password", k: "hotspotPass", kind: "secret" },
                        { n: 9, isNew: true, icon: "settings_input_antenna", label: "Band", k: "hotspotBand", kind: "seg", o: ["2.4 GHz", "5 GHz"] }
                    ] }
            ] },
            { t: "VPN", rows: [
                { n: 10, isNew: true, kind: "w", w: "tunnels", kw: "vpn wireguard tunnel" },
                { n: 10, isNew: true, icon: "upload_file", label: "Add a tunnel", kind: "button", btn: "Import", act: "vpnImport", detail: ".conf or .ovpn" }
            ] }
        ]
    },
    output: {
        id: "output", name: "Output", icon: "speaker", preview: "sound",
        status: s => s.outputName,
        groups: [
            { rows: [
                { n: 17, kind: "w", w: "volume", kw: "volume mute", fmt: pct },
                { n: 15, icon: "speaker", label: "Play through", k: "output", kind: "choice", o: s => s.outputs, kw: "output device",
                    why: "Where sound goes. The speaker in the sidebar switches it too." },
                { n: 18, icon: "unfold_more", label: "Keys step by", k: "volStep", kind: "seg", o: [[0.02, "2%"], [0.05, "5%"], [0.1, "10%"]], cfg: "volume.step", kw: "volume step" },
                { n: 19, isNew: true, icon: "campaign", label: "Past 100%", k: "overAmp", kind: "toggle", detail: "louder, can crackle", kw: "volume above 100 boost",
                    why: "Lets the slider run to 150%. The bead turns accent once it passes the mark at 100%." }
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
        id: "mixer", name: "Apps", icon: "tune", preview: "sound",
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
                { n: 79, icon: "history", label: "Remember", k: "notifHistory", kind: "step", min: 10, max: 500, step: 10, cfg: "notifications.maxHistory", fmt: v => `${v}`, kw: "notification history length" }
            ] },
            { t: "By app", rows: [
                { n: 81, isNew: true, kind: "w", w: "rules", kw: "per-app notification rules" }
            ] },
            { t: "The island", rows: [
                { n: [], icon: "download_done", label: "Downloads", k: "islandDownloads", kind: "toggle", cfg: "island.downloads", detail: s => s.v("islandDownloads") ? "says when a file lands" : "says nothing", kw: "island finished downloads announce",
                    why: "Watches your downloads folder and says when a file has finished arriving. Needs inotifywait (inotify-tools)." },
                { n: [], icon: "music_note", label: "Now playing", k: "islandMusic", kind: "toggle", cfg: "island.nowPlaying", detail: s => s.v("islandMusic") ? "shows each new track" : "only when you go up to it", kw: "island now playing track change music song",
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
                { n: 22, isNew: true, icon: "notifications_active", label: "Alert sounds", k: "alerts", kind: "toggle", detail: "notifications · low battery · errors" },
                { n: 22, isNew: true, icon: "music_note", label: "Sound set", k: "alertSet", kind: "seg", o: ["soft", "clear", "wood"], dis: s => !s.v("alerts") },
                { n: 22, isNew: true, icon: "volume_down", label: "Alert volume", k: "alertVol", kind: "slider", min: 0, max: 1, step: 0.01, fmt: pct, dis: s => !s.v("alerts") }
            ] },
            { t: "Media", rows: [
                { n: 82, icon: "swap_vert", label: "Wheel seeks", k: "wheelSeek", kind: "step", min: 0, max: 30, unit: " s", cfg: "media.wheelSeek", detail: s => s.v("wheelSeek") ? "per notch on the player" : "off", kw: "media controls scroll to seek" },
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
                    why: "Moves, resolutions, rates, scale and turns wait for Apply, then go to Hyprland's monitor lines together. A change to the picture asks you to keep it, and goes back by itself after 15 seconds if you can't. Hold ctrl while dragging to move freely; shift with the arrows moves 10 px; tab picks the next screen.", kw: "screen arrangement position monitors layout drag snap centre nudge apply" },
                { n: 29, isNew: true, icon: "power_settings_new", label: "Use this screen", k: "scr:on", kind: "toggle", detail: s => s.onlyOn ? "the last one stays on" : "", dis: s => s.onlyOn, kw: "turn a screen off" },
                { n: 29, isNew: true, icon: "flip", label: "Mirror", k: "scr:mirror", kind: "choice", o: s => [["", "nothing"]].concat(s.monitorNames.filter(m => m !== s.selMon).map(m => [m, m])), dis: s => !s.v("scr:on") },
                { n: 24, icon: "aspect_ratio", label: "Resolution", k: "scr:res", kind: "choice", o: s => s.resolutions, detail: s => s.pendingNote("res"), dis: s => !s.v("scr:on") },
                { n: 25, icon: "speed", label: "Refresh rate", k: "scr:hz", kind: "choice", o: s => s.rates, detail: s => s.pendingNote("hz"), dis: s => !s.v("scr:on") },
                { n: 26, icon: "zoom_in", label: "Scale", k: "scr:scale", kind: "seg", o: [[1, "1"], [1.25, "1.25"], [1.5, "1.5"], [2, "2"]], detail: s => s.pendingNote("scale"), dis: s => !s.v("scr:on") },
                { n: 27, icon: "screen_rotation", label: "Turn", k: "scr:rot", kind: "seg", o: [[0, "0°"], [90, "90°"], [180, "180°"], [270, "270°"]], detail: s => s.pendingNote("rot"), dis: s => !s.v("scr:on"), kw: "rotation portrait" },
                { n: 28, icon: "motion_photos_auto", label: "Variable refresh", k: "scr:vrr", kind: "toggle", detail: s => s.pendingNote("vrr") || "smoother games · may flicker", dis: s => !s.v("scr:on"), kw: "vrr freesync" },
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
                { n: 34, isNew: true, icon: "schedule", label: "On a schedule", k: "nightSched", kind: "seg", o: ["off", "sunset", "set times"], detail: s => s.v("nightSched") === "sunset" ? "tonight 18:24 to 07:41" : s.v("nightSched") === "set times" ? "21:00 to 07:00" : "", kw: "night light schedule" }
            ] }
        ]
    },
    colour: {
        id: "colour", name: "Colour", icon: "palette", preview: "chassis",
        status: s => `${s.v("fromWall") ? "wallpaper" : s.v("theme")} · ${s.v("accent")}`,
        groups: [
            { rows: [
                { n: 42, kind: "w", w: "themes", kw: "theme palette" },
                { n: 43, icon: "colorize", label: "Take it from the wallpaper", k: "fromWall", kind: "toggle", cfg: "themeFromWallpaper", detail: s => s.v("fromWall") ? s.wallName : "", kw: "theme from wallpaper" },
                { n: 44, icon: "contrast", label: "Accent", k: "accent", kind: "seg", o: ["dim", "mid", "bright"], cfg: "colour.accent", kw: "accent strength",
                    why: "Which of the theme’s three accents leads. Dim sits back, bright jumps out." },
                { n: 45, icon: "layers", label: "Surface depth", k: "surface", kind: "slider", min: 0, max: 6, step: 1, fmt: v => `ramp ${v}`, cfg: "colour.surface",
                    why: "Which step of the theme ramp the frame and panels are painted with. Lower is darker." },
                { n: 46, icon: "opacity", label: "See-through", k: "surfaceAlpha", kind: "slider", min: 0.5, max: 1, step: 0.01, fmt: v => `${Math.round((1 - v) * 100)}%`, cfg: "material.surfaceAlpha", kw: "transparency" }
            ] }
        ]
    },
    wallpaper: {
        id: "wallpaper", name: "Wallpaper", icon: "wallpaper", preview: "wallpaper",
        status: s => s.v("wallOn") ? s.wallName.toLowerCase() : "off",
        groups: [
            { rows: [
                { n: 36, icon: "wallpaper", label: "Wallpaper", k: "wallOn", kind: "toggle", cfg: "wallpaper.enabled", detail: s => s.v("wallOn") ? "" : "the surface colour shows" },
                { n: 35, icon: "select_window", label: "Put it on", k: "wallTarget", kind: "seg", o: ["this screen", "everywhere"], cfg: "wallpaper.perScreen", dis: s => !s.v("wallOn"), kw: "one screen everywhere" },
                { n: [35, 37], kind: "w", w: "walls", kw: "pick wallpaper" },
                { n: 37, icon: "folder", label: "Folder", k: "wallDir", kind: "path", cfg: "wallpaper.dir", kw: "wallpaper folder" }
            ] },
            { t: "Motion", rows: [
                { n: 38, icon: "animation", label: "Play animated ones", k: "wallAnim", kind: "toggle", cfg: "wallpaper.animate", detail: "pauses under full-screen windows", kw: "animated wallpapers" },
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
        status: s => `${s.v("font")} · ${(s.v("largerText") ? 11 : s.v("fontBase")) * 2} px`,
        groups: [
            { rows: [
                { n: 47, icon: "text_fields", label: "Font", k: "font", kind: "choice", o: s => s.fonts, cfg: "font.family",
                    why: "Monocraft is drawn on a 9 px grid, so text sizes stay whole multiples of the base." },
                { n: 48, icon: "interests", label: "Icons", k: "iconFont", kind: "seg", o: [["Material Symbols Rounded", "rounded"], ["Material Symbols Outlined", "outlined"], ["Material Symbols Sharp", "sharp"]], cfg: "font.icon", kw: "icon fonts" },
                { n: 49, icon: "format_size", label: "Text size", k: "fontBase", kind: "seg", o: [[8, "16"], [9, "18"], [10, "20"]], cfg: "font.base", dis: s => s.v("largerText"), detail: s => s.v("largerText") ? "set by larger text" : "small size in px",
                    why: "Sizes step from the base: small is twice it, normal three times, large four." },
                { n: 50, icon: "photo_size_select_small", label: "Icon size", k: "iconScale", kind: "slider", min: 0.8, max: 1.6, step: 0.05, fmt: v => `${v.toFixed(2)}×`, cfg: "font.iconScale" }
            ] }
        ]
    },
    shape: {
        id: "shape", name: "Shape and motion", icon: "rounded_corner", preview: "chassis",
        status: s => s.v("follow") ? "following hyprland" : `${s.v("rounding")} px · power ${s.v("power")}`,
        groups: [
            { rows: [
                { n: 55, icon: "sync_alt", label: "Follow Hyprland", k: "follow", kind: "toggle", cfg: "compositor.follow", detail: s => s.v("follow") ? s.followDetail : "uses the values below", dis: s => s.v("bare"), kw: "compositor corners gaps",
                    why: "Reads rounding, gaps and border size from Hyprland so the frame lines up with your windows." },
                { n: 51, icon: "rounded_corner", label: "Rounding", k: "rounding", kind: "slider", min: 0, max: 30, fmt: v => `${v} px`, cfg: "rounding.base", dis: s => s.v("follow"), kw: "corner rounding" },
                { n: 51, icon: "crop_square", label: "Squareness", k: "power", kind: "slider", min: 2, max: 10, step: 0.5, fmt: v => v <= 2 ? "circle" : `power ${v}`, cfg: "rounding.power", dis: s => s.v("follow"), kw: "corner rounding squircle",
                    why: "Corners are superellipses. Power 2 is a plain circle; higher keeps the edge straight longer before it turns." },
                { n: 52, icon: "border_outer", label: "Frame", k: "border", kind: "slider", min: 0, max: 24, fmt: v => `${v} px`, cfg: "edge.border", dis: s => s.v("follow"), kw: "gaps window border band" },
                { n: 53, icon: "rounded_corner", label: "Round the screen", k: "roundOuter", kind: "toggle", cfg: "edge.roundOuter", kw: "outer screen corners" },
                { n: 56, icon: "border_color", label: "Paint window borders", k: "pushBorders", kind: "toggle", cfg: "compositor.pushBorders", detail: s => s.v("sourceEdits") ? "writes the accent to Hyprland" : "needs Hyprland edits on", dis: s => !s.v("sourceEdits"), kw: "push theme window borders" },
                { n: 54, icon: "crop_free", label: "Bare", k: "bare", kind: "toggle", cfg: "edge.bare", detail: "no frame, no band", kw: "bare mode",
                    why: "Drops the frame and the sidebar’s band. Panels float on their own." }
            ] },
            { t: "Motion", rows: [
                { n: 57, icon: "motion_blur", label: "Pace", k: "anim", kind: "slider", min: 80, max: 500, step: 10, fmt: v => `${v} ms`, cfg: "anim.base", dis: s => s.v("reduceMotion"), kw: "animation speed",
                    why: "The normal animation length. Fast and slow scale from it." }
            ] }
        ]
    },
    sidebar: {
        id: "sidebar", name: "Sidebar", icon: "side_navigation", preview: "sidebar",
        status: s => s.v("sidebar") ? `${s.v("wsStyle")} · ${s.v("sidebarW")} px` : "hidden",
        groups: [
            { rows: [
                { n: 58, icon: "side_navigation", label: "Sidebar", k: "sidebar", kind: "toggle", cfg: "sidebar.enabled", detail: s => s.v("sidebar") ? "" : "super + b brings it back" },
                { n: 59, icon: "width", label: "Width", k: "sidebarW", kind: "slider", min: 40, max: 72, fmt: v => `${v} px`, cfg: "sidebar.width", dis: s => !s.v("sidebar") }
            ] },
            { t: "Workspaces", rows: [
                { n: 60, kind: "w", w: "wsStyles", kw: "workspace style plates map blocks" },
                { n: 61, icon: "palette", label: "App marks", k: "iconMode", kind: "seg", o: ["colour", "mono"], cfg: "sidebar.workspaces.iconMode", kw: "workspace icons",
                    why: "Plates show the apps inside each workspace. Mono tints the marks to match the text." },
                { n: 62, icon: "filter_5", label: "Always there", k: "persistent", kind: "step", min: 1, max: 10, cfg: "sidebar.workspaces.persistent", fmt: v => `${v}`, detail: "more show up when busy", kw: "always-shown workspaces" },
                { n: 63, isNew: true, icon: "stacks", label: "Special workspaces", k: "specialsShown", kind: "toggle", cfg: "sidebar.workspaces.specials", detail: s => s.specialNames.join(" · ") || "none yet", kw: "scratchpad special", layer: [
                    { n: 63, kind: "w", w: "specials" }
                ] }
            ] },
            { t: "Clock and date", rows: [
                { n: [], isNew: true, icon: "schedule", label: "Clock", k: "sbClock", kind: "seg", o: ["stacked", "small", "one line", "off"], cfg: "sidebar.clock.style", kw: "sidebar clock style simplified one line hide",
                    why: "Stacked is hours over minutes at the normal size. Small is the same at the small size. One line turns the time on its side so it reads as 14:32." },
                { n: [], isNew: true, icon: "calendar_today", label: "Date", k: "sbDate", kind: "seg", o: [["day and month", "14 oct"], ["day", "14"], ["off", "off"]], cfg: "sidebar.clock.date", kw: "sidebar calendar date hide",
                    why: "The date under the clock. It still opens the calendar when you tap or pull it." }
            ] },
            { t: "Status", rows: [
                { n: [], icon: "sync", label: "Update button", k: "sbUpdate", kind: "seg", o: [["always", "always"], ["new", "when new"], ["never", "never"]], cfg: "sidebar.update", kw: "sidebar update button hide",
                    why: "When new keeps the sidebar clean until there is something to install. Updates stay reachable from System either way." },
                { n: [], isNew: true, icon: "volume_up", label: "Sound", k: "sbSound", kind: "toggle", cfg: "sidebar.status.sound", kw: "sidebar status icons" },
                { n: [], isNew: true, icon: "wifi", label: "Network", k: "sbNet", kind: "toggle", cfg: "sidebar.status.network", kw: "sidebar status icons" },
                { n: [], isNew: true, icon: "bluetooth", label: "Bluetooth", k: "sbBt", kind: "toggle", cfg: "sidebar.status.bluetooth", kw: "sidebar status icons" },
                { n: [], isNew: true, icon: "battery_5_bar", label: "Battery", k: "sbBatt", kind: "toggle", cfg: "sidebar.status.battery", detail: s => s.hasBattery ? "" : "no battery in this machine", dis: s => !s.hasBattery, kw: "sidebar status icons" }
            ] },
            { t: "Tray", rows: [
                { n: 64, isNew: true, icon: "apps", label: "Tray", k: "tray", kind: "toggle", detail: s => `${s.trayCount} apps`, kw: "tray" },
                { n: 64, icon: "more_horiz", label: "Most icons", k: "trayMax", kind: "step", min: 1, max: 12, cfg: "sidebar.tray.max", fmt: v => `${v}`, detail: "the rest fold away", dis: s => !s.v("tray") }
            ] }
        ]
    },
    windows: {
        id: "windows", name: "Windows", icon: "select_window", preview: "drop",
        status: s => `${s.v("layout") === "custom" ? "custom layout" : s.v("layout")} · ${s.v("dropMode")} on drop`,
        groups: [
            { t: "Layout", rows: [
                { n: [], isNew: true, kind: "w", w: "winLayouts", kw: "tiling layout dwindle master scrolling hy3 custom" }
            ] },
            { t: "Moving", rows: [
                { n: 66, icon: "vertical_align_top", label: "Bottom edge lifts windows", k: "edgeLift", kind: "toggle", cfg: "windows.edge", detail: "push down to peek" },
                { n: 67, icon: "swap_horiz", label: "Dropping on a window", k: "dropMode", kind: "seg", o: ["move", "swap"], cfg: "windows.mode", kw: "move swap",
                    why: "Move takes the spot and nudges the other aside. Swap trades the two." },
                { n: 68, icon: "trending_flat", label: "Follow a sent window", k: "followSent", kind: "toggle", cfg: "windows.follow", detail: s => s.v("followSent") ? "you go with it" : "you stay put" }
            ] },
            { t: "Panel widths", rows: [
                { n: 65, icon: "search", label: "Launcher", k: "launcherW", kind: "slider", min: 600, max: 1200, step: 20, fmt: v => `${v}`, cfg: "launcher.width", kw: "panel sizes" },
                { n: 65, icon: "content_paste", label: "Clipboard", k: "clipW", kind: "slider", min: 600, max: 1400, step: 20, fmt: v => `${v}`, cfg: "clipboard.width", kw: "panel sizes" },
                { n: 65, icon: "menu", label: "Menus", k: "menuW", kind: "slider", min: 320, max: 560, step: 10, fmt: v => `${v}`, cfg: "menu.width", kw: "panel sizes" },
                { n: 65, icon: "tune", label: "Settings", k: "settingsW", kind: "slider", min: 1040, max: 1440, step: 20, fmt: v => `${v}`, cfg: "settings.width", detail: "this one", kw: "panel sizes settings window" }
            ] }
        ]
    },
    launcher: {
        id: "launcher", name: "Launcher", icon: "search", preview: "launcher",
        status: s => `${s.v("concept")} · ${s.starredCount} starred`,
        groups: [
            { t: "Layout", rows: [
                { n: 69, icon: "view_agenda", label: "Concept", k: "concept", kind: "seg", o: ["list", "niagara"], cfg: "launcher.concept", kw: "launcher layout",
                    why: "List is a plain search list. Niagara is a thumb-sized alphabet rail with favourites on a bow." },
                { n: 70, icon: "photo_size_select_large", label: "Icon size", k: "launcherIcon", kind: "slider", min: 18, max: 48, step: 2, fmt: v => `${v} px`, cfg: "launcher.iconSize", kw: "launcher icon size" },
                { n: 71, icon: "trending_up", label: "Habit fades over", k: "halfLife", kind: "step", min: 1, max: 60, unit: " days", cfg: "launcher.halfLifeDays", detail: "apps you use rise", extra: { icon: "history", tip: "forget what it learned", act: "forgetHabit" }, kw: "app ranking by habit" }
            ] },
            { t: "Apps", rows: [
                { n: 72, kind: "w", w: "chips", list: "starred", kw: "starred apps favourites" },
                { n: 72, kind: "w", w: "chips", list: "hidden", kw: "hidden apps" },
                { n: 72, kind: "w", w: "folders", kw: "app folders" },
                { n: 73, kind: "w", w: "overrides", kw: "app icon overrides" }
            ] }
        ]
    },
    clipboard: {
        id: "clipboard", name: "Clipboard", icon: "content_paste", preview: "clipboard",
        status: s => s.v("clip") ? `keeping ${s.v("clipMax")}` : "off",
        groups: [
            { rows: [
                { n: 74, icon: "fiber_manual_record", label: "Record", k: "clip", kind: "toggle", cfg: "clipboard.record", detail: "super + v opens it", extra: { icon: "delete_sweep", tip: "clear it all", act: "clearClip" }, kw: "clipboard history on off" },
                { n: 75, icon: "format_list_numbered", label: "Keep", k: "clipMax", kind: "step", min: 50, max: 2000, step: 50, cfg: "clipboard.maxEntries", fmt: v => `${v}`, dis: s => !s.v("clip"), kw: "clipboard limits" },
                { n: 75, icon: "notes", label: "Longest text", k: "clipText", kind: "seg", o: [[262144, "256 KB"], [1048576, "1 MB"], [8388608, "8 MB"]], cfg: "clipboard.maxText", dis: s => !s.v("clip"), kw: "clipboard limits" },
                { n: 75, icon: "image", label: "Largest image", k: "clipBlob", kind: "seg", o: [[8388608, "8 MB"], [33554432, "32 MB"], [134217728, "128 MB"]], cfg: "clipboard.maxBlob", dis: s => !s.v("clip"), kw: "clipboard limits" }
            ] },
            { t: "Import", rows: [
                { n: 76, icon: "move_to_inbox", label: "From clipse", kind: "button", btn: s => s.clipseImported ? "Done" : "Import", act: "importClipse", cfg: "clipboard.importClipse", detail: s => s.clipseDetail, dis: s => s.clipseImported, kw: "import clipse" }
            ] }
        ]
    },
    modes: {
        id: "modes", name: "Modes", icon: "tune", preview: "modes",
        status: s => s.v("mode") !== "none" ? s.v("mode") : "none",
        groups: [
            { rows: [
                { n: [], isNew: true, kind: "w", w: "modes", kw: "modes focus work play stream sleep" }
            ] },
            { t: "Do not disturb", rows: [
                { n: 80, isNew: true, icon: "do_not_disturb_on", label: "Do not disturb", k: "dnd", kind: "toggle", detail: "still collects them", kw: "dnd focus", layer: [
                    { n: 80, isNew: true, icon: "timer_off", label: "Ends", k: "dndUntil", kind: "choice", o: ["in an hour", "at 18:00", "tomorrow", "off by hand"] },
                    { n: 80, isNew: true, icon: "alarm", label: "Let alarms through", k: "dndAlarms", kind: "toggle" }
                ] },
                { n: 80, isNew: true, icon: "bedtime", label: "Every night", k: "dndNightly", kind: "toggle", detail: "22:00 to 07:30", kw: "do not disturb schedule" }
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
                { n: 84, icon: "update", label: "Catch up", k: "catchUp", kind: "step", min: 0, max: 240, step: 15, unit: " min", cfg: "clock.catchUpMinutes", detail: s => s.v("catchUp") ? "rings late after sleep" : "missed means missed", kw: "alarms catch-up",
                    why: "If the laptop slept through an alarm, it still rings on wake when it is this late or less." },
                { n: 85, icon: "hourglass", label: "Longest timer", k: "timerMax", kind: "step", min: 1, max: 24, unit: " h", cfg: "clock.timerMax", kw: "timer limits" },
                { n: 85, icon: "alarm", label: "Most alarms", k: "alarmMax", kind: "step", min: 1, max: 20, cfg: "clock.alarmMax", fmt: v => `${v}`, kw: "alarm limits" }
            ] },
            { t: "Places", rows: [
                { n: 86, kind: "w", w: "clocks", kw: "world clocks" }
            ] },
            { t: "Calendar", rows: [
                { n: 83, icon: "swipe", label: "Swiping right goes", k: "rightForward", kind: "seg", o: [[true, "forward"], [false, "back"]], cfg: "calendar.rightGoesForward", kw: "calendar scroll direction" }
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
                { n: 88, isNew: true, kind: "w", w: "usage", kw: "screen time usage today" }
            ] },
            { t: "Limits", rows: [
                { n: 88, icon: "hourglass_bottom", label: "Daily cap", k: "capHours", kind: "step", min: 1, max: 16, unit: " h", cfg: "usage.capHours", detail: s => `${s.usedLabel} so far`, kw: "screen time cap" },
                { n: 88, isNew: true, icon: "filter_b_and_w", label: "Grey at the cap", k: "greyCap", kind: "toggle", detail: "drains colour once the time is up" },
                { n: 88, isNew: true, icon: "self_improvement", label: "Breaks", k: "breaks", kind: "toggle", detail: s => s.v("breaks") ? `a nudge every ${s.v("breakEvery")} min` : "off", layer: [
                    { n: 88, isNew: true, icon: "timer", label: "Every", k: "breakEvery", kind: "step", min: 15, max: 120, step: 5, unit: " min" }
                ] }
            ] }
        ]
    },
    keyboard: {
        id: "keyboard", name: "Keyboard", icon: "keyboard", preview: "sheet",
        status: s => s.kbLayouts.map(l => l.name).join(" · "),
        groups: [
            { rows: [
                { n: 99, isNew: true, kind: "w", w: "kbLayouts", kw: "keyboard layout" },
                { n: 99, isNew: true, icon: "keyboard_tab", label: "Repeat after", k: "kbDelay", kind: "slider", min: 150, max: 800, step: 10, fmt: v => `${v} ms`, kw: "key repeat delay" },
                { n: 99, isNew: true, icon: "fast_forward", label: "Repeat rate", k: "kbRate", kind: "slider", min: 10, max: 60, fmt: v => `${v}/s`, kw: "key repeat rate" }
            ] },
            { t: "Hotkey sheet", rows: [
                { n: 98, icon: "keyboard_alt", label: "Draw the board", k: "sheetBoard", kind: "toggle", cfg: "cheatsheet.board", detail: "super + /", kw: "hotkey sheet" },
                { n: 98, icon: "keyboard", label: "Board", k: "sheetKeyboard", kind: "choice", o: [["ansi", "ansi"], ["iso", "iso"], ["split", "split"], ["file", "from file"]], cfg: "cheatsheet.keyboard", dis: s => !s.v("sheetBoard"), kw: "hotkey sheet keyboard via import",
                    why: "Ansi, iso and split are drawn from built-in layouts. From file draws your own board from a VIA definition, so the sheet matches the keyboard on your desk." },
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
                { n: 100, isNew: true, icon: "mouse", label: "Mouse speed", k: "mouseSpeed", kind: "slider", min: -1, max: 1, step: 0.05, fmt: signed, kw: "mouse speed" },
                { n: 100, isNew: true, icon: "touchpad_mouse", label: "Touchpad speed", k: "padSpeed", kind: "slider", min: -1, max: 1, step: 0.05, fmt: signed, kw: "touchpad speed" },
                { n: 100, isNew: true, icon: "swipe_vertical", label: "Natural scrolling", k: "naturalScroll", kind: "toggle", detail: "content follows your fingers" },
                { n: 100, isNew: true, icon: "touch_app", label: "Tap to click", k: "tapClick", kind: "toggle" }
            ] }
        ]
    },
    tablet: {
        id: "tablet", name: "Tablet", icon: "tablet", preview: "tablet",
        status: s => s.v("autoKeyboard") ? `board ${Math.round(s.v("boardHeight") * 100)}%` : "no board",
        groups: [
            { t: "Touch", rows: [
                { n: 101, icon: "border_left", label: "Finger-sized edges", k: "touchEdges", kind: "toggle", cfg: "control.touchEdges", detail: "wider swipe-in strips" },
                { n: 101, icon: "gesture", label: "Gesture feel", k: "gestureFeel", kind: "seg", o: [[0.15, "light"], [0.25, "balanced"], [0.4, "firm"]], cfg: "control.pullCommit",
                    why: "How far a pull has to travel before it commits. Light gives way at a nudge." }
            ] },
            { t: "Tablet", rows: [
                { n: 102, icon: "keyboard_hide", label: "Keyboard on fold", k: "autoKeyboard", kind: "toggle", cfg: "tablet.autoKeyboard" },
                { n: 102, icon: "vertical_align_bottom", label: "Board takes room", k: "docked", kind: "toggle", cfg: "tablet.docked", detail: s => s.v("docked") ? "windows move up" : "floats over them", dis: s => !s.v("autoKeyboard") },
                { n: 102, icon: "height", label: "Board height", k: "boardHeight", kind: "slider", min: 0.25, max: 0.5, step: 0.01, fmt: pct, cfg: "tablet.height", dis: s => !s.v("autoKeyboard") },
                { n: 102, isNew: true, icon: "repeat", label: "Held keys repeat", k: "boardRepeat", kind: "toggle", cfg: "tablet.repeatDelay", detail: s => s.repeatDetail, dis: s => !s.v("autoKeyboard"), kw: "key repeat" }
            ] }
        ]
    },
    pen: {
        id: "pen", name: "Pen", icon: "stylus_note", preview: "pen",
        status: s => s.v("pen") ? `mapped to ${s.v("penScreen")}` : "off",
        groups: [
            { rows: [
                { n: 103, icon: "stylus", label: "Pen", k: "pen", kind: "toggle", cfg: "pen.enabled", detail: s => s.v("pen") ? s.penName : "off", kw: "pen device" },
                { n: 103, icon: "monitor", label: "Maps to", k: "penScreen", kind: "seg", o: s => s.screensOn.concat(["all"]), dis: s => !s.v("pen"), kw: "pen area mapping" },
                { n: 103, icon: "aspect_ratio", label: "Keep the shape", k: "aspectLock", kind: "toggle", cfg: "pen.aspectLock", detail: "trims the pad to match", dis: s => !s.v("pen"), kw: "pen aspect lock" },
                { n: 103, isNew: true, icon: "radio_button_unchecked", label: "Lower button", k: "penBtn1", kind: "choice", o: ["right click", "middle click", "erase", "nothing"], dis: s => !s.v("pen"), kw: "pen buttons" },
                { n: 103, isNew: true, icon: "radio_button_checked", label: "Upper button", k: "penBtn2", kind: "choice", o: ["right click", "middle click", "erase", "nothing"], dis: s => !s.v("pen"), kw: "pen buttons" }
            ] }
        ]
    },
    battery: {
        id: "battery", name: "Battery", icon: "battery_5_bar", preview: "battery", off: s => !s.hasBattery, away: s => !s.hasBattery,
        status: s => !s.hasBattery ? "no battery in this machine" : s.v("chargeLimit") ? `${s.batteryPct}% · held at ${s.v("chargeMax")}%` : `${s.batteryPct}%`,
        groups: [
            { rows: [
                { n: 104, kind: "w", w: "battery", kw: "battery charge health history" }
            ] },
            { t: "Charging", rows: [
                { n: 106, isNew: true, icon: "battery_charging_80", label: "Hold the charge", k: "chargeLimit", kind: "toggle", detail: "kinder to the cells", kw: "charge limit" },
                { n: 106, isNew: true, icon: "battery_full", label: "Stop at", k: "chargeMax", kind: "slider", min: 60, max: 100, step: 5, fmt: v => `${v}%`, dis: s => !s.v("chargeLimit"), kw: "charge limit" },
                { n: 107, isNew: true, icon: "battery_alert", label: "Warn at", k: "lowWarn", kind: "slider", min: 5, max: 30, fmt: v => `${v}%`, kw: "low battery warning" },
                { n: 107, isNew: true, icon: "battery_0_bar", label: "Nearly empty", k: "lowAction", kind: "choice", o: ["suspend at 5%", "hibernate at 5%", "nothing"], kw: "low battery" }
            ] }
        ]
    },
    powermode: {
        id: "powermode", name: "Power and lid", lidless: "Power", icon: "bolt", preview: "battery",
        status: s => s.hasLid ? `${s.v("profile")} · lid ${s.v("lidBattery")}` : s.v("profile"),
        groups: [
            { rows: [
                { n: 105, isNew: true, icon: "bolt", label: "Power mode", k: "profile", kind: "seg", o: ["saver", "balanced", "fast"], kw: "power profile performance" }
            ] },
            { t: "Lid", away: s => !s.hasLid, rows: [
                { n: 108, isNew: true, icon: "laptop", label: "On battery", k: "lidBattery", kind: "choice", o: ["suspend", "hibernate", "lock", "nothing"], kw: "lid close action" },
                { n: 108, isNew: true, icon: "power", label: "Plugged in", k: "lidPlugged", kind: "choice", o: ["suspend", "lock", "nothing"], kw: "lid close action" },
                { n: 108, isNew: true, icon: "monitor", label: "With screens attached", k: "lidDocked", kind: "choice", o: ["nothing", "lock", "suspend"], kw: "lid close action docked" }
            ] }
        ]
    },
    lock: {
        id: "lock", name: "Lock and idle", icon: "lock", preview: "lock",
        status: s => `locks after ${s.v("idleLock")}`,
        groups: [
            { t: "Lock screen", rows: [
                { n: 90, icon: "blur_on", label: "Blur", k: "lockBlur", kind: "slider", min: 0, max: 1, step: 0.05, fmt: pct, cfg: "lock.blur", kw: "lock screen look" },
                { n: 90, icon: "brightness_4", label: "Dim", k: "lockDim", kind: "slider", min: 0, max: 1, step: 0.05, fmt: pct, cfg: "lock.dim", kw: "lock screen look" },
                { n: 90, icon: "filter_b_and_w", label: "Drain colour", k: "lockDesat", kind: "slider", min: 0, max: 1, step: 0.05, fmt: pct, cfg: "lock.desaturate", kw: "lock screen look" },
                { n: 90, icon: "lock", label: "Try it", kind: "button", btn: "Lock", act: "lockNow", detail: "your password brings you back" }
            ] },
            { t: "When idle", rows: [
                { n: 91, isNew: true, icon: "lock_clock", label: "Lock after", k: "idleLock", kind: "choice", o: ["1 min", "5 min", "15 min", "never"], kw: "auto-lock idle" },
                { n: 91, isNew: true, icon: "monitor", label: "Screens off after", k: "idleOff", kind: "choice", o: ["5 min", "10 min", "30 min", "never"], kw: "screen-off idle" },
                { n: 91, isNew: true, icon: "bedtime", label: "Sleep after", k: "idleSuspend", kind: "choice", o: ["15 min", "30 min", "1 h", "never"], detail: s => s.hasBattery ? "on battery only" : "", kw: "suspend idle" }
            ] }
        ]
    },
    defaults: {
        id: "defaults", name: "Default apps", icon: "open_in_new", preview: "defaults",
        status: s => `${s.v("defBrowser")} · ${s.v("defTerm")}`,
        groups: [
            { rows: [
                { n: 111, isNew: true, icon: "public", label: "Web", k: "defBrowser", kind: "choice", o: s => s.appsFor("defBrowser"), kw: "default apps browser" },
                { n: 111, isNew: true, icon: "folder", label: "Files", k: "defFiles", kind: "choice", o: s => s.appsFor("defFiles"), kw: "default apps" },
                { n: 111, isNew: true, icon: "terminal", label: "Terminal", k: "defTerm", kind: "choice", o: s => s.appsFor("defTerm"), kw: "default apps" },
                { n: 111, isNew: true, icon: "mail", label: "Mail", k: "defMail", kind: "choice", o: s => s.appsFor("defMail"), kw: "default apps" },
                { n: 111, isNew: true, icon: "image", label: "Pictures", k: "defImages", kind: "choice", o: s => s.appsFor("defImages"), kw: "default apps" },
                { n: 111, isNew: true, icon: "movie", label: "Video", k: "defVideo", kind: "choice", o: s => s.appsFor("defVideo"), kw: "default apps" }
            ] }
        ]
    },
    startup: {
        id: "startup", name: "Startup apps", icon: "login", preview: "signin",
        status: s => `${s.startupOn} apps`,
        groups: [
            { rows: [
                { n: 112, isNew: true, kind: "w", w: "startup", kw: "startup apps autostart boot login sign-in" }
            ] }
        ]
    },
    files: {
        id: "files", name: "Files", icon: "folder", preview: "files",
        status: s => `${s.v("filesView")} · by ${s.v("filesSort")}${s.v("filesHidden") ? " · hidden shown" : ""}`,
        groups: [
            { rows: [
                { n: 92, icon: "view_module", label: "View", k: "filesView", kind: "seg", o: ["icons", "list"], cfg: "files.view", kw: "files app view" },
                { n: 92, icon: "sort", label: "Sort by", k: "filesSort", kind: "seg", o: ["name", "date", "size", "type"], cfg: "files.sort", kw: "files sort" },
                { n: 92, icon: "visibility_off", label: "Hidden files", k: "filesHidden", kind: "toggle", cfg: "files.hidden", detail: "ctrl + 5 or .", kw: "files hidden" },
                { n: 92, icon: "markdown", label: "Markdown", k: "filesMarkdown", kind: "seg", o: ["rendered", "source"], cfg: "files.markdown", kw: "files previews" },
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
                { n: 89, icon: "highlight_alt", label: "Outline", k: "outline", kind: "step", min: 0, max: 6, unit: " px", cfg: "picker.outline", detail: s => s.v("outline") ? "around the selection" : "none", kw: "screenshots outline" }
            ] },
            { t: "Streaming", rows: [
                { n: 95, icon: "cast", label: "Streamer mode", k: "stream", kind: "toggle", cfg: "stream.enabled", detail: "hides names, passwords, previews", layer: [
                    { n: 95, icon: "monitor", label: "Band on", k: "streamScreen", kind: "choice", o: s => s.monitorNames, cfg: "stream.screen" },
                    { n: 95, icon: "height", label: "Band height", k: "streamHeight", kind: "slider", min: 200, max: 600, step: 20, fmt: v => `${v} px`, cfg: "stream.height" }
                ] },
                { n: 96, kind: "w", w: "obs", kw: "obs connection websocket" }
            ] }
        ]
    },
    region: {
        id: "region", name: "Language", icon: "language", preview: "region",
        status: s => `${s.v("lang")} · ${s.v("region")}`,
        groups: [
            { t: "Time", rows: [
                { n: 109, isNew: true, icon: "schedule", label: "24-hour clock", k: "clock24", kind: "toggle", detail: s => s.v("clock24") ? "14:32" : "2:32 pm", kw: "time format" },
                { n: 109, isNew: true, icon: "calendar_today", label: "Dates", k: "dateFormat", kind: "choice", o: ["14/10/2026", "14. okt. 2026", "2026-10-14", "wed 14 oct"], kw: "date format" },
                { n: 109, isNew: true, icon: "my_location", label: "Zone from network", k: "autoZone", kind: "toggle", kw: "time zone" },
                { n: 109, isNew: true, icon: "public", label: "Zone", k: "zone", kind: "choice", o: s => s.zoneChoices, dis: s => s.v("autoZone"), kw: "time zone" }
            ] },
            { t: "Language", rows: [
                { n: 110, isNew: true, icon: "translate", label: "Language", k: "lang", kind: "choice", o: ["English (UK)", "English (US)", "Dansk"], kw: "language" },
                { n: 110, isNew: true, icon: "payments", label: "Formats", k: "region", kind: "choice", o: ["Denmark", "United Kingdom", "United States"], detail: s => ({ Denmark: "1.234,56 kr. · monday first", "United Kingdom": "£1,234.56 · monday first", "United States": "$1,234.56 · sunday first" })[s.v("region")] || "", kw: "region numbers currency" }
            ] }
        ]
    },
    access: {
        id: "access", name: "Accessibility", icon: "accessibility_new", preview: "chassis",
        status: s => [s.v("reduceMotion") && "less motion", s.v("largerText") && "larger text", s.v("contrast") && "more contrast"].filter(Boolean).join(" · ") || "nothing on",
        groups: [
            { rows: [
                { n: 113, isNew: true, icon: "animation", label: "Less motion", k: "reduceMotion", kind: "toggle", detail: "fades instead of slides", kw: "accessibility reduce motion" },
                { n: 113, isNew: true, icon: "format_size", label: "Larger text", k: "largerText", kind: "toggle", detail: "base 9 becomes 11", kw: "accessibility larger text" },
                { n: 113, isNew: true, icon: "contrast", label: "More contrast", k: "contrast", kind: "toggle", detail: "faint text gets brighter", kw: "accessibility contrast" }
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
                { n: [], icon: "memory", label: "New kernel", k: "kernelEvery", kind: "step", min: 0, max: 1440, step: 60, unit: " min", cfg: "packages.interval", detail: s => s.v("kernelEvery") ? "the island says when Linux updates" : "never looks", kw: "kernel linux update pacman checkupdates system",
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
                { n: 115, icon: "keyboard_tab", label: "Tab completion", k: "tabComplete", kind: "toggle", detail: "for the shell’s cli" },
                { n: 116, icon: "edit_document", label: "Edit Hyprland files", k: "sourceEdits", kind: "toggle", cfg: "sourceEdits.acknowledged", detail: s => s.v("sourceEdits") ? "only its own include" : "hands off", kw: "permission to edit hyprland files",
                    why: "The shell writes borders, screen layout and binds into one file it owns. Your own Hyprland files are never touched." }
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
                { n: [], icon: "upload", label: "Export settings", kind: "button", btn: "Export", act: "exportCfg", detail: "config.json and your lists", kw: "backup export" },
                { n: [], isNew: true, icon: "download", label: "Restore from a file", kind: "button", btn: "Restore", act: "importCfg", detail: "shows what changes first", kw: "backup import restore" }
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
            ] }
        ]
    }
};

const CATS = [
    { id: "connections", name: "Connections", icon: "wifi",
        blurb: s => [s.v("wifi") && s.wifiNet ? s.wifiNet : "wi-fi off", s.v("bt") ? `${s.btConnected.length} devices` : "bluetooth off", s.vpnOn ? "vpn on" : ""].filter(Boolean).join(" · "),
        tiles: [
            { k: "wifi", icon: "wifi", label: "Wi-Fi", det: s => s.v("wifi") ? s.wifiNet || "not connected" : "off" },
            { k: "bt", icon: "bluetooth", label: "Bluetooth", det: s => s.v("bt") ? "on" : "off" },
            { k: "hotspot", icon: "wifi_tethering", label: "Hotspot" },
            { k: "vpnFirst", icon: "vpn_lock", label: "VPN", det: s => s.vpnOn || (s.tunnelCount ? "off" : "no tunnels"), dis: s => !s.tunnelCount }
        ],
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
        suggest: s => !s.v("dndNightly") ? { icon: "bedtime", label: "Go quiet every night", detail: "22:00 to 07:30", set: ["dndNightly", true] } : null,
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
        blurb: s => s.hasBattery ? `${s.batteryPct}% · ${s.v("profile")}${s.v("chargeLimit") ? ` · held at ${s.v("chargeMax")}%` : ""}` : `on mains · ${s.v("profile")}`,
        tiles: [
            { k: "chargeLimit", icon: "battery_charging_80", label: "Hold charge", away: s => !s.hasBattery, dis: s => !s.hasBattery, det: s => !s.hasBattery ? "no battery" : s.v("chargeLimit") ? `${s.v("chargeMax")}%` : "off" },
            { k: "saver", icon: "eco", label: "Saver", det: s => s.v("profile") === "saver" ? "on" : "off" }
        ],
        suggest: s => s.hasBattery && !s.v("chargeLimit") && s.healthKnown ? { icon: "health_and_safety", label: `Health is at ${s.healthPct}%`, detail: "holding the charge at 80% slows that", set: ["chargeLimit", true] } : null,
        subs: ["battery", "powermode", "lock"] },
    { id: "apps", name: "Apps", icon: "apps",
        blurb: s => `${s.v("defBrowser")} · ${s.v("defTerm")} · ${s.startupOn} at startup`,
        tiles: [
            { k: "stream", icon: "cast", label: "Streamer mode" },
            { k: "filesHidden", icon: "visibility_off", label: "Hidden files" }
        ],
        suggest: s => !s.clipseImported && s.clipseWaiting > 0 ? { icon: "move_to_inbox", label: "Bring clipse’s history over", detail: `${s.clipseWaiting} entries waiting`, go: "clipboard" } : null,
        subs: ["defaults", "startup", "files", "terminal", "capture"] },
    { id: "system", name: "System", icon: "settings",
        blurb: s => `${s.version} · ${s.v("lang")}`,
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

function walk(rows, page, group, parent, out) {
    for (const r of rows) {
        r.page = page.id;
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
    return row.why || (row.kind === "w" ? WIDGET_WHY[row.w] || "" : "") || val(row.detail, s) || "";
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
                    hay: `${label} ${r.kw || ""} ${typeof g.t === "string" ? g.t : ""} ${r.cfg || ""} ${p.name}`.toLowerCase()
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
        const words = q.split(/\s+/);
        hits = INDEX.filter(x => words.every(w => x.hay.indexOf(w) >= 0));
        const lead = x => x.label.toLowerCase().indexOf(q) === 0 ? 1 : 0;
        hits = hits.map((x, i) => ({ x: x, i: i })).sort((a, b) => lead(b.x) - lead(a.x) || a.i - b.i).map(e => e.x);
    }
    return hits.filter((x, i, a) => a.findIndex(y => y.label === x.label && y.page === x.page) === i).slice(0, 12);
}

const ALIASES = {
    network: "wifi", ethernet: "wired", hotspot: "vpn", sound: "output", audio: "output", microphone: "mic", monitors: "screens", display: "screens",
    brightness: "light", theme: "colour", font: "type", appearance: "colour", general: "windows", keybinds: "shortcuts", hotkeys: "shortcuts",
    device: "about", developer: "shell", cli: "shell", power: "powermode", idle: "lock", language: "region"
};

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
    const fresh = new Set();
    for (const r of rows)
        for (const n of numbers(r)) {
            nums.add(n);
            if (r.isNew)
                fresh.add(n);
        }
    return { settings: nums.size, fresh: fresh.size };
}

function rowCount(cat) {
    let n = 0;
    for (const p of cat.pages)
        for (const g of p.groups)
            n += g.rows.length;
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

const NIA_LETTERS = "#abcdefghijklmnopqrstuvwxyz".split("");
const NIA_PATH = [[null, 0, 700], ["a", 220, 600], ["d", 260, 550], ["f", 200, 650], ["k", 300, 550], ["o", 260, 500], ["s", 260, 650], [null, 0, 900]];

function niagaraAt(ms) {
    const total = NIA_PATH.reduce((a, p) => a + p[1] + p[2], 0);
    let t = ms % total;
    let prev = NIA_LETTERS.indexOf("a");
    const ease = x => x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
    for (const p of NIA_PATH) {
        const to = p[0] ? NIA_LETTERS.indexOf(p[0]) : null;
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
    sbClock: "clock", sbDate: "clock", sbUpdate: "update", sbSound: "status", sbNet: "status", sbBt: "status", sbBatt: "status"
};

function zoneOf(row) {
    if (!row)
        return "";
    return ZONES[row.k] || ZONES[row.w] || "";
}
