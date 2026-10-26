pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    property double now: Date.now()

    width: parent ? parent.width : 0

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    function offsetOf(id: string): int {
        return Clock.offsetMap[id] ?? Clock.localOffset;
    }

    Repeater {
        model: Clock.places

        delegate: SettingsRowFrame {
            id: place

            required property string modelData

            readonly property int diff: Math.round((root.offsetOf(place.modelData) - Clock.localOffset) / 60)

            width: root.width
            interactive: false
            label: Clock.cityOf(place.modelData).toLowerCase()
            detail: place.diff ? `${Math.abs(place.diff)} h ${place.diff > 0 ? "ahead" : "behind"}` : "same as here"
            onPointed: SettingsView.hovered = root.row
            lead: Component {
                StyledText {
                    width: Math.max(76, implicitWidth)
                    text: Clock.zoneTime(root.offsetOf(place.modelData), root.now).text
                }
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                tip: "take it off"
                onClicked: Clock.removeZone(place.modelData)
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "add_location"
        label: "Add a time zone"
        onPointed: SettingsView.hovered = root.row

        SettingsField {
            id: zone

            anchors.verticalCenter: parent.verticalCenter
            placeholder: "Europe/Oslo"
            onCommitted: t => {
                const id = t.trim();
                if (!id)
                    return;
                if (!Clock.validZone(id))
                    return SettingsView.drop(`${id} is not a time zone`, "error");
                Clock.addZone(id);
                zone.clear();
            }
        }
    }
}
