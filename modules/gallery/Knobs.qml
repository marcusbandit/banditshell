pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// THE KNOBS: the controls a page's demo answers to, rendered from the page's
// own declaration.
//
// A page advertises `knobs`, a list of definitions, and declares a real
// property on itself for each one. The knob owns nothing but its own local
// state and PUSHES the value onto the page's property; the page's demo reads
// its property the ordinary way, so every binding inside the demo is a normal
// reactive one and the knob panel is the only writer. That one direction is
// the whole contract: knobs influence the look, the demo answers, nothing
// reads back - the gallery is a workbench, not a second settings page.
//
// Three kinds, each built from the primitive the shell already has for the
// question, so the gallery is drawn out of the components it showcases:
//
//   toggle   a yes/no              -> Toggle      pushes a bool
//   choice   one of a named set    -> Segments    pushes the chosen string
//   value    a number on a range   -> Slider      pushes a real
//
// A definition may carry `initial` and, for a value, a `format` for the
// readout. It may also carry `when`: false hides the knob, for a control
// that only exists in some of the page's states - a "checked" knob with no
// toggle variant on the page would be a knob lying about what it drives.
// Every property named by a `prop` MUST exist on the page: there is
// no error worth catching here that does not announce itself the first time
// the demo ignores its knob.
Column {
    id: root

    // The page being knobbled. Its `knobs` list is the model below.
    property Item page

    readonly property var defs: root.page ? root.page.knobs ?? [] : []
    // The live subset: those not turned off by their own `when`.
    readonly property var shown: root.defs.filter(d => d.when !== false)

    spacing: Appearance.padding.normal

    StyledText {
        text: "knobs"
        color: Appearance.colour.textFaint
    }

    // Nothing declared yet, which is the placeholder page's state: say so
    // rather than drawing an empty column that looks broken.
    StyledText {
        visible: root.shown.length === 0
        width: Math.min(parent.width, 220)
        text: "no knobs yet - this page has no demo to drive"
        color: Appearance.colour.textGhost
        wrapMode: Text.Wrap
    }

    Repeater {
        model: root.shown.filter(d => d.kind === "toggle")

        // A BOOL. The label says what it influences; the switch is the shell's
        // own, so the knob panel doubles as a Toggle under every lighting a
        // gallery visitor will ever see.
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

                // Local first, page second: the knob's own truth, then the
                // push. Flipping on `toggled` here is the knob doing what any
                // caller of Toggle does - the control still owns no state.
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

        // ONE OF A NAMED SET. The page receives the chosen STRING, not the
        // index: a page has no business knowing its options are numbered.
        //
        // More than fits wraps onto further rows, and the fill is GREEDY BY
        // MEASURED WIDTH, not a fixed count: Monocraft is a monospace font,
        // so an option's width is its character count on the type ladder's
        // grid, and "extra small" and "outlined" are different-sized words
        // that deserve different rows. A fixed three would have elided the
        // size knob's first row into mush.
        delegate: Column {
            id: choiceRow

            required property var modelData

            property int chosen: Math.max(0, choiceRow.modelData.options.indexOf(choiceRow.modelData.initial ?? ""))

            readonly property real charW: Math.ceil(Appearance.font.size.small * 2 / 3)
            readonly property real room: root.width
            // The measure is Segments' OWN rule, not a sum of each option's
            // width: every segment in a row is as wide as the row's WIDEST
            // label, so a row of five short words can be wider than the
            // five words are. Filling by the sum alone put three options on
            // a row that then clipped.
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

        // A NUMBER ON A RANGE. The readout is the knob's own opinion of its
        // value (a `format` off the definition when there is one); the page
        // always gets the raw real.
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
