import QtQuick
import QtWebSockets

WebSocket {
    id: root

    signal dropped

    active: false

    onStatusChanged: if (root.status === WebSocket.Closed || root.status === WebSocket.Error)
        root.dropped()
}
