import QtQuick
import Quickshell

Loader {
    property string preview: Quickshell.env("BANDITSHELL_PREVIEW")
    source: preview === "" ? "" : Qt.resolvedUrl(`previews/${preview}.qml`)
}
