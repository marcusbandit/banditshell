pragma ComponentBehavior: Bound

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
    readonly property bool wanted: Config.loaded && DesktopLayout.loaded && win.cfg.enabled && !Hypr.fullscreenOn(win.output)
    readonly property bool showing: win.wanted && (win.cfg.shown !== "empty" || win.bare)
    readonly property bool live: win.showing || shown.value > 0.002

    readonly property real margin: Math.max(Compositor.gapsOut, Appearance.padding.large)
    property var reserve: ({
            top: 0,
            right: 0,
            bottom: 0,
            left: 0
        })
    readonly property rect area: Qt.rect(win.reserve.left + win.margin, win.reserve.top + win.margin, Math.max(0, win.width - win.reserve.left - win.reserve.right - win.margin * 2), Math.max(0, win.height - win.reserve.top - win.reserve.bottom - win.margin * 2))

    readonly property var widgets: [clock, weather, media, system, limits]
    readonly property bool opened: sheet.open || win.widgets.some(w => w.visible && w.expanded)
    readonly property bool grabbing: win.widgets.some(w => w.held)
    readonly property var heights: ({
            clock: clock.visible ? clock.restHeight : 0,
            weather: weather.visible ? weather.restHeight : 0,
            media: media.visible ? media.restHeight : 0,
            system: system.visible ? system.restHeight : 0,
            limits: limits.visible ? limits.restHeight : 0
        })

    function closeAll(except: Item): void {
        for (const w of win.widgets)
            if (w !== except)
                w.close();
    }

    function settle(): void {
        for (const w of win.widgets)
            if (w.visible && !DesktopLayout.placeOf(win.output, w.key))
                DesktopLayout.place(win.output, w.key, w.place);
    }

    function menu(w: Item, x: real, y: real): void {
        win.closeAll(null);
        const sizes = [["small", "Small", "crop_square"], ["medium", "Medium", "crop_7_5"], ["large", "Large", "crop_free"]];
        const actions = sizes.map(([size, label, icon]) => ({
                    icon,
                    label,
                    run: () => DesktopLayout.resize(w.key, size)
                }));
        actions.push({
            icon: "restart_alt",
            label: "Reset position",
            apart: true,
            run: () => DesktopLayout.forget(win.output, w.key)
        });
        sheet.popup(x, y, actions, sizes.findIndex(s => s[0] === w.rest));
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: win.live
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "banditshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onShowingChanged: if (!win.showing)
        win.closeAll(null)

    mask: Region {
        item: win.opened || win.grabbing ? catcher : null

        Region {
            intersection: Intersection.Combine
            item: clock.visible ? clock : null
        }

        Region {
            intersection: Intersection.Combine
            item: weather.visible ? weather : null
        }

        Region {
            intersection: Intersection.Combine
            item: media.visible ? media : null
        }

        Region {
            intersection: Intersection.Combine
            item: system.visible ? system : null
        }

        Region {
            intersection: Intersection.Combine
            item: limits.visible ? limits : null
        }

        Region {
            intersection: Intersection.Combine
            item: clock.visible ? clock.badge : null
        }

        Region {
            intersection: Intersection.Combine
            item: weather.visible ? weather.badge : null
        }

        Region {
            intersection: Intersection.Combine
            item: media.visible ? media.badge : null
        }

        Region {
            intersection: Intersection.Combine
            item: system.visible ? system.badge : null
        }

        Region {
            intersection: Intersection.Combine
            item: limits.visible ? limits.badge : null
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: win.live && win.cfg.weather && Weather.wanted
        triggeredOnStart: true
        onTriggered: Weather.keepFresh()
    }

    Follow {
        id: shown

        target: win.showing ? 1 : 0
        speed: Appearance.animation.settleSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    GlassSource {
        id: glass

        anchors.fill: parent
        source: Wallpaper.enabled && win.wanted ? Wallpaper.faceOf(Wallpaper.shownOn(win.output)) : ""
    }

    Backdrop {
        id: backdrop

        source: Wallpaper.enabled ? Wallpaper.faceOf(Wallpaper.shownOn(win.output)) : ""
        screen: Qt.size(win.width, win.height)
        region: clock.visible ? Qt.rect(clock.x, clock.y, clock.width, clock.height) : Qt.rect(0, 0, 0, 0)
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: win.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.closeAll(null)
    }

    Item {
        id: desk

        anchors.fill: parent
        opacity: shown.value

        ClockWidget {
            id: clock

            output: win.output
            backdrop: glass
            area: win.area
            heights: win.heights
            visible: win.cfg.clock
            running: win.live
            ink: backdrop.lightInk ? Appearance.colour.paper : Appearance.colour.ink
            backed: backdrop.busy
            onOpened: win.closeAll(clock)
            onMoved: win.settle()
            onMenuAsked: (x, y) => win.menu(clock, x, y)
        }

        WeatherWidget {
            id: weather

            output: win.output
            backdrop: glass
            area: win.area
            heights: win.heights
            visible: win.cfg.weather && Weather.ready
            onOpened: win.closeAll(weather)
            onMoved: win.settle()
            onMenuAsked: (x, y) => win.menu(weather, x, y)
        }

        MediaWidget {
            id: media

            output: win.output
            backdrop: glass
            area: win.area
            heights: win.heights
            visible: win.cfg.media && Media.hasTrack
            running: win.live
            onOpened: win.closeAll(media)
            onMoved: win.settle()
            onMenuAsked: (x, y) => win.menu(media, x, y)
        }

        SystemWidget {
            id: system

            output: win.output
            backdrop: glass
            area: win.area
            heights: win.heights
            visible: win.cfg.system
            running: win.live && win.cfg.system
            onOpened: win.closeAll(system)
            onMoved: win.settle()
            onMenuAsked: (x, y) => win.menu(system, x, y)
        }

        AgentLimitsWidget {
            id: limits

            output: win.output
            backdrop: glass
            area: win.area
            heights: win.heights
            visible: win.cfg.limits && AgentLimits.anyEnabled
            running: win.live && win.cfg.limits
            onOpened: win.closeAll(limits)
            onMoved: win.settle()
            onMenuAsked: (x, y) => win.menu(limits, x, y)
        }
    }

    ActionSheet {
        id: sheet

        anchors.fill: parent
        z: 100
    }
}
