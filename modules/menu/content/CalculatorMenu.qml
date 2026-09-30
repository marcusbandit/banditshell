pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    spacing: Appearance.padding.normal

    property string entry: "0"

    property bool typed: false

    property real acc: 0

    property string op: ""

    property string history: ""

    property bool expandable: false

    property bool expanded: false

    signal expandToggled

    readonly property real gap: Appearance.padding.small

    readonly property int columns: Math.max(...root.keys.map(row => row.reduce((n, k) => n + (k.span ?? 1), 0)))

    readonly property real unit: (root.width - root.gap * (root.columns - 1)) / root.columns

    readonly property real restKeyHeight: Math.max(Appearance.sizes.minTarget, Math.round(Appearance.font.size.normal * 4 / 3) + Appearance.padding.normal * 2)

    property real rowHeight: 0

    readonly property real keyHeight: root.rowHeight > 0 ? root.rowHeight : root.restKeyHeight

    readonly property real chromeHeight: readout.height + root.spacing * 2 + rule.height

    readonly property int rows: root.keys.length

    readonly property var keys: [
        [
            {
                tag: "back",
                icon: "backspace",
                span: 2
            },
            {
                tag: "clear",
                label: "C"
            },
            {
                tag: "op",
                label: "÷"
            }
        ],
        [
            {
                tag: "digit",
                label: "7"
            },
            {
                tag: "digit",
                label: "8"
            },
            {
                tag: "digit",
                label: "9"
            },
            {
                tag: "op",
                label: "×"
            }
        ],
        [
            {
                tag: "digit",
                label: "4"
            },
            {
                tag: "digit",
                label: "5"
            },
            {
                tag: "digit",
                label: "6"
            },
            {
                tag: "op",
                label: "−"
            }
        ],
        [
            {
                tag: "digit",
                label: "1"
            },
            {
                tag: "digit",
                label: "2"
            },
            {
                tag: "digit",
                label: "3"
            },
            {
                tag: "op",
                label: "+"
            }
        ],
        [
            {
                tag: "digit",
                label: "0",
                span: 2
            },
            {
                tag: "dot",
                label: "."
            },
            {
                tag: "equals",
                label: "="
            }
        ]
    ]

    function value(): real {
        if (root.entry === "∞")
            return Infinity;
        if (root.entry === "-∞")
            return -Infinity;
        const v = parseFloat(root.entry);
        return isNaN(v) ? 0 : v;
    }

    function beginEntry(): void {
        if (root.op === "")
            root.history = "";
    }

    function digit(d: string): void {
        if (!root.typed) {
            root.beginEntry();
            root.entry = d;
            root.typed = true;
            return;
        }

        root.entry = root.entry === "0" ? d : root.entry + d;
    }

    function dot(): void {
        if (!root.typed) {
            root.beginEntry();

            root.entry = "0.";
            root.typed = true;
            return;
        }
        if (!root.entry.includes("."))
            root.entry += ".";
    }

    function back(): void {
        if (!root.typed)
            root.beginEntry();
        root.typed = true;
        root.entry = root.entry.slice(0, -1);
        if (root.entry === "" || root.entry === "-") {
            root.entry = "0";
            root.typed = false;
        }
    }

    function operate(o: string): void {
        if (root.op !== "" && root.typed)
            root.settle();

        root.acc = root.value();
        root.op = o;

        root.typed = false;
    }

    function settle(): void {
        const a = root.acc;
        const o = root.op;
        const b = root.value();
        const r = Calculator.apply(a, o, b);

        root.history = `${Calculator.format(a)} ${o} ${Calculator.format(b)} = ${Calculator.format(r)}`;
        root.entry = Calculator.format(r);
        root.acc = r;
        root.op = "";
        root.typed = false;
    }

    function equals(): void {
        if (root.op !== "")
            root.settle();
    }

    function clear(): void {
        root.entry = "0";
        root.typed = false;
        root.acc = 0;
        root.op = "";
        root.history = "";
    }

    function press(spec: var): void {
        switch (spec.tag) {
        case "digit":
            root.digit(spec.label);
            break;
        case "dot":
            root.dot();
            break;
        case "op":
            root.operate(spec.label);
            break;
        case "equals":
            root.equals();
            break;
        case "back":
            root.back();
            break;
        case "clear":
            root.clear();
            break;
        }
    }

    function typeKey(key: int, text: string): bool {
        if (key === Qt.Key_Backspace) {
            root.press({
                tag: "back"
            });
            return true;
        }

        if (key === Qt.Key_Delete) {
            root.press({
                tag: "clear"
            });
            return true;
        }

        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            root.press({
                tag: "equals"
            });
            return true;
        }

        const c = text ?? "";
        if (c.length !== 1)
            return false;

        if (c >= "0" && c <= "9") {
            root.press({
                tag: "digit",
                label: c
            });
            return true;
        }

        if (c === "." || c === ",") {
            root.press({
                tag: "dot"
            });
            return true;
        }

        if (c === "=") {
            root.press({
                tag: "equals"
            });
            return true;
        }

        if (c === "c" || c === "C") {
            root.press({
                tag: "clear"
            });
            return true;
        }

        const o = Calculator.operators[c];
        if (o !== undefined) {
            root.press({
                tag: "op",
                label: o
            });
            return true;
        }

        return false;
    }

    readonly property string working: {
        if (root.op === "")
            return root.history;
        const left = `${Calculator.format(root.acc)} ${root.op}`;
        return root.typed ? `${left} ${root.entry}` : left;
    }

    component Key: Item {
        id: key

        required property var spec

        readonly property bool lit: key.spec.tag === "op" && root.op === key.spec.label

        readonly property int span: key.spec.span ?? 1

        readonly property color rest: {
            switch (key.spec.tag) {
            case "op":
                return Appearance.colour.fillStrong;
            case "equals":
                return Appearance.colour.fillStronger;
            }
            return Appearance.colour.fill;
        }

        readonly property color raised: {
            switch (key.spec.tag) {
            case "op":
                return Appearance.colour.fillStronger;
            case "equals":
                return Appearance.blend(Appearance.colour.fillStronger, Appearance.colour.text, 0.15);
            }
            return Appearance.colour.fillStrong;
        }

        readonly property color ink: key.spec.tag === "back" || key.spec.tag === "clear" ? Appearance.colour.textDim : Appearance.colour.text

        implicitWidth: root.unit * key.span + root.gap * (key.span - 1)
        implicitHeight: root.keyHeight
        width: implicitWidth
        height: implicitHeight

        scale: press.pressed ? 0.96 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal

            color: key.lit ? Appearance.colour.accentFill : press.containsMouse || press.pressed ? key.raised : key.rest

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: inkOffsetX
            anchors.verticalCenterOffset: inkOffsetY

            visible: !!key.spec.icon
            name: key.spec.icon ?? ""

            size: Appearance.font.size.normal
            color: key.ink
        }

        StyledText {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: inkOffsetX
            anchors.verticalCenterOffset: inkOffsetY

            visible: !key.spec.icon
            text: key.spec.label ?? ""
            font.pixelSize: Appearance.font.size.normal
            color: key.lit ? Appearance.colour.accent : key.ink

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.press(key.spec)
        }
    }

    Item {
        id: readout

        width: parent.width
        height: Math.max(answer.height + Appearance.padding.small + working.height, expander.height)

        Item {
            id: expander

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            visible: root.expandable
            width: root.expandable ? Appearance.sizes.minTarget : 0
            height: root.expandable ? Appearance.sizes.minTarget : 0

            scale: grab.pressed ? 0.96 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: grab.containsMouse || grab.pressed ? Appearance.colour.fillStrong : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: inkOffsetX
                anchors.verticalCenterOffset: inkOffsetY

                name: root.expanded ? "close_fullscreen" : "open_in_full"
                size: Appearance.font.size.normal
                color: grab.containsMouse || grab.pressed ? Appearance.colour.text : Appearance.colour.textDim

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            MouseArea {
                id: grab

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandToggled()
            }
        }

        Item {
            id: lines

            anchors.left: expander.right
            anchors.leftMargin: root.expandable ? Appearance.padding.normal : 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            height: answer.height + Appearance.padding.small + working.height

            TextMetrics {
                id: probe

                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.large
                text: root.entry
            }

            StyledText {
                id: answer

                width: parent.width
                height: Math.round(Appearance.font.size.large * 4 / 3)

                text: root.entry
                font.pixelSize: probe.width <= lines.width ? Appearance.font.size.large : Appearance.font.size.normal

                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }

            StyledText {
                id: working

                anchors.top: answer.bottom
                anchors.topMargin: Appearance.padding.small

                width: parent.width
                height: Math.round(Appearance.font.size.small * 4 / 3)

                text: root.working
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter

                elide: Text.ElideLeft
            }
        }
    }

    Separator {
        id: rule

        width: parent.width
    }

    Column {
        id: pad

        width: parent.width
        spacing: root.gap

        Repeater {
            model: root.keys

            delegate: Row {
                id: line

                required property var modelData

                width: pad.width
                spacing: root.gap

                Repeater {
                    model: line.modelData

                    delegate: Key {
                        required property var modelData

                        spec: modelData
                    }
                }
            }
        }
    }
}
