import QtQuick

MouseArea {
    id: root

    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    hoverEnabled: true

    onWheel: wheel => {
        let page = root.parent;
        while (page && typeof page.scrollByWheel !== "function")
            page = page.parent;
        if (page && page.interactive && page.canScrollVertically)
            page.scrollByWheel(wheel);
        wheel.accepted = true;
    }
}
