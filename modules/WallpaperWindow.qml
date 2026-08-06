pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The wallpaper.
//
// Its own surface on the BACKGROUND layer, below everything including normal
// windows, taking no input at all. That is why this is not part of ShellWindow:
// the shell draws above windows and the wallpaper draws below them, so they
// cannot be the same surface.
//
// Two slots that cross-fade. Reassigning one slot's path shows a frame of
// nothing while the new file decodes, which on a wallpaper reads as the whole
// desktop blinking. So the NEXT one always loads into whichever is hidden, and
// they only swap once it has actually decoded.
//
// A SLOT IS NOT AN IMAGE. It is a components/WallpaperSource, which builds
// whatever element can draw the file it is given: a picture, an SVG, a GIF, or
// a video. Everything in here is written in terms of "has it decoded yet" and
// "is it in front", and neither question has a different answer for a video
// than for a png, which is the entire reason the formats do not appear here.
PanelWindow {
    id: win

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "black"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "banditshell-wallpaper"

    // Nothing here is clickable.
    mask: Region {
        width: 0
        height: 0
    }

    // Which slot is in front.
    property bool showB: false
    readonly property WallpaperSource front: showB ? b : a
    readonly property WallpaperSource back: showB ? a : b

    // WHETHER MOTION IS ALLOWED TO RUN, and the only reason an animated
    // wallpaper is affordable at all.
    //
    // A video behind a full screen of windows is a decoder thread and a GPU
    // surface producing frames that are, by definition, entirely covered. So it
    // runs while THIS MONITOR's workspace has nothing on it and stops the
    // moment something does, which is the same moment you stopped being able to
    // see it. Per monitor, because this surface is per monitor: a window opened
    // on the left screen has no opinion about the picture on the right one.
    //
    // Paused rather than stopped, and the last frame stays on screen; see
    // WallpaperSource. So what a busy workspace shows is a still of whatever
    // frame it was on, which is a wallpaper rather than a hole.
    readonly property bool bare: Hypr.windowsOn(win.screen?.name ?? "") === 0
    readonly property bool playing: Wallpaper.enabled && Config.values.wallpaper.animate && win.bare

    function load(): void {
        const path = Wallpaper.shown;
        if (!path || front.path === path)
            return;
        // First one: no fade, there is nothing to fade from.
        //
        // Compared as a STRING, which it now genuinely is: this used to read an
        // Image's `source`, a QML url that is a JS object even when empty, so
        // `!front.source` was always false and this branch never ran. Every
        // first wallpaper cross-faded in from black instead of simply being
        // there.
        if (front.path === "") {
            front.path = path;
            return;
        }

        // ASSIGN, THEN ASK, and the second half is not belt and braces.
        //
        // Going A -> B -> A quickly is the common case here, because that is
        // what scrubbing a picker back and forth IS, and the back slot is still
        // holding A when you come back to it. Assigning the path it already has
        // changes nothing, so no readiness signal is emitted, so the swap it
        // would have triggered never happens and the desktop sits on B while
        // everything else says A. The wallpaper it wanted was already decoded
        // and waiting: the only thing missing was somebody to say so.
        back.path = path;
        win.settled(back);
    }

    // Only swap when the one that just decoded is the hidden one AND it is still
    // what we want; a stale decode arriving late must not pull the old picture
    // back to the front.
    // `var` rather than the type it always is, and a null guard in front of it,
    // because this is called from a slot's own onReadyChanged and that can fire
    // while the pair is still being built: a typed parameter is COERCED at the
    // call, and coercing an object that does not exist yet yields null rather
    // than an error, so the guard has to be here rather than at the call site.
    function settled(slot: var): void {
        if (!slot || !back)
            return;
        if (slot.ready && slot === back && slot.path === Wallpaper.shown) {
            showB = !showB;
            // A NEW SHAPE, chosen before the sweep starts rather than during
            // it: the seed shifts the phases of the sines the outline is made
            // of, so changing it mid-transition would make the blob writhe.
            // Six is a full turn and a bit, which is all the range there is.
            win.seed = Math.random() * 6.283;
            // The swap is the moment the new one is BEHIND the mask, not the
            // moment it is on screen: `sweep` is what puts it there, from
            // nothing to everything, out of wherever the choice was made.
            sweep.restart();
            retire.restart();
        }
    }

    // LETTING GO OF THE ONE THAT JUST LEFT.
    //
    // After a swap the back slot is holding the PREVIOUS wallpaper, which
    // nothing is going to ask for again: the next change loads into it. For a
    // picture that is a texture nobody minds, which is why this did not exist
    // while a wallpaper could only be a picture. For a video it is a decoder
    // thread and a hardware surface held open for a clip that is not on screen
    // and is not playing, and the whole argument for animated wallpapers here
    // is that they cost nothing when you cannot see them.
    //
    // ON A TIMER rather than at the swap, because the swap is the START of the
    // reveal and the outgoing wallpaper is what is showing through the hole for
    // the whole of it. A quarter over, so it fires after the circle has closed
    // over the last corner rather than on the frame it reaches it.
    Timer {
        id: retire

        interval: Appearance.sizes.wallpaperReveal * 1.25

        onTriggered: {
            if (win.back.path !== Wallpaper.shown)
                win.back.path = "";
        }
    }

    Component.onCompleted: load()

    Connections {
        target: Wallpaper

        function onShownChanged(): void {
            win.load();
        }
    }

    // HOW A NEW WALLPAPER ARRIVES: as a hole opening in the old one, from the
    // point the choice was made at. See components/reveal.frag for the argument
    // and the maths; what lives here is only the state it runs on.
    //
    // 0 is "the outgoing one is whole", 1 is "the incoming one is". It rests at
    // 1, because the resting state is a wallpaper that has finished arriving.
    property real reveal: 1

    // WHICH BLOB THIS ONE IS. Rerolled at every swap, so the shape that arrives
    // is different every time; see components/reveal.frag. A transition that
    // repeats itself exactly is one you stop seeing after the third time.
    property real seed: 0

    NumberAnimation on reveal {
        id: sweep

        running: false
        from: 0
        to: 1
        duration: Appearance.sizes.wallpaperReveal

        // OutCubic, and the tier matters more than it looks.
        //
        // It has to leave fast enough that the change reads as caused by the
        // press, and arrive slowly enough to be watched, which is what any
        // Out-curve does. What it must NOT do is spend so much of itself in the
        // first fifth that the interesting part, the blob while it is still
        // small and lumpy, is over before the eye has found it. OutQuint was
        // that: five-fifths of the growth in a fifth of the time, and the shape
        // this shader exists to draw went past too quickly to be a shape.
        easing.type: Easing.OutCubic
    }

    // TURNED OFF is a light going out, not a surface going away.
    //
    // The window stays, the slots keep their paths, the reveal underneath keeps
    // working: only this group's opacity moves, so what is left is the black
    // this surface was already painting behind the picture. Changing wallpaper
    // while it is off still happens, silently, and comes back already right.
    Item {
        id: picture

        anchors.fill: parent
        opacity: Wallpaper.enabled ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.slow
            }
        }

        // TWO SLOTS, ONE STACK, and the incoming one is simply the one on top.
        //
        // There is no cross-fade here any more and no second opacity to keep in
        // step: the outgoing wallpaper draws normally, the incoming one draws
        // over it through a mask, and when the mask is fully open the incoming
        // one is covering the whole screen on its own. `z` is what makes the
        // pair a stack rather than a blend, and it flips with the swap.
        WallpaperSource {
            id: a

            anchors.fill: parent
            z: win.showB ? 0 : 1

            // ONLY THE ONE IN FRONT MOVES. The hidden slot is a wallpaper that
            // has been decoded and is waiting to be swapped in; letting it play
            // would mean two decoders running for one visible picture, and the
            // one you cannot see would be the one that never stops.
            playing: win.playing && win.front === a
            audible: Config.values.wallpaper.audio

            // THE MASK IS ONLY REAL WHILE IT IS MOVING, and only on the slot
            // that is arriving. A layer is an offscreen render target: leaving
            // one on a full-screen item would cost a whole extra pass every
            // frame for a wallpaper that is not going anywhere. Off, the slot
            // draws itself straight into the scene, which is what it does for
            // all but a second of its life.
            layer.enabled: win.front === a && sweep.running
            layer.effect: RevealMask {
                progress: win.reveal
                aspect: win.width / Math.max(1, win.height)
                origin: Wallpaper.origin
                seed: win.seed
            }

            onReadyChanged: win.settled(a)
        }

        WallpaperSource {
            id: b

            anchors.fill: parent
            z: win.showB ? 1 : 0

            playing: win.playing && win.front === b
            audible: Config.values.wallpaper.audio

            layer.enabled: win.front === b && sweep.running
            layer.effect: RevealMask {
                progress: win.reveal
                aspect: win.width / Math.max(1, win.height)
                origin: Wallpaper.origin
                seed: win.seed
            }

            onReadyChanged: win.settled(b)
        }
    }
}
