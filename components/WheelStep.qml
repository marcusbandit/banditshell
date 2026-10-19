import QtQuick
import qs.config

WheelHandler {
    id: root

    required property Flickable flick

    property real notch: 100

    readonly property real top: root.flick.originY - root.flick.topMargin
    readonly property real bottom: Math.max(root.top, root.flick.originY + root.flick.contentHeight + root.flick.bottomMargin - root.flick.height)

    readonly property real goal: root.glide.running ? root.glide.to : root.flick.contentY
    readonly property bool gliding: root.glide.running

    function bound(y: real): real {
        return Math.max(root.top, Math.min(y, root.bottom));
    }

    function scrollTo(y: real): void {
        root.flick.cancelFlick();
        root.glide.to = root.bound(y);
        root.glide.restart();
    }

    function stop(): void {
        root.glide.stop();
    }

    function reclamp(): void {
        if (root.glide.running && root.glide.to !== root.bound(root.glide.to))
            root.scrollTo(root.glide.to);
    }

    enabled: root.flick.interactive
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: event => {
        if (Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) || Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y)) {
            event.accepted = false;
            return;
        }
        if (event.phase === Qt.NoScrollPhase && (event.angleDelta.y !== 0 || event.pixelDelta.y !== 0)) {
            const notches = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 15;
            root.scrollTo(root.goal - notches * root.notch);
            return;
        }
        root.glide.stop();
        root.flick.cancelFlick();
        root.flick.contentY = root.bound(root.flick.contentY - event.pixelDelta.y);
    }

    property NumberAnimation glide: NumberAnimation {
        target: root.flick
        property: "contentY"
        duration: Appearance.still ? 0 : 200
        easing.type: Easing.OutCubic
    }

    property Connections hooks: Connections {
        target: root.flick

        function onMovementStarted(): void {
            root.glide.stop();
        }

        function onContentHeightChanged(): void {
            root.reclamp();
        }

        function onHeightChanged(): void {
            root.reclamp();
        }
    }
}
