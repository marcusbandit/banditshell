pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.panel
import "catalogue.js" as SettingsCatalogue

Scope {
    id: root

    function settingsScreen(screen: string): string {
        return screen || Focus.offStageScreen || "";
    }

    function unknownSetting(page: string): string {
        return page && !SettingsCatalogue.resolve(page) ? `no such page: ${page} (have: ${SettingsCatalogue.CATS.map(c => c.id).concat(SettingsCatalogue.PAGES.map(p => p.id)).join(", ")}, or any setting's key)` : "";
    }

    IpcHandler {
        target: "settings"

        function toggle(): string {
            Appearance.instantly();
            Settings.toggle(root.settingsScreen(""));
            return Settings.open ? "open" : "closed";
        }

        function open(page: string, screen: string): string {
            Appearance.instantly();
            const wrong = root.unknownSetting(page);
            if (wrong)
                return wrong;
            if (screen && !Shell.forScreen(screen))
                return PanelWindows.missing(screen);
            const found = page ? SettingsCatalogue.resolve(page) : null;
            Settings.openAt(root.settingsScreen(screen), found ? found.page || found.cat : "", found?.row ? page : "");
            return page ? `open at ${page}` : "open";
        }

        function close(): string {
            Appearance.instantly();
            Settings.hide();
            return "closed";
        }

        function page(key: string): string {
            if (!key)
                return Settings.page || "no page";
            const wrong = root.unknownSetting(key);
            if (wrong)
                return wrong;
            const found = SettingsCatalogue.resolve(key);
            Settings.page = found.page || found.cat;
            if (found.row)
                Settings.reveal = key;
            return `page ${Settings.page}`;
        }

        function status(): string {
            return [`open       ${Settings.open}`, `page       ${Settings.page || "-"}`, `screen     ${Settings.screenName || "-"}`].join("\n");
        }
    }
}
