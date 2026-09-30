pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components

Item {
    id: root

    required property real originX

    required property real inset

    readonly property bool open: currentKey !== ""

    property var warmSource: []
    property var warm: []

    onWarmSourceChanged: {
        const next = root.warmSource.filter(e => !!e.body).map(e => ({
                    key: e.key,
                    body: e.body
                }));
        const now = root.warm;
        if (now.length === next.length && now.every((e, i) => e.key === next[i].key && e.body === next[i].body))
            return;
        root.warm = next;
    }

    readonly property Item maskItem: ghost

    property string pinnedKey: ""

    readonly property bool pinned: root.pinnedKey !== "" && root.pinnedKey === root.currentKey

    property bool sawPointer: false

    readonly property bool needsKeyboard: root.open && Prompts.activeIn(root.shellWindow)

    readonly property var shellWindow: QsWindow.window

    readonly property bool wantsEscape: root.pinnedKey !== ""

    property bool keyboardHeld: false

    function claimKeys(): void {
        if (root.open && root.wantsEscape && !root.needsKeyboard && !root.keyboardHeld)
            keys.forceActiveFocus();
    }

    onWantsEscapeChanged: {
        if (root.wantsEscape)
            Qt.callLater(root.claimKeys);
        else
            keys.focus = false;
    }

    onNeedsKeyboardChanged: {
        if (!root.needsKeyboard)
            Qt.callLater(root.claimKeys);
    }

    readonly property var blobs: panel.width > 0 ? [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: panel.cornerRadius,
            smooth: Math.min(Appearance.sizes.melt, Math.min(panel.width, panel.height) / 2)
        }
    ] : []

    property real requestedCentre: 0

    property string currentKey: ""
    property string currentTitle: ""

    property Component currentBody: null

    property rect held: Qt.rect(0, 0, 0, 0)

    readonly property rect panelRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)

    function syncGhost(): void {
        const r = root.panelRect;
        if (!ghostPointer.hovered) {
            root.held = r;
            return;
        }
        const x = Math.min(root.held.x, r.x);
        const y = Math.min(root.held.y, r.y);
        root.held = Qt.rect(x, y, Math.max(root.held.x + root.held.width, r.x + r.width) - x, Math.max(root.held.y + root.held.height, r.y + r.height) - y);
    }

    onPanelRectChanged: root.syncGhost()

    Connections {
        target: ghostPointer

        function onHoveredChanged(): void {
            root.syncGhost();
        }
    }

    readonly property bool hovered: pointer.hovered || ghostPointer.hovered

    property bool shellHovered: false

    onShellHoveredChanged: {
        if (root.shellHovered) {
            root.sawPointer = true;
            return;
        }
        root.release();
    }

    function show(key: string, title: string, body: Component, centreY: real, pin: bool): void {

        const wasClosed = !root.open;

        const swapping = key !== root.currentKey;
        const sameBody = body === root.currentBody;

        grace.stop();
        root.currentKey = key;
        root.currentTitle = title;
        root.currentBody = body;
        if (swapping && sameBody)
            panel.swap();
        root.requestedCentre = centreY;
        if (wasClosed) {

            centre.snap();

            root.sawPointer = root.shellHovered;
        }
        reveal.target = 1;

        if (pin)
            root.pinnedKey = key;
    }

    function hide(): void {
        grace.stop();
        root.currentKey = "";

        root.pinnedKey = "";
        reveal.target = 0;

        root.held = Qt.rect(0, 0, 0, 0);
    }

    function release(): void {
        if (root.open && !root.pinned)
            grace.restart();
    }

    function push(fraction: real): void {
        reveal.target = Math.max(reveal.epsilon, 1 - fraction);
    }

    function pushEnd(committed: bool): void {
        if (committed)
            root.hide();
        else
            reveal.target = 1;
    }

    function clampCentre(y: real): real {
        const half = panel.implicitHeight / 2;
        return Math.max(root.inset + half, Math.min(y, root.height - root.inset - half));
    }

    Timer {
        id: grace
        interval: Appearance.anim.grace

        onTriggered: {

            if (root.pinned || root.hovered || root.shellHovered || root.needsKeyboard)
                return;

            if (!root.sawPointer) {
                root.pinnedKey = root.currentKey;
                return;
            }

            root.hide();
        }
    }

    Follow {
        id: centre

        target: root.clampCentre(root.requestedCentre)

        speed: Appearance.anim.trackSpeed
    }

    Follow {
        id: reveal
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Pull {
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        dirX: -1
        dirY: 0

        angle: Appearance.sizes.pullAngleEdge

        travel: panel.fullWidth

        armed: root.open

        onPulled: fraction => root.push(fraction)
        onFinished: committed => root.pushEnd(committed)

    }

    MenuPanel {
        id: panel

        title: root.currentTitle

        key: root.currentKey
        body: root.currentBody
        warm: root.warm
        available: root.height - root.inset * 2
        reveal: reveal.value

        x: root.originX

        y: centre.value - height / 2

        HoverHandler {
            id: pointer
        }
    }

    Item {
        id: ghost

        x: root.held.x
        y: root.held.y
        width: root.held.width
        height: root.held.height

        HoverHandler {
            id: ghostPointer
        }
    }

    Item {
        id: keys

        Keys.onPressed: event => {

            if (event.key === Qt.Key_Escape && root.open) {
                root.hide();
                event.accepted = true;
            }
        }
    }
}
