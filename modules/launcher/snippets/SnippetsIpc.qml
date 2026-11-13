import Quickshell.Io
import qs.services

IpcHandler {
    target: "snippets"

    function expand(): string {
        return SnippetExpander.expand();
    }
}
