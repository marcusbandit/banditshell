import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property string output: win.screen?.name ?? ""
    readonly property var cfg: Config.values.widgets
    readonly property bool bare: Hypr.windowsOn(win.output) === 0
    readonly property bool wanted: Config.loaded && win.cfg.enabled && !Hypr.fullscreenOn(win.output)
    readonly property bool showing: win.wanted && (win.cfg.shown !== "empty" || win.bare)
    readonly property bool live: win.showing || shown.value > 0.002

    readonly property real margin: Math.max(Compositor.gapsOut, Appearance.padding.large)
    readonly property real reserveLeft: Appearance.bare ? 0 : Appearance.sizes.border + Appearance.sizes.sidebarReserve
    readonly property real reserveRight: Appearance.bare ? 0 : Appearance.sizes.border
    readonly property real reserveTop: Appearance.bare ? 0 : Appearance.sizes.border
    readonly property real originX: column.fromRight ? (win.screen?.width ?? 0) - win.reserveRight - win.width : win.reserveLeft

    anchors {
        top: true
        bottom: true
        left: win.cfg.side !== "right"
        right: win.cfg.side === "right"
    }

    implicitWidth: Math.min((win.screen?.width ?? 1920) / 2, column.cardWidth * 3 + column.spacing * 2 + win.margin * 2)

    color: "transparent"
    visible: win.live
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "banditshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: column
    }

    Follow {
        id: shown

        target: win.showing ? 1 : 0
        speed: Appearance.animation.settleSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Backdrop {
        id: backdrop

        source: Wallpaper.enabled ? Wallpaper.faceOf(Wallpaper.shownOn(win.output)) : ""
        screen: Qt.size(win.screen?.width ?? 0, win.screen?.height ?? 0)
        region: Qt.rect(win.originX + column.x + column.clockRect.x, win.reserveTop + column.y + column.clockRect.y, column.clockRect.width, column.clockRect.height)
    }

    WidgetColumn {
        id: column

        x: column.fromRight ? win.width - width - win.margin : win.margin
        y: win.margin
        room: win.height - win.margin * 2
        fromRight: win.cfg.side === "right"
        opacity: shown.value
        running: win.live
        clockInk: backdrop.lightInk ? Appearance.colour.paper : Appearance.colour.ink
        clockBacked: backdrop.busy
    }
}
