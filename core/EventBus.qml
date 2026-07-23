import QtQuick

QtObject {
    // Single, auditable event surface. Theme scripts subscribe through `onEvent`.
    signal event(string name, var payload)
    readonly property var supportedEvents: [
        "SceneLoaded", "BeforeIdle", "AfterIdle", "BeforeEnterLogin",
        "AfterEnterLogin", "BeforeLoginAttempt", "AfterLoginAttempt",
        "LoginSuccess", "LoginFailure", "AuthenticationStarted",
        "AuthenticationFinished", "SceneUnload", "ThemeLoaded",
        "ThemeUnloaded", "MouseMove", "MouseClick", "KeyboardInput",
        "UsernameFocused", "PasswordFocused", "FieldChanged",
        "EnterPressed", "EscapePressed", "WebSceneEvent"
    ]

    function emit(name, payload) {
        if (supportedEvents.indexOf(name) < 0) {
            console.warn("Theme attempted to emit unknown event:", name)
            return false
        }
        event(name, payload || {})
        return true
    }
}
