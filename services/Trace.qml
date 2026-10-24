pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool recording: Quickshell.env("BANDITSHELL_TRACE") === "1"

    readonly property real wallStart: Date.now()
    readonly property int keep: 4000

    property var live: []
    property var done: []
    property int liveCount: 0
    property var boot: null

    function now(): real {
        return clock.elapsedNs();
    }

    function begin(name: string, detail = "", quietMs = 150, capMs = 4000): var {
        if (!root.recording)
            return null;
        const at = root.now();
        const span = {
            name: name,
            detail: detail,
            start: at,
            wall: root.wallStart + at / 1e6,
            quiet: quietMs * 1e6,
            cap: capMs * 1e6,
            touched: at,
            steps: [],
            frames: 0,
            first: -1,
            last: -1,
            previous: -1,
            worst: 0
        };
        root.live.push(span);
        root.liveCount = root.live.length;
        return span;
    }

    function step(label: string, span: var): void {
        if (!span || root.live.indexOf(span) < 0)
            return;
        const at = root.now();
        span.steps.push([label, at - span.start]);
        span.touched = at;
    }

    function note(label: string): void {
        if (root.liveCount > 0)
            root.step(label, root.live[root.live.length - 1]);
    }

    function mark(label: string): void {
        if (root.boot)
            root.step(label, root.boot);
    }

    function frame(): void {
        if (root.liveCount === 0)
            return;
        const at = root.now();
        for (const span of root.live) {
            if (span.first < 0)
                span.first = at - span.start;
            else
                span.worst = Math.max(span.worst, at - span.previous);
            span.previous = at;
            span.last = at - span.start;
            span.frames++;
            span.touched = at;
        }
    }

    function settle(): void {
        const at = root.now();
        const still = [];
        for (const span of root.live) {
            const quiet = at - span.touched >= span.quiet;
            const capped = at - span.start >= span.cap;
            if (quiet || capped)
                root.finish(span, capped && !quiet);
            else
                still.push(span);
        }
        root.live = still;
        root.liveCount = still.length;
    }

    function finish(span: var, capped: bool): void {
        const steps = span.steps.slice();
        if (span.first >= 0) {
            steps.push(["first frame", span.first]);
            steps.push(["settled", span.last]);
        }
        steps.sort((a, b) => a[1] - b[1]);
        if (span === root.boot)
            root.boot = null;
        root.done.push({
            name: span.name,
            detail: span.detail,
            start: span.start,
            wall: span.wall,
            steps: steps,
            frames: span.frames,
            worstGap: span.worst,
            capped: capped
        });
        if (root.done.length > root.keep)
            root.done.splice(0, root.done.length - root.keep);
    }

    Component.onCompleted: root.boot = root.begin("boot", "", 1500, 30000)

    ElapsedTimer {
        id: clock
    }

    Timer {
        interval: 50
        repeat: true
        running: root.liveCount > 0

        onTriggered: root.settle()
    }

    function stop(): void {
        root.recording = false;
        root.live = [];
        root.liveCount = 0;
        root.boot = null;
    }

    function take(): string {
        const out = JSON.stringify({
            wallStart: root.wallStart,
            now: root.now(),
            spans: root.done
        });
        root.done = [];
        return out;
    }
}
