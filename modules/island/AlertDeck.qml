pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.modules.notifications
import qs.services

Item {
    id: root

    property var entries: []

    property var groups: null
    property var unfolded: []
    property var folding: []

    readonly property bool grouped: root.groups !== null
    readonly property var cards: {
        if (!root.grouped)
            return root.entries;
        const out = [];
        for (const group of root.groups) {
            const open = root.unfolded.includes(group.key);
            for (const entry of group.entries)
                if (entry === group.entries[0] || open || root.folding.includes(entry))
                    out.push(entry);
        }
        return out;
    }

    property real fanned: 0

    property real maxHeight: 100000

    property bool footed: true

    property bool liftsAway: true

    signal dismissed(var entry)
    signal kept(var entry)
    signal history
    signal advanced(bool forward, int count, var previous)
    signal lifted

    readonly property real shuffleSpeed: Appearance.animation.revealSpeed * 0.45
    readonly property real notch: Appearance.font.line.small * 4
    readonly property int sweepStep: 20

    property var clearing: []
    property var swept: []
    property bool sweeping: false

    function groupOf(entry: var): var {
        return root.grouped ? root.groups.find(g => g.entries.includes(entry)) ?? null : null;
    }

    function toggle(group: var): void {
        if (!group)
            return;
        if (root.unfolded.includes(group.key)) {
            root.folding = [...root.folding, ...group.entries.slice(1).filter(e => !root.folding.includes(e))];
            root.unfolded = root.unfolded.filter(k => k !== group.key);
        } else {
            root.unfolded = [...root.unfolded, group.key];
            root.folding = root.folding.filter(e => !group.entries.includes(e));
        }
    }

    function foldAll(): void {
        root.unfolded = [];
        root.folding = [];
    }

    function part(entry: var, keep: bool): void {
        const group = root.groupOf(entry);
        const all = group && group.entries[0] === entry && !root.unfolded.includes(group.key) ? group.entries : [entry];
        for (const e of all) {
            if (keep)
                root.kept(e);
            else
                root.dismissed(e);
        }
    }

    function slotFor(entry: var): Item {
        for (let i = 0; i < slots.count; i++) {
            const s = slots.itemAt(i);
            if (s?.modelData === entry)
                return s;
        }
        return null;
    }

    function flick(entry: var, direction: int): void {
        if (!entry || entry.leaving)
            return;
        const slot = root.slotFor(entry);
        if (slot)
            slot.fling(direction);
        else
            root.dismissed(entry);
    }

    function dismissFront(direction: int): void {
        root.flick(root.front, direction);
    }

    function clearAll(only: var): void {
        const all = root.standing.filter(e => !only || only.includes(e));
        if (all.length === 0)
            return;
        root.swept = all;
        root.sweeping = true;
        const shown = [];
        for (const e of all) {
            const slot = root.slotFor(e);
            if (slot?.onScreen)
                shown.push(slot);
            else
                root.flick(e, 1);
        }
        shown.sort((a, b) => a.y - b.y);
        root.clearing = shown.map(s => s.modelData);
        clear.restart();
    }

    function scrollBy(by: real): void {
        if (root.scrollMax <= 0 || root.fanned < 0.5)
            return;
        scroll.target = Math.max(0, Math.min(root.scrollMax, Math.min(scroll.target, root.scrollMax) - by));
        scroll.snap();
    }

    property real lift: 0
    property var liftedAway: []

    readonly property real naturalView: root.foldedHeight + (root.spreadHeight - root.foldedHeight) * root.fanned
    readonly property real liftTravel: Math.max(1, root.naturalView + root.footerHeight * footing.value)
    readonly property real raised: rise.value
    readonly property real liftFade: 1 - Math.min(1, Math.max(0, root.raised) / root.liftTravel)
    readonly property real giveRoom: Appearance.padding.huge * 2

    function give(reach: real): real {
        const k = Config.values.control.dragResistance;
        const m = Math.abs(reach);
        const given = root.giveRoom * (1 - 1 / (1 + m * k / root.giveRoom));
        return reach < 0 ? -given : given;
    }

    function ungive(raised: real): real {
        const k = Math.max(0.01, Config.values.control.dragResistance);
        const m = Math.min(Math.abs(raised), root.giveRoom * 0.99);
        const reach = root.giveRoom * (1 / (1 - m / root.giveRoom) - 1) / k;
        return raised < 0 ? -reach : reach;
    }

    function holdLift(): void {
        rise.hold(root.lift >= 0 && root.liftsAway ? root.lift : root.give(root.lift));
    }

    function dragBy(by: real): void {
        if (!rise.held)
            root.lift = rise.value >= 0 && root.liftsAway ? rise.value : root.ungive(rise.value);
        const canScroll = root.scrollMax > 0 && root.fanned >= 0.5;
        let rest = Math.abs(by);
        if (by < 0) {
            if (root.lift < 0) {
                const used = Math.min(-root.lift, rest);
                root.lift += used;
                rest -= used;
            }
            if (rest > 0 && canScroll && root.lift >= 0) {
                const from = Math.min(scroll.target, root.scrollMax);
                const used = Math.min(root.scrollMax - from, rest);
                if (used > 0) {
                    scroll.target = from + used;
                    scroll.snap();
                    rest -= used;
                }
            }
            root.lift += rest;
        } else if (by > 0) {
            if (root.lift > 0) {
                const used = Math.min(root.lift, rest);
                root.lift -= used;
                rest -= used;
            }
            if (rest > 0 && canScroll && root.lift <= 0) {
                const from = Math.min(scroll.target, root.scrollMax);
                const used = Math.min(from, rest);
                if (used > 0) {
                    scroll.target = from - used;
                    scroll.snap();
                    rest -= used;
                }
            }
            root.lift -= rest;
        }
        if (root.lift !== 0 || rise.held)
            root.holdLift();
    }

    function letGo(): void {
        if (rise.held && !root.handling)
            root.dragEnd(0);
    }

    onHandlingChanged: if (!root.handling)
        Qt.callLater(root.letGo)

    function dragEnd(speed: real): void {
        if (!rise.held) {
            root.scrollGlide(speed);
            return;
        }
        const up = root.lift > 0;
        const thrown = speed < -root.throwSpeed && root.lift > Config.values.control.dragThreshold;
        const gone = up && !(speed > root.throwSpeed) && (thrown || root.lift > root.liftTravel * Config.values.control.pullCommit);
        rise.target = gone && root.liftsAway ? root.liftTravel : 0;
        rise.release();
        const settledScroll = Math.abs(root.lift) < 0.5;
        root.lift = 0;
        if (settledScroll)
            root.scrollGlide(speed);
        if (gone) {
            if (root.liftsAway)
                root.liftedAway = [...root.standing];
            root.lifted();
        }
    }

    readonly property real throwSpeed: 0.6
    readonly property real tugNear: 0.18
    readonly property real tugFar: 0.06

    function scrollGlide(speed: real): void {
        if (root.scrollMax <= 0 || root.fanned < 0.5)
            return;
        scroll.target = Math.max(0, Math.min(root.scrollMax, Math.min(scroll.target, root.scrollMax) - speed * 260));
    }

    property var outgoing: []
    property var recalled: null

    readonly property var standing: root.cards.filter(e => !e.leaving && !root.outgoing.includes(e))
    readonly property var front: root.standing[0] ?? null
    readonly property var behind: root.standing.slice(1)

    readonly property int markMax: 3
    readonly property var behindMarks: {
        const seen = [];
        const out = [];
        for (const e of root.behind) {
            const key = e.appName || e.mark || e.summary;
            if (seen.includes(key))
                continue;
            seen.push(key);
            out.push(e);
        }
        return out.slice(0, root.markMax);
    }

    readonly property real footerHeight: clearButton.implicitHeight + Appearance.padding.card
    readonly property real footerShown: footer.height

    property int reshaped: 0

    readonly property var tops: {
        root.reshaped;
        const out = [0];
        for (let i = 0; i < slots.count; i++)
            out.push(out[i] + (slots.itemAt(i)?.room ?? 0));
        return out;
    }

    readonly property real listHeight: root.tops[root.tops.length - 1]

    readonly property real foldedHeight: {
        root.reshaped;
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (slot?.isFront)
                return slot.cardHeight;
        }
        return slots.itemAt(0)?.cardHeight ?? 0;
    }

    readonly property real settledList: {
        root.reshaped;
        let sum = 0;
        for (let i = 0; i < slots.count; i++)
            sum += slots.itemAt(i)?.settledRoom ?? 0;
        return sum;
    }

    property real lockedList: 0
    property real lockedView: 0

    onSettledListChanged: {
        root.lockedView = root.spreadHeight;
        root.lockedList = root.listHeight;
    }

    readonly property real viewMax: Math.max(root.foldedHeight, root.maxHeight - root.footerHeight)
    readonly property real settledView: Math.min(root.settledList, root.viewMax)
    readonly property real spreadProgress: Math.abs(root.settledList - root.lockedList) < 0.5 ? 1 : Math.max(0, Math.min(1, (root.listHeight - root.lockedList) / (root.settledList - root.lockedList)))
    readonly property real spreadHeight: root.lockedView + (root.settledView - root.lockedView) * root.spreadProgress
    readonly property real scrollMax: Math.max(0, root.listHeight - root.spreadHeight)
    readonly property real scrolled: Math.min(scroll.value, root.scrollMax)

    readonly property real fullHeight: {
        root.reshaped;
        let sum = 0;
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (slot && !slot.leaving)
                sum += slot.cardHeight + Math.max(slot.gapTarget, slot.gapShown);
        }
        return Math.min(sum, Math.max(0, root.maxHeight - root.footerHeight)) + (root.footed && root.behind.length > 0 ? root.footerHeight : 0);
    }

    readonly property bool handling: {
        root.reshaped;
        for (let i = 0; i < slots.count; i++)
            if (slots.itemAt(i)?.handling)
                return true;
        return false;
    }

    property int moreShown: 0
    property var facesShown: []
    property var lastFront: null

    onBehindChanged: if (root.behind.length > 0)
        root.moreShown = root.behind.length
    onBehindMarksChanged: if (root.behindMarks.length > 0)
        root.facesShown = root.behindMarks

    onFrontChanged: {
        const previous = root.lastFront;
        const recalled = root.recalled;
        root.lastFront = root.front;
        root.recalled = null;
        if (!previous || !root.front || root.fanned > 0 || root.sweeping)
            return;
        const forward = root.standing.includes(previous) && root.front !== recalled;
        if (forward) {
            root.slotFor(root.front)?.settle();
            root.slotFor(previous)?.settle();
        }
        root.advanced(forward, root.standing.length, previous);
    }

    onCardsChanged: {
        if (root.cards.length === 0) {
            root.liftedAway = [];
            rise.target = 0;
            rise.snap();
        }
        root.outgoing = root.outgoing.filter(e => root.cards.includes(e) && !e.leaving);
        const folding = root.folding.filter(e => root.cards.includes(e) && !e.leaving);
        if (folding.length !== root.folding.length)
            Qt.callLater(() => root.folding = root.folding.filter(e => root.cards.includes(e) && !e.leaving));
        if (root.sweeping && root.swept.every(e => !root.cards.includes(e)))
            root.sweeping = false;
    }

    onStandingChanged: {
        if (root.sweeping && root.standing.some(e => !root.swept.includes(e)))
            root.sweeping = false;
        if (rise.target > 0 && root.standing.some(e => !root.liftedAway.includes(e))) {
            root.liftedAway = [];
            rise.target = 0;
            rise.snap();
        }
    }

    onFannedChanged: if (root.fanned === 0) {
        scroll.target = 0;
        scroll.snap();
    }

    implicitHeight: view.height + footer.height

    Spring {
        id: rise

        epsilon: 0.5
    }

    Timer {
        id: clear

        interval: root.sweepStep
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const next = root.clearing.filter(e => e && !e.leaving);
            if (next.length === 0) {
                clear.stop();
                root.clearing = [];
                return;
            }
            root.clearing = next.slice(1);
            root.flick(next[0], 1);
        }
    }

    Follow {
        id: footing

        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
        target: root.footed && root.behind.length > 0 ? 1 : 0
    }

    Follow {
        id: scroll

        speed: Appearance.animation.trackSpeed * 1.4
        epsilon: 0.25
    }

    Item {
        id: view

        width: root.width
        height: Math.max(0, root.naturalView - root.raised)
        clip: true
        opacity: root.liftFade

        layer.enabled: root.scrollMax > 0 && root.fanned > 0
        layer.effect: ShaderEffect {
            id: edges

            readonly property real reach: Appearance.padding.huge
            readonly property vector4d fades: Qt.vector4d(Math.min(edges.reach, root.scrolled), Math.min(edges.reach, root.scrollMax - root.scrolled), edges.height, 1)

            fragmentShader: Qt.resolvedUrl("../../components/edgefade.frag.qsb")
        }

        WheelHandler {
            enabled: root.scrollMax > 0 && root.fanned > 0.5
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                const fine = event.device.type === PointerDevice.TouchPad && event.pixelDelta.y !== 0;
                const step = fine ? event.pixelDelta.y * 2 : event.angleDelta.y / 120 * root.notch;
                const from = Math.min(scroll.target, root.scrollMax);
                const to = Math.max(0, Math.min(root.scrollMax, from - step));
                event.accepted = to !== from;
                scroll.target = to;
            }
        }

        Repeater {
            id: slots

            model: ScriptModel {
                values: root.cards
            }

            onItemAdded: root.reshaped++
            onItemRemoved: root.reshaped++

            Item {
                id: slot

                required property var modelData
                required property int index

                function fling(direction: int): void {
                    card.fling(direction);
                }

                function settle(): void {
                    promotion.snap();
                }

                readonly property bool leaving: slot.modelData?.leaving ?? false
                readonly property bool isFront: slot.modelData === root.front
                readonly property var group: root.groupOf(slot.modelData)
                readonly property bool head: !!slot.group && slot.group.entries[0] === slot.modelData
                readonly property bool spread: !!slot.group && root.unfolded.includes(slot.group.key)
                readonly property bool folding: root.folding.includes(slot.modelData)
                readonly property bool apart: root.grouped && !!slot.above && slot.above.group !== slot.group && (slot.spread || slot.above.spread)
                readonly property real gapTarget: slot.apart ? Appearance.padding.small : 0
                readonly property real gapShown: gap.value
                readonly property int tally: slot.head ? slot.group.entries.filter(e => !e.leaving).length : 1
                readonly property bool loose: card.loose
                readonly property real pull: card.pull
                readonly property Item above: {
                    root.reshaped;
                    return slot.index > 0 ? slots.itemAt(slot.index - 1) : null;
                }
                readonly property Item below: {
                    root.reshaped;
                    return slots.itemAt(slot.index + 1);
                }
                readonly property bool handling: card.handling
                readonly property bool outgoing: card.flinging
                readonly property real open: slot.tucks ? unfold.value : Math.max(0, arrival.value - departure.value)
                readonly property real cardHeight: card.implicitHeight
                readonly property real room: (slot.cardHeight + gap.value) * (root.sweeping ? 1 : slot.open)
                readonly property bool tucks: root.grouped && !!slot.group && !slot.head && !slot.leaving
                readonly property real settledRoom: slot.leaving || slot.folding ? 0 : slot.cardHeight + slot.gapTarget

                property real leftAt: 0

                readonly property real step: slot.leaving ? slot.leftAt : promotion.value
                readonly property real away: 1 - slot.step

                readonly property real spreadTop: root.tops[slot.index] ?? 0
                readonly property real spreadY: slot.spreadTop - root.scrolled
                readonly property bool inView: slot.y < view.height && slot.y + slot.height > 0
                readonly property bool onScreen: slot.inView && slot.opacity > 0.005

                onOutgoingChanged: {
                    if (slot.outgoing && !root.outgoing.includes(slot.modelData)) {
                        root.outgoing = [...root.outgoing, slot.modelData];
                    } else if (!slot.outgoing && !slot.leaving && root.outgoing.includes(slot.modelData)) {
                        root.recalled = slot.modelData;
                        root.outgoing = root.outgoing.filter(e => e !== slot.modelData);
                        Qt.callLater(() => root.recalled = null);
                    }
                }
                onLeavingChanged: if (slot.leaving)
                    slot.leftAt = promotion.value

                width: view.width
                height: root.fanned > 0 ? slot.room : slot.cardHeight
                y: (root.fanned > 0 ? slot.spreadY : slot.away * Appearance.padding.normal) - root.raised
                z: root.fanned > 0 ? 0 : slot.step
                clip: root.fanned > 0 && slot.height < slot.cardHeight + gap.value - 0.5
                scale: root.fanned > 0 ? 1 : 1 - 0.06 * slot.away
                transformOrigin: Item.Bottom
                opacity: !slot.inView ? 0 : root.fanned > 0 ? (slot.tucks ? 1 : slot.open) : slot.step * slot.step * slot.open

                Travel {
                    id: promotion

                    epsilon: 0.004
                    target: slot.isFront ? 1 : 0
                }

                Follow {
                    id: arrival

                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.004
                    Component.onCompleted: arrival.target = 1
                }

                Travel {
                    id: gap

                    epsilon: 0.25
                    target: slot.gapTarget
                    Component.onCompleted: gap.snap()
                }

                Travel {
                    id: unfold

                    epsilon: 0.004
                    target: slot.folding ? 0 : 1

                    onValueChanged: if (slot.folding && unfold.value <= 0.001)
                        root.folding = root.folding.filter(e => e !== slot.modelData)
                }

                Follow {
                    id: departure

                    speed: Appearance.animation.snapSpeed
                    epsilon: 0.004
                    target: slot.leaving ? 1 : 0
                }

                NotificationCard {
                    id: card

                    y: gap.value - (slot.tucks && root.fanned > 0 ? (slot.cardHeight + gap.value) * (1 - slot.open) : 0)
                    width: slot.width
                    entry: slot.modelData
                    count: slot.tally
                    countOpen: slot.spread
                    folded: slot.tally > 1 && !slot.spread
                    tiled: root.grouped
                    joinedAbove: root.grouped && !!slot.above && !slot.apart
                    joinedBelow: root.grouped && !!slot.below && !slot.below.apart
                    aboveLoose: slot.above?.loose ?? false
                    belowLoose: slot.below?.loose ?? false
                    tug: root.grouped ? ((slot.above?.pull ?? 0) + (slot.below?.pull ?? 0)) * root.tugNear + ((slot.above?.above?.pull ?? 0) + (slot.below?.below?.pull ?? 0)) * root.tugFar : 0

                    onCountTapped: root.toggle(slot.group)
                    onReleased: root.part(slot.modelData, false)
                    onKept: root.part(slot.modelData, true)
                    onScrolled: by => root.dragBy(by)
                    onScrollEnded: speed => root.dragEnd(speed)
                }

                Separator {
                    x: card.pad
                    width: slot.width - card.pad * 2
                    visible: slot.index > 0 && root.fanned > 0.01 && !root.grouped
                    opacity: root.fanned * (1 - card.shiftFade)
                }
            }
        }
    }

    Item {
        id: footer

        y: view.height
        width: root.width
        height: Math.max(0, root.footerHeight * footing.value - Math.max(0, root.raised - root.naturalView))
        clip: true
        opacity: footing.value * root.liftFade
        visible: footing.value > 0.01

        Row {
            id: faces

            x: Appearance.padding.card
            y: (root.footerHeight - Appearance.padding.card - height) / 2
            spacing: Appearance.padding.hair
            opacity: 1 - root.fanned
            visible: opacity > 0.01

            Repeater {
                model: root.facesShown.filter(e => e)

                NotificationMark {
                    required property var modelData

                    entry: modelData
                    size: Appearance.font.line.small
                }
            }
        }

        StyledText {
            anchors.left: faces.right
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: faces.verticalCenter
            text: `${root.moreShown} more`
            color: Appearance.colour.textFaint
            opacity: 1 - root.fanned
            visible: opacity > 0.01
        }

        Button {
            id: historyButton

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.card
            y: (root.footerHeight - Appearance.padding.card - height) / 2
            size: 0
            style: "ring"
            icon: "notifications"
            text: "all notifications"
            opacity: root.fanned
            visible: opacity > 0.01 && !root.grouped
            onClicked: root.history()
        }

        Button {
            id: clearButton

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.card
            y: (root.footerHeight - Appearance.padding.card - height) / 2
            size: 0
            style: "ring"
            icon: "clear_all"
            text: "clear all"
            onClicked: root.clearAll(null)
        }
    }
}
