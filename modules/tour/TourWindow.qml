pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import "../../services/tour.js" as Logic

PanelWindow {
    id: win

    required property var shell

    readonly property string output: win.screen?.name ?? ""
    readonly property var frame: win.shell?.frame ?? null

    readonly property var flags: ({
            launcher: win.shell?.launcher?.open ?? false,
            island: win.shell?.island?.expanded ?? false,
            sidebar: (win.shell?.menus?.open ?? false) || (!!win.frame?.rail && win.frame.railOpen > 0.9),
            hotkeys: win.shell?.hotkeys?.open ?? false,
            settings: Panels.isOpen("settings")
        })

    readonly property string layout: !win.frame?.sidebar ? "none" : win.frame.rail ? "rail" : "full"

    onFlagsChanged: Tour.report(win.output, win.flags, win.layout)
    onLayoutChanged: Tour.report(win.output, win.flags, win.layout)
    Component.onCompleted: Tour.report(win.output, win.flags, win.layout)
    Component.onDestruction: Tour.forget(win.output)

    readonly property bool mine: win.output === Tour.screen
    readonly property string mode: Tour.parting ? "parting" : !Tour.running ? "" : Tour.phase === "finished" ? "finished" : Tour.phase
    readonly property bool wanted: win.mine && win.mode !== "" && !(win.shell?.covering ?? false) && !(win.shell?.underFullscreen ?? false)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "banditshell-tour"

    mask: Region {
        item: shown.value > 0.5 ? card : null
    }

    readonly property real band: Appearance.sizes.border
    readonly property real gap: Appearance.padding.large
    readonly property var bounds: ({
            x: win.band + win.gap,
            y: win.band + win.gap,
            w: win.width - (win.band + win.gap) * 2,
            h: win.height - (win.band + win.gap) * 2
        })

    readonly property real launcherWidth: win.shell?.launcher?.panelWidth ?? Appearance.sizes.launcherWidth
    readonly property real islandWidth: win.shell?.island?.largeWidth ?? Appearance.sizes.notificationWidth
    readonly property real corner: Math.max(Appearance.sizes.minTarget, win.band + Appearance.sizes.cornerIcon + Appearance.padding.normal * 2)

    readonly property real menuEdge: {
        const menus = win.shell?.menus;
        const item = menus?.open ? menus.maskItem : null;
        return item ? item.mapToItem(null, item.width, 0).x : 0;
    }

    readonly property var spot: {
        const size = {
            w: card.width,
            h: card.height
        };
        const centre = {
            x: win.width / 2,
            y: win.height / 2,
            w: 0,
            h: 0
        };
        const id = win.mode === "ask" || win.mode === "seen" ? Tour.step?.id ?? "" : "";
        switch (id) {
        case "launcher":
            return Logic.place(size, {
                x: (win.width - win.launcherWidth) / 2,
                y: win.band,
                w: win.launcherWidth,
                h: win.height - win.band
            }, win.bounds, ["rightBottom", "leftBottom"], [], win.gap);
        case "island":
            return Logic.place(size, {
                x: (win.width - win.islandWidth) / 2,
                y: 0,
                w: win.islandWidth,
                h: win.height / 3
            }, win.bounds, ["rightTop", "leftTop", "below"], [], win.gap);
        case "sidebar":
            return Logic.place(size, {
                x: 0,
                y: 0,
                w: Math.max(win.frame?.fullBarWidth ?? win.band, win.menuEdge),
                h: win.height
            }, win.bounds, ["right"], [], win.gap);
        case "settings":
            return Logic.place(size, {
                x: win.width - win.corner,
                y: win.height - win.corner,
                w: win.corner,
                h: win.corner
            }, win.bounds, ["leftBottom", "above"], [
                {
                    x: 0,
                    y: 0,
                    w: (win.frame?.barWidth ?? win.band) + Appearance.sizes.settingsWidth + win.gap,
                    h: win.height
                }
            ], win.gap);
        }
        return Logic.place(size, centre, win.bounds, ["centre"], [], win.gap);
    }

    Follow {
        id: shown

        target: win.wanted ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
    }

    Travel {
        id: glideX

        target: win.spot.x
    }

    Travel {
        id: glideY

        target: win.spot.y
    }

    onWantedChanged: if (win.wanted && shown.value < 0.05) {
        glideX.snap();
        glideY.snap();
    }

    function showMe(id: string): void {
        if (id === "launcher")
            win.shell?.launcher?.show();
        else if (id === "island" && win.shell?.island)
            win.shell.island.pinned = true;
        else if (id === "hotkeys")
            win.shell?.hotkeys?.show();
        else if (id === "settings")
            Panels.open("settings", {
                screen: win.output
            });
    }

    Item {
        anchors.fill: parent

        TourCard {
            id: card

            x: glideX.value
            y: glideY.value + (1 - shown.value) * Appearance.padding.large
            width: win.islandWidth
            height: implicitHeight
            opacity: shown.value
            visible: shown.value > 0.001

            mode: win.mode || "ask"
            title: win.mode === "finished" ? "Tour done" : win.mode === "parting" ? "Tour put away" : Tour.words.title ?? ""
            payoff: win.mode === "finished" ? "Everything else in the shell hangs off these five." : win.mode === "parting" ? "It is there whenever you want it." : Tour.words.payoff ?? ""
            ask: win.mode === "finished" || win.mode === "parting" ? "Open it again from Settings, About, or type tour in the launcher." : Tour.words.ask ?? ""
            away: Tour.words.away ?? ""
            chord: Tour.step?.chord ?? ""
            pointing: win.spot.side ?? ""
            number: Tour.number
            count: Tour.steps.length
            offersButton: Tour.step?.button ?? false

            onPassed: Tour.pass()
            onQuit: Tour.quit()
            onFinished: Tour.finish()
            onShowMe: win.showMe(Tour.step?.id ?? "")
            onClosed: Tour.parting = false
        }
    }
}
