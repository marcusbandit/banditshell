pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.calculator
import qs.modules.cheatsheet
import qs.modules.clipboard
import qs.modules.keyboard
import qs.modules.media
import qs.modules.keyring
import qs.modules.menu
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.session
import qs.modules.sidebar
import qs.modules.wallpaper
import qs.modules.windows
import qs.services

PanelWindow {
    id: win

    readonly property Menus menus: menuLayer
    readonly property Launcher launcher: launcherLayer

    readonly property ClipboardPanel clipboard: clipLayer
    readonly property WallpaperPicker wallpapers: wallpaperLayer
    readonly property SessionMenu session: sessionLayer

    readonly property CalculatorPanel calculator: calcLayer

    readonly property OnScreenKeyboard keyboard: keyboardLayer

    readonly property KeyringPrompt keyring: keyringLayer

    readonly property CheatSheet hotkeys: cheatLayer

    readonly property MediaController media: mediaLayer

    readonly property NotificationTray notifications: popups
    readonly property TopNotch notch: topNotch

    readonly property var statusItems: sidebar.menuItems
    readonly property var statusKeys: sidebar.menuKeys
    readonly property bool cursorOnShell: onShell.hovered

    readonly property var usage: Usage

    Component.onCompleted: Shell.register(win)
    Component.onDestruction: Shell.unregister(win)

    function openMenu(key: string, pin = true): bool {
        const entry = sidebar.entryFor(key);
        const source = sidebar.iconFor(key);
        if (!entry || !source)
            return false;

        const centre = source.mapToItem(win.contentItem, source.width / 2, source.height / 2);
        menuLayer.show(key, entry.title, entry.body, centre.y, pin);
        return true;
    }

    Timer {
        id: whatsNewSummon

        interval: 2500
        repeat: false

        running: WhatsNew.ready

        onTriggered: {

            if (WhatsNew.pending.length > 0 && Shell.forScreen("") === win)
                win.openMenu("update", true);
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    WlrLayershell.keyboardFocus: keyringLayer.needsKeyboard || launcherLayer.open || clipLayer.open || wallpaperLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || mediaLayer.open || menuLayer.needsKeyboard || popups.wantsEscape || topNotch.wantsEscape ? WlrKeyboardFocus.Exclusive : menuLayer.wantsEscape ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    WlrLayershell.namespace: "banditshell"

    readonly property int border: Appearance.sizes.border

    mask: Region {
        width: win.width
        height: win.height

        Region {
            intersection: Intersection.Subtract
            x: chassis.holeX
            y: chassis.holeY
            width: chassis.holeWidth
            height: chassis.holeHeight
        }

        Region {
            intersection: Intersection.Combine
            item: menuLayer.open ? menuLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: launcherLayer.open ? launcherLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: clipLayer.open ? clipLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: wallpaperLayer.open ? wallpaperLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: sessionLayer.open ? sessionLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: calcLayer.open ? calcLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: keyboardLayer.open ? keyboardLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: cheatLayer.open ? cheatLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: mediaLayer.open ? mediaLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : launchEdge.maskItem
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : windowEdge.maskItem
        }

        Region {
            intersection: Intersection.Combine
            item: windowEdge.lifted ? windowEdge.grabItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: topNotch.active ? topNotch.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : topNotch.grabItem
        }

        Region {
            intersection: Intersection.Combine
            item: popups.any ? popups.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : popups.grabItem
        }

        Region {
            intersection: Intersection.Combine
            item: keyringLayer.open ? keyringLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: volumeRail.active ? volumeRail.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : volumeRail.grabItem
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : settingsCorner.maskItem
        }

    }

    FocusScope {
        id: body

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;

            if (launcherLayer.open)
                launcherLayer.hide();
            else if (clipLayer.open)
                clipLayer.hide();
            else if (wallpaperLayer.open)
                wallpaperLayer.hide();
            else if (sessionLayer.open)
                sessionLayer.hide();
            else if (cheatLayer.open)
                cheatLayer.hide();
            else if (calcLayer.open)
                calcLayer.hide();
            else if (mediaLayer.open)
                mediaLayer.hide();
            else if (menuLayer.wantsEscape)
                menuLayer.hide();
            else if (topNotch.wantsEscape)
                topNotch.pinned = false;
            else if (popups.wantsEscape)
                popups.pinned = false;
            else
                return;

            event.accepted = true;
        }

        HoverHandler {
            id: onShell
        }

        readonly property var barBlobs: chassis.sidebar ? sidebar.blobs.map(b => ({
                    x: b.x + sidebar.x,
                    y: b.y + sidebar.y,
                    w: b.w,
                    h: b.h,
                    radius: b.radius,
                    smooth: b.smooth
                })) : []

        Chassis {
            id: chassis

            anchors.fill: parent

            panels: [...body.barBlobs, ...menuLayer.blobs, ...launcherLayer.blobs, ...clipLayer.blobs, ...wallpaperLayer.blobs, ...topNotch.blobs, ...popups.blobs, ...launchEdge.blobs, ...volumeRail.blobs, ...sessionLayer.blobs, ...calcLayer.blobs, ...keyboardLayer.blobs, ...tip.blobs, ...micIndicator.blobs, ...launchNotice.blobs, ...settingsCorner.blobs]
        }

        Sidebar {
            id: sidebar

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: win.border
            anchors.bottomMargin: win.border
            width: chassis.barWidth
            visible: chassis.sidebar

            menusShown: menuLayer.open

            pullSpan: Math.hypot(win.width, win.height)
        }

        Connections {
            target: sidebar.status

            function onRequested(key: string, deliberate: bool): void {
                if (deliberate && menuLayer.pinned && menuLayer.currentKey === key) {
                    menuLayer.hide();
                    return;
                }
                win.openMenu(key, deliberate);
            }

            function onReleased(): void {
                menuLayer.release();
            }
        }

        Connections {
            target: sidebar.tray

            function onRequested(key: string, deliberate: bool): void {
                if (deliberate && menuLayer.pinned && menuLayer.currentKey === key) {
                    menuLayer.hide();
                    return;
                }
                win.openMenu(key, deliberate);
            }

            function onReleased(): void {
                menuLayer.release();
            }
        }

        Connections {
            target: sidebar

            function onCalendarRequested(deliberate: bool): void {
                if (deliberate && menuLayer.pinned && menuLayer.currentKey === "calendar") {
                    menuLayer.hide();
                    return;
                }
                win.openMenu("calendar", deliberate);
            }

            function onCalendarPulled(): void {
                win.openMenu("calendar", true);
            }

            function onCalendarPullEnded(open: bool): void {
                if (!open)
                    menuLayer.hide();
            }

            function onUpdateRequested(deliberate: bool): void {
                if (deliberate && menuLayer.pinned && menuLayer.currentKey === "update") {
                    menuLayer.hide();
                    return;
                }
                win.openMenu("update", deliberate);
            }
        }

        NotificationTray {
            id: popups

            anchors.fill: parent
            inset: win.border + Appearance.sizes.gap

            edgeInset: win.border

            keyboardHeld: launcherLayer.open || clipLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || menuLayer.needsKeyboard
        }

        Menus {
            id: menuLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border

            shellHovered: onShell.hovered

            warmSource: sidebar.status.items

            keyboardHeld: launcherLayer.open || clipLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open
        }

        Launcher {
            id: launcherLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border

            onOpenChanged: if (open) {
                Keyring.refuse();
                sessionLayer.hide();
                cheatLayer.hide();
                wallpaperLayer.hide();
                clipLayer.hide();
                calcLayer.hide();
                mediaLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        ClipboardPanel {
            id: clipLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border

            onOpenChanged: if (open) {
                Keyring.refuse();
                launcherLayer.hide();
                wallpaperLayer.hide();
                sessionLayer.hide();
                cheatLayer.hide();
                calcLayer.hide();
                mediaLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        WallpaperPicker {
            id: wallpaperLayer

            anchors.fill: parent

            screen: win.screen?.name ?? ""

            onOpenChanged: if (open) {
                Keyring.refuse();
                launcherLayer.hide();
                clipLayer.hide();
                mediaLayer.hide();
            }
        }

        SessionMenu {
            id: sessionLayer

            anchors.fill: parent
            border: win.border

            onOpenChanged: if (open) {
                Keyring.refuse();
                launcherLayer.hide();
                clipLayer.hide();
                cheatLayer.hide();
                calcLayer.hide();
                mediaLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        CalculatorPanel {
            id: calcLayer

            anchors.fill: parent
            originX: chassis.barWidth

            onOpenChanged: if (open) {
                Keyring.refuse();
                launcherLayer.hide();
                clipLayer.hide();
                wallpaperLayer.hide();
                sessionLayer.hide();
                cheatLayer.hide();
                mediaLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        OnScreenKeyboard {
            id: keyboardLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border
        }

        CheatSheet {
            id: cheatLayer

            anchors.fill: parent
            holeX: chassis.holeX
            holeY: chassis.holeY
            holeWidth: chassis.holeWidth
            holeHeight: chassis.holeHeight

            onOpenChanged: if (open) {
                Keyring.refuse();
                launcherLayer.hide();
                clipLayer.hide();
                sessionLayer.hide();
                calcLayer.hide();
                mediaLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }

            Component.onCompleted: {
                cheatLayer.board = Config.get("cheatsheet.board");
                cheatLayer.symbols = Config.get("cheatsheet.symbols");
            }

            onBoardChanged: {
                if (cheatLayer.board !== Config.get("cheatsheet.board"))
                    Config.set("cheatsheet.board", cheatLayer.board);
            }

            onSymbolsChanged: {
                if (cheatLayer.symbols !== Config.get("cheatsheet.symbols"))
                    Config.set("cheatsheet.symbols", cheatLayer.symbols);
            }
        }

        MediaController {
            id: mediaLayer

            anchors.fill: parent
            border: win.border

            onOpenChanged: if (open) {
                launcherLayer.hide();
                clipLayer.hide();
                wallpaperLayer.hide();
                sessionLayer.hide();
                cheatLayer.hide();
                calcLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        Connections {
            target: Config

            function onValuesChanged(): void {
                cheatLayer.board = Config.get("cheatsheet.board");
                cheatLayer.symbols = Config.get("cheatsheet.symbols");
            }
        }

        LaunchEdge {
            id: launchEdge

            property var target: null

            anchors.fill: parent
            border: win.border
            span: launcherLayer.open ? wallpaperLayer.panelWidth : launcherLayer.panelWidth

            armed: true

            property bool aimed: false

            property var leaving: null

            function aim(): void {
                if (launchEdge.aimed)
                    return;
                launchEdge.aimed = true;
                launchEdge.target = wallpaperLayer.open ? null : launcherLayer.open ? wallpaperLayer : launcherLayer;
                launchEdge.leaving = launchEdge.target === wallpaperLayer ? launcherLayer : null;
            }

            onPressed: {
                launchEdge.aimed = false;
                launchEdge.aim();
            }

            onDragged: fraction => {
                launchEdge.aim();
                launchEdge.target?.dragTo(fraction);

                launchEdge.leaving?.dragTo(1 - fraction);
            }

            onFinished: open => {
                launchEdge.aim();
                launchEdge.target?.dragEnd(open);

                launchEdge.leaving?.dragEnd(!open);
                launchEdge.aimed = false;
                launchEdge.target = null;
                launchEdge.leaving = null;
            }
        }

        WindowEdge {
            id: windowEdge

            anchors.fill: parent
            screen: win.screen
            border: win.border

            fallback: launchEdge

            holeX: chassis.holeX
            holeY: chassis.holeY
            holeWidth: chassis.holeWidth
            holeHeight: chassis.holeHeight

            blocked: keyboardLayer.open || launcherLayer.open || clipLayer.open || wallpaperLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || menuLayer.open
        }

        TopNotch {
            id: topNotch

            anchors.fill: parent
            border: win.border

            keyboardHeld: launcherLayer.open || clipLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || menuLayer.needsKeyboard
        }

        MicIndicator {
            id: micIndicator

            anchors.fill: parent
            border: win.border
        }

        LaunchNotice {
            id: launchNotice

            anchors.fill: parent
            border: win.border
        }

        VolumeRail {
            id: volumeRail

            anchors.fill: parent
            border: win.border
        }

        SettingsCorner {
            id: settingsCorner

            anchors.fill: parent
            border: win.border

            onActivated: Settings.toggle(win.screen.name)
        }

        KeyringPrompt {
            id: keyringLayer

            anchors.fill: parent

            holeX: chassis.holeX
            holeY: chassis.holeY
            holeWidth: chassis.holeWidth
            holeHeight: chassis.holeHeight
        }

        Tooltip {
            id: tip

            anchors.fill: parent
        }
    }
}
