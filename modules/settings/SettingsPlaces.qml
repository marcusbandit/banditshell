pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/weather.js" as Forecast

Column {
    id: root

    property bool active: false
    property string query: ""
    property string saved: ""
    property real indent: 0
    property int current: -1

    signal picked(string text)

    readonly property bool asking: root.active && root.query !== root.saved && Forecast.placeName(root.query).length >= 3
    readonly property var shown: root.asking ? Weather.places : []
    readonly property bool fresh: Weather.placesFor === root.query && !Weather.findingPlaces
    readonly property bool answered: root.asking && root.fresh
    readonly property string chosen: root.fresh && root.current >= 0 && root.current < root.shown.length ? root.shown[root.current].text : ""
    readonly property string note: !root.answered || root.shown.length ? "" : Weather.placesFailed ? "Place suggestions need a connection" : "No town by that name"

    readonly property bool wanted: root.shown.length > 0 || root.note !== ""

    visible: root.wanted
    leftPadding: root.indent
    bottomPadding: Appearance.padding.small

    function step(by: int): void {
        const count = root.shown.length;
        if (count)
            root.current = root.current + by < -1 ? count - 1 : root.current + by >= count ? -1 : root.current + by;
    }

    function ask(): void {
        root.current = -1;
        if (root.asking)
            Weather.lookUp(root.query);
        else if (Weather.placeQuery !== "")
            Weather.stopLooking();
    }

    onQueryChanged: root.ask()
    onAskingChanged: root.ask()
    Component.onDestruction: if (root.asking)
        Weather.stopLooking()

    StyledText {
        x: Appearance.padding.normal
        visible: root.note !== ""
        text: root.note
        color: Appearance.colour.textFaint
    }

    Repeater {
        model: root.shown

        delegate: SettingsRowFrame {
            id: place

            required property var modelData
            required property int index

            width: root.width - root.indent
            icon: "location_on"
            label: place.modelData.name
            detail: [place.modelData.region, place.modelData.country].filter(Boolean).join(", ")
            selected: place.index === root.current
            off: !root.fresh
            onActivated: if (root.fresh)
                root.picked(place.modelData.text)
        }
    }
}
