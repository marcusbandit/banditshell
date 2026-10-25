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

    readonly property bool railWide: !!win.frame?.rail && win.frame.railOpen > 0.9

    readonly property var flags: ({
            launcher: win.shell?.launcher?.open ?? false,
            island: win.shell?.island?.expanded ?? false,
            sidebar: (win.shell?.menus?.open ?? false) || win.railWide,
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
    property string held: "ask"
    readonly property string face: win.mode || win.held

    onModeChanged: if (win.mode)
        win.held = win.mode

    readonly property bool wanted: win.mine && win.mode !== "" && !(win.shell?.covering ?? false) && !(win.shell?.underFullscreen ?? false)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: Tour.running || Tour.parting || shown.value > 0.001
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

    readonly property real settingsEdge: (win.frame?.barWidth ?? win.band) + Appearance.sizes.settingsWidth + win.gap

    readonly property real islandHeight: win.band + (win.shell?.island?.compactHeight ?? Appearance.font.line.small) + win.gap

    readonly property var aim: {
        const id = win.face === "ask" || win.face === "seen" ? Tour.step?.id ?? "" : "";
        switch (id) {
        case "launcher":
            return {
                target: {
                    x: (win.width - win.launcherWidth) / 2,
                    y: win.height - win.band - win.gap,
                    w: win.launcherWidth,
                    h: win.band + win.gap
                },
                sides: ["rightBottom", "leftBottom"],
                avoid: []
            };
        case "island":
            return {
                target: {
                    x: (win.width - win.islandWidth) / 2,
                    y: 0,
                    w: win.islandWidth,
                    h: win.islandHeight
                },
                sides: ["rightTop", "leftTop", "below"],
                avoid: []
            };
        case "sidebar":
            return {
                target: {
                    x: 0,
                    y: 0,
                    w: Math.max(win.frame?.fullBarWidth ?? win.band, win.menuEdge),
                    h: win.height
                },
                sides: ["right"],
                avoid: []
            };
        case "settings":
            return {
                target: {
                    x: win.width - win.corner,
                    y: win.height - win.corner,
                    w: win.corner,
                    h: win.corner
                },
                sides: ["leftBottom", "above"],
                avoid: [
                    {
                        x: 0,
                        y: 0,
                        w: win.settingsEdge,
                        h: win.height
                    }
                ],
                room: win.width - win.corner - win.gap - win.settingsEdge
            };
        }
        return {
            target: {
                x: win.width / 2,
                y: win.height / 2,
                w: 0,
                h: 0
            },
            sides: ["centre"],
            avoid: []
        };
    }

    readonly property var cardSize: ({
            w: card.width,
            h: card.height
        })

    readonly property var spot: Logic.place(win.cardSize, win.aim.target, win.bounds, win.aim.sides, win.aim.avoid, win.gap)

    readonly property var tail: Logic.tail({
        x: glideX.value,
        y: glideY.value,
        side: win.spot.side
    }, win.cardSize, win.aim.target)

    readonly property var closing: Logic.closing(Tour.chords.launcher ?? "", Appearance.bare)

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

    onWidthChanged: if (shown.value < 0.05) {
        glideX.snap();
        glideY.snap();
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
        else if (id === "sidebar")
            win.shell?.openMenu("calendar", true);
        else if (id === "hotkeys")
            win.shell?.hotkeys?.show();
        else if (id === "settings")
            Panels.open("settings", {
                screen: win.output
            });
    }

    function primary(): void {
        if (win.face === "seen")
            return Tour.pass();
        if (win.face === "finished") {
            Tour.finish();
            return win.showMe("launcher");
        }
        win.showMe(Tour.step?.id ?? "");
    }

    function secondary(): void {
        if (win.face === "finished")
            Tour.finish();
        else
            Tour.pass();
    }

    Item {
        anchors.fill: parent

        TourCard {
            id: card

            x: glideX.value
            y: glideY.value + (1 - shown.value) * Appearance.padding.large
            width: Math.min(implicitWidth, win.bounds.w, Math.max(win.islandWidth, win.aim.room ?? Infinity))
            height: implicitHeight
            opacity: shown.value
            visible: shown.value > 0.001

            mode: win.face
            title: win.face === "finished" ? win.closing.title : win.face === "parting" ? "Tour put away" : Tour.words.title ?? ""
            intro: win.face === "ask" || win.face === "seen" ? Tour.words.payoff ?? "" : ""
            line: win.face === "finished" ? win.closing.now : win.face === "parting" ? win.closing.again : win.face === "seen" ? Tour.words.away ?? "" : Tour.words.ask ?? ""
            after: win.face === "finished" ? win.closing.again : ""
            chord: win.face === "finished" ? Tour.chords.launcher ?? "" : Tour.step?.chord ?? ""
            primary: win.face === "ask" ? Tour.words.open ?? "" : win.face === "seen" ? "Next" : win.face === "finished" ? win.closing.open : ""
            secondary: win.face === "ask" ? "Skip this step" : win.face === "finished" ? "Close" : ""
            tailEdge: win.tail.edge
            tailAt: win.tail.at
            number: Tour.number
            count: Tour.steps.length

            onPrimaryPressed: win.primary()
            onSecondaryPressed: win.secondary()
            onQuit: Tour.quit()
            onClosed: Tour.parting = false
        }
    }
}
