import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Column {
    id: root

    property var items: []

    property var picked: null

    readonly property bool open: !!root.picked && root.items.includes(root.picked)

    spacing: Appearance.padding.small

    Repeater {
        model: root.items

        delegate: MenuRow {
            id: row

            required property var modelData

            width: root.width
            visible: !root.open
            label: Tray.nameOf(row.modelData)
            detail: Tray.detailOf(row.modelData)
            askable: true

            mark: Component {
                AppMark {
                    size: Appearance.sizes.trayIcon
                    spec: Tray.markFor(row.modelData)
                    fits: AppIcons.fits
                    onMeasured: (path, box) => AppIcons.recordFit(path, box)
                    color: Appearance.colour.textDim
                }
            }

            onActivated: {
                if (!Tray.activate(row.modelData))
                    root.picked = row.modelData;
            }

            onAsked: root.picked = row.modelData
        }
    }

    MenuRow {
        width: root.width
        visible: root.open
        icon: "arrow_back"
        label: "All tray icons"
        onActivated: root.picked = null
    }

    TrayMenu {
        width: root.width
        visible: root.open
        item: root.open ? root.picked : null
    }
}
