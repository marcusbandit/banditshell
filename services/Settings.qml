pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool open: false
    property string screenName: ""
    property string page: "connections"
    property string reveal: ""

    function show(screen: string, which: string): void {
        root.screenName = screen || root.screenName || Quickshell.screens[0]?.name || "";
        if (which)
            root.page = which;
        root.open = true;
    }

    function hide(): void {
        root.open = false;
    }

    function toggle(screen: string): void {
        if (root.open && (!screen || screen === root.screenName))
            root.hide();
        else
            root.show(screen, "");
    }

    function openAt(screen: string, page: string, row: string): void {
        root.show(screen, page);
        root.reveal = row ?? "";
    }

    function remember(): void {
        Relaunch.keep("settings", {
            open: root.open,
            screen: root.screenName,
            page: root.page
        });
    }

    onOpenChanged: root.remember()
    onScreenNameChanged: root.remember()
    onPageChanged: root.remember()

    Component.onCompleted: {
        const was = Relaunch.recall("settings");
        if (!was)
            return;
        if (was.page)
            root.page = was.page;
        if (was.open && Quickshell.screens.some(s => s.name === was.screen))
            root.show(was.screen, "");
    }
}
