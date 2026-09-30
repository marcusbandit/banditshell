pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property var items: [...SystemTray.items.values].filter(i => i && i.status !== Status.Passive).sort((a, b) => root.keyOf(a).localeCompare(root.keyOf(b)))

    function keyOf(item: var): string {
        return item?.id || item?.title || "";
    }

    function nameOf(item: var): string {
        return item?.title || item?.tooltipTitle || item?.id || "tray item";
    }

    function detailOf(item: var): string {
        const name = root.nameOf(item);
        return [item?.tooltipTitle ?? "", item?.tooltipDescription ?? ""].filter(p => p && p !== name).join(" · ");
    }

    function classFor(id: string): string {
        if (!id)
            return "";
        const want = id.toLowerCase();
        for (const cls of AppIcons.classes) {
            const low = cls.toLowerCase();
            if (low === want || low.split(".").pop() === want)
                return cls;
        }
        return "";
    }

    function markFor(item: var): string {
        const id = item?.id ?? "";
        if (!id) {
            const bare = item?.icon ?? "";
            return bare ? `mono:${bare}` : "";
        }
        const cls = root.classFor(id);
        const picked = AppIcons.markFor(id) || AppIcons.markFor(id.toLowerCase()) || (cls ? AppIcons.markFor(cls) : "");
        if (picked)
            return picked;
        const art = item?.icon ?? "";
        return art ? `mono:${art}` : "";
    }

    function urgent(item: var): bool {
        return item?.status === Status.NeedsAttention;
    }

    function activate(item: var): bool {
        if (!item || item.onlyMenu)
            return false;
        item.activate();
        return true;
    }

    function secondary(item: var): void {
        item?.secondaryActivate();
    }

    function scroll(item: var, delta: int): void {
        item?.scroll(delta, false);
    }
}
