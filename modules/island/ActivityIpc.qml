import Quickshell.Io
import qs.services

IpcHandler {
    id: root

    target: "activity"

    readonly property var providers: [Moments, Privacy]

    function reply(error: string, done: string): string {
        return error ? `refused: ${error}` : done;
    }

    function push(id: string, text: string, detail: string, progress: string, icon: string, until: string, priority: string, run: string): string {
        return root.reply(Activities.push({
            id: id,
            text: text,
            detail: detail,
            progress: progress,
            icon: icon,
            until: until,
            priority: priority,
            act: run,
            source: "ipc"
        }), `pushed ${id}`);
    }

    function update(id: string, text: string, detail: string, progress: string, icon: string, until: string): string {
        const patch = {};
        if (text)
            patch.text = text;
        if (detail)
            patch.detail = detail === "-" ? "" : detail;
        if (progress)
            patch.progress = progress;
        if (icon)
            patch.icon = icon;
        if (until)
            patch.until = until;
        return root.reply(Activities.update(id, patch), `updated ${id}`);
    }

    function end(id: string, outcome: string): string {
        return root.reply(Activities.end(id, outcome), `ended ${id}`);
    }

    function list(): string {
        return Activities.lines();
    }
}
