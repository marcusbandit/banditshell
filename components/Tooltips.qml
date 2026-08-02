pragma Singleton

import QtQuick
import Quickshell
import qs.config

// WHAT IS THAT THING, answered after you have wondered for a moment.
//
// It lives in components rather than services because it knows nothing about
// this shell: it holds an item and a line of text. That is what lets MenuRow ask
// for one without a component reaching into the shell it happens to be in.
//
// One at a time, shell-wide, because that is what a tooltip is: there is only
// ever one cursor, so there is only ever one question. Widgets ask by handing
// over themselves and a line of text; this decides whether and when it appears,
// and Tooltip.qml decides where.
//
// THE DELAY IS THE WHOLE DESIGN. A label that appears the instant the cursor
// touches something turns a column of icons into a strobe on the way past, and
// one that never appears leaves a bar of unlabelled glyphs. So: nothing for a
// beat, and then, once you have clearly stopped on something, an answer. Moving
// from one labelled thing to its neighbour swaps instantly, with no second
// wait, because by then the question is already open.
Singleton {
    id: root

    // What is showing, and for whom.
    property Item anchor: null
    property string text: ""

    // What has been asked for and is still serving its wait.
    property Item pending: null
    property string pendingText: ""

    readonly property bool shown: !!anchor && !!text

    function request(item: Item, label: string): void {
        if (!item || !label) {
            root.release(item);
            return;
        }

        root.pending = item;
        root.pendingText = label;

        // Already answering: the question is open, so answer this one now.
        if (root.shown) {
            root.anchor = item;
            root.text = label;
            delay.stop();
        } else {
            delay.restart();
        }
    }

    // BY ITEM, not unconditionally. A leave and an enter arrive in an order Qt
    // does not promise, so a release that fires after the next item's request
    // would take down the tooltip that request just asked for.
    function release(item: Item): void {
        if (root.pending === item) {
            root.pending = null;
            root.pendingText = "";
            delay.stop();
        }
        if (root.anchor === item) {
            root.anchor = null;
            root.text = "";
        }
    }

    Timer {
        id: delay

        interval: Appearance.anim.tooltip
        onTriggered: {
            root.anchor = root.pending;
            root.text = root.pendingText;
        }
    }
}
