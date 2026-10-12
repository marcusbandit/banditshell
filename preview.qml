import QtQuick
import Quickshell

Loader {
    id: root

    property string preview: Quickshell.env("BANDITSHELL_PREVIEW") ?? ""
    property bool failed: false

    function check(): void {
        if (root.failed || (root.preview !== "" && root.status !== Loader.Error))
            return;
        root.failed = true;
        console.error(root.preview === "" ? "preview.qml: BANDITSHELL_PREVIEW is not set" : `preview.qml: the ${root.preview} preview did not load`);
        Qt.callLater(() => Qt.exit(1));
    }

    source: root.preview === "" ? "" : Qt.resolvedUrl(`previews/${root.preview}.qml`)

    onStatusChanged: root.check()
    Component.onCompleted: root.check()
}
