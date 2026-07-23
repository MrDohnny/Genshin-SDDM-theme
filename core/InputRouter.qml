import QtQuick

Item {
    required property var eventBus
    required property var animations
    property bool panelActivationRequired: false
    signal panelActivationRequested()
    focus: true
    TapHandler {
        onTapped: function(eventPoint) {
            eventBus.emit("MouseClick", { x: eventPoint.position.x, y: eventPoint.position.y })
            if (panelActivationRequired) panelActivationRequested()
        }
    }
    HoverHandler { onPointChanged: eventBus.emit("MouseMove", { x: point.position.x, y: point.position.y }) }
    Keys.onPressed: function(event) {
        eventBus.emit("KeyboardInput", { key: event.key, text: event.text })
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) eventBus.emit("EnterPressed")
        if (event.key === Qt.Key_Escape) eventBus.emit("EscapePressed")
    }
}
