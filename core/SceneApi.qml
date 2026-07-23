import QtQuick
import QtQuick3D

QtObject {
    id: api
    required property var animationController
    required property var sceneRoot
    required property var view
    required property var transition
    required property var pluginRegistry
    property var cameras: ({})
    property var objects: ({})
    property var sounds: ({})

    // This is the complete capability boundary available to theme scripts.
    function playAnimation(name, loops) { return animationController.play(name, loops) }
    function registerAnimation(name, player) { return animationController.registerPlayer(name, player) }
    function stopAnimation(name) { return animationController.stop(name) }
    function changeCamera(name) {
        if (!cameras[name]) return false
        view.camera = cameras[name]
        return true
    }
    function setLight(name, values) { return setProperties(name, values, ["brightness", "color", "visible", "eulerRotation"]) }
    function changeMaterial(name, values) { return setProperties(name, values, ["baseColor", "roughness", "metalness", "opacity"]) }
    function setObject(name, values) { return setProperties(name, values, ["position", "scale", "eulerRotation", "visible", "opacity"]) }
    function spawnParticles(name, enabled) { return setProperties(name, {"visible": enabled !== false}, ["visible"]) }
    function playSound(name) { if (sounds[name]) { sounds[name].play(); return true } return false }
    function changeEnvironment(values) {
        if (!view.environment) return false
        return assignAllowed(view.environment, values, ["backgroundMode", "clearColor", "probeExposure", "tonemapMode"])
    }
    function shakeCamera(intensity, duration) {
        return pluginRegistry.create("camera", "shake", { camera: view.camera, intensity: intensity, duration: duration }) !== null
    }
    function setFog(values) { return pluginRegistry.create("effect", "fog", values) !== null }
    function setExposure(value) { if (!view.environment) return false; view.environment.probeExposure = value; return true }
    function fade(opacity, duration) { transition.fade(opacity, duration); return true }
    function runAction(name, options) { return pluginRegistry.create("action", name, options) }

    function setProperties(name, values, allowlist) {
        var target = objects[name]
        return target ? assignAllowed(target, values, allowlist) : false
    }
    function assignAllowed(target, values, allowlist) {
        if (!values || typeof values !== "object") return false
        for (var key in values)
            if (allowlist.indexOf(key) >= 0) target[key] = values[key]
        return true
    }
}
