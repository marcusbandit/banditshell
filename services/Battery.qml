pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// UPower, adapted.
//
// `available` is the first thing anything should ask. On a desktop there is no
// battery, and UPower still hands over a display device that reads 0% and
// "unknown"; a widget that trusts it shows a flat battery on a machine that has
// none. Everything below is only meaningful when `available` is true.
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice

    readonly property bool available: !!device?.isLaptopBattery
    readonly property real percentage: device?.percentage ?? 0
    readonly property bool charging: {
        const s = device?.state;
        return s === UPowerDeviceState.Charging || s === UPowerDeviceState.FullyCharged || s === UPowerDeviceState.PendingCharge;
    }
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery

    // Watts. Negative while discharging in some drivers, so take the magnitude
    // and let `charging` say the direction.
    readonly property real rate: Math.abs(device?.changeRate ?? 0)
    readonly property real health: device?.healthPercentage ?? 0

    // Seconds until the interesting end, whichever that is. UPower reports 0
    // when it does not know yet, which is common for the first minute after a
    // plug or unplug.
    readonly property int secondsLeft: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)
    readonly property bool estimating: available && secondsLeft <= 0 && !full

    // Below this, the shell is allowed to shout about it.
    readonly property real lowThreshold: 0.2
    readonly property bool low: available && onBattery && percentage <= lowThreshold

    readonly property string state: !available ? "no battery" : full ? "full" : charging ? "charging" : onBattery ? "on battery" : "plugged in"

    function timeLabel(): string {
        if (!available || full)
            return "";
        if (estimating)
            return "estimating";
        const mins = Math.round(secondsLeft / 60);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        const left = h > 0 ? `${h}h ${m}m` : `${m}m`;
        return charging ? `${left} to full` : `${left} left`;
    }

    // Material Symbols has a clean 0..6 bar ramp for a discharging battery and a
    // RAGGED set for a charging one: 20, 30, 50, 60, 80, 90 exist, 40, 70 and
    // 100 do not. Snapping to the nearest name that is really in the font is why
    // this is a lookup and not arithmetic; computing the name gave
    // `battery_charging_70`, which the font renders as the WORDS, in a menu.
    readonly property var chargingSteps: [20, 30, 50, 60, 80, 90]

    function icon(): string {
        if (!available)
            return "power";
        if (percentage >= 1)
            return charging ? "battery_charging_full" : "battery_full";
        // Clamped to 6: the font has battery_0_bar through battery_6_bar, and
        // floor(percentage * 7) reaches 7 at exactly 100%. That is unreachable
        // only because the line above catches it first, which is the kind of
        // safety that stops being safe the moment someone edits the guard.
        if (!charging)
            return `battery_${Math.min(6, Math.floor(percentage * 7))}_bar`;

        const want = percentage * 100;
        const step = root.chargingSteps.reduce((best, s) => Math.abs(s - want) < Math.abs(best - want) ? s : best);
        return `battery_charging_${step}`;
    }
}
