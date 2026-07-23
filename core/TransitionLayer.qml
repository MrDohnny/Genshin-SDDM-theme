import QtQuick

Rectangle {
    id: root
    color: "black"
    opacity: 0
    visible: opacity > 0
    z: 1000

    Behavior on opacity { NumberAnimation { duration: root.duration } }
    property int duration: 300
    function fade(to, milliseconds) {
        duration = Math.max(0, milliseconds || 300)
        opacity = Math.max(0, Math.min(1, to))
    }
}

