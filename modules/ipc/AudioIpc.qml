pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    function roleLine(role: string): string {
        const node = Audio.roleNode(role);
        return node ? `${role} (${Audio.deviceLabel(node)})` : role;
    }

    function goRole(role: string): string {
        const landed = Audio.setOutputRole(role);
        return landed ? root.roleLine(landed) : `cannot switch to ${role}: ${Audio.roleProblem(role)}`;
    }

    IpcHandler {
        target: "output"

        function toggle(): string {
            const landed = Audio.toggleOutput();
            if (landed)
                return root.roleLine(landed);
            if (Audio.rolesCollide)
                return "speakers and headphones name the same device, so there is nowhere to toggle to";

            if (Audio.outputRole) {
                const other = Audio.outputRole === "speakers" ? "headphones" : "speakers";
                return `cannot switch to ${other}: ${Audio.roleProblem(other)}`;
            }
            return `cannot switch: speakers ${Audio.roleProblem("speakers")}; headphones ${Audio.roleProblem("headphones")}`;
        }

        function speakers(): string {
            return root.goRole("speakers");
        }

        function headphones(): string {
            return root.goRole("headphones");
        }

        function status(): string {
            const say = role => {
                const name = Audio.roleName(role);
                if (!name)
                    return "not assigned";
                const node = Audio.roleNode(role);
                return node ? `${Audio.deviceLabel(node)} · ${name}` : `${name} · not connected`;
            };

            const on = Audio.outputRole || (Audio.sink ? `neither, playing through ${Audio.deviceLabel(Audio.sink)}` : "no output device");
            const lines = [`playing     ${on}`, `speakers    ${say("speakers")}`, `headphones  ${say("headphones")}`];
            if (Audio.rolesCollide)
                lines.push("both roles name one device, so the toggle cannot move the sound");
            return lines.join("\n");
        }

        function list(): string {
            if (!Audio.sinks.length)
                return "no output devices";
            return Audio.sinks.map(n => {
                const marks = [n.name === Audio.sink?.name ? "playing" : "", n.name === Audio.speakersName ? "speakers" : "", n.name === Audio.headphonesName ? "headphones" : ""].filter(m => m);
                return `${n.name}  ${Audio.deviceLabel(n)}${marks.length ? ` [${marks.join(", ")}]` : ""}`;
            }).join("\n");
        }

        function assign(role: string, name: string): string {
            if (role !== "speakers" && role !== "headphones")
                return `assign takes speakers or headphones, not: ${role}`;
            Config.set(`audio.${role}`, name);
            if (!name)
                return `${role} unassigned`;
            const node = Audio.sinkByName(name);
            return node ? `${role} = ${Audio.deviceLabel(node)} (${name})` : `${role} = ${name}, which is not a sink that is here right now`;
        }
    }
}
