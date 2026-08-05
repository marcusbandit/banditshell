import QtQuick
import qs.config
import qs.components
import qs.services

// ONE BACKGROUND APPLICATION: what it is currently saying, the click the icon
// already answers, and everything it will let you do without opening it.
//
// The rows underneath are somebody else's and are drawn by TrayEntries. What is
// here is the part the shell gets to write: the name in the panel's heading
// comes from the menu layer, the line under it is the application's own status,
// and the first row is the primary action written down. An icon that does
// something on click and never says what is a guess; this is where the guess is
// spelled out.
Column {
    id: root

    // The item this menu is about. Written once by whoever opened it and never
    // bound: two of these exist during a cross-fade, and the outgoing one has to
    // go on being about the application it was about.
    property var item: null

    spacing: Appearance.padding.small

    // What the application is currently saying about itself, which is the whole
    // reason some of these icons exist: a sync client's tray icon IS its status
    // line. A fact, not a control, so it takes the quiet tier and no row.
    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        visible: !!text
        text: Tray.detailOf(root.item)
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }

    // Absent, rather than present and lying, when the application has declared
    // it has no primary action.
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

    // Nothing to say, said plainly. Plenty of applications register a tray icon
    // and no menu behind it, and a menu that opens onto an empty panel reads as
    // one that failed to load.
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
