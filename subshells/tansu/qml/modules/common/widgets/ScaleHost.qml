import QtQuick

Item {
    id: host

    property real factor: 1
    default property alias content: inner.data

    readonly property real f: Math.max(0.1, host.factor)

    Item {
        id: inner
        width: host.width / host.f
        height: host.height / host.f
        scale: host.f
        transformOrigin: Item.TopLeft
    }
}
