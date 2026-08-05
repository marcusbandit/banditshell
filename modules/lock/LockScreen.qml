pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The lock, as the compositor sees it.
//
// Shell-wide rather than per-screen, and so NOT inside shell.qml's Variants:
// ext-session-lock is one lock over the whole session, and the compositor makes
// a surface per output from the one component below. Locking is not something
// that happens to a monitor.
//
// This file is deliberately almost empty. It holds no state of its own, because
// the question "is the screen locked" has four askers and none of them are here;
// see services/Lock.qml. All this does is put that answer onto the wire.
//
// `locked` is a BINDING, not something toggled here. WlSessionLock also has an
// unlock() method, and caelestia shadows it with a signal so it can animate the
// surface away before clearing `locked`. This does not: an animation between PAM
// saying yes and the lock actually coming down is a place to get stuck, and
// getting stuck there costs a trip to a TTY. The screen goes away the moment it
// is allowed to.
Scope {
    id: root

    WlSessionLock {
        id: lock

        locked: Lock.active

        LockSurface {
            lock: lock
        }
    }
}
