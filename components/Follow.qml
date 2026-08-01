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

    // Close enough to stop chasing and just land. Exponential decay is
    // asymptotic, so without this it would tick forever getting nowhere.
    property real epsilon: 0.25

    // Settled means EXACTLY on target, not near it.
    //
    // This looks like it should be the epsilon test, and must not be. `running`
    // is evaluated before a tick, so an epsilon-based `settled` stops the timer
    // one tick BEFORE the snap below could ever run: the snap becomes dead code
    // and the value halts up to epsilon short of target, permanently. That is
    // invisible for a position (a fifth of a pixel) and not at all invisible for
    // a 0-to-1 reveal, where "never quite 0" leaves a closed panel a sliver
    // wide and every `if (closed)` test downstream silently false.
    readonly property bool settled: value === target

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
            // A non-positive speed means "no smoothing", not "never arrive":
            // the step would be zero and the timer would spin at 60fps forever.
            root.value = root.speed <= 0 || Math.abs(d) < root.epsilon ? root.target : root.value + d * (1 - Math.exp(-root.speed * (interval / 1000)));
        }
    }
}
