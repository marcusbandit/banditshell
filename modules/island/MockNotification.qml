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
    property bool hasInlineReply: false
    property string inlineReplyPlaceholder: ""
    property var replies: []

    signal closed

    function sendInlineReply(text: string): void {
        root.replies = [...root.replies, text];
    }

    function dismiss(): void {
        root.closed();
        root.destroy();
    }

    function expire(): void {
        root.closed();
    }
}
