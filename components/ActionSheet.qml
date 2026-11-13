pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var actions: []
    property bool open: false

    property int selected: 0

    property int worn: -1

    property real atX: 0
    property real atY: 0

    property int inner: -1
    property bool deep: false
    property int innerSelected: 0
    property int pending: -1

    readonly property var innerActions: root.inner >= 0 ? root.actions[root.inner]?.children ?? [] : []

    signal closed

    function popup(x: real, y: real, list: var, start: var): void {
        root.actions = list ?? [];
        root.leave();
        if (!root.actions.length)
            return;
        const at = typeof start === "number" && start >= 0 ? start : -1;
        root.atX = x;
        root.atY = y;
        root.worn = at;
        root.selected = Math.max(0, Math.min(root.actions.length - 1, at));

        main.snap();
        root.open = true;
    }

    function close(): void {
        if (!root.open)
            return;
        root.open = false;
        root.leave();
        root.closed();
    }

    function choose(index: int): void {
        if (index >= 0 && index < root.actions.length)
            root.selected = index;
    }

    function move(delta: int): void {
        if (root.deep) {
            root.innerSelected = Math.max(0, Math.min(root.innerActions.length - 1, root.innerSelected + delta));
            return;
        }
        root.leave();
        root.choose(Math.max(0, Math.min(root.actions.length - 1, root.selected + delta)));
    }

    function nests(index: int): bool {
        return !!root.actions[index]?.children?.length;
    }

    function enter(index: int): bool {
        if (!root.nests(index))
            return false;
        root.selected = index;
        if (root.inner !== index) {
            root.inner = index;
            root.innerSelected = 0;
            sub.snap();
        }
        return true;
    }

    function leave(): void {
        grace.stop();
        root.pending = -1;
        root.deep = false;
        root.inner = -1;
    }

    function run(action: var): void {
        root.close();
        if (action?.run)
            action.run();
    }

    function activate(index: int): void {
        if (root.deep) {
            root.run(root.innerActions[root.innerSelected]);
            return;
        }
        if (root.enter(index)) {
            root.deep = true;
            return;
        }
        root.run(root.actions[index]);
    }

    function key(event: var): bool {
        if (!root.open)
            return false;
        switch (event.key) {
        case Qt.Key_Down:
        case Qt.Key_Tab:
            root.move(1);
            return true;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            root.move(-1);
            return true;
        case Qt.Key_Right:
            if (!root.deep && root.enter(root.selected))
                root.deep = true;
            return true;
        case Qt.Key_Left:
            if (root.inner >= 0)
                root.leave();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activate(root.selected);
            return true;
        case Qt.Key_Escape:
            if (root.inner >= 0)
                root.leave();
            else
                root.close();
            return true;
        }
        return false;
    }

    function hoverMain(index: int): void {
        root.deep = false;
        if (root.inner >= 0 && index !== root.inner) {
            root.pending = index;
            grace.restart();
            return;
        }
        grace.stop();
        root.choose(index);
        root.enter(index);
    }

    function hoverInner(index: int): void {
        grace.stop();
        root.pending = -1;
        root.selected = root.inner;
        root.deep = true;
        root.innerSelected = index;
    }

    Timer {
        id: grace

        interval: 250
        onTriggered: {
            const to = root.pending;
            root.pending = -1;
            if (to < 0)
                return;
            if (!root.enter(to))
                root.inner = -1;
            root.choose(to);
        }
    }

    property real zoom: 1

    readonly property real sized: Math.min(root.zoom, Math.max(1, (root.height - root.edge * 2) / Math.max(1, main.plainHeight)))

    readonly property real edge: Appearance.padding.normal

    readonly property bool flipX: root.atX + main.width > root.width - root.edge
    readonly property bool flipY: root.atY + main.height > root.height - root.edge
    readonly property real originX: Math.max(root.edge, Math.min(root.flipX ? root.atX - main.width : root.atX, root.width - root.edge - main.width))
    readonly property real originY: Math.max(root.edge, Math.min(root.flipY ? root.atY - main.height : root.atY, root.height - root.edge - main.height))

    readonly property bool innerLeft: main.x + main.width + sub.width > root.width - root.edge && main.x - sub.width >= root.edge

    visible: root.open

    onOpenChanged: if (root.open)
        root.forceActiveFocus()

    Keys.onEscapePressed: {
        if (root.inner >= 0)
            root.leave();
        else
            root.close();
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.close()
    }

    ActionMenu {
        id: main

        x: root.originX
        y: root.originY
        width: implicitWidth
        height: implicitHeight

        actions: root.actions
        selected: root.selected
        worn: root.worn
        opened: root.inner
        sized: root.sized
        widest: root.width - root.edge * 2

        onHovered: index => root.hoverMain(index)
        onClicked: index => {
            root.choose(index);
            root.deep = false;
            root.activate(index);
        }
    }

    ActionMenu {
        id: sub

        visible: root.inner >= 0
        x: root.innerLeft ? main.x - width + main.gap : Math.min(main.x + main.width - main.gap, root.width - root.edge - width)
        y: Math.max(root.edge, Math.min(main.y + main.rowTop(Math.max(0, root.inner)), root.height - root.edge - height))
        width: implicitWidth
        height: implicitHeight

        actions: root.innerActions
        selected: root.innerSelected
        sized: root.sized
        widest: root.width - root.edge * 2

        onHovered: index => root.hoverInner(index)
        onClicked: index => {
            root.hoverInner(index);
            root.run(root.innerActions[index]);
        }
    }
}
