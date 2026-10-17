import Quickshell.Io
import qs.services

IpcHandler {
    target: "migration"

    function status(): string {
        if (CliMigration.declined)
            return `declined (${CliMigration.deprecated} old binds, in ${CliMigration.staleFiles.length} file(s); clear cli.bindsDeclined to be asked again)`;
        if (CliMigration.deprecated === 0)
            return CliMigration.scanned ? "all binds speak the new grammar" : "not scanned yet";
        return `${CliMigration.deprecated} old bind(s) in: ${CliMigration.staleFiles.join(", ")}`;
    }

    function migrate(): string {
        return CliMigration.migrate();
    }
}
