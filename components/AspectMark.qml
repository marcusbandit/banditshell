import QtQuick
import qs.config

Item {
    id: root

    property real aspect: 0

    property real reference: 0

    property bool fits: false

    property real size: Appearance.font.iconSize

    implicitWidth: size
    implicitHeight: size

    readonly property real inner: root.size - Appearance.font.stem * 4

    function spanW(a: real, box: real): real {
        return a >= 1 ? box : box * a;
    }

    function spanH(a: real, box: real): real {
        return a >= 1 ? box / a : box;
    }

    G2Rect {
        anchors.centerIn: parent
        width: root.reference > 0 ? root.spanW(root.reference, root.size) : root.size
        height: root.reference > 0 ? root.spanH(root.reference, root.size) : root.size
        radius: Appearance.rounding.small / 2
        color: "transparent"
        stroke: Appearance.colour.textFaint
        strokeWidth: Appearance.font.stem
    }

    G2Rect {
        anchors.centerIn: parent
        visible: root.aspect > 0
        width: root.spanW(root.aspect, root.inner)
        height: root.spanH(root.aspect, root.inner)
        radius: Appearance.rounding.small / 2
        color: root.fits ? Appearance.colour.accent : Appearance.colour.textFaint
    }
}
