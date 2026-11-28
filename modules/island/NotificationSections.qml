pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.modules.notifications
import qs.services
import "notification-sections.js" as Sections

Item {
    id: root

    property var groups: []
    property var holders: []
    property bool watched: false
    property real maxHeight: 100000
    property real contentLead: Appearance.padding.card

    signal chosen(var activity)

    readonly property var sections: Sections.split(root.groups, root.holders.length)
    readonly property var opened: Sections.newest(root.groups)
    readonly property var drawn: root.groups.reduce((all, g) => all.concat(g.entries.filter(e => !e.leaving)), [])

    readonly property real markSize: Appearance.font.line.small + Appearance.padding.small
    readonly property real barHeight: root.markSize + Appearance.padding.normal * 2
    readonly property real barRoom: root.barHeight + Appearance.padding.small
    readonly property real fullHeight: list.implicitHeight
    readonly property bool overflows: root.fullHeight > root.maxHeight + 0.5
    readonly property real viewHeight: root.overflows ? Math.max(0, root.maxHeight - root.barRoom) : root.fullHeight

    implicitHeight: root.overflows ? root.maxHeight : root.fullHeight

    function foldAll(): void {
        for (let i = 0; i < sectionRepeater.count; i++)
            sectionRepeater.itemAt(i)?.deck.foldAll();
    }

    onWatchedChanged: if (!root.watched)
        wheel.scrollTo(0)

    readonly property var placed: {
        scroller.contentY;
        list.implicitHeight;
        sectionRepeater.count;
        const out = [];
        for (let i = 0; i < sectionRepeater.count; i++) {
            const section = sectionRepeater.itemAt(i);
            if (!section)
                continue;
            const rowCount = section.rows.count;
            for (let h = 0; h < rowCount; h++) {
                const row = section.rows.itemAt(h);
                if (row)
                    out.push({
                        key: `holder:${row.modelData.key}`,
                        holder: row.modelData,
                        top: section.y + section.rowsTop + row.y,
                        height: row.height
                    });
            }
            const deck = section.deck;
            for (const p of deck.placed)
                out.push({
                    key: `entry:${p.entry.id || out.length}`,
                    entry: p.entry,
                    top: section.y + deck.y + p.top,
                    height: p.height
                });
        }
        return out;
    }

    readonly property var below: root.overflows ? root.placed.map(p => Object.assign({}, p, {
                shown: 1 - Sections.seen(p.top - scroller.contentY, p.height, 0, root.viewHeight)
            })).filter(p => p.shown > 0.001) : []

    Flickable {
        id: scroller

        function nudge(by: real): void {
            wheel.stop();
            scroller.contentY = wheel.bound(scroller.contentY - by);
        }

        function glide(speed: real): void {
            wheel.scrollTo(scroller.contentY - speed * 260);
        }

        width: root.width
        height: root.viewHeight
        contentHeight: list.implicitHeight
        interactive: root.overflows
        boundsBehavior: Flickable.StopAtBounds
        clip: root.overflows

        WheelStep {
            id: wheel

            flick: scroller
        }

        Column {
            id: list

            width: scroller.width
            spacing: Appearance.padding.normal

            Repeater {
                id: sectionRepeater

                model: ScriptModel {
                    values: root.sections
                    objectProp: "key"
                }

                Column {
                    id: section

                    required property var modelData

                    readonly property alias deck: deck
                    readonly property alias rows: holderRows
                    readonly property real rowsTop: holderColumn.y

                    width: list.width
                    spacing: Appearance.padding.small

                    StyledText {
                        x: root.contentLead
                        text: section.modelData.title
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }

                    Column {
                        id: holderColumn

                        width: parent.width
                        spacing: Appearance.stroke.line
                        visible: section.modelData.key === "silent" && root.holders.length > 0

                        Repeater {
                            id: holderRows

                            model: section.modelData.key === "silent" ? root.holders : []

                            SilentRow {
                                required property var modelData
                                required property int index

                                width: holderColumn.width
                                holder: modelData
                                contentLead: root.contentLead
                                joinedAbove: index > 0
                                joinedBelow: index < root.holders.length - 1 || section.modelData.groups.length > 0
                                onChosen: root.chosen({
                                    kind: "privacy",
                                    data: {
                                        privacy: modelData.kind
                                    }
                                })
                            }
                        }
                    }

                    AlertDeck {
                        id: deck

                        width: parent.width
                        visible: section.modelData.groups.length > 0
                        groups: section.modelData.groups
                        fanned: 1
                        footed: false
                        contentLead: root.contentLead
                        liftsAway: false
                        warm: root.watched
                        briefRest: true
                        opened: root.opened
                        scroller: scroller

                        onDismissed: entry => Notifications.forget(entry)
                        onKept: entry => Notifications.forget(entry)
                    }
                }
            }
        }
    }

    Item {
        id: bar

        readonly property real lit: root.below.reduce((most, p) => Math.max(most, p.shown), 0)

        x: Appearance.padding.small
        y: root.viewHeight + Appearance.padding.small
        width: root.width - Appearance.padding.small * 2
        height: root.barHeight
        visible: root.overflows && bar.lit > 0.01
        opacity: Math.min(1, bar.lit * 3)

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.tile
        }

        Item {
            x: root.contentLead - Appearance.padding.small
            width: parent.width - x * 2
            height: parent.height
            clip: true

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: ScriptModel {
                        values: root.below
                        objectProp: "key"
                    }

                    Item {
                        id: chip

                        required property var modelData

                        width: (root.markSize + Appearance.padding.small) * Math.min(1, chip.modelData.shown * 2)
                        height: root.markSize
                        opacity: chip.modelData.shown

                        Item {
                            anchors.centerIn: parent
                            width: root.markSize
                            height: root.markSize
                            scale: 0.4 + 0.6 * chip.modelData.shown

                            NotificationMark {
                                visible: !!chip.modelData.entry
                                entry: chip.modelData.entry ?? null
                                size: root.markSize
                                radius: Appearance.rounding.small
                            }

                            AppMark {
                                visible: !!chip.modelData.holder
                                spec: chip.modelData.holder?.spec ?? ""
                                fallback: chip.modelData.holder?.icon ?? "apps"
                                size: root.markSize
                                color: Appearance.colour.text
                                fits: AppIcons.fits
                            }
                        }
                    }
                }
            }
        }
    }
}
