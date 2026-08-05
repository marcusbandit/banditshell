import Quickshell
import Quickshell.Wayland
import qs.modules.lock

// The lock screen's face, in an ordinary overlay surface: `banditshell lockpreview`.
//
// It exists because a session lock is the one thing in this shell you cannot
// open to look at. Checking whether the clock is centred by locking the screen
// means locking the screen to find out the field is broken, and the way back
// from that is a TTY. This draws the same LockFace in a surface that can be
// screenshotted and killed, which is the same bargain modules/Ipc.qml makes for
// menus that only open on hover.
//
// It takes NO input - the mask is empty - so it cannot trap a cursor or a
// keyboard, and nothing here can authenticate: the field is live but the lock it
// would release is not up. Run it with a timeout; it is not meant to outlive a
// screenshot.
ShellRoot {
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "black"
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-lockpreview"

        mask: Region {
            width: 0
            height: 0
        }

        LockFace {
            anchors.fill: parent
            active: true

            // Six marks, so the field can be looked at as it is while someone is
            // actually typing into it. Nothing can type into this surface: the
            // mask is empty, which is exactly why the count has to be said.
            previewDots: 6
        }
    }
}
