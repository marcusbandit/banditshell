import Quickshell.Io
import qs.services

IpcHandler {
    target: "files"

    function open(path: string): string {
        Files.show(path);
        return path ? `files ${path}` : "files";
    }

    function toggle(path: string): string {
        Files.toggle(path);
        return Files.windowOpen ? "open" : "closed";
    }

    function close(): string {
        Files.hide();
        return "closed";
    }

    function status(): string {
        const shell = Files.term ? `rows=${Files.term.rows} alt=${Files.term.altActive}` : "no session";
        return `open=${Files.windowOpen} cwd=${Files.cwd} entries=${Files.entries.length} focus=${Files.focus} terminal=[${shell}] error=[${Files.error}]`;
    }
}
