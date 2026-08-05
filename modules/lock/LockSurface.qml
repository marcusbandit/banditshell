pragma ComponentBehavior: Bound

import Quickshell.Wayland
import qs.config

// The lock, as a surface. One of these per screen, made by the compositor.
//
// It holds nothing and draws nothing: everything you can see is in LockFace,
// which is a plain Item and can therefore be put in an ordinary window and
// looked at. That split is the whole point of this file being three lines long.
// A session lock cannot be opened to check on it - engaging one to see whether
// the field is centred means engaging one to find out the field is broken - and
// this shell already takes the view that anything reachable only by a gesture
// needs a second way in. See the IpcHandler comments in modules/Ipc.qml, which
// exist for the same reason about hover.
//
// Black rather than transparent. There is nothing behind a lock surface by
// definition, and saying so means a wallpaper that fails to decode leaves a
// black screen with a working field on it rather than whatever happened to be
// in that buffer.
WlSessionLockSurface {
    id: surface

    required property WlSessionLock lock

    color: "black"

    LockFace {
        anchors.fill: parent

        // The surface exists slightly before the compositor maps it, and the
        // arrival should start when it is on screen rather than when it was
        // constructed.
        active: surface.visible
    }
}
