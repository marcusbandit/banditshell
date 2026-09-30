import QtQuick
import qs.config
import qs.components
import qs.components.marks

Item {
    id: root

    property string spec: ""
    property string fallback: "apps"
    property color color: Appearance.colour.text
    property int size: Appearance.font.iconSize

    readonly property int mark: spec.indexOf(":")
    readonly property string kind: mark < 0 ? "" : spec.slice(0, mark)
    readonly property string value: mark < 0 ? "" : spec.slice(mark + 1)

    implicitWidth: size
    implicitHeight: size

    readonly property var drawnMarks: ({
            Kitty: kittyMark
        })

    Loader {
        id: drawn

        anchors.centerIn: parent
        active: root.kind === "draw" && !!root.value
        sourceComponent: drawn.active ? root.drawnMarks[root.value] ?? null : null

        onLoaded: {
            drawn.item.colour = Qt.binding(() => root.color);
            drawn.item.size = Qt.binding(() => root.size);
        }
    }

    Component {
        id: kittyMark

        Kitty {}
    }

    Icon {
        anchors.centerIn: parent
        visible: root.kind === "symbol" || root.kind === "" || root.kind === "glyph"
        size: root.size
        color: root.color
        name: root.kind === "symbol" && root.value ? root.value : root.fallback

        glyph: root.kind === "glyph" && root.value ? String.fromCodePoint(parseInt(root.value, 16)) : ""
    }

    FittedImage {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        visible: root.kind === "image" || root.kind === "mono"
        source: visible ? root.value : ""
        tint: root.kind === "mono"
        colour: root.color
    }
}
