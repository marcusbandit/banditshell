import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property string said: ""
    property string found: ""

    spacing: Appearance.padding.card

    Item {
        width: parent.width
        height: Math.max(300, scanner.implicitHeight)

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.fill
        }

        QrScanner {
            id: scanner

            width: parent.width
            active: SettingsView.pin?.type === "scan"
            note: root.said
            onDecoded: text => {
                const trouble = Network.joinQr(text);
                if (trouble) {
                    root.said = trouble;
                    return;
                }
                root.found = text;
                SettingsView.unpin();
                SettingsView.drop("joining from the code", "qr_code_scanner");
            }
        }
    }

    StyledText {
        width: parent.width
        text: scanner.status
        color: Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }
}
