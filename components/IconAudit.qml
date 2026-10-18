pragma Singleton

import QtQuick
import qs.config

Item {
    id: root

    property var pending: []

    function watch(icon: var): void {
        if (!root.pending.includes(icon))
            root.pending.push(icon);
        timer.restart();
    }

    Timer {
        id: timer

        interval: Appearance.animation.wait.slow

        onTriggered: {
            const icons = root.pending;
            root.pending = [];
            for (const icon of icons)
                if (icon && icon.lost)
                    console.warn(`Icon: "${icon.name}" is not in ${Appearance.font.icon}; drawing ${icon.fallback} instead.`);
        }
    }
}
