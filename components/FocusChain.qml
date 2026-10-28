import QtQuick
import qs.config
import "focus-chain.js" as Chain

Item {
    id: root

    property Item scope: null

    property Item area: root.scope

    property Item holder: null

    property WheelStep scroller: null

    property Item current: null

    readonly property bool active: shown.active

    onScopeChanged: root.reset()

    property rect spot: Qt.rect(0, 0, 0, 0)

    property bool spotted: false

    property int spotIndex: -1

    property string spotKind: ""

    function kindOf(item: Item): string {
        return String(item).split("(")[0];
    }

    onCurrentChanged: if (!root.current && root.spotted)
        rebuilt.restart()

    Timer {
        id: rebuilt

        interval: Appearance.animation.settle
        onTriggered: root.recover()
    }

    function anchor(chain: var): int {
        const at = chain.items.indexOf(root.current);
        if (at >= 0 || !root.spotted)
            return at;
        const same = chain.items[root.spotIndex];
        if (same && root.kindOf(same) === root.spotKind)
            return root.spotIndex;
        return Chain.nearest(chain.rects, {
            x: root.spot.x,
            y: root.spot.y,
            w: root.spot.width,
            h: root.spot.height
        });
    }

    function recover(): void {
        if (!root.spotted || !shown.active || root.current?.visible)
            return;
        const chain = root.members();
        const near = root.anchor(chain);
        if (near >= 0)
            root.land(chain.items[near]);
    }

    function reset(): void {
        const was = root.current;
        root.spotted = false;
        root.current = null;
        shown.clear();
        if (was?.activeFocus && root.holder)
            root.holder.forceActiveFocus();
    }

    function members(): var {
        const found = [];
        const rects = [];
        const walk = (item, clip) => {
            for (const child of item.children) {
                if (!child.visible || !child.enabled || child.opacity <= 0.01)
                    continue;
                const at = child.mapToItem(root.scope, 0, 0);
                const box = {
                    x: at.x,
                    y: at.y,
                    w: child.width,
                    h: child.height
                };
                const seen = Chain.cut(clip, box);
                if ((child.keyable === true || child.typable === true) && seen.w > 0 && seen.h > 0) {
                    found.push(child);
                    rects.push(box);
                }
                const inner = child.clip ? Chain.cut(clip, box) : clip;
                if (!inner || inner.w > 0 && inner.h > 0)
                    walk(child, inner);
            }
        };
        if (root.scope)
            walk(root.scope, null);
        const order = Chain.readingOrder(rects);
        return {
            items: order.map(i => found[i]),
            rects: order.map(i => rects[i])
        };
    }

    function groupOf(item: Item): string {
        for (let at = item; at && at !== root.scope; at = at.parent)
            if (typeof at.focusGroup === "string" && at.focusGroup !== "")
                return at.focusGroup;
        return "";
    }

    function land(item: Item): void {
        if (!item)
            return;
        const at = item.mapToItem(root.scope, 0, 0);
        root.spot = Qt.rect(at.x, at.y, item.width, item.height);
        root.spotted = true;
        root.spotIndex = root.members().items.indexOf(item);
        root.spotKind = root.kindOf(item);
        root.current = item;
        shown.keyed();
        item.forceActiveFocus(Qt.TabFocusReason);
        root.show(item);
    }

    function show(item: Item): void {
        const flick = root.scroller?.flick;
        if (!flick || !flick.interactive)
            return;
        const top = item.mapToItem(flick.contentItem, 0, 0).y;
        const goal = root.scroller.goal;
        const to = Chain.reveal(goal, flick.height, top, top + item.height, Appearance.padding.normal);
        if (Math.abs(to - goal) > 0.5)
            root.scroller.scrollTo(to);
    }

    function handle(event: var): bool {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const key = event.key === Qt.Key_Tab && shift ? Qt.Key_Backtab : event.key;
        const chain = root.members();
        const count = chain.items.length;
        if (!count)
            return false;
        const at = root.anchor(chain);
        const here = at >= 0 ? chain.items[at] : null;
        const across = key === Qt.Key_Left || key === Qt.Key_Right;
        const along = key === Qt.Key_Up || key === Qt.Key_Down;

        if (here && (here.adjusts === "horizontal" && across || here.adjusts === "vertical" && along)) {
            root.land(here);
            here.adjust(key === Qt.Key_Right || key === Qt.Key_Up ? 1 : -1);
            rebuilt.restart();
            return true;
        }

        const line = Appearance.sizes.rowHeight;
        let to = -1;
        switch (key) {
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (at < 0)
                to = key === Qt.Key_Up ? count - 1 : 0;
            else
                to = Chain.step(chain.rects, at, key === Qt.Key_Up ? "up" : key === Qt.Key_Down ? "down" : key === Qt.Key_Left ? "left" : "right", line);
            break;
        case Qt.Key_Home:
            to = 0;
            break;
        case Qt.Key_End:
            to = Chain.last(chain.rects);
            break;
        case Qt.Key_PageUp:
        case Qt.Key_PageDown:
            to = at < 0 ? 0 : Chain.page(chain.rects, at, key === Qt.Key_PageDown, root.scroller?.flick?.height ?? 0);
            break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            to = Chain.group(chain.items.map(item => root.groupOf(item)), at, key === Qt.Key_Tab);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (!here || typeof here.press !== "function")
                return false;
            root.land(here);
            here.press();
            rebuilt.restart();
            return true;
        case Qt.Key_Delete:
            if (!here || typeof here.remove !== "function")
                return false;
            here.remove();
            return true;
        default:
            return false;
        }
        root.land(to >= 0 ? chain.items[to] : here);
        return true;
    }

    FocusVisible {
        id: shown

        parent: root.area

        onActiveChanged: if (!shown.active && root.current?.activeFocus && root.current.keyable === true && root.holder)
            root.holder.forceActiveFocus()
    }
}
