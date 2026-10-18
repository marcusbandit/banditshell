pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

Item {
    id: root

    required property real originX

    readonly property bool open: root.shown
    property bool shown: false

    property bool full: false

    readonly property Item maskItem: catcher

    readonly property real contentWidth: Appearance.sizes.menuWidth - Appearance.padding.large * 2

    readonly property real flankWidth: root.originX + root.contentWidth + Appearance.padding.large * 2
    readonly property real flankHeight: pad.chromeHeight + pad.rows * pad.restKeyHeight + (pad.rows - 1) * pad.gap + Appearance.padding.large * 2

    readonly property real inset: Appearance.sizes.melt
    readonly property real fullX: root.originX + root.inset
    readonly property real fullY: Appearance.sizes.band + root.inset
    readonly property real fullWidth: root.width - root.fullX - Appearance.sizes.band - root.inset
    readonly property real fullHeight: root.height - (Appearance.sizes.band + root.inset) * 2

    readonly property real fullness: shape.value

    function mix(a: real, b: real): real {
        return a + (b - a) * root.fullness;
    }

    readonly property real panelWidth: root.mix(root.flankWidth, root.fullWidth)
    readonly property real panelHeight: root.mix(root.flankHeight, root.fullHeight)

    readonly property real restX: root.mix(0, root.fullX)
    readonly property real restY: root.mix((root.height - root.flankHeight) / 2, root.fullY)

    readonly property real slide: (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property real panelX: root.restX - root.slide

    readonly property var blobs: [
        {
            x: root.panelX,
            y: root.restY,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    readonly property real keyCeiling: Appearance.font.line.large + Appearance.padding.huge * 2
    readonly property real keyRoom: (root.fullHeight - Appearance.padding.large * 2 - pad.chromeHeight - (pad.rows - 1) * pad.gap) / pad.rows
    readonly property real fullKeyHeight: Math.max(pad.restKeyHeight, Math.min(root.keyCeiling, root.keyRoom))

    readonly property real fullBodyWidth: Math.min(root.fullWidth - Appearance.padding.large * 2, root.contentWidth * (root.fullKeyHeight / pad.restKeyHeight))

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;

        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        keys.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function app(): void {
        root.full = true;
        root.show();
    }

    function panel(): void {
        root.full = false;
        root.show();
    }

    function toggleFull(): void {
        root.full = !root.full;
    }

    readonly property string memoryKey: `calculator ${root.screenName}`

    function remember(): void {
        Relaunch.keep(root.memoryKey, {
            full: root.full,
            entry: pad.entry,
            typed: pad.typed,
            acc: pad.acc,
            op: pad.op,
            history: pad.history
        });
    }

    Connections {
        target: pad

        function onEntryChanged(): void {
            root.remember();
        }

        function onTypedChanged(): void {
            root.remember();
        }

        function onAccChanged(): void {
            root.remember();
        }

        function onOpChanged(): void {
            root.remember();
        }

        function onHistoryChanged(): void {
            root.remember();
        }
    }

    Component.onCompleted: {
        const was = Relaunch.recall(root.memoryKey);
        if (!was)
            return;
        pad.entry = was.entry ?? "0";
        pad.typed = !!was.typed;
        pad.acc = was.acc ?? 0;
        pad.op = was.op ?? "";
        pad.history = was.history ?? "";
        root.full = !!was.full;
    }

    Follow {
        id: reveal

        speed: Appearance.animation.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: shape

        speed: Appearance.animation.revealSpeed
        target: root.full ? 1 : 0
        epsilon: 0.005

        Component.onCompleted: snap()
    }

    onFullChanged: {
        if (!root.shown)
            shape.snap();
        root.remember();
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Appearance.instantly();
                root.hide();
                event.accepted = true;
                return;
            }

            event.accepted = pad.typeKey(event.key, event.text);
        }
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.hide()
    }

    Item {
        id: panel

        x: root.panelX
        y: root.restY
        width: root.panelWidth
        height: root.panelHeight
        visible: reveal.value > 0.001
        enabled: root.open

        CalculatorMenu {
            id: pad

            x: root.mix(root.originX + Appearance.padding.large, (panel.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter

            width: root.mix(root.contentWidth, root.fullBodyWidth)
            rowHeight: root.mix(pad.restKeyHeight, root.fullKeyHeight)

            expandable: true
            expanded: root.full

            onExpandToggled: root.toggleFull()
        }
    }
}
