import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""
    property string glyph: ""
    property string title: ""
    property string note: ""
    property string primary: ""

    signal primed
    signal asked
    signal noteTapped

    readonly property bool noteHovered: noteHover.hovered && root.note !== ""

    implicitHeight: Math.max(Appearance.sizes.rowHeight, actionsKey.height + Appearance.padding.small * 2)

    Separator {
        width: parent.width
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.right: actions.left
        anchors.rightMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.normal

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== "" || root.glyph !== ""
            name: root.icon
            glyph: root.glyph
            size: Appearance.icon.normal
            color: Appearance.colour.textDim
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - x)
            text: root.note || root.title
            font.pixelSize: Appearance.font.size.small
            color: root.note ? Appearance.colour.accent : Appearance.colour.textDim
            elide: Text.ElideRight

            HoverHandler {
                id: noteHover

                enabled: root.note !== ""
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.note !== ""
                onTapped: root.noteTapped()
            }
        }
    }

    Row {
        id: actions

        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.large

        Row {
            visible: root.primary !== ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.primary
                font.pixelSize: Appearance.font.size.small
                color: primeHover.hovered ? Appearance.colour.text : Appearance.colour.textDim
            }

            Keycap {
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter"
            }

            HoverHandler {
                id: primeHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.primed()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.stroke.line
            height: actionsKey.height
            color: Appearance.colour.separator
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Actions"
                font.pixelSize: Appearance.font.size.small
                color: askHover.hovered ? Appearance.colour.text : Appearance.colour.textDim
            }

            Keycap {
                id: actionsKey

                anchors.verticalCenter: parent.verticalCenter
                text: "Ctrl K"
            }

            HoverHandler {
                id: askHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.asked()
            }
        }
    }
}
