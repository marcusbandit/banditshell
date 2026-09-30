pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var cfg: Config.values
    readonly property var theme: Themes.get(cfg.theme)

    readonly property bool follows: root.cfg.compositor.follow && Compositor.available && !root.cfg.edge.bare

    readonly property bool bare: root.cfg.edge.bare

    function tier(base: real, scale: var, i: int): real {
        return base * scale[Math.max(0, Math.min(i, scale.length - 1))];
    }

    function rampAt(i: real, alpha: real): color {
        const r = root.theme.ramp;
        const c = Math.max(0, Math.min(i, r.length - 1));
        const lo = Math.floor(c);
        const hi = Math.min(lo + 1, r.length - 1);
        return mix(r[lo], r[hi], c - lo, alpha);
    }

    function blend(a: color, b: color, t: real): color {
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, a.a + (b.a - a.a) * k);
    }

    function shade(c: color, tier: int): color {
        const w = root.cfg.material.label;
        return Qt.rgba(c.r, c.g, c.b, w[Math.max(0, Math.min(tier, w.length - 1))]);
    }

    function mix(a: string, b: string, t: real, alpha: real): color {
        const pa = parseInt(a.slice(1), 16);
        const pb = parseInt(b.slice(1), 16);
        const lerp = (shift) => {
            const x = (pa >> shift) & 255;
            const y = (pb >> shift) & 255;
            return (x + (y - x) * t) / 255;
        };
        return Qt.rgba(lerp(16), lerp(8), lerp(0), alpha);
    }

    readonly property color tint: theme.ramp[theme.ramp.length - 1]

    function veil(alpha: real): color {
        return root.mix(root.tint, root.tint, 0, alpha);
    }

    readonly property QtObject colour: QtObject {

        readonly property color surface: root.rampAt(root.cfg.colour.surface, root.cfg.material.surfaceAlpha)

        readonly property color surfaceSolid: root.rampAt(root.cfg.colour.surface, 1)

        readonly property color text: root.veil(root.cfg.material.label[0])
        readonly property color textDim: root.veil(root.cfg.material.label[1])
        readonly property color textFaint: root.veil(root.cfg.material.label[2])

        readonly property color textGhost: root.veil(root.cfg.material.label[3])

        readonly property color fill: root.veil(root.cfg.material.fill[0])
        readonly property color fillStrong: root.veil(root.cfg.material.fill[1])
        readonly property color fillStronger: root.veil(root.cfg.material.fill[2])

        readonly property color separator: root.veil(root.cfg.material.separator)

        readonly property color accent: root.theme[root.cfg.colour.accent]

        readonly property color accentFill: Qt.rgba(accent.r, accent.g, accent.b, root.cfg.material.accentFill)

        readonly property color accentGrey: {
            const l = accent.r * 0.2126 + accent.g * 0.7152 + accent.b * 0.0722;
            return Qt.rgba(l, l, l, 1);
        }

        readonly property color accentFillDull: {
            const k = Math.max(0, Math.min(1, root.cfg.material.accentDull));
            return Qt.rgba(
                accent.r + (accentGrey.r - accent.r) * k,
                accent.g + (accentGrey.g - accent.g) * k,
                accent.b + (accentGrey.b - accent.b) * k,
                root.cfg.material.accentFill
            );
        }

        readonly property real veilWeight: root.cfg.material.accentFill

        readonly property color alarm: root.theme.alarm

        readonly property color accentText: root.rampAt(1, 1)

        readonly property color ink: root.rampAt(0, 1)
        readonly property color paper: root.rampAt(root.theme.ramp.length - 1, 1)

        readonly property var spectrum: [root.theme.dim, root.theme.mid, root.theme.bright]

        readonly property var terminalPalette: root.cfg.files.terminal.palette

        readonly property color updateAvailable: root.cfg.updates.availableColour
        readonly property color updateFailed: root.cfg.updates.failedColour
        readonly property color updateReady: root.cfg.updates.readyColour

        readonly property color frame: root.cfg.edge.outerColour

        readonly property color scrim: Qt.rgba(0, 0, 0, 0.45)

        readonly property color seam: Qt.rgba(root.colour.paper.r, root.colour.paper.g, root.colour.paper.b, 0.08)
    }

    readonly property QtObject font: QtObject {
        readonly property string family: root.cfg.font.family
        readonly property string icon: root.cfg.font.icon
        readonly property string brand: root.cfg.font.brand

        readonly property QtObject size: QtObject {
            readonly property int small: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 0))
            readonly property int normal: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 1))
            readonly property int large: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 2))
        }

        readonly property int iconSize: Math.round(size.small * root.cfg.font.iconScale)

        readonly property int stem: Math.max(1, Math.round(size.small / root.cfg.font.base))
    }

    readonly property QtObject rounding: QtObject {

        readonly property real base: root.follows ? Compositor.rounding : root.cfg.rounding.base

        readonly property real small: at(0)
        readonly property real normal: at(1)
        readonly property real large: at(2)

        readonly property real power: root.follows ? Compositor.roundingPower : root.cfg.rounding.power

        function at(i: int): real {
            return root.tier(base, root.cfg.rounding.scale, i);
        }
    }

    readonly property QtObject padding: QtObject {
        readonly property int small: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 0))
        readonly property int normal: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 1))

        readonly property int card: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 2))
        readonly property int large: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 3))
        readonly property int huge: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 4))
    }

    readonly property QtObject button: QtObject {

        function at(list: var, i: int): real {
            return list[Math.max(0, Math.min(i, list.length - 1))];
        }

        function label(i: int): real {
            return root.tier(root.cfg.font.base, root.cfg.button.scale, i);
        }

        function height(i: int): real {
            return at(root.cfg.button.heights, i);
        }

        function padX(i: int): real {
            return at(root.cfg.button.padX, i);
        }

        function iconSize(i: int): real {
            return at(root.cfg.button.iconSizes, i);
        }

        function iconGap(i: int): real {
            return at(root.cfg.button.iconGaps, i);
        }
    }

    readonly property QtObject anim: QtObject {
        readonly property int fast: Math.round(root.tier(root.cfg.anim.base, root.cfg.anim.scale, 0))
        readonly property int normal: Math.round(root.tier(root.cfg.anim.base, root.cfg.anim.scale, 1))
        readonly property int slow: Math.round(root.tier(root.cfg.anim.base, root.cfg.anim.scale, 2))

        readonly property real trackSpeed: root.cfg.anim.trackSpeed
        readonly property real revealSpeed: root.cfg.anim.revealSpeed
        readonly property real railSpeed: root.cfg.anim.railSpeed
        readonly property real resizeSpeed: root.cfg.anim.resizeSpeed
        readonly property real scrollSpeed: root.cfg.anim.scrollSpeed

        readonly property int grace: root.cfg.anim.grace
        readonly property int dwell: root.cfg.anim.dwell
        readonly property int tooltip: root.cfg.anim.tooltip

        readonly property int settle: root.cfg.anim.settle
    }

    readonly property QtObject sizes: QtObject {

        readonly property int border: root.follows ? Compositor.gapsOut : root.cfg.edge.border
        readonly property int sidebarWidth: root.cfg.sidebar.width
        readonly property real sidebarFlare: root.rounding.at(root.cfg.sidebar.flareTier)
        readonly property int wsSlot: root.cfg.sidebar.workspaces.slot
        readonly property int wsGap: root.cfg.sidebar.workspaces.gap
        readonly property int wsPersistent: root.cfg.sidebar.workspaces.persistent

        readonly property var wsSpecials: root.cfg.sidebar.workspaces.specials

        readonly property int wsIcon: Math.round(root.font.iconSize * root.cfg.sidebar.workspaces.iconScale)
        readonly property int wsWindowPitch: Math.round(wsIcon * root.cfg.sidebar.workspaces.windowPitch)
        readonly property string wsIconMode: root.cfg.sidebar.workspaces.iconMode

        readonly property string wsStyle: root.cfg.sidebar.workspaces.style
        readonly property int wsMapBar: root.cfg.sidebar.workspaces.mapBar
        readonly property int wsMapGap: root.cfg.sidebar.workspaces.mapGap
        readonly property int wsBlock: root.cfg.sidebar.workspaces.block
        readonly property int wsBlockGap: root.cfg.sidebar.workspaces.blockGap
        readonly property real wsEmptyReach: root.cfg.sidebar.workspaces.emptyReach
        readonly property real wsBusyReach: root.cfg.sidebar.workspaces.busyReach
        readonly property real wsHover: root.cfg.sidebar.workspaces.hover
        readonly property int statusSlot: root.cfg.sidebar.status.slot
        readonly property int statusGap: root.cfg.sidebar.status.gap

        readonly property int traySlot: root.cfg.sidebar.tray.slot
        readonly property int trayGap: root.cfg.sidebar.tray.gap
        readonly property int trayIcon: Math.round(root.font.iconSize * root.cfg.sidebar.tray.iconScale)
        readonly property int trayMax: root.cfg.sidebar.tray.max

        readonly property real melt: root.cfg.blob.melt
        readonly property real meltFeather: root.cfg.blob.feather

        readonly property int signalBands: root.cfg.control.signalBands
        readonly property int deviceListMax: root.cfg.control.deviceListMax
        readonly property int minTarget: root.cfg.control.minTarget
        readonly property real dragDismissFraction: root.cfg.control.dragDismissFraction
        readonly property real dragResistance: root.cfg.control.dragResistance
        readonly property int dragThreshold: root.cfg.control.dragThreshold

        readonly property int pullSlack: root.cfg.control.pullSlack
        readonly property real pullCommit: root.cfg.control.pullCommit
        readonly property real pullReversal: root.cfg.control.pullReversal
        readonly property real flickVelocity: root.cfg.control.flickVelocity
        readonly property int pullAngleCorner: root.cfg.control.pullAngleCorner
        readonly property int pullAngleEdge: root.cfg.control.pullAngleEdge
        readonly property real pullTravel: root.cfg.control.pullTravel

        readonly property bool touchEdges: root.cfg.control.touchEdges

        readonly property bool windowEdge: root.cfg.windows.edge
        readonly property int windowGrab: root.cfg.windows.grab
        readonly property int windowSettle: root.cfg.windows.settle
        readonly property int windowHold: root.cfg.windows.hold
        readonly property int windowHoldSlop: root.cfg.windows.holdSlop
        readonly property real windowTravel: root.cfg.windows.travel
        readonly property real windowFling: root.cfg.windows.fling
        readonly property real windowScale: root.cfg.windows.scale
        readonly property real windowPlate: root.cfg.windows.plate
        readonly property string windowMode: root.cfg.windows.mode
        readonly property bool windowFollow: root.cfg.windows.follow
        readonly property int rowHeight: root.cfg.control.rowHeight
        readonly property real wheelRows: root.cfg.control.wheelRows
        readonly property real coastMs: root.cfg.control.coastMs
        readonly property int sliderHeight: root.cfg.control.sliderHeight
        readonly property int toggleWidth: root.cfg.control.toggleWidth
        readonly property int toggleHeight: root.cfg.control.toggleHeight

        readonly property int pickerOutline: root.cfg.picker.outline
        readonly property int launcherWidth: root.cfg.launcher.width
        readonly property int launcherIcon: root.cfg.launcher.iconSize

        readonly property int clipboardWidth: root.cfg.clipboard.width
        readonly property int clipboardPreview: root.cfg.clipboard.preview
        readonly property int clipboardLines: root.cfg.clipboard.previewLines

        readonly property int clipboardIcon: Math.round(root.font.iconSize * root.cfg.clipboard.iconScale)

        readonly property int wallpaperReveal: root.cfg.wallpaper.reveal
        readonly property int notchTrack: root.cfg.notch.trackWidth

        readonly property int scrubStroke: root.cfg.media.stroke
        readonly property int scrubWaveLength: root.cfg.media.waveLength
        readonly property int scrubWaveAmplitude: root.cfg.media.waveAmplitude
        readonly property real scrubWaveSpeed: root.cfg.media.waveSpeed
        readonly property real scrubWheelSeek: root.cfg.media.wheelSeek

        readonly property int mediaPanelWidth: root.cfg.media.panelWidth
        readonly property real mediaSeekSmall: root.cfg.media.seekSmall
        readonly property real mediaSeekLarge: root.cfg.media.seekLarge
        readonly property int notificationWidth: root.cfg.notifications.width
        readonly property int notificationBadge: root.cfg.notifications.badge
        readonly property int cornerZone: root.cfg.notifications.cornerZone

        readonly property real volumeStep: root.cfg.volume.step

        readonly property int volumeRailWidth: root.cfg.volume.railWidth

        readonly property int volumeMeterGlyphs: root.cfg.volume.meterGlyphs
        readonly property int volumeLinger: root.cfg.volume.linger
        readonly property real volumeGrabFraction: root.cfg.volume.grabFraction

        readonly property int usageCapHours: root.cfg.usage.capHours

        readonly property bool calendarRightGoesForward: root.cfg.calendar.rightGoesForward

        readonly property int sessionButton: root.cfg.session.button
        readonly property int sessionIcon: Math.round(root.font.iconSize * root.cfg.session.iconScale)

        readonly property int settingsWidth: root.cfg.settings.width
        readonly property int settingsHeight: root.cfg.settings.height
        readonly property int settingsRail: root.cfg.settings.rail

        readonly property int settingsRailRow: root.cfg.settings.railRow
        readonly property int settingsPane: root.cfg.settings.pane

        readonly property int settingsGutter: root.cfg.settings.gutter

        readonly property int filesWidth: root.cfg.files.width
        readonly property int filesHeight: root.cfg.files.height

        readonly property real filesZoom: root.cfg.files.zoom
        readonly property int filesTile: Math.round(root.cfg.files.tile * filesZoom)
        readonly property int filesPreview: root.cfg.files.preview

        readonly property int filesText: Math.round(root.cfg.files.text * filesZoom)
        readonly property int filesSidebar: root.cfg.files.sidebar

        readonly property int filesRow: Math.round(root.cfg.files.text * 2)
        readonly property int filesThumbnail: root.cfg.files.thumbnail
        readonly property int filesTextMax: root.cfg.files.textMax

        readonly property int filesTerminalRows: root.cfg.files.terminal.rows
        readonly property int filesScrollback: root.cfg.files.terminal.scrollback

        readonly property string filesTerminalFont: root.cfg.files.terminal.font

        readonly property int cornerIcon: Math.round(root.font.iconSize * root.cfg.corner.iconScale)

        readonly property int lockField: root.cfg.lock.fieldWidth
        readonly property real lockFieldHeight: Math.round(root.font.size.small * 4 / 3) + root.padding.normal * 2
        readonly property real lockBlur: root.cfg.lock.blur
        readonly property real lockDim: root.cfg.lock.dim
        readonly property real lockDesaturate: root.cfg.lock.desaturate
        readonly property int lockDot: Math.round(root.font.iconSize * root.cfg.lock.dotScale)

        readonly property real seam: 2
        readonly property real lockReveal: root.cfg.lock.revealSpeed

        readonly property int menuWidth: root.cfg.menu.width
        readonly property int menuMinHeight: root.cfg.menu.minHeight
        readonly property int menuMaxHeight: root.cfg.menu.maxHeight

        readonly property bool roundOuter: root.cfg.edge.roundOuter

        readonly property real windowRadius: root.rounding.base + (root.follows ? Compositor.borderSize : 0) + root.cfg.edge.outerExtra
        readonly property real gap: border
        readonly property real band: border
    }
}
