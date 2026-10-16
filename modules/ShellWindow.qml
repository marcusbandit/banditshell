pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.calculator
import qs.modules.cheatsheet
import qs.modules.clipboard
import qs.modules.island
import qs.modules.keyboard
import qs.modules.media
import qs.modules.password
import qs.modules.menu
import qs.modules.quickcontrols
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.session
import qs.modules.settings
import qs.modules.sidebar
import qs.modules.stream
import qs.modules.wallpaper
import qs.modules.windows
import qs.services

PanelWindow {
    id: win

    readonly property Menus menus: menuLayer
    readonly property Launcher launcher: launcherLayer

    readonly property LazyPanel clipboard: clipLayer
    readonly property LazyPanel wallpapers: wallpaperLayer
    readonly property LazyPanel session: sessionLayer

    readonly property LazyPanel calculator: calcLayer

    readonly property LazyPanel keyboard: keyboardLayer

    readonly property LazyPanel keyring: keyringLayer

    readonly property LazyPanel hotkeys: cheatLayer

    readonly property LazyPanel media: mediaLayer

    readonly property LazyPanel settings: settingsLayer

    readonly property NotificationTray notifications: popups
    readonly property Island island: islandLayer
    readonly property QuickControls quickControls: quickLayer

    readonly property var statusItems: sidebar.menuItems
    readonly property var statusKeys: sidebar.menuKeys
    readonly property bool cursorOnShell: onShell.hovered

    readonly property var usage: Usage
    readonly property var clipboardHistory: Clipboard

    readonly property var panels: [launcherLayer, clipLayer, wallpaperLayer, sessionLayer, cheatLayer, calcLayer, mediaLayer]

    readonly property bool panelOpen: win.panels.some(panel => panel.open)
    readonly property bool covering: win.panels.some(panel => panel.open && panel !== mediaLayer)

    property bool claiming: false

    Component.onCompleted: {
        Shell.register(win);
        resumer.start();
    }
    Component.onDestruction: Shell.unregister(win)

    readonly property var named: ({
            launcher: launcherLayer,
            clipboard: clipLayer,
            wallpapers: wallpaperLayer,
            session: sessionLayer,
            calculator: calcLayer,
            hotkeys: cheatLayer,
            media: mediaLayer
        })

    readonly property string memoryKey: `screen ${win.screen?.name ?? ""}`

    readonly property var remembered: ({
            panel: Object.keys(win.named).find(name => win.named[name].open) ?? "",
            menu: menuLayer.pinned ? menuLayer.currentKey : "",
            keyboard: keyboardLayer.open,
            quickControls: quickLayer.pinned,
            notifications: popups.pinned,
            island: islandLayer.pinned
        })

    property bool resumed: false

    onRememberedChanged: if (win.resumed)
        Relaunch.keep(win.memoryKey, win.remembered)

    Timer {
        id: resumer

        property var was: null
        property int tries: 0

        interval: 200
        repeat: true

        onTriggered: {
            if (!win.resumed) {
                resumer.was = Relaunch.recall(win.memoryKey);
                win.named[resumer.was?.panel ?? ""]?.show();
                if (resumer.was?.keyboard)
                    keyboardLayer.show();
                quickLayer.pinned = !!resumer.was?.quickControls;
                popups.pinned = !!resumer.was?.notifications;
                islandLayer.pinned = !!resumer.was?.island;
                win.resumed = true;
            }
            const menu = resumer.was?.menu ?? "";
            if (!menu || menuLayer.open || win.openMenu(menu, true) || ++resumer.tries >= 25)
                resumer.stop();
        }
    }

    function closeOthers(opening: Item): void {
        Keyring.refuse();
        for (const window of Shell.windows)
            window.closePanels(opening, window === win);
    }

    function closePanels(opening: Item, here: bool): void {
        for (const panel of win.panels)
            if (panel !== opening)
                panel.hide();
        if (quickLayer !== opening)
            quickLayer.pinned = false;
        if (menuLayer.needsKeyboard)
            menuLayer.hide();
        if (here)
            return;
        popups.pinned = false;
        islandLayer.pinned = false;
    }

    function openMenu(key: string, pin = true): bool {
        const entry = sidebar.entryFor(key);
        const beside = streamPanel.anchorFor(key);
        const source = beside ?? sidebar.iconFor(key);
        if (!entry || !source)
            return false;

        const centre = source.mapToItem(menuLayer, source.width / 2, source.height / 2);
        menuLayer.show(key, entry.heading ?? entry.title, entry.body, beside ? centre.x : centre.y, pin, !!beside);
        return true;
    }

    function act(notice: var): void {
        if (notice.mock && notice.kind !== "music")
            return;
        switch (notice.kind) {
        case "launch":
            islandLayer.close();
            Hypr.focusClient([].concat(...Object.values(Hypr.clients)).find(c => Launching.fits(notice.rec, Hypr.classOf(c))) ?? null);
            return;
        case "dictation":
            islandLayer.close();
            clipLayer.build().setTab(1);
            clipLayer.show();
            return;
        case "recording":
            ScreenRecorder.stop();
            return;
        case "music":
            if (notice.origin && !mediaLayer.open) {
                islandLayer.handOff();
                mediaLayer.build().showFrom(notice.origin);
            } else {
                islandLayer.close();
                mediaLayer.show();
            }
            break;
        case "notifications":
            popups.pinned = true;
            return;
        case "update":
            if (!win.openMenu("update", true))
                Settings.show(win.screen?.name ?? "", "updates");
            break;
        case "kernel":
            Pacman.upgrade();
            break;
        case "restart":
            sessionLayer.show();
            break;
        case "download":
            Files.reveal(notice.path);
            break;
        }
        if (notice.key)
            Notices.settle(notice.key);
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

    WlrLayershell.keyboardFocus: (keyringLayer.item?.needsKeyboard ?? false) || (settingsLayer.item?.holdsKeys ?? false) || win.covering || win.claiming || quickLayer.pinned || menuLayer.needsKeyboard ? WlrKeyboardFocus.Exclusive : mediaLayer.open || menuLayer.wantsEscape || popups.wantsEscape || islandLayer.wantsEscape || settingsLayer.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
            intersection: Intersection.Subtract
            item: mediaLayer.open ? islandLayer.passItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: settingsLayer.open ? settingsLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: settingsLayer.open ? (settingsLayer.item?.toastMask ?? null) : null
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
            item: Appearance.bare ? null : islandLayer.grabItem
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
            item: quickLayer.active ? quickLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : quickLayer.grabItem
        }

        Region {
            intersection: Intersection.Combine
            item: Appearance.bare ? null : settingsCorner.maskItem
        }

    }

    IdleInhibitor {
        window: win
        enabled: Idle.awake
    }

    FocusScope {
        id: body

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;

            const open = win.panels.find(panel => panel.open);
            if (open)
                open.hide();
            else if (quickLayer.pinned)
                quickLayer.pinned = false;
            else if (menuLayer.wantsEscape)
                menuLayer.hide();
            else if (islandLayer.wantsEscape)
                islandLayer.pinned = false;
            else if (popups.wantsEscape)
                popups.pinned = false;
            else
                return;

            event.accepted = true;
        }

        HoverHandler {
            id: onShell
        }

        Window.onActiveChanged: if (body.Window.active)
            win.claiming = false

        Timer {
            id: claim

            interval: 400
            onTriggered: win.claiming = false
        }

        function lowered(blobs: var): var {
            return chassis.streamReach ? blobs.map(b => Object.assign({}, b, {
                        y: b.y + chassis.streamReach
                    })) : blobs;
        }

        readonly property var barBlobs: chassis.sidebar ? sidebar.blobs.map(b => ({
                    x: b.x + sidebar.x,
                    y: b.y + sidebar.y,
                    w: b.w,
                    h: b.h,
                    radius: b.radius,
                    smooth: b.smooth
                })) : []

        WallpaperCover {
            anchors.fill: parent

            output: win.screen?.name ?? ""
            wanted: wallpaperLayer.open
        }

        Chassis {
            id: chassis

            anchors.fill: parent

            panels: [...body.barBlobs, ...body.lowered([...menuLayer.blobs, ...launcherLayer.blobs, ...clipLayer.blobs, ...wallpaperLayer.blobs, ...popups.blobs, ...launchEdge.blobs, ...quickLayer.blobs, ...sessionLayer.blobs, ...calcLayer.blobs, ...settingsLayer.blobs]), ...keyboardLayer.blobs, ...tip.blobs, ...body.lowered(settingsCorner.blobs)]
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

            modeIcon: SettingsState.modeIcon
        }

        StreamPanel {
            id: streamPanel

            anchors.fill: parent
            reach: chassis.streamReach

            openKey: menuLayer.fromTop ? menuLayer.currentKey : ""

            onMenuRequested: key => {
                if (menuLayer.pinned && menuLayer.currentKey === key)
                    menuLayer.hide();
                else
                    win.openMenu(key, true);
            }
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
            anchors.topMargin: chassis.streamReach
            inset: win.border + Appearance.sizes.gap

            edgeInset: win.border

            keyboardHeld: win.panelOpen || menuLayer.needsKeyboard
        }

        Menus {
            id: menuLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach
            originX: chassis.barWidth
            inset: win.border

            shellHovered: onShell.hovered

            warmSource: sidebar.status.items

            keyboardHeld: win.panelOpen
        }

        Launcher {
            id: launcherLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach
            originX: chassis.barWidth
            inset: win.border

            onOpenChanged: if (open)
                win.closeOthers(launcherLayer)
        }

        LazyPanel {
            id: clipLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach

            onOpenChanged: if (open)
                win.closeOthers(clipLayer)

            panel: ClipboardPanel {
                originX: chassis.barWidth
                inset: win.border
            }
        }

        LazyPanel {
            id: wallpaperLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach

            onOpenChanged: if (open)
                win.closeOthers(wallpaperLayer)

            panel: WallpaperPicker {
                screen: win.screen?.name ?? ""
            }
        }

        LazyPanel {
            id: sessionLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach

            onOpenChanged: if (open)
                win.closeOthers(sessionLayer)

            panel: SessionMenu {
                border: win.border
            }
        }

        LazyPanel {
            id: calcLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach

            onOpenChanged: if (open)
                win.closeOthers(calcLayer)

            panel: CalculatorPanel {
                originX: chassis.barWidth
            }
        }

        LazyPanel {
            id: keyboardLayer

            anchors.fill: parent

            needed: Tablet.folded && Config.values.tablet.autoKeyboard

            panel: OnScreenKeyboard {
                originX: chassis.barWidth
                inset: win.border

                onDismissed: {
                    for (const window of Shell.windows)
                        window.keyboard.hide();
                }
            }
        }

        LazyPanel {
            id: cheatLayer

            anchors.fill: parent

            onOpenChanged: if (open)
                win.closeOthers(cheatLayer)

            panel: CheatSheet {
                id: cheatSheet

                holeX: chassis.holeX
                holeY: chassis.holeY
                holeWidth: chassis.holeWidth
                holeHeight: chassis.holeHeight

                Component.onCompleted: {
                    cheatSheet.board = Config.get("cheatsheet.board");
                }

                onBoardChanged: {
                    if (cheatSheet.board !== Config.get("cheatsheet.board"))
                        Config.set("cheatsheet.board", cheatSheet.board);
                }

                Connections {
                    target: Config

                    function onValuesChanged(): void {
                        cheatSheet.board = Config.get("cheatsheet.board");
                    }
                }
            }
        }

        LazyPanel {
            id: mediaLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach

            onOpenChanged: {
                if (mediaLayer.open)
                    win.closeOthers(mediaLayer);
                win.claiming = mediaLayer.open && !body.Window.active;
                if (win.claiming)
                    claim.restart();
            }

            panel: MediaController {
                border: win.border
            }
        }

        LazyPanel {
            id: settingsLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach

            needed: Settings.open && Settings.screenName === (win.screen?.name ?? "")

            onOpenChanged: if (open)
                win.closeOthers(settingsLayer)

            panel: SettingsPanel {
                originX: chassis.barWidth
                band: win.border
                yielded: win.panelOpen || menuLayer.open || Settings.away || (quickLayer.active && farEdge > win.width - quickLayer.panelWidth)
            }
        }

        LaunchEdge {
            id: launchEdge

            property var target: null

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach
            border: win.border
            span: launcherLayer.open ? wallpaperLayer.item?.panelWidth ?? wallpaperLayer.width : launcherLayer.panelWidth

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

        Island {
            id: islandLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach
            z: mediaLayer.open ? 1 : 0
            border: win.border
            edge: Math.max(0, chassis.topBand - chassis.streamReach)

            keyboardHeld: win.panelOpen || menuLayer.needsKeyboard

            onChosen: notice => win.act(notice)
            onEyeingMusicChanged: if (islandLayer.eyeingMusic)
                mediaLayer.build().warm()
        }

        QuickControls {
            id: quickLayer

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach
            border: win.border

            onPinnedChanged: if (pinned)
                win.closeOthers(quickLayer)
        }

        SettingsCorner {
            id: settingsCorner

            anchors.fill: parent
            anchors.topMargin: chassis.streamReach
            border: win.border

            onActivated: Settings.toggle(win.screen.name)
        }

        LazyPanel {
            id: keyringLayer

            anchors.fill: parent

            needed: Keyring.asked + Polkit.asked + PasswordRequest.asked > 0

            panel: PasswordPrompt {
                holeX: chassis.holeX
                holeY: chassis.holeY
                holeWidth: chassis.holeWidth
                holeHeight: chassis.holeHeight
            }
        }

        Tooltip {
            id: tip

            anchors.fill: parent
        }
    }
}
