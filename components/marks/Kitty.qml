import QtQuick
import QtQuick.Shapes
import qs.config

Item {
    id: root

    property color colour: Appearance.colour.text

    property real size: Appearance.font.iconSize

    readonly property real behind: 0.7
    readonly property real between: 0.85

    readonly property real artX: 24.75
    readonly property real artY: 834.862
    readonly property real artW: 190.5
    readonly property real artH: 195

    implicitWidth: Math.round(root.size * root.artW / root.artH)
    implicitHeight: root.size

    Item {
        anchors.centerIn: parent

        width: root.artW
        height: root.artH
        scale: root.size / root.artH

        Shape {

            width: 240
            height: 240
            x: -root.artX
            y: -root.artY

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Qt.rgba(root.colour.r, root.colour.g, root.colour.b, root.colour.a * root.behind)
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathSvg {
                    path: "M67.896 1029.71h104.208a7.065 7.065 0 0 0 7.065-7.066V918.436a7.065 7.065 0 0 0-7.065-7.065H67.896a7.065 7.065 0 0 0-7.065 7.065v104.208a7.065 7.065 0 0 0 7.065 7.065m55.813-38.35h37.444a4.239 4.239 0 0 1 0 8.479H123.71a4.239 4.239 0 0 1 0-8.478m-45.032-45.71a4.239 4.239 0 0 1 5.991-5.99l26.48 26.464a4.24 4.24 0 0 1 0 5.992l-26.48 26.48a4.239 4.239 0 0 1-5.991-5.992l23.484-23.484z"
                }
            }

            ShapePath {
                fillColor: root.colour
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathSvg {
                    path: "M193.128 836.886c-4.596-4.85-25.53 1.022-38.295 8.936-9.957-5.106-21.956-8.17-34.721-8.17-13.02 0-25.02 3.064-34.977 8.17-12.765-7.914-33.955-14.042-38.295-8.936-4.595 5.106 3.32 26.296 12.765 38.04-.766 3.064-1.276 6.128-1.276 9.446 0 10.212 4.34 19.659 11.744 27.318h42.124c-1.276-2.553.511-4.085 8.17-4.085 7.659.255 9.19 1.532 8.17 4.085h42.124c7.404-7.66 11.744-17.36 11.744-27.318 0-3.318-.51-6.382-1.276-9.446 8.935-11.744 16.594-33.189 11.999-38.04m-97.015 67.4c-8.935 0-16.339-7.404-16.339-16.34s7.404-16.339 16.34-16.339 16.339 7.404 16.339 16.34-7.404 16.339-16.34 16.339m47.997 0c-8.936 0-16.34-7.404-16.34-16.34s7.404-16.339 16.34-16.339 16.34 7.404 16.34 16.34-7.15 16.339-16.34 16.339"
                }
            }

            ShapePath {
                fillColor: Qt.rgba(root.colour.r, root.colour.g, root.colour.b, root.colour.a * root.between)
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"

                PathSvg {
                    path: "M52.6 893.563c-6.382 0-11.743 3.32-14.296 8.425h-.766c-6.893 0-12.765 5.106-12.765 11.489 0 8.935 9.19 13.786 17.615 10.722 5.106 7.404 16.084 7.915 20.17 0 6.126-.255 16.083-1.276 17.615-10.722 1.021-6.383-5.617-11.489-12.765-11.489h-.766c-2.042-5.106-7.659-8.425-14.041-8.425m134.8 0c6.382 0 11.743 3.32 14.296 8.425h.766c3.574 0 12.765 5.106 12.765 11.489 0 8.935-9.19 13.786-17.615 10.722-5.107 7.404-16.084 7.915-20.17 0-6.126-.255-16.083-1.276-17.615-10.722-1.021-6.383 9.19-11.489 12.765-11.489h.766c2.042-5.106 7.659-8.425 14.041-8.425"
                }
            }

            ShapePath {
                fillColor: Appearance.colour.accent
                strokeColor: "transparent"

                PathSvg {
                    path: "M96.085 898.143c1.881 0 3.386-3.574 3.386-8.17 0-4.595-1.505-8.169-3.386-8.169-1.88 0-3.385 3.574-3.385 8.17 0 4.595 1.504 8.17 3.385 8.17"
                }
            }

            ShapePath {
                fillColor: Appearance.colour.accent
                strokeColor: "transparent"

                PathSvg {
                    path: "M143.542 898.143c1.881 0 3.386-3.574 3.386-8.17 0-4.595-1.505-8.169-3.386-8.169-1.88 0-3.386 3.574-3.386 8.17 0 4.595 1.505 8.17 3.386 8.17"
                }
            }
        }
    }
}
