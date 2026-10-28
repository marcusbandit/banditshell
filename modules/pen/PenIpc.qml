pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.services

Scope {
    id: root

    property alias handler: served

    function penmapStatus(): string {
        const r = PenMap.region;
        const lock = PenMap.aspectLocked ? "locked" : "free";
        const pad = PenMap.padConnected ? "pad" : "no pad";
        const mode = PenMap.followWindow ? ", follow" : "";
        return `${Math.round(r.width)}x${Math.round(r.height)} at ${Math.round(r.x)},${Math.round(r.y)} on ${PenMap.monitorName || "no monitor"} (${lock}, ${pad}${mode})`;
    }

    IpcHandler {
        id: served

        target: "penmap"

        function open(): string {
            PenMap.begin();
            return "open";
        }

        function commit(): string {
            PenMap.commit();
            return "committed";
        }

        function cancel(): string {
            PenMap.cancel();
            return "cancelled";
        }

        function aspect(): string {
            PenMap.toggleAspect();
            return PenMap.aspectLocked ? "locked" : "free";
        }

        function centre(): string {
            PenMap.fitAndCentre();
            return root.penmapStatus();
        }

        function follow(): string {
            PenMap.toggleFollowWindow();
            return PenMap.followWindow ? "following" : "off";
        }

        function set(x: string, y: string, w: string, h: string): string {
            const nums = [x, y, w, h].map(Number);
            if (nums.some(isNaN))
                return "four numbers: x y w h";
            PenMap.proposeRegion(nums[0], nums[1], nums[2], nums[3]);
            PenMap.commit();
            return root.penmapStatus();
        }

        function status(): string {
            return root.penmapStatus();
        }
    }
}
