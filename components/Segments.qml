pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// A SEGMENTED CONTROL: one row of mutually exclusive choices, of which exactly
// one is taken.
//
// It exists because the hotkey sheet had two of these questions to ask (which
// view, and how a chord is spelled) and neither of them fits the two controls
// the shell already owns. It lives here rather than beside the sheet because the
// clipboard's tabs are the same question a third time, and a control that knows
// nothing about the thing it is asked on behalf of belongs with the rest of the
// primitives (DESIGN.md 8: components know nothing about the shell). A Toggle is a SWITCH: it says one thing is on or off, and both
// of the sheet's questions are a choice between two named alternatives, neither
// of which is the absence of the other. "List" is not "not board", and "words"
// is not "not symbols"; a switch labelled "board" would be asking you to read
// its off state as the other view, which is exactly the sort of guessing an
// interface should be doing for you. A Pill is a BUTTON: it does something when
// pressed and holds no state at all, so a pair of them could show the choice
// only by colouring one differently, which is this control with the track and
// the slide left out.
//
// So it is built from the primitives rather than being a third idiom: a G2Rect
// track, a G2Rect thumb, and the labels. Everything about its size comes from
// the same two lines Pill uses (a line box plus a padding tier, floored at the
// minimum target), so the two sit at the same height in a row.
//
// N SEGMENTS, not two. The sheet only ever asks binary questions today, and
// writing it for two would put the second question's answer at a hardcoded half
// (~/.claude/rules/math-over-hardcoding.md). The width is the count, the segment
// is the width over the count, and the thumb's place is the index times the
// segment; nothing in here knows there are two of anything.
Item {
    id: root

    // The choices, in the order they are offered. The list IS the model: there
    // is no separate count, and no per-index branch anywhere below.
    property var options: []

    // WHICH ONE IS TAKEN, bound in from outside rather than held here. Toggle's
    // argument, unchanged: a control that flips itself and then finds out the
    // change did not take is worse than one that waits to be told.
    property int current: 0

    signal picked(int index)

    readonly property int count: root.options.length

    // The width of one segment, which is the only geometry in here. Guarded
    // against an empty model, because a Repeater over nothing still evaluates
    // this binding and a division by zero would put an Infinity into a width.
    readonly property real segment: root.count > 0 ? root.width / root.count : root.width

    // Every segment is as wide as the WIDEST label needs, so the thumb travels
    // in equal steps and the control does not lurch when the choice changes the
    // string lengths. Measured off the data rather than off a number written
    // here, exactly as the sheet's chord column is.
    readonly property string widest: {
        let out = "";
        for (const o of root.options)
            if (o.length > out.length)
                out = o;
        return out;
    }

    implicitWidth: root.count * (Math.ceil(ink.width) + Appearance.padding.normal * 2)
    implicitHeight: Math.max(Appearance.sizes.minTarget, Math.round(Appearance.font.size.small * 4 / 3) + Appearance.padding.small * 2)
    width: implicitWidth
    height: implicitHeight

    TextMetrics {
        id: ink

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.widest
    }

    // WHERE THE THUMB IS, smoothed rather than assigned.
    //
    // A Follow and not a Behavior on x, which is the shell's rule and is worth
    // stating here because Toggle next door does the opposite: its knob travels
    // between two ends of a fixed-width track, so a fixed duration is a fixed
    // distance and reads the same every time. This track's width comes from the
    // header it is laid out in and its segment count comes from the caller, so
    // the same duration would be a different speed on a two-choice control and a
    // four-choice one. Exponential smoothing is the same FEEL at any distance,
    // which is the whole reason this shell tracks rather than animates
    // (~/.claude/rules/animation-smoothing.md).
    Follow {
        id: slide

        speed: Appearance.anim.trackSpeed
        target: root.current * root.segment
    }

    // Snapped on the first layout, because there is no "from". Without this the
    // thumb glides in from the left edge the first time the sheet is drawn,
    // which reads as the control answering a press nobody made.
    Component.onCompleted: slide.snap()

    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fillStrong
    }

    // THE TAKEN SEGMENT, in the accent AS A FILL rather than as a label. This is
    // state worth a hue by Appearance's own test: which view you are looking at
    // is the one thing about this control you need to know from the corner of
    // your eye, and a tint says it without painting a saturated block behind
    // text that then has to fight it.
    G2Rect {
        x: slide.value
        width: root.segment
        height: parent.height
        radius: height / 2
        color: Appearance.colour.accentFill
        visible: root.count > 0
    }

    Repeater {
        model: root.options

        delegate: Item {
            id: seg

            required property string modelData
            required property int index

            x: seg.index * root.segment
            width: root.segment
            height: root.height

            StyledText {
                anchors.fill: parent
                // Clamped rather than free, and the clamp is never reached
                // while the control is at its implicit width: the segment is
                // already as wide as the longest label plus a padding tier. It
                // is here for a header that gave this control less room than it
                // asked for, where a label must lose characters rather than run
                // out over its neighbour.
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                text: seg.modelData
                // The hierarchy is carried by colour, not by size: there are
                // three sizes in this shell and a control is not the thing a
                // view is about (~/.claude/rules/type-scale.md).
                color: seg.index === root.current ? Appearance.colour.text : Appearance.colour.textFaint
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // No hoverEnabled. A hovering pointer over a segmented control
                // has nothing to say that the thumb is not already saying, and
                // a hoverEnabled area is the topmost thing that gets hover:
                // adding one here would take it away from whatever in the sheet
                // wants it next.
                onClicked: root.picked(seg.index)
            }
        }
    }
}
