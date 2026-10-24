import QtQuick
import qs.services

Item {
    id: root

    property string label: ""
    property bool seen: false

    Connections {
        target: Trace.recording ? root.Window.window : null

        function onFrameSwapped(): void {
            if (!root.seen) {
                root.seen = true;
                Trace.mark(`first frame ${root.label}`);
            }
            Trace.frame();
        }
    }
}
