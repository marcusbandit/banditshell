import QtQuick
import qs.config

// A value that chases a target by exponential smoothing.
//
//     value += (target - value) * (1 - exp(-speed * dt))
//
// Fast when far, gentle when close, and correct at any frame time, which a
// fixed-duration animation is not when the target moves mid-flight. That is the
// whole reason it exists: things in this shell track each other (an indicator
// following the focused workspace, a menu following the icon that opened it)
// rather than playing from A to B. See ~/.claude/rules/animation-smoothing.md.
//
// The timer only runs while there is distance left to cover, so an idle shell
// wakes nothing up.
Item {
    id: root

    property real target: 0
    property real value: 0
    property real speed: Appearance.anim.trackSpeed

    // Close enough to stop. Below this the value snaps, so it settles exactly on
    // target instead of asymptotically never arriving.
    property real epsilon: 0.25

    readonly property bool settled: Math.abs(value - target) <= epsilon

    // Jump without animating: for the first layout, where there is no "from".
    function snap(): void {
        root.value = root.target;
    }

    Timer {
        interval: 16
        repeat: true
        running: !root.settled

        onTriggered: {
            const d = root.target - root.value;
            root.value = Math.abs(d) < root.epsilon ? root.target : root.value + d * (1 - Math.exp(-root.speed * (interval / 1000)));
        }
    }
}
