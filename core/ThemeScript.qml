import QtQuick

QtObject {
    // Base class: scripts receive capabilities, not engine/global OS objects.
    required property var scene
    required property var events
    property bool enabled: true
    function onThemeEvent(name, payload) {}
    property Connections eventConnection: Connections {
        target: events
        function onEvent(name, payload) { if (enabled) onThemeEvent(name, payload) }
    }
}
