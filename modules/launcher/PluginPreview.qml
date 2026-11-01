import QtQuick
import qs.config

Item {
    id: root

    property var entry: null

    readonly property var drawing: root.entry?.qml && root.entry?.owner ? PluginHost.drawingOf(root.entry.owner.pluginId, root.entry.qml) : null
    readonly property real narrowest: Appearance.sizes.launcherWidth * 0.4
    readonly property real widest: Appearance.sizes.launcherWidth * 0.7

    readonly property PluginContext context: PluginContext {
        owner: root.entry?.owner ?? null
        item: root.entry?.item ?? null
        selected: true
        preview: true
    }

    width: own.item?.implicitWidth > 0 ? Math.max(root.narrowest, Math.min(root.widest, own.item.implicitWidth)) : root.widest
    height: own.item?.implicitHeight > 0 ? own.item.implicitHeight : Math.round(root.width * 0.6)

    function draw(): void {
        if (root.drawing)
            own.setSource(root.drawing.url, {
                row: root.context
            });
        else
            own.source = "";
    }

    onDrawingChanged: root.draw()
    Component.onCompleted: root.draw()

    Loader {
        id: own

        anchors.fill: parent
        asynchronous: true
        clip: true
    }
}
