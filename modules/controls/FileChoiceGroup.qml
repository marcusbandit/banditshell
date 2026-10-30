pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property var row: ({})
    property string picked: ""
    property bool opened: false

    readonly property var others: root.row.others ?? []
    readonly property bool holdsPicked: root.others.some(o => o.path === root.picked)
    readonly property bool showing: root.opened

    signal chosen(string path)

    onHoldsPickedChanged: if (root.holdsPicked)
        root.opened = true
    Component.onCompleted: root.opened = root.holdsPicked

    FileChoiceRow {
        width: root.width
        path: root.row.path ?? ""
        detail: root.row.detail ?? ""
        warn: !!root.row.warn
        picked: root.row.path === root.picked
        onChosen: root.chosen(root.row.path)
    }

    Button {
        x: Appearance.padding.large
        visible: root.others.length > 0
        size: 0
        style: "bare"
        icon: root.showing ? "expand_less" : "expand_more"
        text: root.others.length === 1 ? "1 other copy" : `${root.others.length} other copies`
        onClicked: root.opened = !root.opened
    }

    Column {
        x: Appearance.padding.large
        width: root.width - Appearance.padding.large
        visible: root.showing

        Repeater {
            model: root.showing ? root.others : []

            FileChoiceRow {
                required property var modelData

                width: parent.width
                path: modelData.path
                detail: modelData.detail ?? ""
                warn: !!modelData.warn
                picked: modelData.path === root.picked
                onChosen: root.chosen(modelData.path)
            }
        }
    }
}
