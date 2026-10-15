import QtQuick
import qs.config
import qs.components
import qs.modules.controls

MenuRow {
    id: root

    required property var result

    property bool holds: false

    property bool offersSymbols: false
    property bool symbolsOpen: false

    signal copied
    signal symbols

    visible: !!root.result

    height: visible ? root.rowHeight : 0

    icon: "calculate"
    label: root.result?.text ?? ""
    detail: root.result?.detail || root.expression
    selected: root.holds
    inlineDetail: true

    onActivated: root.copied()

    property string expression: ""

    Row {
        spacing: Appearance.padding.normal

        Button {
            visible: root.offersSymbols && !root.result?.money
            anchors.verticalCenter: parent.verticalCenter
            icon: "function"
            text: "Symbols"
            style: "text"
            checkable: true
            checked: root.symbolsOpen
            onToggled: root.symbols()
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "copy"
            font.pixelSize: Appearance.font.size.small
            color: root.holds ? Appearance.colour.accent : Appearance.colour.textGhost

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.fast
                }
            }
        }
    }
}
