import Quickshell.Io
import qs.services

IpcHandler {
    target: "trace"

    function on(): string {
        Trace.recording = true;
        return "recording";
    }

    function off(): string {
        Trace.stop();
        return "stopped";
    }

    function status(): string {
        return `${Trace.recording ? "recording" : "stopped"}, ${Trace.done.length} spans kept, ${Trace.liveCount} waiting for frames`;
    }

    function pending(): string {
        return String(Trace.liveCount);
    }

    function take(): string {
        return Trace.take();
    }

    function watch(name: string, ms: string): string {
        const span = Trace.begin(name, "", Number(ms) || 2000, Number(ms) || 2000);
        return span ? "watching" : "not recording";
    }

    function clear(): string {
        Trace.done = [];
        return "cleared";
    }
}
