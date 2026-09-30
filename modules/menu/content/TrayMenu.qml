import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property var item: null

    spacing: Appearance.padding.small

    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        visible: !!text
        text: Tray.detailOf(root.item)
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }

    MenuRow {
        width: parent.width
        visible: !!root.item && !root.item.onlyMenu
        icon: "open_in_full"
        label: "Show it"
        onActivated: Tray.activate(root.item)
    }

    Separator {
        width: parent.width
        visible: entries.entries.length > 0
    }

    TrayEntries {
        id: entries

        width: parent.width
        menu: root.item?.menu ?? null
    }

    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        visible: !entries.entries.length
        text: root.item?.onlyMenu ? "nothing here yet" : "no menu; click it to show it"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }
}
