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
        if (front.path === "")
            front.path = path;
        else
            back.path = path;
    }

    // Only swap when the one that just decoded is the hidden one AND it is still
    // what we want; a stale decode arriving late must not pull the old picture
    // back to the front.
    function settled(slot: WallpaperSource): void {
        if (slot.ready && slot === back && slot.path === Wallpaper.shown) {
            showB = !showB;
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
    // cross-fade and the outgoing wallpaper has to stay on screen for all of it.
    // Half a tier over the fade, so it fires after the fade has finished rather
    // than on the same frame it ends.
    Timer {
        id: retire

        interval: Appearance.anim.slow * 1.5

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

    // TURNED OFF is a light going out, not a surface going away.
    //
    // The window stays, the slots keep their paths, the cross-fade underneath
    // keeps working: only this group's opacity moves, so what is left is the
    // black this surface was already painting behind the picture. Changing
    // wallpaper while it is off still happens, silently, and comes back already
    // right.
    //
    // A group rather than a term in each slot's own opacity, because these two
    // are mid-cross-fade half the time and folding a second reason to be
    // invisible into that expression is how one of them gets stuck. No `layer`:
    // ungrouped opacity multiplies per child, which is exactly the blend the
    // cross-fade already wants.
    Item {
        id: picture

        anchors.fill: parent
        opacity: Wallpaper.enabled ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.slow
            }
        }

        WallpaperSource {
            id: a

            anchors.fill: parent

            // ONLY THE ONE IN FRONT MOVES. The hidden slot is a wallpaper that
            // has been decoded and is waiting to be swapped in; letting it play
            // would mean two decoders running for one visible picture, and the
            // one you cannot see would be the one that never stops.
            playing: win.playing && win.front === a
            audible: Config.values.wallpaper.audio

            opacity: win.showB ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.slow
                }
            }

            onReadyChanged: win.settled(a)
        }

        WallpaperSource {
            id: b

            anchors.fill: parent

            playing: win.playing && win.front === b
            audible: Config.values.wallpaper.audio

            opacity: win.showB ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.slow
                }
            }

            onReadyChanged: win.settled(b)
        }
    }
}
