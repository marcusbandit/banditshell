pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

Column {
    id: root

    property Item page

    readonly property var defs: root.page ? root.page.knobs ?? [] : []

    readonly property var shown: root.defs.filter(d => d.when !== false)

    spacing: Appearance.padding.normal

    StyledText {
        text: "knobs"
        color: Appearance.colour.textFaint
    }

    StyledText {
        visible: root.shown.length === 0
        width: Math.min(parent.width, 220)
        text: "no knobs yet - this page has no demo to drive"
        color: Appearance.colour.textGhost
        wrapMode: Text.Wrap
    }

    Repeater {
        model: root.shown.filter(d => d.kind === "toggle")

        delegate: Row {
            id: toggleRow

            required property var modelData

            width: root.width
            spacing: Appearance.padding.small

            StyledText {
                width: parent.width - toggleCtl.width - Appearance.padding.small
                text: toggleRow.modelData.label
                color: Appearance.colour.textDim
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            Toggle {
                id: toggleCtl

                anchors.verticalCenter: parent.verticalCenter

                property bool own: toggleRow.modelData.initial ?? false

                checked: toggleCtl.own

                onToggled: {
                    toggleCtl.own = !toggleCtl.own;
                    root.page[toggleRow.modelData.prop] = toggleCtl.own;
                }

                Component.onCompleted: root.page[toggleRow.modelData.prop] = toggleCtl.own
            }
        }
    }

    Repeater {
        model: root.shown.filter(d => d.kind === "choice")

        delegate: Column {
            id: choiceRow

            required property var modelData

            property int chosen: Math.max(0, choiceRow.modelData.options.indexOf(choiceRow.modelData.initial ?? ""))

            readonly property real charW: Math.ceil(Appearance.font.size.small * 2 / 3)
            readonly property real room: root.width

            readonly property var rows: {
                const per = [];
                let row = [];
                let widest = 0;
                for (const o of choiceRow.modelData.options) {
                    const w = o.length * choiceRow.charW + Appearance.padding.normal * 2;
                    if (row.length > 0 && Math.max(widest, w) * (row.length + 1) > choiceRow.room) {
                        per.push(row);
                        row = [];
                        widest = 0;
                    }
                    row.push(o);
                    widest = Math.max(widest, w);
                }
                if (row.length > 0)
                    per.push(row);
                return per;
            }

            width: root.width
            spacing: Appearance.padding.small

            StyledText {
                text: choiceRow.modelData.label
                color: Appearance.colour.textDim
            }

            Repeater {
                model: choiceRow.rows

                delegate: Segments {
                    id: rowCtl

                    required property int index

                    readonly property var slice: choiceRow.rows[rowCtl.index]
                    readonly property int taken: Math.max(0, Math.min(rowCtl.slice.length - 1, choiceRow.chosen - choiceRow.rows.slice(0, rowCtl.index).reduce((n, r) => n + r.length, 0)))

                    options: rowCtl.slice
                    current: rowCtl.taken

                    onPicked: index => {
                        const before = choiceRow.rows.slice(0, rowCtl.index).reduce((n, r) => n + r.length, 0);
                        choiceRow.chosen = before + index;
                        root.page[choiceRow.modelData.prop] = choiceRow.modelData.options[choiceRow.chosen];
                    }
                }
            }

            Component.onCompleted: root.page[choiceRow.modelData.prop] = choiceRow.modelData.options[chosen]
        }
    }

    Repeater {
        model: root.shown.filter(d => d.kind === "value")

        delegate: Column {
            id: valueRow

            required property var modelData

            readonly property string shown: valueRow.modelData.format ? valueRow.modelData.format(valueCtl.own) : valueCtl.own.toFixed(2)

            width: root.width
            spacing: Appearance.padding.small

            Row {
                width: parent.width

                StyledText {
                    id: valueLabel

                    text: valueRow.modelData.label
                    color: Appearance.colour.textDim
                }

                StyledText {
                    width: parent.width - valueLabel.implicitWidth
                    text: valueRow.shown
                    color: Appearance.colour.text
                    horizontalAlignment: Text.AlignRight
                }
            }

            Slider {
                id: valueCtl

                property real own: valueRow.modelData.initial ?? 0

                width: parent.width
                from: valueRow.modelData.from ?? 0
                to: valueRow.modelData.to ?? 1
                step: valueRow.modelData.step ?? 0.05
                value: valueCtl.own

                onMoved: value => {
                    valueCtl.own = value;
                    root.page[valueRow.modelData.prop] = value;
                }

                Component.onCompleted: root.page[valueRow.modelData.prop] = valueCtl.own
            }
        }
    }
}
