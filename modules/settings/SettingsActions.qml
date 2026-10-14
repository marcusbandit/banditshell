pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root

    function later(label: string): void {
        SettingsView.drop(`${label} · not built yet, nothing changed`, "construction");
    }

    function run(act: string, row: var, from: Item): void {
        switch (act) {
        case "testNotif":
            Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "chat", "a test", `stays ${Math.round(Config.values.notifications.timeout / 1000)} s, like the rest`]);
            return;
        case "forgetHabit":
            return root.later("forgetting what the launcher learned");
        case "clearClip":
            {
                const kept = Clipboard.entries.slice();
                Clipboard.clear();
                return SettingsView.drop("clipboard cleared", "delete_sweep", {
                    label: "undo",
                    run: () => {
                        Clipboard.entries = kept.filter(e => e.pinned || !e.file);
                        Clipboard.save();
                        SettingsView.drop("put back", "undo");
                    }
                });
            }
        case "importClipse":
            return SettingsView.drop("clipse’s history comes over the next time the shell starts", "move_to_inbox");
        case "lockNow":
            Settings.hide();
            return Lock.lock();
        case "reload":
            return Quickshell.reload(true);
        case "rules":
            Files.installRules();
            return SettingsView.drop("window rules read again", "rule");
        case "reread":
            CompositorSync.refresh();
            return SettingsView.drop(`read hyprland again · rounding ${Math.round(Compositor.rounding)} · gaps ${Compositor.gapsOut}`, "sync");
        case "previewReveal":
            return root.later("replaying the reveal");
        case "exportCfg":
            return root.exportSettings();
        case "importCfg":
            return root.later("restoring from a file");
        }
        console.warn(`SettingsActions: nothing knows how to ${act}`);
    }

    function stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd-HHmm");
    }

    function exportSettings(): void {
        const dir = `${Quickshell.env("HOME")}/Documents`;
        const file = `${dir}/banditshell-settings-${root.stamp()}.json`;
        exporter.path = file;
        exporter.setText(JSON.stringify({
            config: Config.values,
            planned: SettingsState.planned
        }, null, 4) + "\n");
    }

    FileView {
        id: exporter

        printErrors: false
        onSaved: SettingsView.drop(`settings saved to ${exporter.path.replace(Quickshell.env("HOME"), "~")}`, "upload")
        onSaveFailed: SettingsView.drop("could not write the copy", "error")
    }
}
