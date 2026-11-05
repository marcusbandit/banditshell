import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    readonly property var ask: Bluetooth.question
    readonly property var code: Bluetooth.displayed

    readonly property string title: root.ask ? root.ask.title : root.code ? root.code.title : ""
    readonly property string detail: root.ask ? root.ask.detail : root.code ? root.code.detail : ""
    readonly property string digits: root.ask ? root.ask.code : root.code ? root.code.code : ""

    visible: !!root.ask || !!root.code
    implicitWidth: parent ? parent.width : 0
    implicitHeight: root.visible ? body.implicitHeight + Appearance.padding.normal * 2 : 0

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.accentFill
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        spacing: Appearance.padding.small

        StyledText {
            width: parent.width
            text: root.title
            color: Appearance.colour.text
            font.pixelSize: Appearance.font.size.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            visible: !!root.digits
            text: root.digits
            color: Appearance.colour.accent
            font.pixelSize: Appearance.font.size.large
            font.letterSpacing: Appearance.font.size.small
        }

        StyledText {
            width: parent.width
            visible: !!root.detail
            text: root.detail
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            wrapMode: Text.WordWrap
        }

        ClockTextField {
            id: entry

            width: parent.width
            visible: !!root.ask?.field
            placeholder: root.ask?.field ?? ""
            onAccepted: text => Bluetooth.answer(true, text)
            onCancelled: Bluetooth.answer(false, "")
        }

        Row {
            visible: !!root.ask
            spacing: Appearance.padding.small

            Button {
                size: 0
                style: "accent"
                text: root.ask?.yes ?? ""
                onClicked: Bluetooth.answer(true, entry.value)
            }

            Button {
                size: 0
                text: root.ask?.no ?? ""
                onClicked: Bluetooth.answer(false, "")
            }
        }
    }
}
