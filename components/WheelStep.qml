import QtQuick
import qs.config

WheelHandler {
    id: root

    required property Flickable flick

    property real notch: ControlTuning.wheelNotch

    property bool gliding: false
    property bool touching: false
    property bool latched: false

    signal began
    signal ended

    readonly property real top: root.flick.originY - root.flick.topMargin
    readonly property real bottom: Math.max(root.top, root.flick.originY + root.flick.contentHeight + root.flick.bottomMargin - root.flick.height)

    readonly property real goal: root.gliding ? root.glide.target : root.flick.contentY

    function bound(y: real): real {
        return Math.max(root.top, Math.min(y, root.bottom));
    }

    function scrollTo(y: real): void {
        root.flick.cancelFlick();
        if (!root.gliding)
            root.glide.value = root.flick.contentY;
        root.glide.target = root.bound(y);
        root.gliding = !root.glide.settled;
    }

    function stop(): void {
        root.gliding = false;
        root.glide.snap();
    }

    function reclamp(): void {
        if (root.gliding)
            root.glide.target = root.bound(root.glide.target);
    }

    enabled: root.flick.interactive
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: event => {
        if (event.phase === Qt.ScrollEnd || event.phase === Qt.ScrollBegin) {
            if (root.touching)
                root.ended();
            root.touching = false;
            root.latched = false;
            event.accepted = false;
            return;
        }
        if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) || Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y) || event.angleDelta.y === 0 && event.pixelDelta.y === 0) {
            event.accepted = false;
            return;
        }
        if (event.phase === Qt.NoScrollPhase) {
            const notches = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 15;
            const to = root.bound(root.goal - notches * root.notch);
            if (to === root.goal) {
                event.accepted = false;
                return;
            }
            if (!root.gliding)
                root.began();
            root.scrollTo(to);
            return;
        }
        const to = root.bound(root.flick.contentY - event.pixelDelta.y);
        if (to === root.flick.contentY && !root.latched) {
            event.accepted = false;
            return;
        }
        root.latched = true;
        if (!root.touching) {
            root.touching = true;
            root.began();
        }
        root.stop();
        root.flick.cancelFlick();
        root.flick.contentY = to;
    }

    property Follow glide: Follow {
        speed: Appearance.animation.scrollSpeed
        epsilon: 0.5

        onValueChanged: if (root.gliding)
            root.flick.contentY = root.glide.value
        onSettledChanged: if (root.glide.settled && root.gliding) {
            root.gliding = false;
            root.ended();
        }
    }

    property Connections hooks: Connections {
        target: root.flick

        function onMovementStarted(): void {
            root.stop();
        }

        function onContentHeightChanged(): void {
            root.reclamp();
        }

        function onHeightChanged(): void {
            root.reclamp();
        }
    }
}
