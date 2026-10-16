import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property real tallest: 360

    width: parent ? parent.width : 0
    spacing: Appearance.padding.small

    WorkshopCanvas {
        width: root.width
        height: Math.min(Math.round(root.width * LayoutDraft.shape.height / LayoutDraft.shape.width), root.tallest)
        model: LayoutDraft.model
        arrangement: LayoutDraft.arrangement
        count: LayoutDraft.count
        shape: LayoutDraft.shape
        selected: LayoutDraft.selected
        opacity: LayoutDraft.running.index === LayoutDraft.arrangement ? 1 : 0.55
        onPicked: id => LayoutDraft.selected = id
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "monitor"
        label: "Screen"
        detail: LayoutDraft.running.index === LayoutDraft.arrangement ? `${LayoutDraft.arrangementName(LayoutDraft.running.index)} in use here` : `${LayoutDraft.arrangementName(LayoutDraft.running.index)} in use here, not ${LayoutDraft.arrangementName(LayoutDraft.arrangement)}`
    }

    Segments {
        x: Appearance.padding.normal
        width: Math.min(implicitWidth, root.width - Appearance.padding.normal * 2)
        options: LayoutDraft.shapes.map(s => `${s.width}×${s.height}`)
        current: Math.min(LayoutDraft.shapeIndex, LayoutDraft.shapes.length - 1)
        onPicked: index => LayoutDraft.shapeIndex = index
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "select_window"
        label: "Windows"

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            Button {
                anchors.verticalCenter: parent.verticalCenter
                size: 0
                visible: LayoutDraft.running.index !== LayoutDraft.arrangement
                text: `Edit ${LayoutDraft.arrangementName(LayoutDraft.running.index)}`
                onClicked: LayoutDraft.pickArrangement(LayoutDraft.running.index)
            }

            SettingsSlider {
                anchors.verticalCenter: parent.verticalCenter
                trackWidth: 140
                from: 1
                to: 8
                step: 1
                value: LayoutDraft.count
                text: `${LayoutDraft.count}`
                onMoved: value => LayoutDraft.count = value
            }
        }
    }
}
