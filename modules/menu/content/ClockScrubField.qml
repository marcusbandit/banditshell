import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property int value: 0
    property int from: 0
    property int to: 59
    property int detent: 1
    property bool wrap: true

    property bool zeroIsEmpty: true

    property int held: 0
    property bool holding: false

    readonly property int shown: root.holding ? root.held : root.value

    signal moved(int value)
    signal committed(int value)

    property bool typing: false

    readonly property bool keyable: !root.typing
    readonly property string adjusts: root.grabbed ? "vertical" : ""

    property bool grabbed: false

    property int grabbedFrom: 0

    function press(): void {
        if (!root.grabbed) {
            root.grabbedFrom = root.value;
            root.grabbed = true;
            return;
        }
        root.grabbed = false;
        root.release();
    }

    function letGo(): bool {
        if (!root.grabbed)
            return false;
        root.grabbed = false;
        quiet.stop();
        root.holding = false;
        if (root.value !== root.grabbedFrom)
            root.moved(root.grabbedFrom);
        return true;
    }

    function edit(first: string): void {
        if (root.typing)
            return;
        if (root.grabbed) {
            root.grabbed = false;
            root.release();
        }
        root.typing = true;
        entry.text = first;
        entry.forceActiveFocus();
        if (first === "")
            entry.selectAll();
        else
            entry.cursorPosition = entry.text.length;
    }

    function finish(save: bool): void {
        if (!root.typing)
            return;
        const keepFocus = entry.activeFocus;
        root.typing = false;
        const n = Clock.typedNumber(entry.text, root.from, root.to);
        entry.text = "";
        if (keepFocus)
            root.forceActiveFocus();
        if (save && n >= 0) {
            root.hold();
            root.step(n);
            root.release();
        }
    }

    Keys.onPressed: event => {
        const held = Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier;
        if (root.typing || (event.modifiers & held) !== 0)
            return;
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            root.edit(event.text);
            event.accepted = true;
        }
    }

    onActiveFocusChanged: if (!root.activeFocus && root.grabbed) {
        root.grabbed = false;
        root.release();
    }

    function adjust(steps: int): void {
        root.nudge(steps);
    }

    readonly property real pitch: Appearance.sizes.minTarget / Math.max(1, root.detent)
    readonly property int span: root.to - root.from + 1

    implicitWidth: Math.max(Appearance.sizes.minTarget, digits.implicitWidth + Appearance.padding.small * 2)
    implicitHeight: Math.max(Appearance.sizes.rowHeight, Appearance.font.line.large)
    width: implicitWidth
    height: implicitHeight

    function fold(v: int): int {
        if (!root.wrap)
            return Math.max(root.from, Math.min(root.to, v));
        return root.from + ((v - root.from) % root.span + root.span) % root.span;
    }

    function magnet(raw: real): int {
        const step = Math.max(1, root.detent);
        const nearest = Math.round(raw / step) * step;
        return Math.abs(raw - nearest) * root.pitch <= Config.values.control.dragThreshold ? nearest : Math.round(raw);
    }

    function hold(): void {
        if (root.holding)
            return;
        root.held = root.value;
        root.holding = true;
    }

    function step(v: int): void {
        if (v === root.held)
            return;
        root.held = v;
        root.moved(v);
    }

    function ask(raw: real): void {
        root.hold();
        root.step(root.fold(root.magnet(raw)));
    }

    function nudge(units: int): void {
        if (units === 0)
            return;
        root.hold();
        root.step(root.fold(root.held + units));
        quiet.restart();
    }

    function release(): void {
        quiet.stop();
        if (!root.holding)
            return;
        root.holding = false;
        if (root.held !== root.value)
            root.committed(root.held);
    }

    onVisibleChanged: if (!root.visible)
        root.release()

    Timer {
        id: quiet

        interval: Appearance.animation.settle
        onTriggered: root.release()
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
        opacity: hoverFade.value

        Follow {
            id: hoverFade

            target: root.grabbed || pointer.containsMouse || pointer.pressed || scroll.active ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }

    FocusMark {
        shown: root.activeFocus
    }

    StyledText {
        id: digits

        anchors.centerIn: parent

        visible: !root.typing
        text: Clock.twoDigits(root.shown)
        font.pixelSize: Appearance.font.size.large
        color: root.grabbed ? Appearance.colour.accent : root.zeroIsEmpty && root.shown === 0 ? Appearance.colour.textFaint : Appearance.colour.text
    }

    TextInput {
        id: entry

        readonly property bool typable: true

        anchors.fill: parent

        visible: root.typing
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        maximumLength: 2
        inputMethodHints: Qt.ImhDigitsOnly
        validator: RegularExpressionValidator {
            regularExpression: /[0-9]{0,2}/
        }

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.large
        renderType: Text.NativeRendering
        color: Appearance.colour.accent
        selectionColor: Appearance.colour.accent
        selectedTextColor: Appearance.colour.accentText

        onEditingFinished: root.finish(true)

        Keys.onEscapePressed: root.finish(false)
    }

    MouseArea {
        id: pointer

        property real fromY: 0
        property int startValue: 0
        property bool dragged: false

        anchors.fill: parent
        enabled: !root.typing
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        preventStealing: true

        onPressed: mouse => {
            scroll.finish();
            root.hold();
            pointer.dragged = false;
            pointer.fromY = mouse.y;
            pointer.startValue = root.held;
        }

        onPositionChanged: mouse => {
            if (!pointer.pressed)
                return;
            if (Math.abs(mouse.y - pointer.fromY) >= Config.values.control.dragThreshold)
                pointer.dragged = true;
            root.ask(pointer.startValue - (mouse.y - pointer.fromY) / root.pitch);
        }

        onReleased: {
            root.release();
            if (!pointer.dragged)
                root.edit("");
        }
        onCanceled: root.release()

        onWheel: wheel => {
            if (!scroll.feed(wheel)) {
                const notches = wheel.angleDelta.y / 120;
                root.nudge(Math.round(notches) || (notches > 0 ? 1 : notches < 0 ? -1 : 0));
                wheel.accepted = true;
                return;
            }

            wheel.accepted = Math.abs(scroll.dy) >= Math.abs(scroll.dx);
        }

        ScrollGesture {
            id: scroll

            armed: !pointer.pressed

            onBegan: {
                root.hold();
                pointer.startValue = root.held;
            }
            onMoved: (dx, dy) => {
                if (Math.abs(dy) >= Math.abs(dx))
                    root.ask(pointer.startValue - dy / root.pitch);
            }
            onEnded: root.release()
        }
    }
}
