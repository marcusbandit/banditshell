pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool open: false
    property string screenName: ""
    property string page: "connections"
    property string reveal: ""
    property bool away: false

    function show(screen: string, which: string): void {
        const span = root.open ? null : Trace.begin("settings open");
        root.screenName = screen || root.screenName || Quickshell.screens[0]?.name || "";
        if (which)
            root.page = which;
        root.open = true;
        Trace.step("shown", span);
    }

    function hide(): void {
        const span = root.open ? Trace.begin("settings close") : null;
        root.open = false;
        Trace.step("hidden", span);
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
        Panels.claim("settings", {
            open: args => root.openAt(args.screen ?? "", args.page ?? "", args.row ?? ""),
            toggle: args => root.toggle(args.screen ?? ""),
            isOpen: () => root.open
        });
        const was = Relaunch.recall("settings");
        if (!was)
            return;
        if (was.page)
            root.page = was.page;
        if (was.open && Quickshell.screens.some(s => s.name === was.screen))
            root.show(was.screen, "");
    }
}
