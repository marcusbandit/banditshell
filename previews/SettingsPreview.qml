import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.modules.settings
import qs.services
import "../modules/settings/catalogue.js" as SettingsCatalogue

ShellRoot {
    id: root

    readonly property var size: (Quickshell.env("SETTINGS_PREVIEW") || "1920x1080").split("x").map(Number)

    FloatingWindow {
        id: win

        title: "banditshell-settingspreview"
        implicitWidth: root.size[0]
        implicitHeight: root.size[1]
        color: Appearance.colour.surfaceSolid

        Component.onCompleted: {
            const page = Quickshell.env("SETTINGS_PAGE");
            const found = page ? SettingsCatalogue.resolve(page) : null;
            Settings.openAt(win.screen?.name ?? "", found ? found.page || found.cat : "", found?.row ? page : "");
        }

        Item {
            id: desk

            anchors.fill: parent

            readonly property real band: Appearance.sizes.border
            readonly property real bar: band + Appearance.sizes.sidebarWidth

            Image {
                anchors.fill: parent
                source: Wallpaper.current ? `file://${Wallpaper.expand(Wallpaper.current)}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            SquircleRect {
                x: desk.bar
                y: desk.band
                width: parent.width - desk.bar - desk.band
                height: parent.height - desk.band * 2
                radius: Appearance.sizes.windowRadius
                color: "transparent"
                stroke: Appearance.colour.surface
                strokeWidth: 0
            }

            Repeater {
                model: panel.blobs

                delegate: SquircleRect {
                    required property var modelData

                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    radius: modelData.radius ?? Appearance.rounding.large
                    color: Appearance.colour.surface
                }
            }

            SettingsPanel {
                id: panel

                anchors.fill: parent
                originX: desk.bar
                band: desk.band
            }
        }
    }
}
