import QtQuick
import qs.config
import qs.components
import "catalogue.js" as Catalogue

Loader {
    id: root

    property var row: ({})

    width: parent ? parent.width : 0

    sourceComponent: root.row.kind === "fact" ? fact : root.row.kind === "w" ? widget : entry

    onLoaded: {
        item.width = Qt.binding(() => root.width);
        if (item.row !== undefined)
            item.row = Qt.binding(() => root.row);
    }

    Component {
        id: widget

        Loader {
            active: root.row.page === SettingsView.current
            source: Qt.resolvedUrl(`widgets/${root.row.w.charAt(0).toUpperCase()}${root.row.w.slice(1)}Widget.qml`)

            onLoaded: {
                item.width = Qt.binding(() => width);
                if (item.row !== undefined)
                    item.row = Qt.binding(() => root.row);
            }
        }
    }

    Component {
        id: entry

        SettingsEntry {}
    }

    Component {
        id: fact

        Item {
            visible: words.text !== ""
            implicitHeight: words.text !== "" ? words.implicitHeight + Appearance.padding.small + Appearance.padding.normal : 0

            HoverHandler {
                onHoveredChanged: if (hovered && Catalogue.labelOf(root.row))
                    SettingsView.hovered = root.row
            }

            StyledText {
                id: words

                x: Appearance.padding.normal
                y: Appearance.padding.small
                width: parent.width - Appearance.padding.normal * 2
                text: String(Catalogue.val(root.row.text, SettingsState) ?? "")
                color: Appearance.colour.textFaint
                wrapMode: Text.WordWrap
            }
        }
    }
}
