import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    signal requested(bool deliberate)

    readonly property string state: Update.state

    readonly property bool stale: CliMigration.stale

    readonly property bool quiet: root.state === Update.idle && !root.stale

    readonly property bool stuck: root.state === Update.failed || (root.state === Update.available && Update.diverged)

    readonly property string glyph: {
        if (root.state === Update.downloaded)
            return "download_done";
        if (root.state === Update.downloading)
            return "cloud_download";
        if (root.stuck)
            return "sync_problem";
        if (root.state === Update.available)
            return "system_update_alt";
        if (root.stale)
            return "published_with_changes";
        return "sync";
    }

    readonly property real markSize: root.quiet ? Math.round(Appearance.font.iconSize * 0.8) : Appearance.font.iconSize

    readonly property color tint: {
        if (root.state === Update.downloaded)
            return Appearance.colour.updateReady;
        if (root.stuck)
            return Appearance.colour.updateFailed;
        if (root.state !== Update.idle)
            return Appearance.colour.updateAvailable;
        if (root.stale)
            return Appearance.colour.accent;
        return press.containsMouse ? Appearance.colour.text : Appearance.colour.textDim;
    }

    visible: !root.quiet || Config.values.updates.alwaysShow

    width: parent ? parent.width : 0
    height: Math.max(Appearance.sizes.minTarget, mark.implicitHeight)

    Icon {
        id: mark

        anchors.centerIn: parent
        name: root.glyph
        fill: 1
        size: root.markSize
        color: root.tint

        scale: press.pressed ? Appearance.press.glyph : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.normal
            }
        }
    }

    MouseArea {
        id: press

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requested(true)
    }

}
