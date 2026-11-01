pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    readonly property var pin: SettingsView.pin

    Column {
        id: top

        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 36

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - close.width - Appearance.padding.normal
                text: SettingsView.pinTitle(root.pin)
                font.pixelSize: Appearance.font.size.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            SettingsTool {
                id: close

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                tip: "put it away"
                onClicked: SettingsView.unpin()
            }
        }

        Item {
            width: parent.width
            height: Appearance.padding.card * 2 + 1

            Rectangle {
                y: Appearance.padding.card
                width: parent.width
                height: 1
                color: Appearance.colour.separator
            }
        }
    }

    Flickable {
        id: scroll

        y: top.height
        width: parent.width
        height: parent.height - y
        contentHeight: pinned.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelStep {
            flick: scroll
        }

        Loader {
            id: pinned

            width: scroll.width
            active: !!root.pin
            source: root.pin?.type ? Qt.resolvedUrl(`pins/${root.pin.type.charAt(0).toUpperCase()}${root.pin.type.slice(1)}Pin.qml`) : ""

            onLoaded: item.width = Qt.binding(() => pinned.width)
        }
    }
}
