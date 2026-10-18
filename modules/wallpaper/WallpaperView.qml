pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string output

    property bool playing: false
    property bool audible: false

    readonly property string wanted: Wallpaper.shownOn(root.output)

    readonly property var slots: [a, b, c]
    property int lifted: 0

    readonly property Slot front: root.slots.reduce((top, slot) => slot.order > top.order ? slot : top)
    readonly property Slot incoming: root.slots.find(slot => slot.order === 0 && slot.path !== "") ?? null

    function load(): void {
        const path = root.wanted;
        if (!path)
            return;

        if (root.front.order === 0) {
            a.path = path;
            a.order = ++root.lifted;
            return;
        }

        if (root.front.path === path) {
            if (root.incoming)
                root.incoming.path = "";
            return;
        }

        const spare = root.incoming ?? root.slots.find(slot => slot.order === 0);
        if (!spare)
            return;

        spare.path = path;
        root.raise(spare);
    }

    function raise(slot: var): void {
        if (slot.order > 0 || !slot.ready || slot.path !== root.wanted)
            return;
        slot.order = ++root.lifted;
        root.reveal(slot);
    }

    function reveal(slot: var): void {
        slot.seed = Math.random() * 6.283;
        slot.origin = Wallpaper.originOn(root.output);
        slot.sweep.value = Appearance.lessMotion ? 1 : 0;
        if (slot.sweep.settled)
            root.landed(slot);
    }

    function landed(slot: var): void {
        if (slot.order === 0)
            return;
        for (const other of root.slots) {
            if (other.order > 0 && other.order < slot.order) {
                other.order = 0;
                other.path = "";
            }
        }
        root.load();
    }

    function replay(): void {
        const slot = root.front;
        if (slot.order === 0)
            return;
        for (const other of root.slots) {
            if (other !== slot) {
                other.order = 0;
                other.path = "";
            }
        }
        root.reveal(slot);
    }

    Component.onCompleted: root.load()

    onWantedChanged: root.load()

    component Slot: WallpaperSource {
        id: slot

        property int order: 0
        property real seed: 0
        property point origin: Qt.point(0.5, 0.5)

        readonly property Follow sweep: Follow {
            target: 1
            speed: 5000 / Math.max(1, Appearance.sizes.wallpaperReveal)
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
        readonly property bool swept: slot.sweep.settled

        anchors.fill: parent
        z: slot.order
        visible: slot.order > 0

        playing: root.playing && root.front === slot
        audible: root.audible

        layer.enabled: slot.visible && !slot.swept
        layer.effect: RevealMask {
            progress: slot.sweep.value
            aspect: slot.width / Math.max(1, slot.height)
            origin: slot.origin
            seed: slot.seed
        }

        onReadyChanged: root.raise(slot)
        onSweptChanged: if (slot.swept)
            root.landed(slot)
    }

    Slot {
        id: a
    }

    Slot {
        id: b
    }

    Slot {
        id: c
    }
}
