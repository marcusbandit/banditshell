pragma Singleton

import QtQuick
import Quickshell
import "notify.js" as Logic

Singleton {
    id: root

    signal alertRequested(string kind)
    signal postRequested(var spec)

    function alert(kind: string): void {
        root.alertRequested(kind);
    }

    function post(spec: var): void {
        root.postRequested(spec);
    }

    function categoryFor(kind: string): string {
        return Logic.categoryFor(kind);
    }

    function kindOf(category: string): string {
        return Logic.kindOf(category);
    }

    function commandFor(spec: var): var {
        return Logic.commandFor(spec);
    }
}
