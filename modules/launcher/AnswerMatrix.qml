import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var rows: []
    property int size: Appearance.font.size.display
    property color colour: Appearance.colour.text

    readonly property int across: root.rows && root.rows.length ? root.rows[0].length : 0
    readonly property int stem: Math.max(Appearance.stroke.ring, Math.round(root.size / 12))
    readonly property int inset: Math.round(root.size * 0.35)

    width: root.across ? grid.width + (root.stem + root.inset) * 2 : 0
    height: grid.height

    Grid {
        id: grid

        x: root.stem + root.inset
        columns: Math.max(1, root.across)
        columnSpacing: Math.round(root.size * 0.7)
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: root.across ? root.rows.reduce((all, row) => all.concat(row), []) : []

            delegate: StyledText {
                required property string modelData

                text: modelData
                font.pixelSize: root.size
                font.weight: Font.DemiBold
                color: root.colour
            }
        }
    }

    Repeater {
        model: root.across ? 2 : 0

        delegate: Item {
            id: bracket

            required property int index

            x: bracket.index === 0 ? 0 : root.width - bracket.width
            width: Math.round(root.size * 0.3)
            height: root.height

            Rectangle {
                x: bracket.index === 0 ? 0 : bracket.width - root.stem
                width: root.stem
                height: bracket.height
                color: root.colour
            }

            Rectangle {
                width: bracket.width
                height: root.stem
                color: root.colour
            }

            Rectangle {
                y: bracket.height - root.stem
                width: bracket.width
                height: root.stem
                color: root.colour
            }
        }
    }
}
