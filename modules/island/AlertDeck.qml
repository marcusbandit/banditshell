pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var entries: []

    property real fanned: 0

    property real lift: 0

    property real maxHeight: 100000

    signal dismissed(var entry)
    signal putAway(var entry)
    signal advanced(bool forward, int count)

    readonly property real shuffleSpeed: Appearance.animation.revealSpeed * 0.45

    property var clearing: []
    readonly property int clearStagger: 6

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

    function putAwayFront(): void {
        const slot = root.slotFor(root.front);
        if (slot)
            slot.tuck();
        else if (root.front)
            root.putAway(root.front);
    }

    function clearAll(only: var): void {
        const all = root.standing.filter(e => !only || only.includes(e));
        if (root.fanned < 0.5) {
            for (const e of all)
                root.flick(e, 1);
            return;
        }
        root.clearing = all;
        clear.flung = 0;
        clear.restart();
    }

    property var outgoing: []

    readonly property var standing: root.entries.filter(e => !e.leaving && !root.outgoing.includes(e))
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

    readonly property real listHeight: {
        let sum = 0;
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (slot)
                sum += slot.cardHeight * slot.open;
        }
        return sum;
    }

    readonly property real foldedHeight: {
        let sum = 0;
        let weight = 0;
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (!slot)
                continue;
            sum += slot.cardHeight * slot.weight;
            weight += slot.weight;
        }
        if (weight > 0.001)
            return sum / weight;
        return slots.itemAt(0)?.cardHeight ?? 0;
    }

    readonly property real viewMax: Math.max(root.foldedHeight, root.maxHeight - root.footerHeight)
    readonly property real spreadHeight: Math.min(root.listHeight, root.viewMax)
    readonly property real scrollMax: Math.max(0, root.listHeight - root.spreadHeight)
    readonly property real scrolled: Math.min(scroll.value, root.scrollMax)

    readonly property real fullHeight: {
        let sum = 0;
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (slot && !slot.leaving)
                sum += slot.cardHeight;
        }
        return Math.min(sum, Math.max(0, root.maxHeight - root.footerHeight)) + (root.behind.length > 0 ? root.footerHeight : 0);
    }

    readonly property bool handling: {
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
        root.lift = 0;
        if (root.lastFront && root.front && root.fanned === 0)
            root.advanced(root.standing.includes(root.lastFront), root.standing.length);
        root.lastFront = root.front;
    }

    onEntriesChanged: root.outgoing = root.outgoing.filter(e => root.entries.includes(e) && !e.leaving)

    onFannedChanged: if (root.fanned === 0) {
        scroll.target = 0;
        scroll.snap();
    }

    implicitHeight: view.height + footer.height

    Timer {
        id: clear

        property int flung: 0

        interval: 60
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const next = root.clearing.filter(e => e && !e.leaving);
            if (next.length === 0) {
                clear.stop();
                root.clearing = [];
                return;
            }
            if (clear.flung >= root.clearStagger) {
                clear.stop();
                root.clearing = [];
                for (const e of next)
                    root.flick(e, 1);
                return;
            }
            clear.flung += 1;
            root.clearing = next.slice(1);
            root.flick(next[0], 1);
        }
    }

    Follow {
        id: footing

        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
        target: root.behind.length > 0 ? 1 : 0
    }

    Follow {
        id: scroll

        speed: Appearance.animation.trackSpeed
        epsilon: 0.25
    }

    Item {
        id: view

        width: root.width
        height: root.foldedHeight + (root.spreadHeight - root.foldedHeight) * root.fanned
        clip: true

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
                const step = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * Appearance.font.line.small * 3;
                const from = Math.min(scroll.target, root.scrollMax);
                const to = Math.max(0, Math.min(root.scrollMax, from - step));
                event.accepted = to !== from;
                scroll.target = to;
            }
        }

        Repeater {
            id: slots

            model: ScriptModel {
                values: root.entries
            }

            Item {
                id: slot

                required property var modelData
                required property int index

                function fling(direction: int): void {
                    card.fling(direction);
                }

                function tuck(): void {
                    card.tuck();
                }

                readonly property bool leaving: slot.modelData?.leaving ?? false
                readonly property bool isFront: slot.modelData === root.front
                readonly property bool handling: card.handling
                readonly property bool outgoing: card.flinging || card.tucking

                onOutgoingChanged: if (slot.outgoing && !root.outgoing.includes(slot.modelData))
                    root.outgoing = [...root.outgoing, slot.modelData]
                readonly property real open: Math.max(0, arrival.value - departure.value)
                readonly property real cardHeight: card.implicitHeight

                property bool fromTop: false
                property real leftAt: 0

                readonly property real step: slot.leaving ? slot.leftAt : promotion.value
                readonly property real weight: slot.leaving ? slot.leftAt * slot.open : promotion.value
                readonly property real away: 1 - slot.step

                readonly property real foldY: slot.fromTop ? -slot.away * slot.cardHeight * 0.6 : slot.away * Appearance.padding.normal
                readonly property real spreadTop: {
                    let sum = 0;
                    for (let i = 0; i < slot.index; i++) {
                        const other = slots.itemAt(i);
                        if (other)
                            sum += other.cardHeight * other.open;
                    }
                    return sum;
                }
                readonly property real spreadY: slot.spreadTop - root.scrolled

                onIsFrontChanged: slot.fromTop = slot.isFront && arrival.value < 0.5 && root.fanned === 0
                onLeavingChanged: if (slot.leaving)
                    slot.leftAt = promotion.value

                Component.onCompleted: slot.fromTop = slot.isFront && root.fanned === 0

                width: view.width
                height: root.fanned > 0 ? slot.cardHeight * slot.open : slot.cardHeight
                y: root.fanned > 0 ? slot.spreadY : slot.foldY
                z: root.fanned > 0 ? 0 : slot.step
                clip: root.fanned > 0 && slot.height < slot.cardHeight - 0.5
                scale: root.fanned > 0 || slot.fromTop ? 1 : 1 - 0.06 * slot.away
                transformOrigin: Item.Bottom
                opacity: root.fanned > 0 ? slot.open : (slot.fromTop ? slot.step : slot.step * slot.step) * slot.open
                visible: slot.opacity > 0.005 && slot.y < view.height && slot.y + slot.height > 0

                Follow {
                    id: promotion

                    speed: root.shuffleSpeed
                    epsilon: 0.004
                    target: slot.isFront ? 1 : 0
                }

                Follow {
                    id: arrival

                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.004
                    Component.onCompleted: arrival.target = 1
                }

                Follow {
                    id: departure

                    speed: Appearance.animation.revealSpeed * 1.5
                    epsilon: 0.004
                    target: slot.leaving ? 1 : 0
                }

                NotificationAlert {
                    id: card

                    width: slot.width
                    entry: slot.modelData
                    loose: !slot.isFront || root.standing.length > 1

                    onLiftChanged: if (slot.isFront)
                        root.lift = card.loose ? 0 : card.lift
                    onDismissed: root.dismissed(slot.modelData)
                    onPutAway: root.putAway(slot.modelData)
                }

                Separator {
                    x: card.pad
                    width: slot.width - card.pad * 2
                    visible: slot.index > 0 && root.fanned > 0.01
                    opacity: root.fanned
                }
            }
        }
    }

    Item {
        id: footer

        y: view.height
        width: root.width
        height: root.footerHeight * footing.value
        clip: true
        opacity: footing.value
        visible: footing.value > 0.01

        Row {
            id: faces

            x: Appearance.padding.card
            y: (root.footerHeight - Appearance.padding.card - height) / 2
            spacing: Appearance.padding.small / 2
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
            id: clearButton

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.card
            y: (root.footerHeight - Appearance.padding.card - height) / 2
            size: 0
            style: "outlined"
            icon: "clear_all"
            text: "clear all"
            onClicked: root.clearAll(null)
        }
    }
}
