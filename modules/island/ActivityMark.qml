import QtQuick
import qs.config
import qs.components
import qs.modules.media
import qs.modules.notifications
import qs.services

Item {
    id: root

    property var look: ({})
    property real size: Appearance.font.line.small
    property bool round: false

    readonly property real radius: root.round ? root.size / 2 : Appearance.rounding.normal
    readonly property real power: root.round ? 2 : Appearance.rounding.power

    implicitWidth: root.size
    implicitHeight: root.size

    AppMark {
        anchors.centerIn: parent
        visible: !!root.look.app
        spec: root.look.app ?? ""
        fits: AppIcons.fits
        onMeasured: (path, box) => AppIcons.recordFit(path, box)
        size: root.size
        fallback: Apps.genericIcon
        opacity: root.look.dim ? 0.5 : 1
    }

    NotificationMark {
        anchors.centerIn: parent
        visible: !!root.look.entry
        entry: root.look.entry ?? null
        size: root.size
        radius: root.radius
        power: root.power
    }

    Icon {
        anchors.centerIn: parent
        visible: !root.look.app && !root.look.entry && !cover.ready
        name: root.look.icon ?? ""
        glyph: root.look.glyph ?? ""
        size: root.size
        fill: 1
        color: root.look.tone ?? Appearance.colour.textDim
    }

    ArtCrossfade {
        id: cover

        anchors.fill: parent
        visible: !!root.look.art
        radius: root.radius
        power: root.power
        source: root.look.art ?? ""
    }
}
