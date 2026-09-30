pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string screen

    readonly property string iconMode: Appearance.sizes.wsIconMode

    readonly property int slot: Appearance.sizes.wsSlot
    readonly property int iconSize: Appearance.sizes.wsIcon
    readonly property int pitch: Appearance.sizes.wsWindowPitch

    readonly property real lane: Math.round((root.width - root.slot) / 2)

    readonly property int dot: Math.round(root.slot * Appearance.sizes.wsEmptyReach)

    readonly property real radius: Appearance.rounding.normal

    readonly property int bleedUp: Math.floor(Appearance.sizes.wsGap / 2)
    readonly property int bleedDown: Appearance.sizes.wsGap - root.bleedUp

    readonly property int barH: Appearance.font.iconSize
    readonly property int barGap: Math.round(Appearance.padding.small / 2)
    readonly property int rackGap: Appearance.padding.large

    readonly property int barMark: Math.round(root.barH * 0.7)

    readonly property real overhang: Math.round(Appearance.padding.small / 2)

    property int hovered: -1
    property int racked: -1

    readonly property var deck: {
        const want = Appearance.sizes.wsSpecials;
        const live = Hypr.specials;
        const out = [];
        for (const name of want)
            out.push(live.find(s => s.label === name) ?? ({
                        id: 0,
                        name: `special:${name}`,
                        label: name,
                        windows: []
                    }));
        for (const s of live.slice().sort((a, b) => a.label.localeCompare(b.label)))
            if (want.indexOf(s.label) < 0)
                out.push(s);
        return out;
    }

    readonly property real rackTop: layout.total + root.rackGap
    readonly property real rackHeight: root.deck.length ? root.deck.length * root.barH + (root.deck.length - 1) * root.barGap : 0

    function barY(i: int): real {
        return root.rackTop + i * (root.barH + root.barGap);
    }

    function barClass(entry: var): string {
        const classes = entry.windows.map(w => Hypr.classOf(w));
        if (!classes.length)
            return "";
        return classes.every(c => c === classes[0]) ? classes[0] : "";
    }

    function barSpec(entry: var): string {
        const cls = root.barClass(entry);
        return cls ? AppIcons.markFor(cls, root.iconMode) : "";
    }

    function barGlyph(entry: var): string {
        const icons = entry.windows.map(w => Apps.iconFor(Hypr.classOf(w)));
        if (!icons.length)
            return "";
        return icons.every(i => i === icons[0]) ? icons[0] : Apps.genericIcon;
    }

    function barName(entry: var): string {
        const cls = root.barClass(entry);
        if (cls)
            return Apps.nameFor(cls);
        const label = entry.label ?? "";
        return label ? label.charAt(0).toUpperCase() + label.slice(1) : "";
    }

    function barWidth(entry: var): real {
        return entry.windows.length ? Math.max(Math.round(root.slot * Appearance.sizes.wsBusyReach), root.barMark + root.barGap * 2) : root.dot;
    }

    implicitHeight: layout.total + (root.deck.length ? root.rackGap + root.rackHeight : 0)

    WorkspaceModel {
        id: layout

        screen: root.screen
        base: root.slot
        pitch: root.pitch

        stack: true
    }

    readonly property int activeIndex: layout.active - layout.band
    readonly property bool onColumn: root.activeIndex >= 0 && root.activeIndex < layout.slots.length

    property int held: 0

    readonly property var heldGeom: layout.slots[root.held] ?? ({
            y: 0,
            h: root.slot
        })

    readonly property var activeGeom: layout.at(root.held)

    onActiveIndexChanged: {
        if (!root.onColumn)
            return;

        const cold = markShown.value < 0.01;
        root.held = root.activeIndex;
        if (cold) {
            markY.snap();
            markH.snap();
        }
    }

    property int heldSlot: 0
    property int heldBar: -1

    readonly property bool hovering: root.hovered >= 0 || root.racked >= 0

    readonly property var hoverGeom: {
        if (root.heldBar >= 0) {
            const e = root.deck[root.heldBar];
            return {
                y: root.barY(root.heldBar),
                h: root.barH,
                w: e ? root.barWidth(e) : root.dot
            };
        }
        const s = layout.slots[root.heldSlot] ?? ({
                y: 0,
                h: root.slot
            });

        const solid = root.slotSolid(s);
        const h = solid ? s.h : root.dot;
        return {
            y: s.y + (s.h - h) / 2,
            h,
            w: solid ? root.slot : root.dot
        };
    }

    function slotSolid(s: var): bool {
        return !!s && (s.windows.length > 0 || layout.active === s.id);
    }

    onHoveredChanged: if (root.hovered >= 0)
        root.mark(root.hovered, -1)

    onRackedChanged: if (root.racked >= 0)
        root.mark(-1, root.racked)

    function mark(slotIndex: int, barIndex: int): void {
        const cold = lit.value < 0.01;
        root.heldSlot = slotIndex;
        root.heldBar = barIndex;
        if (cold) {
            hoverY.snap();
            hoverH.snap();
            hoverW.snap();
        }
    }

    readonly property var tags: {
        if (root.heldBar >= 0)
            return [];
        const s = layout.slots[root.heldSlot];
        if (!s)
            return [];
        return s.marks.filter(m => m.count > 1).map(m => ({
                    row: m.row,
                    count: m.count
                }));
    }

    TextMetrics {
        id: digit

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    readonly property real tagAir: Math.round(Appearance.padding.small / 2)

    function tagWidth(count: int): real {
        const digits = `${count}`.length;
        return Math.round((digits - 1) * digit.advanceWidth + digit.tightBoundingRect.width) + root.tagAir * 2;
    }

    readonly property real tagHeight: Math.round(digit.tightBoundingRect.height) + root.tagAir * 2

    readonly property real tagX: root.lane + (root.slot + root.iconSize) / 2 + root.tagAir

    readonly property real tagBed: Appearance.padding.small

    function tagY(row: int, h: real): real {
        return hoverY.value + (root.slot - root.pitch) / 2 + row * root.pitch + (root.pitch - h) / 2;
    }

    readonly property var blobs: root.grown.value < 0.01 ? [] : root.tags.map(t => {
        const w = root.tagWidth(t.count) * root.grown.value + root.tagBed * 2;
        const h = root.tagHeight * root.grown.value + root.tagBed * 2;
        return {
            x: root.tagX + (root.tagWidth(t.count) - w) / 2 + root.tagBed,
            y: root.tagY(t.row, h - root.tagBed * 2) - root.tagBed,
            w,
            h,
            radius: Math.min(Appearance.rounding.normal, h / 2),
            smooth: Appearance.sizes.melt / 3
        };
    })

    readonly property Follow grown: growth

    Follow {
        id: growth

        speed: Appearance.anim.revealSpeed
        target: root.tags.length && root.hovering && !layout.scrubbing ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: markY

        speed: Appearance.anim.trackSpeed
        target: root.heldGeom.y
    }

    Follow {
        id: markH

        speed: Appearance.anim.trackSpeed
        target: root.heldGeom.h
    }

    Follow {
        id: markShown

        speed: Appearance.anim.revealSpeed
        target: root.onColumn ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: hoverY

        speed: Appearance.anim.trackSpeed
        target: root.hoverGeom.y
    }

    Follow {
        id: hoverH

        speed: Appearance.anim.trackSpeed
        target: root.hoverGeom.h
    }

    Follow {
        id: hoverW

        speed: Appearance.anim.trackSpeed
        target: root.hoverGeom.w
    }

    Follow {
        id: lit

        speed: Appearance.anim.revealSpeed

        target: root.hovering && !layout.scrubbing ? 1 : 0
        epsilon: 0.005
    }

    Component.onCompleted: {
        root.held = root.onColumn ? root.activeIndex : 0;
        root.heldSlot = root.held;
        markY.snap();
        markH.snap();
        markShown.snap();
        hoverY.snap();
        hoverH.snap();
        hoverW.snap();
    }

    MouseArea {
        id: backstop

        x: 0
        y: 0
        width: root.width
        height: layout.total

        preventStealing: layout.scrubbing

        onPressed: mouse => {
            const p = backstop.mapToItem(null, mouse.x, mouse.y);
            layout.scrubPress(p.x, p.y);
        }

        onPositionChanged: mouse => {
            if (!backstop.pressed)
                return;
            const p = backstop.mapToItem(null, mouse.x, mouse.y);
            layout.scrubMove(p.x, p.y);
        }

        onReleased: layout.scrubRelease()
        onCanceled: layout.scrubCancel()

        onWheel: wheel => layout.scrubWheel(wheel)
    }

    G2Rect {
        x: root.lane
        y: markY.value
        width: root.slot
        height: markH.value
        radius: root.radius
        color: Appearance.colour.fillStrong
        opacity: markShown.value

        G2Rect {
            anchors.fill: parent
            radius: root.radius
            color: Appearance.colour.accentFill
            opacity: layout.eclipsed ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    G2Rect {
        x: Math.round((root.width - width) / 2)
        y: hoverY.value
        width: hoverW.value
        height: hoverH.value
        radius: root.radius
        color: Appearance.colour.fillStrong
        opacity: lit.value
    }

    Repeater {

        model: root.deck.length

        delegate: G2Rect {
            id: bar

            required property int index
            readonly property var entry: root.deck[bar.index] ?? ({
                    name: "",
                    label: "",
                    windows: []
                })

            readonly property bool open: !!bar.entry.name && layout.special === bar.entry.name
            readonly property string name: root.barName(bar.entry)

            x: Math.round((root.width - width) / 2)
            y: root.barY(bar.index)
            width: bar.open ? root.dot : root.barWidth(bar.entry)
            height: root.barH

            radius: root.radius

            color: Appearance.colour.fill

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            G2Rect {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.colour.accentFill
                opacity: bar.open ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Item {
                anchors.fill: parent
                opacity: bar.open ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                AppMark {
                    anchors.centerIn: parent
                    visible: bar.entry.windows.length > 0
                    size: root.barMark
                    spec: root.barSpec(bar.entry)
                    fallback: root.barGlyph(bar.entry)
                    color: Appearance.colour.textDim

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }
            }

            MouseArea {
                id: barMouse

                x: -bar.x
                y: -root.barGap
                width: root.width
                height: parent.height + root.barGap * 2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.racked = bar.index
                onExited: if (root.racked === bar.index)
                    root.racked = -1
                onClicked: Hypr.toggleSpecial(bar.entry.name)

                property bool naming: false

                onPressAndHold: {
                    barMouse.naming = true;
                    Tooltips.request(bar, bar.name, true);
                }

                onReleased: if (barMouse.naming) {
                    barMouse.naming = false;
                    Tooltips.release(bar);
                }

                onCanceled: if (barMouse.naming) {
                    barMouse.naming = false;
                    Tooltips.release(bar);
                }

                HoverTip {
                    text: bar.name
                    host: bar

                    now: true
                }
            }
        }
    }

    Repeater {

        model: Math.max(layout.count, layout.live.length)

        delegate: Item {
            id: slotItem

            required property int index
            readonly property var info: layout.slots[index] ?? ({
                    id: layout.idAt(index),
                    windows: [],
                    marks: []
                })
            readonly property var geom: layout.at(index)

            readonly property bool isActive: layout.active === slotItem.info.id
            readonly property bool isOccupied: slotItem.info.windows.length > 0

            readonly property bool covered: slotItem.isActive && layout.eclipsed

            y: slotItem.geom.y
            width: root.width
            height: slotItem.geom.h

            MouseArea {
                id: slotMouse

                anchors.fill: parent
                anchors.topMargin: -root.bleedUp
                anchors.bottomMargin: -root.bleedDown
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: layout.scrubbing
                onEntered: root.hovered = slotItem.index
                onExited: if (root.hovered === slotItem.index)
                    root.hovered = -1

                onPressed: mouse => {
                    const p = slotMouse.mapToItem(null, mouse.x, mouse.y);
                    layout.scrubPress(p.x, p.y);
                }

                onPositionChanged: mouse => {

                    if (!slotMouse.pressed)
                        return;
                    const p = slotMouse.mapToItem(null, mouse.x, mouse.y);
                    layout.scrubMove(p.x, p.y);
                }

                onReleased: {
                    if (!layout.scrubRelease())
                        Hypr.switchTo(slotItem.info.id);
                }

                onCanceled: layout.scrubCancel()

                onWheel: wheel => layout.scrubWheel(wheel)

                Component.onDestruction: {
                    if (slotMouse.pressed)
                        layout?.scrubCancel();
                }
            }

            G2Rect {
                id: cell

                readonly property bool solid: root.slotSolid(slotItem.info)

                readonly property real fullTarget: cell.solid ? 1 : 0

                property real full: cell.fullTarget

                width: Math.round(root.dot + (root.slot - root.dot) * cell.full)
                height: Math.round(root.dot + (parent.height - root.dot) * cell.full)
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)

                radius: root.radius

                color: Appearance.colour.fill

                Behavior on full {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {

                    model: ScriptModel {
                        values: slotItem.info.marks
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property string appClass: row.modelData.cls ?? ""
                        readonly property int count: row.modelData.count ?? 1

                        readonly property bool lit: row.count > 1 ? slotItem.info.windows.some(w => Hypr.classOf(w) === row.appClass && Hypr.isFocused(w)) : Hypr.isFocused(row.modelData.client)

                        x: Math.round((cell.width - root.slot) / 2)
                        y: (root.slot - root.pitch) / 2 + (row.modelData.row ?? row.index) * root.pitch
                        width: root.slot
                        height: root.pitch
                        opacity: slotItem.covered ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.normal
                            }
                        }

                        AppMark {
                            anchors.centerIn: parent
                            size: root.iconSize
                            spec: AppIcons.markFor(row.appClass, root.iconMode)
                            fallback: Apps.iconFor(row.appClass)

                            color: row.lit ? Appearance.colour.text : Appearance.colour.textDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                    }
                }
            }
        }
    }

    Repeater {
        model: root.tags

        delegate: G2Rect {
            id: tag

            required property var modelData

            readonly property real fullW: root.tagWidth(tag.modelData.count)

            width: tag.fullW * growth.value
            height: root.tagHeight * growth.value
            x: root.tagX + (tag.fullW - width) / 2
            y: root.tagY(tag.modelData.row, height)
            visible: growth.value > 0.01

            radius: root.radius
            color: Appearance.colour.fill

            G2Rect {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.colour.fillStrong
            }

            G2Rect {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.colour.accentFill
                visible: layout.active === layout.idAt(root.heldSlot) && !layout.eclipsed
            }

            StyledText {
                anchors.centerIn: parent

                anchors.horizontalCenterOffset: inkOffsetX
                anchors.verticalCenterOffset: inkOffsetY

                opacity: Math.max(0, (growth.value - 0.4) / 0.6)

                text: `${tag.modelData.count}`
                color: Appearance.colour.text
            }
        }
    }

    Repeater {
        model: root.deck.length

        delegate: Item {
            id: pad

            required property int index
            readonly property var entry: root.deck[pad.index] ?? ({
                    name: "",
                    label: "",
                    windows: []
                })

            readonly property bool open: !!pad.entry.name && layout.special === pad.entry.name

            readonly property var windows: pad.entry.windows
            readonly property int rows: Math.max(1, pad.windows.length)

            readonly property real full: root.slot + (pad.rows - 1) * root.pitch
            readonly property real cardW: root.slot - root.overhang * 2
            readonly property real cardY: root.activeGeom.y + (root.activeGeom.h - pad.full) / 2
            readonly property real barW: root.barWidth(pad.entry)

            property real shown: pad.open ? 1 : 0

            function reach(from: real, to: real): real {
                return from + (to - from) * pad.shown;
            }

            x: Math.round((root.width - width) / 2)
            width: pad.reach(pad.barW, pad.cardW)
            height: pad.reach(root.barH, pad.full)
            y: pad.reach(root.barY(pad.index), pad.cardY)
            visible: pad.shown > 0

            Behavior on shown {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.toggleSpecial(pad.entry.name)

                onWheel: wheel => wheel.accepted = true
            }

            MultiEffect {
                anchors.fill: card
                source: card

                opacity: Math.min(1, pad.shown * 2)

                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.35

                blurMax: Appearance.padding.normal
                shadowBlur: 1
                shadowVerticalOffset: Math.round(Appearance.padding.small / 3)
            }

            G2Rect {
                id: card

                anchors.fill: parent

                layer.enabled: true
                layer.samples: 4
                visible: false

                radius: root.radius

                color: Appearance.colour.surface

                G2Rect {
                    anchors.fill: parent
                    radius: root.radius
                    color: Appearance.colour.fillStronger
                }

                G2Rect {
                    anchors.fill: parent
                    radius: root.radius
                    color: Appearance.colour.accentFill
                    opacity: pad.shown
                }

                Repeater {
                    model: ScriptModel {
                        values: pad.windows
                    }

                    delegate: AppMark {
                        id: mark

                        required property var modelData
                        required property int index

                        readonly property real markSize: pad.reach(root.barMark, root.iconSize)

                        x: Math.round((pad.width - mark.markSize) / 2)
                        y: pad.reach(Math.round((root.barH - mark.markSize) / 2), root.slot / 2 + mark.index * root.pitch - mark.markSize / 2)
                        size: Math.round(mark.markSize)

                        spec: AppIcons.markFor(Hypr.classOf(mark.modelData), root.iconMode)
                        fallback: Apps.iconFor(Hypr.classOf(mark.modelData))
                        color: Hypr.isFocused(mark.modelData) ? Appearance.colour.text : Appearance.colour.textDim
                    }
                }
            }
        }
    }
}
