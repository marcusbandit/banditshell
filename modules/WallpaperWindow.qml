import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The wallpaper.
//
// Its own surface on the BACKGROUND layer, below everything including normal
// windows, taking no input at all. That is why this is not part of ShellWindow:
// the shell draws above windows and the wallpaper draws below them, so they
// cannot be the same surface.
//
// Two images that cross-fade. Reassigning one Image's source shows a frame of
// nothing while the new file decodes, which on a wallpaper reads as the whole
// desktop blinking. So the NEXT one always loads into whichever is hidden, and
// they only swap once it has actually decoded.
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

    // Which image is in front.
    property bool showB: false
    readonly property Image front: showB ? b : a
    readonly property Image back: showB ? a : b

    function load(): void {
        const path = Wallpaper.current;
        if (!path || front.source == path)
            return;
        // First one: no fade, there is nothing to fade from.
        //
        // Compared as a STRING: a QML url is a JS object even when empty, so
        // `!front.source` is always false and this branch never ran. Every first
        // wallpaper cross-faded in from black instead of simply being there.
        if (String(front.source) === "")
            front.source = path;
        else
            back.source = path;
    }

    // Only swap when the one that just decoded is the hidden one AND it is still
    // what we want; a stale decode arriving late must not pull the old image
    // back to the front.
    function settled(image: Image): void {
        if (image.status === Image.Ready && image === back && image.source == Wallpaper.current)
            showB = !showB;
    }

    Component.onCompleted: load()

    Connections {
        target: Wallpaper
        function onCurrentChanged(): void {
            win.load();
        }
    }

    Image {
        id: a

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Decoded at the size it is drawn at, not the file's own: a 4K png on a
        // 1080p screen is four times the memory for no pixels anyone can see.
        sourceSize.width: win.width
        sourceSize.height: win.height

        opacity: win.showB ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.slow
            }
        }

        onStatusChanged: win.settled(a)
    }

    Image {
        id: b

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: win.width
        sourceSize.height: win.height

        opacity: win.showB ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.slow
            }
        }

        onStatusChanged: win.settled(b)
    }
}
