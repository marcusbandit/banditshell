pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var row: null
    property bool selected: false

    readonly property var item: root.row?.item ?? null
    readonly property int span: root.row?.span ?? 1
    readonly property bool tall: root.span !== 1
    readonly property var drawing: root.item?.qml && root.row?.owner ? PluginHost.drawingOf(root.row.owner.pluginId, root.item.qml) : null
    readonly property bool drawn: !!root.drawing && own.status === Loader.Ready

    readonly property PluginContext context: PluginContext {
        owner: root.row?.owner ?? null
        item: root.item
        selected: root.selected
    }

    implicitHeight: root.drawn ? own.item.implicitHeight : words.implicitHeight + Appearance.padding.normal * 2

    function claimKey(event: var): bool {
        return root.drawn && typeof own.item.claimKey === "function" && !!own.item.claimKey(event);
    }

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
        visible: root.drawn
    }

    Item {
        id: mark

        readonly property real side: root.tall ? Math.max(Appearance.sizes.launcherIcon, Math.min(root.height - Appearance.padding.normal * 2, Appearance.sizes.launcherIcon * 3)) : Appearance.sizes.launcherIcon

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: mark.side
        height: mark.side
        visible: !root.drawn

        SquircleImage {
            id: picture

            anchors.fill: parent
            source: root.item?.image || root.row?.iconSource || ""
            radius: Appearance.rounding.small
            visible: picture.ready
        }

        Icon {
            anchors.centerIn: parent
            visible: !picture.ready
            size: root.tall ? Math.min(mark.side * 0.6, Appearance.sizes.launcherIcon * 1.4) : Appearance.sizes.launcherIcon
            name: root.row?.icon ?? ""
            glyph: root.row?.glyph ?? ""
            color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
        }
    }

    StyledText {
        id: aside

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width * 0.45)
        visible: !root.drawn && !root.tall && text !== ""
        text: root.row?.detail ?? ""
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
        elide: Text.ElideRight
    }

    Column {
        id: words

        anchors.left: mark.right
        anchors.leftMargin: Appearance.padding.normal
        anchors.right: aside.visible ? aside.left : parent.right
        anchors.rightMargin: aside.visible ? Appearance.padding.large : 0
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.drawn

        StyledText {
            width: parent.width
            text: root.item?.title ?? ""
            font.pixelSize: Appearance.font.size.normal
            color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text !== "" && root.tall
            text: root.row?.detail ?? ""
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
            elide: Text.ElideRight
        }

        StyledText {
            readonly property real room: root.height - Appearance.padding.small * 2 - Appearance.font.line.normal - (root.row?.detail ? Appearance.font.line.small : 0)

            width: parent.width
            visible: text !== "" && root.tall && (root.span === 0 || room >= Appearance.font.line.small)
            text: root.item?.text ?? ""
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
            wrapMode: Text.Wrap
            maximumLineCount: root.span === 0 ? 40 : Math.max(1, Math.floor(room / Appearance.font.line.small))
            elide: Text.ElideRight
        }
    }
}
