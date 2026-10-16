pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real originX
    required property real inset

    property Item surface: null
    property TextInput input: null
    property Item view: null
    property real rowPitch: 0
    property real travel: 0

    property bool shown: false
    readonly property bool open: root.shown

    readonly property real drawnHeight: root.surface?.height ?? 0

    readonly property Item maskItem: catcher

    readonly property var blobs: !root.surface || root.surface.height <= 0 ? [] : [
        {
            x: root.surface.x,
            y: root.surface.y,
            w: root.surface.width,
            h: root.surface.height,
            radius: Appearance.rounding.large,
            smooth: Math.min(Appearance.sizes.melt, Math.min(root.surface.width, root.surface.height) / 2)
        }
    ]

    property string restoreTo: ""

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    property bool answerless: false

    readonly property var answer: root.answerless ? null : Calculator.answerFor(root.input?.text ?? "")

    Connections {
        target: root.input

        function onTextChanged(): void {
            Calculator.ask(root.input.text);
        }
    }

    Connections {
        target: Polkit

        function onActiveChanged(): void {
            if (!Polkit.active && root.shown)
                Qt.callLater(root.input.forceActiveFocus);
        }
    }

    property bool answerHolds: false

    onAnswerChanged: root.answerHolds = !!root.answer && root.answer.firm !== false

    property bool dragging: false
    property real dragProgress: 0

    readonly property real revealed: root.dragging ? root.dragProgress : rise.value

    readonly property int pageRows: Math.max(1, Math.floor((root.view?.height ?? 0) / root.rowPitch) - 1)

    signal showing
    signal cleared
    signal hidden
    signal dropped(stayedOpen: bool)

    function show(): void {
        if (!root.shown)
            root.restoreTo = Hypr.focusedOn(root.screenName);
        if (!Calculator.qalcFound)
            Calculator.probeQalc();

        root.showing();
        root.shown = true;
        root.input.text = "";
        root.cleared();

        Qt.callLater(root.input.forceActiveFocus);
    }

    function hide(): void {
        root.shown = false;
        root.input.focus = false;
        root.hidden();
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;

        rise.value = root.dragProgress;

        if (open) {
            if (!root.shown)
                root.show();
        } else {
            root.hide();
        }

        root.dropped(open);
        root.dragProgress = 0;
    }

    function copyAnswer(): bool {
        if (!root.answerHolds || !root.answer)
            return false;

        if (root.answer.missing) {
            Calculator.installQalc();
            return true;
        }

        Clipboard.copy({
            text: root.answer.text
        });
        root.hide();
        return true;
    }

    function launch(what: var): void {
        what();
        root.restoreTo = "";
        Hypr.claimNextWindow();
        root.hide();
    }

    function back(): void {
        root.hide();
    }

    function accept(): void {
    }

    function move(delta: int): void {
    }

    function page(rows: int): void {
        root.move(rows);
    }

    function claimKey(event: var): bool {
        return false;
    }

    function pressKey(event: var): void {
        if (root.claimKey(event)) {
            event.accepted = true;
            return;
        }

        switch (event.key) {
        case Qt.Key_Escape:
            root.back();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.accept();
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            root.move(1);
            break;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            root.move(-1);
            break;
        case Qt.Key_PageDown:
            root.page(root.pageRows);
            break;
        case Qt.Key_PageUp:
            root.page(-root.pageRows);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    Pull {
        id: putAway

        x: root.surface?.x ?? 0
        y: root.surface?.y ?? 0
        width: root.surface?.width ?? 0
        height: root.surface?.height ?? 0

        armed: root.open

        dirX: 0
        dirY: 1

        angle: Config.values.control.pullAngleEdge

        travel: root.travel

        onPulled: fraction => root.dragTo(1 - fraction)

        onFinished: gone => root.dragEnd(!gone)
    }
}
