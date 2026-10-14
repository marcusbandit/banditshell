import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property real band: Appearance.sizes.border

    readonly property var toast: SettingsView.toast
    readonly property bool shown: !!root.toast && rise.target > 0

    readonly property real fullHeight: 52 + root.band
    readonly property real pillWidth: line.implicitWidth + Appearance.padding.large * 2

    readonly property var blobs: rise.value <= 0.002 ? [] : [
        {
            x: (root.width - root.pillWidth) / 2,
            y: root.height - root.fullHeight * rise.value,
            w: root.pillWidth,
            h: root.fullHeight,
            radius: Appearance.rounding.large
        }
    ]

    readonly property Item maskItem: hit

    onToastChanged: {
        if (!root.toast) {
            rise.target = 0;
            return;
        }
        rise.target = 1;
        hold.interval = root.toast.action ? 6000 : 2800;
        hold.restart();
    }

    Timer {
        id: hold

        onTriggered: rise.target = 0
    }

    Follow {
        id: rise

        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
        onSettledChanged: if (settled && target === 0)
            SettingsView.clearToast()
    }

    Item {
        id: hit

        x: (root.width - root.pillWidth) / 2
        y: root.height - root.fullHeight * rise.value
        width: root.pillWidth
        height: root.fullHeight * rise.value
        clip: true
        visible: rise.value > 0.002

        HoverHandler {
            onHoveredChanged: hovered ? hold.stop() : hold.restart()
        }

        Row {
            id: line

            x: Appearance.padding.large
            y: (52 - height) / 2
            spacing: Appearance.padding.small

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.toast?.icon ?? "check"
                color: Appearance.colour.accent
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.toast?.text ?? ""
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.toast?.action
                text: root.toast?.action?.label ?? ""
                color: Appearance.colour.accent
                font.underline: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Appearance.padding.small
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const act = root.toast?.action;
                        rise.target = 0;
                        if (act)
                            act.run();
                    }
                }
            }
        }
    }
}
