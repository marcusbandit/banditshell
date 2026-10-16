import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string source: ""
    property real radius: Appearance.rounding.normal
    property real power: Appearance.rounding.power
    property bool blurred: false
    property real brightness: 0
    property real tame: 0

    property bool second: false

    readonly property Item front: (root.second ? two : one).item
    readonly property Item spare: (root.second ? one : two).item

    readonly property bool ready: !!root.front?.ready

    function take(): void {
        if (!root.front || !root.spare)
            return;
        if (root.front.source === root.source) {
            root.spare.source = "";
            return;
        }
        root.spare.source = root.source;
        root.check();
    }

    function check(): void {
        const spare = root.spare;
        if (!spare || spare.source !== root.source)
            return;
        if (spare.ready || spare.status === Image.Error || root.source === "")
            root.second = !root.second;
    }

    onSourceChanged: root.take()

    Component.onCompleted: {
        if (root.front)
            root.front.source = root.source;
    }

    Connections {
        target: root.spare

        function onStatusChanged(): void {
            root.check();
        }
    }

    Follow {
        id: mix

        target: root.second ? 1 : 0
        speed: Appearance.animation.revealSpeed * 0.6
        epsilon: 0.003
    }

    Component {
        id: plain

        SquircleImage {
            radius: root.radius
            power: root.power
        }
    }

    Component {
        id: soft

        BlurredImage {
            radius: root.radius
            brightness: root.brightness
            tame: root.tame
        }
    }

    Loader {
        id: one

        anchors.fill: parent
        sourceComponent: root.blurred ? soft : plain
        opacity: 1 - mix.value
        visible: opacity > 0.003
    }

    Loader {
        id: two

        anchors.fill: parent
        sourceComponent: root.blurred ? soft : plain
        opacity: mix.value
        visible: opacity > 0.003
    }
}
