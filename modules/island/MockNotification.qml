import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    property string appName: ""
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string desktopEntry: ""
    property string image: ""
    property int urgency: NotificationUrgency.Normal
    property var actions: []
    property var hints: ({})

    signal closed

    function dismiss(): void {
        root.closed();
        root.destroy();
    }

    function expire(): void {
        root.closed();
    }
}
