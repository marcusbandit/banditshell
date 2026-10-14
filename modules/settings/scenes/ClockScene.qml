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

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Clock.zoneTime(Clock.localOffset, root.now).text
        font.pixelSize: Appearance.font.size.large
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: Clock.places.slice(0, 3).map(z => `${Clock.cityOf(z).toLowerCase()} ${Clock.zoneTime(Clock.offsetMap[z] ?? Clock.localOffset, root.now).text}`).join(" · ")
        color: Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }
}
