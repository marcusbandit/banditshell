pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var config: Config.values
    readonly property var theme: Themes.get(root.config.theme)

    readonly property bool follows: root.config.compositor.follow && Compositor.available && !root.config.edge.bare

    readonly property bool bare: root.config.edge.bare

    readonly property bool lessMotion: root.config.access.lessMotion

    readonly property real fontBase: root.config.access.largerText ? root.config.access.largerBase : root.config.font.base

    readonly property var labelAlphas: root.config.access.moreContrast ? root.config.access.contrastLabel : root.config.material.label

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
        const w = root.labelAlphas;
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

        readonly property color surface: root.rampAt(root.config.colour.surface, root.config.material.surfaceAlpha)

        readonly property color surfaceSolid: root.rampAt(root.config.colour.surface, 1)

        readonly property color text: root.veil(root.labelAlphas[0])
        readonly property color textDim: root.veil(root.labelAlphas[1])
        readonly property color textFaint: root.veil(root.labelAlphas[2])

        readonly property color textGhost: root.veil(root.labelAlphas[3])

        readonly property color fill: root.veil(root.config.material.fill[0])
        readonly property color fillStrong: root.veil(root.config.material.fill[1])
        readonly property color fillStronger: root.veil(root.config.material.fill[2])

        readonly property color separator: root.veil(root.config.material.separator)

        readonly property color accent: root.theme[root.config.colour.accent]

        readonly property color accentFill: Qt.rgba(accent.r, accent.g, accent.b, root.config.material.accentFill)

        readonly property color accentGrey: {
            const l = accent.r * 0.2126 + accent.g * 0.7152 + accent.b * 0.0722;
            return Qt.rgba(l, l, l, 1);
        }

        readonly property color accentFillDull: {
            const k = Math.max(0, Math.min(1, root.config.material.accentDull));
            return Qt.rgba(
                accent.r + (accentGrey.r - accent.r) * k,
                accent.g + (accentGrey.g - accent.g) * k,
                accent.b + (accentGrey.b - accent.b) * k,
                root.config.material.accentFill
            );
        }

        readonly property real veilWeight: root.config.material.accentFill

        readonly property color alarm: root.theme.alarm

        readonly property color accentText: root.rampAt(1, 1)

        readonly property color ink: root.rampAt(0, 1)
        readonly property color paper: root.rampAt(root.theme.ramp.length - 1, 1)

        readonly property var spectrum: [root.theme.dim, root.theme.mid, root.theme.bright]

        readonly property var themePalette: {
            const t = root.theme;
            const r = t.ramp;
            return [r[1], t.alarm, t.bright, t.mid, t.dim, t.mid, t.bright, r[9], r[6], t.alarm, t.bright, t.mid, t.dim, t.mid, t.bright, r[10]].map(c => String(c));
        }

        readonly property var terminalPalette: root.config.files.terminal.palette === "theme" ? root.colour.themePalette : root.config.files.terminal.palette

        readonly property color updateAvailable: root.config.updates.availableColour
        readonly property color updateFailed: root.config.updates.failedColour
        readonly property color updateReady: root.config.updates.readyColour

        readonly property color frame: root.config.edge.outerColour

        readonly property color scrim: Qt.rgba(0, 0, 0, 0.45)

        readonly property color seam: Qt.rgba(root.colour.paper.r, root.colour.paper.g, root.colour.paper.b, 0.08)

        readonly property color pane: root.blend(root.colour.surfaceSolid, root.colour.paper, 0.12)
    }

    readonly property QtObject opacity: QtObject {
        readonly property real disabled: 0.4
        readonly property real trail: 0.55
        readonly property real glow: 0.8
    }

    readonly property QtObject stroke: QtObject {
        readonly property int line: 1
        readonly property int ring: root.font.stem
    }

    readonly property QtObject icon: QtObject {
        readonly property int small: Math.round(root.font.iconSize * 0.8)
        readonly property int normal: root.font.iconSize
        readonly property int large: Math.round(root.font.iconSize * 1.4)
        readonly property int huge: root.font.iconSize * 2
        readonly property int hero: root.font.iconSize * 3
    }

    readonly property QtObject font: QtObject {
        readonly property string family: root.config.font.family
        readonly property string icon: root.config.font.icon
        readonly property string brand: root.config.font.brand
        readonly property string lock: root.config.lock.font

        readonly property QtObject size: QtObject {
            readonly property int small: Math.round(root.tier(root.fontBase, root.config.font.scale, 0))
            readonly property int normal: Math.round(root.tier(root.fontBase, root.config.font.scale, 1))
            readonly property int large: Math.round(root.tier(root.fontBase, root.config.font.scale, 2))
            readonly property int display: Math.round(large * 1.5)
        }

        readonly property real leading: 4 / 3

        readonly property QtObject line: QtObject {
            readonly property int small: Math.round(root.font.size.small * root.font.leading)
            readonly property int normal: Math.round(root.font.size.normal * root.font.leading)
            readonly property int large: Math.round(root.font.size.large * root.font.leading)
        }

        readonly property int iconSize: Math.round(size.small * root.config.font.iconScale)

        readonly property int stem: Math.max(1, Math.round(size.small / root.fontBase))
    }

    readonly property QtObject press: QtObject {
        readonly property real plate: 0.96
        readonly property real ring: 0.94
        readonly property real ringHover: 1.12
        readonly property real glyph: 0.92
        readonly property real lift: 1.15
        readonly property real grab: 1.3
    }

    readonly property QtObject rounding: QtObject {

        readonly property real base: root.follows ? Compositor.rounding : root.config.rounding.base

        readonly property real small: at(0)
        readonly property real normal: at(1)
        readonly property real large: at(2)

        readonly property real power: root.follows ? Compositor.roundingPower : root.config.rounding.power

        function at(i: int): real {
            return root.tier(base, root.config.rounding.scale, i);
        }
    }

    readonly property QtObject padding: QtObject {
        readonly property int hair: Math.round(small / 2)
        readonly property int small: Math.round(root.tier(root.config.padding.base, root.config.padding.scale, 0))
        readonly property int normal: Math.round(root.tier(root.config.padding.base, root.config.padding.scale, 1))

        readonly property int card: Math.round(root.tier(root.config.padding.base, root.config.padding.scale, 2))
        readonly property int large: Math.round(root.tier(root.config.padding.base, root.config.padding.scale, 3))
        readonly property int huge: Math.round(root.tier(root.config.padding.base, root.config.padding.scale, 4))
    }

    readonly property QtObject button: QtObject {

        function at(list: var, i: int): real {
            return list[Math.max(0, Math.min(i, list.length - 1))];
        }

        function height(i: int): real {
            return at(root.config.button.heights, i);
        }

        function padX(i: int): real {
            return at(root.config.button.padX, i);
        }

        function iconSize(i: int): real {
            return at(root.config.button.iconSizes, i);
        }

        function iconGap(i: int): real {
            return at(root.config.button.iconGaps, i);
        }

        readonly property real seam: Math.max(3, Math.round(Appearance.rounding.small / 2))
        readonly property real seamRadius: Appearance.rounding.small
    }

    readonly property QtObject animation: QtObject {
        readonly property QtObject fade: QtObject {
            readonly property int fast: Math.round(root.tier(root.config.anim.base, root.config.anim.scale, 0))
            readonly property int normal: Math.round(root.tier(root.config.anim.base, root.config.anim.scale, 1))
            readonly property int slow: Math.round(root.tier(root.config.anim.base, root.config.anim.scale, 2))
        }

        readonly property int fast: root.lessMotion ? root.config.access.stillMs : fade.fast
        readonly property int normal: root.lessMotion ? root.config.access.stillMs : fade.normal
        readonly property int slow: root.lessMotion ? root.config.access.stillMs : fade.slow

        readonly property real trackSpeed: root.config.anim.trackSpeed
        readonly property real revealSpeed: root.config.anim.revealSpeed
        readonly property real railSpeed: root.config.anim.railSpeed
        readonly property real resizeSpeed: root.config.anim.resizeSpeed
        readonly property real scrollSpeed: root.config.anim.scrollSpeed
        readonly property real settleSpeed: revealSpeed * 0.5
        readonly property real snapSpeed: revealSpeed * 1.5

        readonly property real fadeEpsilon: 0.002

        readonly property int grace: root.config.anim.grace
        readonly property int dwell: root.config.anim.dwell
        readonly property int tooltip: root.config.anim.tooltip

        readonly property int settle: root.config.anim.settle
    }

    readonly property QtObject sizes: QtObject {

        readonly property int border: root.follows ? Compositor.gapsOut : root.config.edge.border
        readonly property int sidebarWidth: root.config.sidebar.width
        readonly property int streamHeight: root.config.stream.height
        readonly property real sidebarFlare: root.rounding.at(root.config.sidebar.flareTier)
        readonly property int workspaceSlot: root.config.sidebar.workspaces.slot
        readonly property int workspaceGap: root.config.sidebar.workspaces.gap

        readonly property int workspaceIcon: Math.round(root.font.iconSize * root.config.sidebar.workspaces.iconScale)
        readonly property int workspaceWindowPitch: Math.round(workspaceIcon * root.config.sidebar.workspaces.windowPitch)

        readonly property int workspaceMapBar: root.config.sidebar.workspaces.mapBar
        readonly property int workspaceMapGap: root.config.sidebar.workspaces.mapGap
        readonly property int workspaceBlock: root.config.sidebar.workspaces.block
        readonly property int workspaceBlockGap: root.config.sidebar.workspaces.blockGap
        readonly property real workspaceEmptyReach: root.config.sidebar.workspaces.emptyReach
        readonly property real workspaceBusyReach: root.config.sidebar.workspaces.busyReach
        readonly property real workspaceHover: root.config.sidebar.workspaces.hover
        readonly property int statusSlot: root.config.sidebar.status.slot
        readonly property int statusGap: root.config.sidebar.status.gap

        readonly property int traySlot: root.config.sidebar.tray.slot
        readonly property int trayGap: root.config.sidebar.tray.gap
        readonly property int trayIcon: Math.round(root.font.iconSize * root.config.sidebar.tray.iconScale)

        readonly property real melt: root.config.blob.melt
        readonly property real meltFeather: root.config.blob.feather

        readonly property int minTarget: root.config.control.minTarget

        readonly property int windowGrab: root.config.windows.grab
        readonly property real windowScale: root.config.windows.scale
        readonly property real windowPlate: root.config.windows.plate
        readonly property int rowHeight: root.config.control.rowHeight
        readonly property int sliderHeight: root.config.control.sliderHeight
        readonly property int toggleWidth: root.config.control.toggleWidth
        readonly property int toggleHeight: root.config.control.toggleHeight

        readonly property int pickerOutline: root.config.picker.outline
        readonly property int launcherWidth: root.config.launcher.width
        readonly property int launcherIcon: root.config.launcher.iconSize

        readonly property int clipboardWidth: root.config.clipboard.width
        readonly property int clipboardPreview: root.config.clipboard.preview
        readonly property int clipboardLines: root.config.clipboard.previewLines

        readonly property int clipboardIcon: Math.round(root.font.iconSize * root.config.clipboard.iconScale)

        readonly property int wallpaperReveal: root.lessMotion ? 0 : root.config.wallpaper.reveal

        readonly property int scrubStroke: root.config.media.stroke
        readonly property int scrubWaveLength: root.config.media.waveLength
        readonly property int scrubWaveAmplitude: root.config.media.waveAmplitude
        readonly property real scrubWaveSpeed: root.config.media.waveSpeed

        readonly property int mediaPanelWidth: root.config.media.panelWidth
        readonly property int notificationWidth: root.config.notifications.width
        readonly property int notificationBadge: root.config.notifications.badge
        readonly property int cornerZone: root.config.notifications.cornerZone

        readonly property int screenSliderWidth: root.config.screen.sliderWidth
        readonly property int screenValueWidth: root.config.screen.valueWidth

        readonly property int sessionButton: root.config.session.button
        readonly property int sessionIcon: Math.round(root.font.iconSize * root.config.session.iconScale)

        readonly property int settingsWidth: root.config.settings.width
        readonly property int settingsHeight: root.config.settings.height
        readonly property int settingsRail: root.config.settings.rail

        readonly property int settingsRailRow: root.config.settings.railRow
        readonly property int settingsPane: root.config.settings.pane

        readonly property int settingsGutter: root.config.settings.gutter

        readonly property int filesWidth: root.config.files.width
        readonly property int filesHeight: root.config.files.height

        readonly property real filesZoom: root.config.files.zoom
        readonly property int filesTile: Math.round(root.config.files.tile * filesZoom)
        readonly property int filesPreview: root.config.files.preview

        readonly property int filesSidebar: root.config.files.sidebar

        readonly property int filesRow: Math.round(root.font.line.small * filesZoom) + root.padding.small
        readonly property int filesThumbnail: root.config.files.thumbnail

        readonly property string filesTerminalFont: root.config.files.terminal.font

        readonly property int cornerIcon: Math.round(root.font.iconSize * root.config.corner.iconScale)

        readonly property int lockField: root.config.lock.fieldWidth
        readonly property real lockFieldHeight: root.font.line.small + root.padding.normal * 2
        readonly property real lockBlur: root.config.lock.blur
        readonly property real lockDim: root.config.lock.dim
        readonly property real lockDesaturate: root.config.lock.desaturate
        readonly property int lockDot: Math.round(root.font.iconSize * root.config.lock.dotScale)
        readonly property real lockClockShare: root.config.lock.clockShare
        readonly property bool lockClockStacked: root.config.lock.clockLayout === "stacked"

        readonly property real seam: 2
        readonly property real lockReveal: root.config.lock.revealSpeed

        readonly property int menuWidth: root.config.menu.width
        readonly property int menuMinHeight: root.config.menu.minHeight
        readonly property int menuMaxHeight: root.config.menu.maxHeight

        readonly property bool roundOuter: root.config.edge.roundOuter

        readonly property real windowRadius: root.rounding.base + (root.follows ? Compositor.borderSize : 0) + root.config.edge.outerExtra
        readonly property real gap: border
        readonly property real band: border
    }
}
