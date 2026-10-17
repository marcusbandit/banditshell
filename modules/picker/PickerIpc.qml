pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.services

Scope {
    id: root
    required property var picker

    IpcHandler {
        target: "picker"

        function open(): string {
            root.picker.show(false, false);
            return "picker";
        }

        function freeze(): string {
            root.picker.show(true, false);
            return "picker (frozen)";
        }

        function clip(): string {
            root.picker.show(false, true);
            return "picker (to clipboard)";
        }

        function freezeclip(): string {
            root.picker.show(true, true);
            return "picker (frozen, to clipboard)";
        }

        function taken(path: string): string {
            Screenshots.captured(path);
            return "shown";
        }

        function close(): string {
            root.picker.close();
            return "closed";
        }
    }
}
