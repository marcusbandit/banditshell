import QtQuick
import qs.services

Item {
    id: root

    property string label: ""
    property bool seen: false
    property real began: -1
    property real next: -1

    Connections {
        target: Trace.recording ? root.Window.window : null

        function onAfterAnimating(): void {
            if (root.began < 0)
                root.began = Trace.now();
            else if (root.next < 0)
                root.next = Trace.now();
        }

        function onFrameSwapped(): void {
            if (!root.seen) {
                root.seen = true;
                Trace.mark(`first frame ${root.label}`);
            }
            Trace.frame(root.began < 0 ? 0 : Trace.now() - root.began);
            root.began = root.next;
            root.next = -1;
        }
    }
}
