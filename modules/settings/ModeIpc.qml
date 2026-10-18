import Quickshell.Io
import qs.config
import qs.services
import "catalogue.js" as SettingsCatalogue
import "../cli.js" as Words

IpcHandler {
    target: "mode"

    function list(): string {
        return Words.columns(SettingsCatalogue.MODES.map(m => [m.id === Modes.current ? "*" : " ", m.id, m.detail]));
    }

    function choose(id: string): string {
        if (!SettingsCatalogue.MODES.some(m => m.id === id))
            return `refused: no such mode: ${id} (have: ${SettingsCatalogue.MODES.map(m => m.id).join(", ")})`;
        if (!Config.writable)
            return `refused: ${Config.path} has not been read, so nothing can be changed`;
        SettingsState.setMode(id);
        return `mode: ${Modes.current}`;
    }

    function status(): string {
        const found = SettingsCatalogue.MODES.find(m => m.id === Modes.current);
        return found ? `${found.id} (${found.detail})` : Modes.current;
    }
}
