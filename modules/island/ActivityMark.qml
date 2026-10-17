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

    readonly property bool ringed: !root.round && root.look.markRing !== undefined

    readonly property real radius: root.round ? root.size / 2 : Appearance.rounding.normal
    readonly property real power: root.round ? 2 : Appearance.rounding.power

    implicitWidth: root.size
    implicitHeight: root.size

    Follow {
        id: remaining

        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
        target: root.look.markRing ?? 0
    }

    ProgressRing {
        anchors.centerIn: parent
        visible: root.ringed
        size: root.size
        thickness: Math.max(2, Math.round(root.size / 11))
        track: Appearance.colour.fillStrong
        colour: root.look.tone ?? Appearance.colour.accent
        value: remaining.value
    }

    AppMark {
        anchors.centerIn: parent
        visible: !!root.look.app
        spec: root.look.app ?? ""
        fits: AppIcons.fits
        onMeasured: (path, box) => AppIcons.recordFit(path, box)
        size: root.size
        fallback: Apps.genericIcon
        opacity: root.look.dim ? Appearance.opacity.disabled : 1
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
        size: root.ringed ? Math.round(root.size * 0.58) : root.size
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
