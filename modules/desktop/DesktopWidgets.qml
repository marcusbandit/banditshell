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
    property var reserve: ({
            top: 0,
            right: 0,
            bottom: 0,
            left: 0
        })
    readonly property real originX: column.fromRight ? (win.screen?.width ?? 0) - win.reserve.right - win.width : win.reserve.left

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

    Timer {
        interval: Math.max(5, Weather.cfg.minutes) * 60000
        repeat: true
        running: win.live && win.cfg.weather && Weather.wanted
        onRunningChanged: if (running)
            Weather.refresh()
        onTriggered: Weather.retry()
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
        region: Qt.rect(win.originX + column.x + column.clockRect.x, win.reserve.top + column.y + column.clockRect.y, column.clockRect.width, column.clockRect.height)
    }

    WidgetColumn {
        id: column

        x: column.fromRight ? win.width - width - win.margin : win.margin
        y: win.margin
        room: win.height - win.margin * 2
        fromRight: win.cfg.side === "right"
        opacity: shown.value
        running: win.live
        seen: win.live && win.bare
        clockInk: backdrop.lightInk ? Appearance.colour.paper : Appearance.colour.ink
        clockBacked: backdrop.busy
    }
}
