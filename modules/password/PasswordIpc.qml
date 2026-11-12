import Quickshell
import Quickshell.Io
import qs.services

Scope {
    id: root

    readonly property string scenes: [...Object.keys(Keyring.scenes), ...Object.keys(Polkit.scenes), "wifi"].join(", ")

    IpcHandler {
        target: "keyring"

        function status(): string {
            return [`prompter   ${Keyring.serving ? "the shell" : Keyring.blocked ? `${Keyring.owner || "another program"} (the shell was refused the bus name)` : "not running"}`, `asking     ${Keyring.active}`, `requester  ${Keyring.requester || "-"}`, `kind       ${Keyring.kind || "-"}`, `title      ${Keyring.title || "-"}`, `message    ${Keyring.message || "-"}`, `warning    ${Keyring.warning || "-"}`, `choice     ${Keyring.choiceLabel ? `${Keyring.choiceChosen ? "yes" : "no"}: ${Keyring.choiceLabel}` : "-"}`, `screen     ${Keyring.screenName || "-"}`].join("\n");
        }

        function refuse(): string {
            if (!Keyring.active)
                return "nothing is being asked";
            Keyring.refuse();
            return "refused";
        }

        function demo(): string {
            Keyring.demo();
            return "showing a made-up question; escape or `banditshell dev keyring close` puts it away";
        }
    }

    IpcHandler {
        target: "polkit"

        function status(): string {
            return [`agent      ${Polkit.serving ? "the shell" : Polkit.wanted ? "another program (the shell could not register)" : "another program (polkit.agent is off)"}`, `stopped    ${Polkit.stopped.map(g => g.what.split("/").pop()).join(", ") || "-"}`, `asking     ${Polkit.active}`, `title      ${Polkit.active ? Polkit.title : "-"}`, `message    ${Polkit.message || "-"}`, `warning    ${Polkit.warning || "-"}`, `screen     ${Polkit.screenName || "-"}`].join("\n");
        }

        function refuse(): string {
            if (!Polkit.active)
                return "nothing is being asked";
            Polkit.refuse();
            return "refused";
        }

        function demo(): string {
            Polkit.demo();
            return "showing a made-up question; escape puts it away";
        }
    }

    IpcHandler {
        target: "password"

        function scene(name: string): string {
            if (Keyring.scene(name) || Polkit.scene(name) || PasswordRequest.scene(name))
                return `showing the made-up ${name} card; escape puts it away`;
            return `no scene called ${name}; try ${root.scenes}`;
        }
    }
}
