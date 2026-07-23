import QtQuick

QtObject {
    // Declarative plugins are capabilities, never native libraries loaded by a theme.
    property var factories: ({})
    readonly property var allowedTypes: ["effect", "particles", "shader", "transition", "camera", "action"]

    function register(type, name, factory) {
        if (allowedTypes.indexOf(type) < 0 || !name || typeof factory !== "function")
            return false
        var copy = Object.assign({}, factories)
        copy[type + ":" + name] = factory
        factories = copy
        return true
    }

    function create(type, name, options) {
        var factory = factories[type + ":" + name]
        return factory ? factory(options || {}) : null
    }
}

