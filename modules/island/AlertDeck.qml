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

    signal dismissed(var entry)
    signal putAway(var entry)

    property var clearing: []

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
        clear.restart();
    }

    readonly property var standing: root.entries.filter(e => !e.leaving)
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

    readonly property real fullHeight: {
        let sum = root.behind.length > 0 ? root.footerHeight : 0;
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (slot && !slot.leaving)
                sum += slot.cardHeight;
        }
        return sum;
    }

    property int moreShown: 0
    property var facesShown: []

    onBehindChanged: if (root.behind.length > 0)
        root.moreShown = root.behind.length
    onBehindMarksChanged: if (root.behindMarks.length > 0)
        root.facesShown = root.behindMarks

    onFrontChanged: root.lift = 0

    readonly property real foldedHeight: {
        let sum = 0;
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (slot)
                sum += slot.foldedHeight;
        }
        return sum;
    }

    implicitHeight: view.height + footer.height

    Timer {
        id: clear

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

    Item {
        id: view

        width: root.width
        height: root.foldedHeight + (cards.implicitHeight - root.foldedHeight) * root.fanned
        clip: true

        Column {
            id: cards

            width: root.width

            Repeater {
                id: slots

                model: ScriptModel {
                    values: root.entries
                }

                Item {
                    id: slot

                    required property var modelData

                    function fling(direction: int): void {
                        card.fling(direction);
                    }

                    function tuck(): void {
                        card.tuck();
                    }

                    readonly property bool leaving: slot.modelData?.leaving ?? false
                    readonly property bool isFront: slot.modelData === root.front
                    readonly property real open: Math.max(0, arrival.value - departure.value)
                    readonly property real shown: root.fanned > 0 ? 1 : promotion.value
                    readonly property real cardHeight: card.implicitHeight
                    readonly property real foldedHeight: slot.cardHeight * slot.open * promotion.value

                    width: cards.width
                    height: slot.cardHeight * slot.open * slot.shown
                    clip: slot.height < card.implicitHeight - 0.5
                    opacity: slot.open

                    Follow {
                        id: promotion

                        speed: Appearance.animation.revealSpeed * 1.5
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
                        visible: !slot.isFront && root.fanned > 0.01
                        opacity: root.fanned
                    }
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
