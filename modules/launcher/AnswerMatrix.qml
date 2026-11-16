import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var rows: null
    property real available: 0
    property color colour: Appearance.colour.text

    readonly property int display: Appearance.font.size.display
    readonly property int across: root.rows && root.rows.length ? root.rows[0].length : 0
    readonly property real inked: {
        let sum = 0;
        for (let c = 0; c < root.across; c++) {
            let widest = 0;
            for (const row of root.rows)
                widest = Math.max(widest, metrics.advanceWidth(row[c]));
            sum += widest;
        }
        return sum;
    }
    readonly property int size: root.across ? Math.floor(Math.min(root.display, root.display * 3 / root.rows.length, (root.available - Appearance.stroke.ring * 2) / (root.inked / root.display + root.across * 0.75 + 0.2))) : 0
    readonly property bool shown: root.across > 0 && root.size >= Appearance.font.size.small * 0.75
    readonly property int stem: Math.max(Appearance.stroke.ring, Math.round(root.size / 12))
    readonly property int inset: Math.round(root.size * 0.35)

    visible: root.shown
    width: grid.width + (root.stem + root.inset) * 2
    height: grid.height

    FontMetrics {
        id: metrics

        font.family: Appearance.font.family
        font.pixelSize: root.display
        font.weight: Font.DemiBold
    }

    Grid {
        id: grid

        x: root.stem + root.inset
        columns: Math.max(1, root.across)
        columnSpacing: Math.round(root.size * 0.7)
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: root.shown ? root.rows.reduce((all, row) => all.concat(row), []) : []

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
        model: 2

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
