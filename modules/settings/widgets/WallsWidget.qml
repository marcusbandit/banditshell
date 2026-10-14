pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import qs.modules.settings

Item {
    id: root

    property var row: ({})

    readonly property string screen: Settings.screenName
    readonly property string shown: Wallpaper.currentOn(root.screen)
    readonly property bool usable: SettingsState.v("wallOn")
    readonly property int columns: SettingsView.tiny ? 2 : 4
    readonly property real gap: Appearance.padding.small
    readonly property real tile: (root.width - Appearance.padding.normal * 2 - (root.columns - 1) * root.gap) / root.columns

    width: parent ? parent.width : 0
    implicitHeight: grid.height + Appearance.padding.small + Appearance.padding.normal

    HoverHandler {
        onHoveredChanged: if (hovered)
            SettingsView.hovered = root.row
    }

    Grid {
        id: grid

        x: Appearance.padding.normal
        y: Appearance.padding.small
        columns: root.columns
        spacing: root.gap

        Repeater {
            model: Wallpaper.available

            delegate: Item {
                id: wp

                required property string modelData

                readonly property bool on: wp.modelData === root.shown
                readonly property bool moving: Wallpaper.movesOf(wp.modelData)

                width: root.tile
                height: Math.round(root.tile * 10 / 16)
                opacity: root.usable ? 1 : 0.35
                scale: hover.hovered && root.usable ? 0.97 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.fast
                    }
                }

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: -4
                    visible: wp.on
                    radius: Appearance.rounding.normal + 4
                    color: Appearance.colour.accent
                }

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: -2
                    visible: wp.on
                    radius: Appearance.rounding.normal + 2
                    color: Appearance.colour.surfaceSolid
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fillStrong
                }

                SquircleImage {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    source: Wallpaper.faceOf(wp.modelData)
                    fillMode: Image.PreserveAspectCrop
                }

                Icon {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    visible: wp.moving
                    name: SettingsState.v("wallAnim") ? "animation" : "pause"
                    size: 16
                    color: "white"
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const at = wp.mapToItem(null, mouse.x, mouse.y);
                        const w = wp.Window.width || 1;
                        const h = wp.Window.height || 1;
                        if (SettingsState.v("wallTarget") === "everywhere")
                            Wallpaper.setFromAll(wp.modelData, at.x / w, at.y / h);
                        else
                            Wallpaper.setFrom(root.screen, wp.modelData, at.x / w, at.y / h);
                    }
                }

                HoverTip {
                    host: wp
                    text: Wallpaper.nameOf(wp.modelData).toLowerCase()
                }
            }
        }
    }
}
