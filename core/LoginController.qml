import QtQuick

QtObject {
    id: root
    required property var adapter
    required property var eventBus
    required property var animations
    property bool authenticating: false
    property int authenticationTimeout: 30000
    property string pendingUsername: ""
    property string pendingPassword: ""
    property int pendingSessionIndex: 0
    signal error(string message)

    function login(username, password, sessionIndex) {
        if (authenticating) return
        authenticating = true
        pendingUsername = String(username)
        pendingPassword = String(password)
        pendingSessionIndex = sessionIndex
        eventBus.emit("BeforeLoginAttempt", { username: username, session: sessionIndex })
        eventBus.emit("AuthenticationStarted")
        animations.play("AuthenticationProcessing")
    }
    function startRealAuthentication(name) {
        if (!authenticating || name !== "AuthenticationProcessing") return
        authenticationGuard.restart()
        adapter.login(pendingUsername, pendingPassword, pendingSessionIndex)
        pendingPassword = ""
    }
    function handleResult(success) {
        if (!authenticating) return
        authenticationGuard.stop()
        authenticating = false
        eventBus.emit("AuthenticationFinished", { success: success })
        eventBus.emit("AfterLoginAttempt", { success: success })
        if (success) {
            animations.activePanelIdle()
            eventBus.emit("LoginSuccess")
        } else {
            eventBus.emit("LoginFailure")
            animations.play("LoginFailed")
            error(qsTr("Authentication failed"))
        }
    }
    function handleAdapterError(message) {
        if (!authenticating) return
        authenticating = false
        authenticationGuard.stop()
        eventBus.emit("AuthenticationFinished", { success: false })
        eventBus.emit("AfterLoginAttempt", { success: false })
        eventBus.emit("LoginFailure")
        animations.play("LoginFailed")
        error(message)
    }
    property Timer authenticationGuard: Timer {
        interval: root.authenticationTimeout
        onTriggered: {
            if (!root.authenticating) return
            root.authenticating = false
            root.eventBus.emit("AuthenticationFinished", { success: false })
            root.eventBus.emit("AfterLoginAttempt", { success: false })
            root.eventBus.emit("LoginFailure")
            root.animations.play("LoginFailed")
            root.error(qsTr("The login service did not respond. Please try again."))
        }
    }
    Component.onCompleted: {
        adapter.loginResult.connect(handleResult)
        animations.finished.connect(startRealAuthentication)
        if (adapter.loginError)
            adapter.loginError.connect(handleAdapterError)
    }
}
