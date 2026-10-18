pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    property Item anchor: null
    property string text: ""

    property Item pending: null
    property string pendingText: ""

    readonly property bool shown: !!anchor && !!text

    property bool warm: false

    function request(item: Item, label: string, now: bool): void {
        if (!item || !label) {
            root.release(item);
            return;
        }

        root.pending = item;
        root.pendingText = label;

        if (now || root.shown || root.warm) {
            root.anchor = item;
            root.text = label;
            delay.stop();
        } else {
            delay.restart();
        }
    }

    function release(item: Item): void {
        if (root.pending === item) {
            root.pending = null;
            root.pendingText = "";
            delay.stop();
        }
        if (root.anchor === item) {
            root.anchor = null;
            root.text = "";
            root.warm = true;
            cool.restart();
        }
    }

    Timer {
        id: cool

        interval: Appearance.animation.grace
        onTriggered: root.warm = false
    }

    Timer {
        id: delay

        interval: Appearance.animation.tooltip
        onTriggered: {
            root.anchor = root.pending;
            root.text = root.pendingText;
        }
    }
}
