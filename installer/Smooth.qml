import QtQuick

// One smoothed number.
//
// `value` chases `target` exponentially: fast while it is far, slow as it
// arrives, and correct at any frame interval because the step is derived from dt
// rather than being a fixed fraction per tick. Nothing in this installer moves
// with a fixed-duration tween.
//
//   value += (target - value) * (1 - exp(-speed * dt))
//
// See ~/.claude/rules/animation-smoothing.md.
Item {
    id: root

    property real target: 0
    property real value: 0

    // 5 is a slow settle, 15 snaps. The default is the middle of the useful
    // range and is what most of the chrome uses.
    property real speed: 9

    // Under this, the remaining distance is less than a pixel of anything and
    // the tick is wasted; the value is finished off and the timer idles.
    property real epsilon: 0.0005

    visible: false

    function jump(v: real): void {
        root.target = v;
        root.value = v;
    }

    Timer {
        interval: 16
        repeat: true
        running: Math.abs(root.target - root.value) > root.epsilon
        onTriggered: {
            const dt = interval / 1000;
            root.value += (root.target - root.value) * (1 - Math.exp(-root.speed * dt));
            if (Math.abs(root.target - root.value) <= root.epsilon)
                root.value = root.target;
        }
    }
}
