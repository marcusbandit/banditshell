import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var row: null

    readonly property var props: root.row?.props ?? ({})
    readonly property var month: root.props.month ?? []
    readonly property real cell: Appearance.font.size.normal * 1.5

    implicitWidth: column.implicitWidth + Appearance.padding.large * 2
    implicitHeight: column.implicitHeight + Appearance.padding.large * 2

    Column {
        id: column

        x: Appearance.padding.large
        y: Appearance.padding.large
        spacing: Appearance.padding.normal

        StyledText {
            text: root.row?.item?.title ?? ""
            font.pixelSize: Appearance.font.size.large
            color: Appearance.colour.text
        }

        StyledText {
            text: `${root.month.filter(d => d).length} of the last ${root.month.length} days · best run ${root.props.best ?? 0}`
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
        }

        Grid {
            id: grid

            columns: 7
            spacing: Appearance.padding.small

            Repeater {
                model: root.month

                delegate: SquircleRect {
                    required property bool modelData

                    width: root.cell
                    height: root.cell
                    radius: Appearance.rounding.small
                    color: modelData ? Appearance.colour.accent : Appearance.colour.fillStrong
                }
            }
        }
    }
}
