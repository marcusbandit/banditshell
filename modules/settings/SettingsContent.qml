pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "catalogue.js" as Catalogue

Item {
    id: root

    property bool compact: false

    signal detailsWanted

    readonly property var s: SettingsState

    Flickable {
        id: view

        anchors.fill: parent
        contentHeight: body.implicitHeight + Appearance.padding.large
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        onContentYChanged: SettingsView.scroll = view.contentY
        onMovementStarted: SettingsView.resumeScroll = 0
        onContentHeightChanged: root.resume()
        onHeightChanged: root.resume()

        WheelStep {
            id: wheel

            flick: view
        }

        Column {
            id: body

            width: view.width

            opacity: SettingsView.reduceMotion ? 1 : 1 - arrive.value
            transform: Translate {
                y: SettingsView.reduceMotion ? 0 : arrive.value * 8
            }

            Connections {
                target: SettingsView

                function onTurnChanged(): void {
                    wheel.stop();
                    view.contentY = 0;
                    arrive.value = 1;
                }

                function onFlashChanged(): void {
                    if (SettingsView.flash)
                        Qt.callLater(root.reveal, SettingsView.flash.uid);
                }
            }

            Follow {
                id: arrive

                target: 0
                speed: Appearance.animation.revealSpeed
                epsilon: 0.005
            }

            Item {
                id: head

                width: parent.width
                height: Math.max(back.visible ? back.height + 4 : 0, words.implicitHeight) + 2 + Appearance.padding.card

                SettingsTool {
                    id: back

                    x: Appearance.padding.normal - Appearance.padding.small
                    y: 2 + 4
                    visible: !SettingsView.hub
                    icon: "arrow_back"
                    tip: SettingsView.cat?.name.toLowerCase() ?? ""
                    onClicked: SettingsView.go(SettingsView.cat.id)
                }

                Column {
                    id: words

                    x: back.visible ? back.x + back.width + Appearance.padding.normal : Appearance.padding.normal
                    y: 2
                    width: parent.width - x - Appearance.padding.normal - (details.visible ? details.width + Appearance.padding.normal : 0)

                    StyledText {
                        width: parent.width
                        text: SettingsView.title
                        font.pixelSize: Appearance.font.size.normal
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: SettingsView.hub ? String(SettingsView.cat.blurb(root.s) ?? "") : String(SettingsView.page?.status(root.s) ?? "")
                        color: Appearance.colour.textFaint
                        elide: Text.ElideRight
                    }
                }

                SettingsTool {
                    id: details

                    x: parent.width - width - Appearance.padding.normal
                    y: 2
                    visible: root.compact
                    icon: "info"
                    tip: "details"
                    onClicked: root.detailsWanted()
                }
            }

            Item {
                id: folded

                readonly property bool wanted: SettingsView.fold && !SettingsView.hub && SettingsView.current === "screens"
                readonly property real full: SettingsView.foldHeight + Appearance.padding.card

                width: parent.width
                height: Math.round(folded.full * drop.value)
                visible: height > 0.5
                clip: true

                Follow {
                    id: drop

                    target: folded.wanted ? 1 : 0
                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.002
                }

                Item {
                    y: Appearance.padding.card + folded.height - folded.full
                    width: parent.width
                    height: SettingsView.foldHeight

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: Appearance.colour.fill
                    }

                    Loader {
                        anchors.fill: parent
                        active: folded.wanted || drop.value > 0.002
                        sourceComponent: ScreenCanvas {
                            editable: true
                        }
                    }
                }
            }

            Loader {
                width: parent.width
                active: SettingsView.hub
                visible: active
                sourceComponent: SettingsHub {}
            }

            Repeater {
                model: SettingsView.hub ? [] : (SettingsView.page?.groups ?? []).filter(g => Catalogue.present(g, root.s))

                delegate: Column {
                    id: group

                    required property var modelData
                    required property int index

                    readonly property string heading: String(Catalogue.val(group.modelData.t, root.s) ?? "")

                    width: body.width
                    topPadding: Appearance.padding.card

                    StyledText {
                        x: Appearance.padding.normal
                        visible: group.heading !== ""
                        text: group.heading.toUpperCase()
                        color: Appearance.colour.textDim
                    }

                    Item {
                        width: parent.width
                        height: Appearance.padding.normal + 1 + Appearance.padding.small
                        visible: group.heading !== ""

                        Rectangle {
                            y: Appearance.padding.normal
                            width: parent.width
                            height: 1
                            color: Appearance.colour.separator
                        }
                    }

                    Repeater {
                        model: group.modelData.rows

                        delegate: SettingsCell {
                            required property var modelData

                            width: body.width
                            row: modelData
                        }
                    }
                }
            }
        }
    }

    function resume(): void {
        const want = SettingsView.resumeScroll;
        if (want <= 0)
            return;
        const reach = Math.max(0, view.contentHeight - view.height);
        view.contentY = Math.min(want, reach);
        if (reach >= want)
            SettingsView.resumeScroll = 0;
    }

    Component.onCompleted: Qt.callLater(root.resume)

    function reveal(uid: string): void {
        const target = root.findRow(body, uid);
        if (!target)
            return;
        const at = target.mapToItem(body, 0, 0).y;
        const want = Math.max(0, Math.min(view.contentHeight - view.height, at - view.height / 3));
        if (SettingsView.reduceMotion) {
            wheel.stop();
            view.contentY = want;
        }
        else
            wheel.scrollTo(want);
    }

    function findRow(item: Item, uid: string): Item {
        if (!item)
            return null;
        if (item.row && item.row.uid === uid)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const hit = root.findRow(item.children[i], uid);
            if (hit)
                return hit;
        }
        return null;
    }
}
