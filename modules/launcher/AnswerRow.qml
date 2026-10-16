import QtQuick
import qs.config
import qs.components
import qs.services
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

    icon: root.result?.icon ?? "calculate"

    mark: root.result?.swatch ? swatch : null

    Component {
        id: swatch

        SquircleRect {
            width: root.iconSize
            height: root.iconSize
            radius: Appearance.rounding.small
            color: root.result?.swatch ?? "transparent"
            stroke: Appearance.colour.seam
            strokeWidth: Appearance.sizes.seam
        }
    }
    label: root.result?.text ?? ""
    detail: root.result?.missing ? "" : root.result?.detail || root.expression
    selected: root.holds
    inlineDetail: true

    onActivated: root.copied()

    property string expression: ""

    Row {
        spacing: Appearance.padding.normal

        Button {
            visible: !!root.result?.missing && Calculator.installing !== "trying"
            anchors.verticalCenter: parent.verticalCenter
            icon: "download"
            text: Calculator.installing === "terminal" ? "Open again" : "Install"
            style: "outlined"
            size: 0
            onClicked: root.copied()
        }

        Button {
            visible: root.offersSymbols && !root.result?.money && !root.result?.missing && !root.result?.icon
            anchors.verticalCenter: parent.verticalCenter
            icon: "function"
            text: "Symbols"
            style: "outlined"
            size: 0
            checkable: true
            checked: root.symbolsOpen
            onToggled: root.symbols()
        }

        StyledText {
            visible: !root.result?.missing
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
