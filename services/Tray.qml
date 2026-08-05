pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Adapter over the StatusNotifierItem host: what is RUNNING but not on screen.
//
// The workspace column answers "what windows are there", and it is complete
// about it, which is exactly why it cannot answer this one: an application
// sitting in the background has no window, so it appears nowhere in that column
// and nowhere else in the shell either. Spotify is playing, the VPN is up,
// Steam is downloading something, and the machine looks idle.
//
// Widgets read this and never `SystemTray` directly, the same rule the rest of
// services/ follows. Everything about the protocol lives here: which items are
// worth drawing, what to call one, and what mark it gets.
Singleton {
    id: root

    // WHAT TO DRAW, in an order that holds still.
    //
    // The host lists items in the order they registered, which is the order the
    // session happened to start them in: a crashed application that comes back
    // lands at the end, and the row you learned this morning is a different row
    // this afternoon. Sorted by identity instead, so the tray is in the same
    // order tomorrow.
    //
    // `Passive` is the protocol's word for "nothing to say right now", and it is
    // meant to be hidden. It is the one filter here: everything else an
    // application chooses to put in the tray is its business.
    readonly property var items: [...SystemTray.items.values].filter(i => i && i.status !== Status.Passive).sort((a, b) => root.keyOf(a).localeCompare(root.keyOf(b)))

    // What an item is called ON THE WIRE, and therefore what a menu key and a
    // sort order are built from. The id is the stable half: a title changes with
    // whatever the application is currently doing ("Spotify - Yumi Zouma"), and
    // sorting on that would reorder the tray every time a track changed.
    function keyOf(item: var): string {
        return item?.id || item?.title || "";
    }

    // What it is called OUT LOUD, which is the title: the protocol's own field
    // for a name meant to be shown to a person. NOT the tooltip's heading, even
    // though that is often the more informative of the two, because what is in
    // it is usually a STATE ("Bluetooth Active"), and a heading that renames
    // itself as the thing it names changes is a heading you cannot learn. The
    // state goes below, where a line that changes is meant to.
    function nameOf(item: var): string {
        return item?.title || item?.tooltipTitle || item?.id || "tray item";
    }

    // That line. The tooltip is where an application says what it is currently
    // doing, in either half of it or in both, so both are taken and whichever
    // has already been said as the name is dropped.
    function detailOf(item: var): string {
        const name = root.nameOf(item);
        return [item?.tooltipTitle ?? "", item?.tooltipDescription ?? ""].filter(p => p && p !== name).join(" · ");
    }

    // THE MARK, as an AppMark spec, through the same table every window in the
    // sidebar goes through: an application you have picked an icon for looks the
    // same whether you are looking at its window or at the fact that it has
    // none. Looked up under the tray id, which is what the application calls
    // itself here and is usually, but not always, its window class.
    //
    // What it falls back to is the icon the item is ADVERTISING, which Quickshell
    // has already resolved out of the theme or out of the pixmap the application
    // sent down the bus. As `mono`, like everything else in this column: it is a
    // mark in a bar, not a logo. FittedImage drops the tint by itself for the
    // ones that are a solid shape and would flatten into a featureless disc.
    function markFor(item: var): string {
        const id = item?.id ?? "";
        const picked = id ? AppIcons.markFor(id) || AppIcons.markFor(id.toLowerCase()) : "";
        if (picked)
            return picked;
        const art = item?.icon ?? "";
        return art ? `mono:${art}` : "";
    }

    // The protocol's one word for "look at me", and the only thing in the tray
    // worth a colour. An application says this when something has happened that
    // it cannot say any other way, which is exactly what `alert` means
    // everywhere else in the sidebar.
    function urgent(item: var): bool {
        return item?.status === Status.NeedsAttention;
    }

    // THE PRIMARY ACTION, which is "show me this thing".
    //
    // Some applications refuse it and offer only a menu (`onlyMenu`), which is
    // the protocol's way of saying a click on them means nothing. Sending one
    // anyway is how a bar ends up with icons that do nothing when pressed and no
    // way to tell which, so it is not sent, and what the caller gets back is
    // whether anything happened.
    function activate(item: var): bool {
        if (!item || item.onlyMenu)
            return false;
        item.activate();
        return true;
    }

    function secondary(item: var): void {
        item?.secondaryActivate();
    }

    // The wheel, forwarded. Volume for a music player, usually; whatever the
    // application decided otherwise.
    function scroll(item: var, delta: int): void {
        item?.scroll(delta, false);
    }
}
