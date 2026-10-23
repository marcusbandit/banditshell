pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string armed: ""

    readonly property string notice: Obs.phase === "missing" ? "Reaching OBS needs qt6-websockets: bash install.sh adds it" : Obs.phase === "closed" ? "OBS is not running" : Obs.phase === "unset" ? "OBS's WebSocket server is off: Tools → WebSocket Server Settings" : Obs.phase === "refused" ? "OBS did not accept its WebSocket password" : "Reaching OBS"

    function arm(want: string): void {
        root.armed = want;
        disarm.restart();
    }

    function pressLive(): void {
        const want = Obs.live ? "stop" : "start";
        if (root.armed !== want) {
            root.arm(want);
            return;
        }
        root.armed = "";
        disarm.stop();
        if (want === "start")
            Obs.startStream();
        else
            Obs.stopStream();
    }

    implicitHeight: Obs.phase === "ready" ? deck.implicitHeight : waitingRow.implicitHeight

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    Column {
        id: deck

        width: parent.width
        spacing: Appearance.padding.small
        visible: Obs.phase === "ready"

        Item {
            width: parent.width
            height: Math.max(broadcast.height, sceneRow.height)

            Row {
                id: broadcast

                spacing: Appearance.padding.small

                Button {
                    icon: "sensors"
                    text: root.armed === "start" ? "Go live?" : root.armed === "stop" ? "End stream?" : Obs.reconnecting ? "Reconnecting" : Obs.live ? `LIVE ${Obs.liveClock}` : Obs.streamState === "starting" ? "Starting" : Obs.streamState === "stopping" ? "Ending" : "Go live"
                    paint: Obs.live || root.armed !== "" ? Appearance.colour.alarm : undefined

                    onClicked: root.pressLive()
                }

                Button {
                    icon: Obs.recordPaused ? "pause_circle" : "radio_button_checked"
                    text: Obs.recordPaused ? `Paused ${Obs.recordClock}` : Obs.recording ? `REC ${Obs.recordClock}` : "Record"
                    paint: Obs.recording ? Appearance.colour.alarm : undefined

                    onClicked: Obs.toggleRecord()
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Obs.live
                    leftPadding: Appearance.padding.normal
                    text: Obs.healthLabel
                    color: Obs.struggling ? Appearance.colour.alarm : Appearance.colour.textFaint
                }
            }

            Row {
                id: sceneRow

                anchors.right: parent.right
                spacing: Appearance.padding.small

                Repeater {
                    model: Obs.scenes

                    delegate: Button {
                        required property string modelData

                        text: modelData
                        checkable: true
                        checked: modelData === Obs.scene

                        onToggled: Obs.showScene(modelData)
                    }
                }
            }
        }

        Row {
            spacing: Appearance.padding.small

            Button {
                visible: Obs.cameras.length > 0
                checkable: true
                checked: Obs.cameraShown
                icon: Obs.cameraShown ? "videocam" : "videocam_off"
                text: "Camera"

                onToggled: Obs.setShown("camera", !Obs.cameraShown)
            }

            Button {
                visible: Obs.captures.length > 0
                checkable: true
                checked: Obs.screenShown
                icon: Obs.screenShown ? "screen_share" : "stop_screen_share"
                text: Obs.screenShown ? "Screen" : "Screen hidden"
                paint: Obs.screenShown ? undefined : Appearance.colour.alarm

                onToggled: Obs.setShown("screen", !Obs.screenShown)
            }

            Button {
                visible: Obs.mics.length > 0
                checkable: true
                checked: !Obs.micMuted
                icon: Obs.micMuted ? "mic_off" : "mic"
                text: "Mic"
                paint: Obs.micMuted ? Appearance.colour.alarm : undefined

                onToggled: Obs.setMuted("mic", !Obs.micMuted)
            }

            Button {
                visible: Obs.desktops.length > 0
                checkable: true
                checked: !Obs.desktopMuted
                icon: Obs.desktopMuted ? "volume_off" : "volume_up"
                text: "Desktop audio"

                onToggled: Obs.setMuted("desktop", !Obs.desktopMuted)
            }
        }
    }

    Row {
        id: waitingRow

        visible: Obs.phase !== "ready"
        height: Appearance.button.height(1)
        spacing: Appearance.padding.normal

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "sensors_off"
            color: Appearance.colour.textFaint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.notice
            color: Appearance.colour.textDim
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: Obs.phase === "closed" && Obs.installed
            icon: "open_in_new"
            text: "Open OBS"

            onClicked: Obs.launch()
        }
    }
}
