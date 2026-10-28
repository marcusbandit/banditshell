pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/weather.js" as Forecast

Item {
    id: root

    property bool active: false
    property string query: ""
    property string saved: ""
    property string uid: ""
    property int current: 0

    signal picked(string text)

    readonly property bool asking: root.active && root.query !== root.saved && Forecast.placeName(root.query).length >= 3
    readonly property var shown: root.asking ? Weather.places : []
    readonly property bool fresh: Weather.placesFor === root.query && !Weather.findingPlaces
    readonly property bool answered: root.asking && root.fresh
    readonly property string chosen: root.fresh && root.current >= 0 && root.current < root.shown.length ? root.shown[root.current].text : ""
    readonly property string note: !root.answered || root.shown.length ? "" : Weather.placesFailed ? "Place suggestions need a connection" : "No town by that name"

    readonly property bool wanted: root.shown.length > 0 || root.note !== ""

    visible: root.wanted
    implicitHeight: list.implicitHeight

    onWantedChanged: SettingsView.lift(root.uid, root.wanted)
    Component.onDestruction: {
        SettingsView.lift(root.uid, false);
        if (root.asking)
            Weather.stopLooking();
    }

    function step(by: int): void {
        const count = root.shown.length;
        if (count)
            root.current = root.current + by < -1 ? count - 1 : root.current + by >= count ? -1 : root.current + by;
    }

    function ask(): void {
        root.current = 0;
        if (root.asking)
            Weather.lookUp(root.query);
        else if (Weather.placeQuery !== "")
            Weather.stopLooking();
    }

    onQueryChanged: root.ask()
    onAskingChanged: root.ask()

    SquircleRect {
        width: root.width
        height: list.implicitHeight
        radius: Appearance.rounding.normal
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: 1
    }

    Column {
        id: list

        width: root.width
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.small

        StyledText {
            x: Appearance.padding.normal
            visible: root.note !== ""
            text: root.note
            color: Appearance.colour.textFaint
        }

        Repeater {
            model: root.shown

            delegate: Item {
                id: place

                required property var modelData
                required property int index

                readonly property bool chosen: place.index === root.current

                width: list.width
                height: Appearance.sizes.rowHeight
                opacity: root.fresh ? 1 : 0.5

                SquircleRect {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.small
                    anchors.rightMargin: Appearance.padding.small
                    radius: Appearance.rounding.small
                    color: place.chosen ? Appearance.colour.fillStrong : hover.hovered ? Appearance.colour.fill : "transparent"
                }

                Row {
                    x: Appearance.padding.normal
                    width: parent.width - Appearance.padding.normal * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.padding.normal

                    Icon {
                        id: pin

                        anchors.verticalCenter: parent.verticalCenter
                        name: "location_on"
                        fill: place.chosen ? 1 : 0
                        color: place.chosen ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    StyledText {
                        id: town

                        anchors.verticalCenter: parent.verticalCenter
                        text: place.modelData.name
                        color: Appearance.colour.text
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - pin.width - town.width - parent.spacing * 2)
                        text: [place.modelData.region, place.modelData.country].filter(Boolean).join(", ")
                        color: Appearance.colour.textFaint
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.fresh ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (root.fresh)
                        root.picked(place.modelData.text)
                }
            }
        }
    }
}
