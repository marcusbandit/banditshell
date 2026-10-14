pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services
import "catalogue.js" as Catalogue

Singleton {
    id: root

    property string current: "connections"

    readonly property bool hub: !!Catalogue.CAT_BY_ID[root.current]
    readonly property var page: root.hub ? null : Catalogue.PAGE_BY_ID[root.current] ?? null
    readonly property var cat: root.hub ? Catalogue.CAT_BY_ID[root.current] : Catalogue.CAT_BY_ID[root.page?.cat ?? "connections"]
    readonly property string title: root.hub ? root.cat.name : Catalogue.nameOf(root.page, SettingsState)
    readonly property string preview: root.hub ? root.cat.preview : root.page?.preview ?? ""

    property var hovered: null
    property var pin: null

    property bool paneOut: false

    property bool compact: false
    property bool tiny: false
    property bool spread: false
    property bool fold: false
    property real foldHeight: 360

    property string query: ""
    property bool searchFocused: false
    readonly property bool searching: root.query.trim() !== "" || root.searchFocused

    property string layoutHover: ""

    property var flash: null
    property int turn: 0

    readonly property bool reduceMotion: SettingsState.v("reduceMotion")

    property var openRows: ({})

    Component.onCompleted: {
        if (Settings.page && Settings.page !== root.current)
            root.go(Settings.page);
    }

    function go(id: string): void {
        const known = Catalogue.CAT_BY_ID[id] || Catalogue.PAGE_BY_ID[id];
        root.current = known ? id : "connections";
        root.hovered = null;
        root.pin = null;
        root.paneOut = false;
        root.turn++;
        Settings.page = root.current;
    }

    function isOpen(uid: string): bool {
        return !!root.openRows[uid];
    }

    function setOpen(uid: string, open: bool): void {
        const next = Object.assign({}, root.openRows);
        if (open)
            next[uid] = true;
        else
            delete next[uid];
        root.openRows = next;
    }

    function focusRow(key: string): void {
        const row = Catalogue.ROWS.find(r => r.page === root.current && (r.k === key || r.w === key));
        if (!row)
            return;
        root.hovered = row;
        root.flash = {
            uid: row.uid,
            at: Date.now()
        };
    }

    function openHit(hit: var): void {
        root.query = "";
        root.go(hit.page.id);
        let r = hit.row;
        while (r.parent) {
            root.setOpen(r.parent.uid, true);
            r = r.parent;
        }
        root.hovered = hit.row;
        root.flash = {
            uid: hit.row.uid,
            at: Date.now()
        };
    }

    function openPin(type: string, id: var, title: string): void {
        root.pin = {
            type,
            id,
            title: title ?? ""
        };
        root.paneOut = true;
    }

    function pinTitle(p: var): string {
        if (!p)
            return "";
        switch (p.type) {
        case "net":
            return p.id;
        case "scan":
            return "scan a code";
        case "dev":
            return Bluetooth.deviceAt(p.id)?.name ?? "device";
        case "key":
            return p.title ?? "key";
        }
        return "";
    }

    function unpin(): void {
        root.pin = null;
    }

    property var toast: null
    property int toastSerial: 0

    function drop(text: string, icon: string, action: var): void {
        if (icon === "error")
            Notifications.alert("error");
        root.toast = {
            text,
            icon: icon || "check",
            action: action ?? null,
            serial: ++root.toastSerial
        };
    }

    function clearToast(): void {
        root.toast = null;
    }

    Connections {
        target: SettingsState

        function onRefused(why: string, go: string): void {
            root.drop(why, "edit_off", go ? {
                label: "go there",
                run: () => root.go(go)
            } : null);
        }
    }

    Connections {
        target: Settings

        function onPageChanged(): void {
            if (Settings.page && Settings.page !== root.current)
                root.go(Settings.page);
        }

        function onRevealChanged(): void {
            if (!Settings.reveal)
                return;
            const found = Catalogue.resolve(Settings.reveal);
            if (found?.row)
                root.openHit({
                    page: Catalogue.PAGE_BY_ID[found.page],
                    row: found.row
                });
            Settings.reveal = "";
        }
    }
}
