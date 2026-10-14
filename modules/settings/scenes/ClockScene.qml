import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

SceneGauge {
    id: root

    property double now: Date.now()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    function shown(t: var): string {
        if (SettingsState.v("clock24"))
            return t.text;
        const h = t.hour % 12 || 12;
        return `${h}:${Clock.twoDigits(t.minute)} ${t.hour < 12 ? "am" : "pm"}`;
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.shown(Clock.zoneTime(Clock.localOffset, root.now))
        font.pixelSize: Appearance.font.size.large
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: Clock.places.slice(0, 3).map(z => `${Clock.cityOf(z).toLowerCase()} ${root.shown(Clock.zoneTime(Clock.offsetMap[z] ?? Clock.localOffset, root.now))}`).join(" · ")
        color: Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }
}
