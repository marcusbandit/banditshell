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

    readonly property var slots: [a, b, c, d, e]
    property int lifted: 0

    readonly property Slot front: root.slots.reduce((top, slot) => slot.order > top.order ? slot : top)
    readonly property Slot incoming: root.slots.find(slot => slot.order === 0 && slot.path !== "") ?? null

    readonly property bool pixels: Config.values.wallpaper.transition === "pixels" && Appearance.sizes.wallpaperReveal > 0

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
                root.retire(root.incoming);
            return;
        }

        const spare = root.incoming ?? root.slots.find(slot => slot.order === 0);
        if (!spare)
            return;

        if (spare.path !== path) {
            spare.path = path;
            if (root.pixels)
                spare.run.request(path);
        }
        root.raise(spare);
    }

    function raise(slot: var): void {
        if (slot.order > 0 || !slot.ready || slot.path !== root.wanted)
            return;
        if (root.pixels && slot.run.asked === slot.path && !slot.run.settled)
            return;
        slot.order = ++root.lifted;
        root.reveal(slot);
    }

    function reveal(slot: var): void {
        slot.seed = Math.random() * 6.283;
        slot.origin = Wallpaper.originOn(root.output);
        slot.under = root.slots.reduce((top, other) => other !== slot && other.order > 0 && (!top || other.order > top.order) ? other : top, null);
        if (root.pixels && slot.run.loaded) {
            slot.pixels = true;
            slot.run.play();
            return;
        }
        slot.run.release();
        slot.sweep.value = Appearance.lessMotion ? 1 : 0;
        if (slot.sweep.settled)
            root.landed(slot);
    }

    function retire(slot: var): void {
        slot.order = 0;
        slot.path = "";
        slot.replaying = false;
        slot.settle();
        slot.sweep.snap();
    }

    function landed(slot: var): void {
        if (slot.order === 0)
            return;
        slot.settle();
        for (const other of root.slots)
            if (other.order > 0 && other.order < slot.order)
                root.retire(other);
        root.load();
    }

    function replay(): void {
        const slot = root.front;
        if (slot.order === 0)
            return;
        for (const other of root.slots)
            if (other.order > 0 && other !== slot)
                root.retire(other);
        if (root.pixels) {
            slot.replaying = true;
            slot.run.request(slot.path);
            return;
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
        property Item under: null
        property bool pixels: false
        property bool replaying: false

        readonly property WallpaperTransitionRun run: run

        function settle(): void {
            slot.pixels = false;
            slot.under = null;
            run.release();
        }

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

        layer.enabled: slot.visible && (!slot.swept || slot.pixels)
        layer.effect: slot.pixels ? pixelsEffect : revealEffect

        onReadyChanged: root.raise(slot)
        onSweptChanged: if (slot.swept)
            root.landed(slot)

        Component {
            id: revealEffect

            RevealMask {
                progress: slot.sweep.value
                aspect: slot.width / Math.max(1, slot.height)
                origin: slot.origin
                seed: slot.seed
            }
        }

        Component {
            id: pixelsEffect

            WallpaperTransition {
                underItem: slot.under
                field: run.field
                line: run.line
                t: run.t
                outline: run.outline
                ember: run.ember
                ink: run.ink
                seed: slot.seed
            }
        }

        WallpaperTransitionRun {
            id: run

            screenWidth: Math.round(slot.width * Screen.devicePixelRatio)
            screenHeight: Math.round(slot.height * Screen.devicePixelRatio)

            onSettledChanged: {
                if (!run.settled)
                    return;
                if (slot.replaying) {
                    slot.replaying = false;
                    root.reveal(slot);
                    return;
                }
                root.raise(slot);
            }
            onFinished: root.landed(slot)
        }
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

    Slot {
        id: d
    }

    Slot {
        id: e
    }
}
