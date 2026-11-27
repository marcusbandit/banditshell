pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "placement.js" as Placement

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
    readonly property var grid: Placement.grid(win.area, Appearance.padding.huge, Appearance.padding.large)
    readonly property Item carried: win.widgets.find(w => w.visible && w.dragging) ?? null
    readonly property bool raising: win.widgets.some(w => w.visible && w.overlaid)
    readonly property var restRects: win.widgets.map(w => w.visible ? w.restRect : null)
    property var recent: []
    readonly property bool opened: sheet.open || win.widgets.some(w => w.visible && w.expanded)
    readonly property bool grabbing: win.widgets.some(w => w.held)
    readonly property var heights: ({
            clock: clock.visible ? clock.restBox.height : 0,
            weather: weather.visible ? weather.restBox.height : 0,
            media: media.visible ? media.restBox.height : 0,
            system: system.visible ? system.restBox.height : 0,
            limits: limits.visible ? limits.restBox.height : 0
        })

    function othersOf(w: Item): var {
        return win.widgets.filter(o => o !== w && o.visible && o.restHeight > 0).map(o => o.restRect);
    }

    function touch(key: string): void {
        win.recent = [...win.recent.filter(k => k !== key), key];
    }

    function resolve(): void {
        if (win.carried)
            return;
        const order = win.widgets.filter(w => w.visible && w.restHeight > 0).sort((a, b) => win.recent.indexOf(a.key) - win.recent.indexOf(b.key));
        const kept = [];
        for (const w of order) {
            const r = w.restRect;
            if (kept.some(o => Placement.crowds(r, o, win.grid.gap))) {
                const to = Placement.freeSpot(r.x, r.y, r.width, r.height, kept, win.grid);
                w.moveTo(to.x, to.y);
                kept.push(Qt.rect(to.x, to.y, r.width, r.height));
            } else {
                kept.push(r);
            }
        }
    }

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
                    run: () => {
                        win.touch(w.key);
                        DesktopLayout.resize(w.key, size);
                    }
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
    onRestRectsChanged: tidy.restart()

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
        id: tidy

        interval: 250
        onTriggered: win.resolve()
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

    GlassSource {
        id: under

        anchors.fill: parent
        source: glass.source

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: win.raising || sheet.open ? desk : null
            live: true
        }
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: win.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.closeAll(null)
    }

    GridLines {
        x: win.area.x - win.grid.gap / 2
        y: win.area.y - win.grid.gap / 2
        width: win.area.width + win.grid.gap
        height: win.area.height + win.grid.gap
        pitch: Qt.vector2d(win.grid.px, win.grid.py)
        centre: win.carried ? Qt.point(win.carried.dragTo.x + win.carried.grabAt.x - x, win.carried.dragTo.y + win.carried.grabAt.y - y) : Qt.point(0, 0)
        reach: Appearance.padding.huge * 14
        colour: Appearance.withAlpha(Appearance.colour.text, 0.28)
        opacity: gridShown.value
        visible: gridShown.value > 0.002

        Follow {
            id: gridShown

            target: win.carried ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
        }
    }

    Item {
        id: desk

        anchors.fill: parent
        opacity: shown.value

        ClockWidget {
            id: clock

            parent: clock.overlaid ? above : desk
            output: win.output
            backdrop: clock.overlaid ? under : glass
            area: win.area
            grid: win.grid
            neighbours: win.othersOf(clock)
            heights: win.heights
            visible: win.cfg.clock
            running: win.live
            ink: backdrop.lightInk ? Appearance.colour.paper : Appearance.colour.ink
            backed: backdrop.busy
            onOpened: win.closeAll(clock)
            onMoved: {
                win.touch(clock.key);
                win.settle();
            }
            onMenuAsked: (x, y) => win.menu(clock, x, y)
        }

        WeatherWidget {
            id: weather

            parent: weather.overlaid ? above : desk
            output: win.output
            backdrop: weather.overlaid ? under : glass
            area: win.area
            grid: win.grid
            neighbours: win.othersOf(weather)
            heights: win.heights
            visible: win.cfg.weather && Weather.ready
            onOpened: win.closeAll(weather)
            onMoved: {
                win.touch(weather.key);
                win.settle();
            }
            onMenuAsked: (x, y) => win.menu(weather, x, y)
        }

        MediaWidget {
            id: media

            parent: media.overlaid ? above : desk
            output: win.output
            backdrop: media.overlaid ? under : glass
            area: win.area
            grid: win.grid
            neighbours: win.othersOf(media)
            heights: win.heights
            visible: win.cfg.media && Media.hasTrack
            running: win.live
            onOpened: win.closeAll(media)
            onMoved: {
                win.touch(media.key);
                win.settle();
            }
            onMenuAsked: (x, y) => win.menu(media, x, y)
        }

        SystemWidget {
            id: system

            parent: system.overlaid ? above : desk
            output: win.output
            backdrop: system.overlaid ? under : glass
            area: win.area
            grid: win.grid
            neighbours: win.othersOf(system)
            heights: win.heights
            visible: win.cfg.system
            running: win.live && win.cfg.system
            onOpened: win.closeAll(system)
            onMoved: {
                win.touch(system.key);
                win.settle();
            }
            onMenuAsked: (x, y) => win.menu(system, x, y)
        }

        AgentLimitsWidget {
            id: limits

            parent: limits.overlaid ? above : desk
            output: win.output
            backdrop: limits.overlaid ? under : glass
            area: win.area
            grid: win.grid
            neighbours: win.othersOf(limits)
            heights: win.heights
            visible: win.cfg.limits && AgentLimits.anyEnabled
            running: win.live && win.cfg.limits
            onOpened: win.closeAll(limits)
            onMoved: {
                win.touch(limits.key);
                win.settle();
            }
            onMenuAsked: (x, y) => win.menu(limits, x, y)
        }
    }

    Item {
        id: above

        anchors.fill: parent
        opacity: shown.value
    }

    ActionSheet {
        id: sheet

        anchors.fill: parent
        z: 100
        backdrop: under
    }
}
