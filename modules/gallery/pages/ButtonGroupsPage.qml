pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Button groups. Related presses held together as one shape.
//
// Wraps components/ButtonGroup.qml - one plate, flush members, a press asked
// for and answered. The page exists to argue the two questions this shell
// has about that: what the members carry, and how many of them there can be
// before "one object with parts" stops being true. The disabled knob is the
// whole-group answer; a per-member disabled is a decision this page has not
// made yet.
//
// The line under the group says which member was pressed last, because a
// group is for pressing and a demo that only restyles itself cannot show the
// press going anywhere.
Item {
    id: page

    property bool drawn: true

    // What was pressed last, as { index, label }, or null.
    property var last: null

    // The values the knobs write.
    property string carries: "words"
    property string members: "three"
    property bool disabled: false

    readonly property var knobs: [
        {
            kind: "choice",
            prop: "carries",
            label: "carries",
            options: ["words", "mark", "both"],
            initial: "words"
        },
        {
            kind: "choice",
            prop: "members",
            label: "members",
            options: ["two", "three", "four"],
            initial: "three"
        },
        {
            kind: "toggle",
            prop: "disabled",
            label: "disabled",
            initial: false
        }
    ]

    // The presses, scaled by the members knob. Words and marks are two
    // spellings of the same four actions, so both come from one table and
    // cannot disagree about what member three is.
    readonly property var table: [
        {
            text: "Cut",
            icon: "content_cut"
        },
        {
            text: "Copy",
            icon: "content_copy"
        },
        {
            text: "Paste",
            icon: "content_paste"
        },
        {
            text: "Select",
            icon: "select_all"
        }
    ]
    readonly property int count: ["two", "three", "four"].indexOf(members) + 2

    readonly property var actions: {
        const out = [];
        for (let i = 0; i < count; i++) {
            out.push({
                text: carries === "words" || carries === "both" ? table[i].text : "",
                icon: carries === "mark" || carries === "both" ? table[i].icon : ""
            });
        }
        return out;
    }

    Column {
        anchors.centerIn: parent
        spacing: Appearance.padding.normal

        ButtonGroup {
            anchors.horizontalCenter: parent.horizontalCenter
            actions: page.actions
            interactive: !page.disabled
            onTriggered: index => page.last = {
                index,
                label: page.table[index].text
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: page.last === null ? "not pressed yet" : `pressed ${page.last.label} (${page.last.index})`
            color: Appearance.colour.textFaint
        }
    }
}
