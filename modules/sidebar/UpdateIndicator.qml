import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    signal requested(bool deliberate)

    readonly property string state: Update.state

    // The migration's claim on the icon: until the old binds are rewritten or
    // the user has confirmed they will fix the config by hand, the icon says
    // so - same tint as an update waiting, a different glyph.
    readonly property bool stale: CliMigration.stale

    readonly property string glyph: {
        if (root.stale)
            return "published_with_changes";
        if (root.state === Update.idle)
            return "sync";
        if (root.state === Update.downloaded)
            return "download_done";
        if (root.state === Update.downloading)
            return "cloud_download";
        if (root.state === Update.failed)
            return "sync_problem";

        return "system_update_alt";
    }

    readonly property real markSize: root.state === Update.idle && !root.stale ? Math.round(Appearance.font.iconSize * 0.8) : Appearance.font.iconSize

    readonly property color tint: {
        if (root.stale)
            return Appearance.colour.updateReady;
        if (root.state === Update.idle)
            return press.containsMouse ? Appearance.colour.text : Appearance.colour.textDim;
        if (root.state === Update.downloaded)
            return Appearance.colour.updateReady;
        if (root.state === Update.failed)
            return Appearance.colour.updateFailed;
        return Appearance.colour.updateAvailable;
    }

    width: parent ? parent.width : 0
    height: Math.max(Appearance.sizes.minTarget, mark.implicitHeight)

    Icon {
        id: mark

        anchors.centerIn: parent
        name: root.glyph
        fill: 1
        size: root.markSize
        color: root.tint

        scale: press.pressed ? 0.92 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.normal
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
