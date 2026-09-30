import QtQuick
import qs.config
import qs.components

MenuRow {
    id: root

    required property var result

    property bool holds: false

    signal copied

    visible: !!root.result

    height: visible ? implicitHeight : 0

    icon: "calculate"
    label: root.result?.text ?? ""
    detail: root.expression
    selected: root.holds
    inlineDetail: true

    onActivated: root.copied()

    property string expression: ""

    StyledText {
        text: "copy"
        font.pixelSize: Appearance.font.size.small
        color: root.holds ? Appearance.colour.accent : Appearance.colour.textGhost

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
}
