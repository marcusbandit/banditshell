import QtQuick
import qs.config
import qs.components

// One row of a settings card: a mark, a name, what it means, and whatever the
// row is for on the right.
//
// NOT MenuRow, and the differences are the reasons it exists:
//
// NOTHING IS EVER CUT SHORT. MenuRow elides, which is right for a launcher
// list scanned at a glance and wrong for a page of settings read on a phone,
// where a sentence ending in "..." is a sentence you cannot act on. Every
// piece of text here wraps, and the row is as tall as the wrapped text
// needs. A value that would not fit beside its name goes under it instead of
// being squeezed. A control too wide to share the line (a segmented choice)
// drops below the text rather than crushing it.
//
// THE HIGHLIGHT IS A PIECE OF THE CARD, not a shape of its own. A hover fill
// with its own corners inside a card with corners is two shapes disagreeing
// about one edge. This fill takes the card's corners exactly where the row
// touches them: the first row's top, the last row's bottom, square in
// between, so a lit row reads as the card lighting up along one band. The
// position comes from the Column the card lays its rows out in, through the
// Positioner attached property, so a row never has to be told where it is.
//
// NO TOOLTIP. A row that says its whole sentence has nothing left to say on
// hover.
Item {
    id: root

    property string icon: ""
    property string label: ""

    // Under the name, wrapped: what the setting means or what it costs.
    property string detail: ""

    // A SHORT ANSWER, right-aligned beside the name when it fits on the line
    // and under the name when it does not. "10%", "5h 44m", "lua".
    property string value: ""

    property bool interactive: true
    property bool selected: false

    // A row that leads somewhere says so with a chevron on its right.
    property bool chevron: false

    // Anything declared inside sits on the right, vertically centred, or
    // under the text if it is too wide to share the line.
    default property alias trailing: trailingSlot.data

    signal activated

    readonly property bool hovered: root.interactive && pointer.containsMouse

    readonly property bool first: root.Positioner.isFirstItem
    readonly property bool last: root.Positioner.isLastItem

    readonly property real inset: Appearance.padding.normal
    readonly property real gap: Appearance.padding.small

    // The trailing control shares the line only while the text keeps most of
    // it; past that it goes under the text at the text's own left edge.
    readonly property real trailingWidth: trailingSlot.childrenRect.width
    readonly property bool stacked: root.trailingWidth > 0 && root.trailingWidth > root.width * 0.4

    // Where the text starts: after the mark, if there is one.
    readonly property real textX: root.inset + (root.icon ? Appearance.font.iconSize + root.inset : 0)
    readonly property real textWidth: root.width - root.textX - root.inset - (root.stacked ? 0 : (root.trailingWidth > 0 ? root.trailingWidth + root.inset : 0) + (root.chevron ? Appearance.font.iconSize + root.gap : 0))

    // The value sits beside the name while it takes under half the line.
    readonly property bool valueBeside: root.value !== "" && valueText.implicitWidth <= root.textWidth * 0.5

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(Appearance.sizes.rowHeight, body.implicitHeight + root.gap * 2 + (root.stacked ? trailingSlot.childrenRect.height + root.gap : 0), root.stacked ? 0 : trailingSlot.childrenRect.height + root.gap * 2)

    G2Rect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        topLeftRadius: root.first ? radius : 0
        topRightRadius: root.first ? radius : 0
        bottomLeftRadius: root.last ? radius : 0
        bottomRightRadius: root.last ? radius : 0
        color: root.selected ? Appearance.colour.fillStrong : Appearance.colour.fill
        opacity: root.hovered || root.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // A hairline between rows of one card, from where the text starts so the
    // marks stand in a column of their own.
    Rectangle {
        visible: !root.first
        x: root.textX
        width: parent.width - x
        height: Appearance.font.stem
        color: Appearance.colour.separator
    }

    // DECLARED BEFORE THE CONTENT, MenuRow's lesson: a row-wide target that
    // came last would sit on top of the row's own control and eat its clicks.
    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Icon {
        x: root.inset
        y: root.gap + (title.implicitHeight - height) / 2
        visible: !!root.icon
        name: root.icon
        color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
    }

    Column {
        id: body

        x: root.textX
        y: root.gap
        width: root.textWidth

        Item {
            width: parent.width
            height: Math.max(title.implicitHeight, root.valueBeside ? valueText.implicitHeight : 0)

            StyledText {
                id: title

                width: parent.width - (root.valueBeside ? valueText.width + root.inset : 0)
                text: root.label
                wrapMode: Text.Wrap
                color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
            }

            StyledText {
                id: valueText

                anchors.right: parent.right
                visible: root.valueBeside
                text: root.value
                color: Appearance.colour.textFaint
            }
        }

        StyledText {
            width: parent.width
            visible: root.value !== "" && !root.valueBeside
            text: root.value
            wrapMode: Text.Wrap
            color: Appearance.colour.textFaint
        }

        StyledText {
            width: parent.width
            visible: !!root.detail
            text: root.detail
            wrapMode: Text.Wrap
            color: Appearance.colour.textFaint
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.verticalCenter: parent.verticalCenter
        visible: root.chevron
        name: "chevron_right"
        color: Appearance.colour.textFaint
    }

    Item {
        id: trailingSlot

        x: root.stacked ? root.textX : root.width - root.inset - (root.chevron ? Appearance.font.iconSize + root.gap : 0) - width
        y: root.stacked ? body.y + body.implicitHeight + root.gap : (root.height - height) / 2
        width: childrenRect.width
        height: childrenRect.height
    }
}
