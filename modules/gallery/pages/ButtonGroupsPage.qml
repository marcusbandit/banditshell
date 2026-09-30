pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

Item {
    id: page

    property bool drawn: true

    property var last: null

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
