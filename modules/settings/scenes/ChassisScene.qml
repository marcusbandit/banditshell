import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../components/squircle.js" as Squircle

Item {
    id: root

    readonly property real stageHeight: 220

    readonly property real band: Appearance.bare ? 0 : Appearance.sizes.border * 0.5
    readonly property real bar: SidebarState.enabled ? Appearance.sizes.sidebarWidth * 0.5 : 0
    readonly property real corner: Appearance.sizes.windowRadius * 0.6

    Item {
        id: mini

        x: Appearance.padding.card
        y: Appearance.padding.card
        width: parent.width - Appearance.padding.card * 2
        height: parent.height - Appearance.padding.card * 2

        SquircleImage {
            anchors.fill: parent
            visible: SettingsState.v("wallOn")
            radius: root.corner
            source: Wallpaper.faceOf(Wallpaper.currentOn(Settings.screenName))
            fillMode: Image.PreserveAspectCrop
        }

        Shape {
            id: frame

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property real hx: root.band + root.bar
            readonly property real hy: root.band
            readonly property real hw: Math.max(0, width - hx - root.band)
            readonly property real hh: Math.max(0, height - root.band * 2)

            ShapePath {
                fillColor: SettingsState.v("wallOn") ? Appearance.colour.surface : Appearance.colour.surfaceSolid
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill

                PathSvg {
                    path: {
                        const outer = Squircle.path(frame.width, frame.height, root.corner, root.corner, root.corner, root.corner, Appearance.rounding.power);
                        const hole = Squircle.path(frame.hw, frame.hh, root.corner, root.corner, root.corner, root.corner, Appearance.rounding.power);
                        let axis = 0;
                        const moved = hole.split(" ").filter(Boolean).map(tok => {
                            if (/^[A-Za-z]$/.test(tok)) {
                                axis = 0;
                                return tok;
                            }
                            const v = +tok + (axis % 2 === 0 ? frame.hx : frame.hy);
                            axis++;
                            return v.toFixed(3);
                        });
                        return `${outer} ${moved.join(" ")}`;
                    }
                }
            }
        }

        Column {
            visible: root.bar > 0
            x: root.band + (root.bar - 10) / 2
            y: root.band + 10
            spacing: 5

            Repeater {
                model: [[4, false], [16, true], [4, false], [10, false]]

                delegate: SquircleRect {
                    required property var modelData

                    width: 10
                    height: modelData[0]
                    radius: 4
                    color: modelData[1] ? Appearance.colour.accent : Appearance.colour.fillStrong
                }
            }
        }

        Item {
            x: root.band + root.bar
            y: parent.height * 0.3
            width: parent.width * 0.52
            height: menu.implicitHeight + 20

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                topLeftRadius: 0
                bottomLeftRadius: 0
                color: Appearance.colour.surface
            }

            Column {
                id: menu

                x: 10
                y: 10
                width: parent.width - 20
                spacing: 7

                SquircleRect {
                    width: parent.width * 0.4
                    height: 6
                    pill: "place"
                    color: Appearance.colour.textDim
                }

                SquircleRect {
                    width: parent.width
                    height: 6
                    pill: "place"
                    color: Appearance.colour.fillStrong
                }

                SquircleRect {
                    width: parent.width * 0.7
                    height: 6
                    pill: "place"
                    color: Appearance.colour.fillStrong
                }

                Toggle {
                    checked: true
                    scale: 0.6
                    transformOrigin: Item.Left
                }
            }
        }
    }
}
