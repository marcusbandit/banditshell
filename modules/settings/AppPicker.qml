pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property var exclude: []
    property int limit: 6

    signal picked(var entry)

    readonly property var found: Apps.search(field.draft).filter(e => root.exclude.indexOf(e.id) < 0).slice(0, root.limit)

    function take(): void {
        field.take();
    }

    width: parent ? parent.width : 0

    Item {
        width: root.width
        height: field.height + Appearance.padding.small * 2

        SettingsField {
            id: field

            x: Appearance.padding.normal
            y: Appearance.padding.small
            width: root.width - Appearance.padding.normal * 2
            placeholder: "find an app"
        }
    }

    Repeater {
        model: root.found

        delegate: SettingsRowFrame {
            id: pick

            required property var modelData

            width: root.width
            label: pick.modelData.name
            detail: pick.modelData.genericName ?? ""
            onActivated: root.picked(pick.modelData)
            lead: Component {
                AppMark {
                    spec: AppIcons.markFor(pick.modelData.id, "colour")
                    color: Appearance.colour.textDim
                }
            }
        }
    }
}
