import QtQuick

QtObject {
    id: root
    required property var sddmObject
    // Named differently than the "sessionModel"/"userModel" context
    // properties they're bound from (see sddm/Main.qml) on purpose: a
    // property assignment like "sessionModel: sessionModel" would have the
    // right-hand side resolve to *this object's own* sessionModel property
    // (QML looks at the object's own properties before the outer context),
    // silently binding it to itself instead of SDDM's real context property
    // — which is exactly the bug that left adapter.sessions/adapter.users
    // undefined on the real greeter while working fine in the desktop
    // preview (whose mock adapter never had this name collision at all).
    required property var sessionModelSource
    required property var userModelSource
    required property var keyboardModel
    property var sessions: sessionModelSource
    // SDDM's own greeter object exposes these as real capability checks
    // (systemd-logind under the hood) — e.g. hibernate is unavailable on
    // machines with no resume-configured swap, in which case the button
    // for it should not be shown at all rather than silently doing nothing.
    property bool canPowerOff: sddmObject.canPowerOff !== undefined ? sddmObject.canPowerOff : true
    property bool canReboot: sddmObject.canReboot !== undefined ? sddmObject.canReboot : true
    property bool canSuspend: sddmObject.canSuspend !== undefined ? sddmObject.canSuspend : true
    property bool canHibernate: sddmObject.canHibernate !== undefined ? sddmObject.canHibernate : true
    property bool canHybridSleep: sddmObject.canHybridSleep !== undefined ? sddmObject.canHybridSleep : false
    property string hostName: sddmObject.hostName !== undefined ? sddmObject.hostName : ""
    // The real system's own last-logged-in user and full user list (SDDM's
    // UserModel, the same kind of QAbstractListModel as sessionModel) —
    // themes should prefer this over any theme-configured placeholder
    // username, and can offer a real account picker when there's more than
    // one system user instead of asking for free-text entry.
    property var users: userModelSource
    property string lastUsername: userModelSource && userModelSource.lastUser !== undefined ? userModelSource.lastUser : ""
    // KeyboardModel exposes plain, directly bindable Q_PROPERTYs (not a list
    // model), so themes can read/bind root.adapter.keyboard.capsLock etc.
    // straight away — no role/delegate access needed, unlike sessions/users.
    property var keyboard: keyboardModel
    signal loginResult(bool success)
    signal loginError(string message)

    function login(username, password, sessionIndex) {
        var normalizedSession = Number(sessionIndex)
        if (!isFinite(normalizedSession) || normalizedSession < 0)
            normalizedSession = 0
        normalizedSession = Math.floor(normalizedSession)
        console.info("SDDM login requested for session index", normalizedSession)
        sddmObject.login(String(username), String(password), normalizedSession)
    }
    function completeLogin() {
        // SDDM owns session startup. This hook intentionally performs no second login.
    }
    function powerOff() { sddmObject.powerOff() }
    function reboot() { sddmObject.reboot() }
    function suspend() { if (sddmObject.suspend) sddmObject.suspend() }
    function hibernate() { if (sddmObject.hibernate) sddmObject.hibernate() }
    function hybridSleep() { if (sddmObject.hybridSleep) sddmObject.hybridSleep() }

    property Connections sddmConnection: Connections {
        target: root.sddmObject
        function onLoginSucceeded() {
            console.info("SDDM login succeeded")
            root.loginResult(true)
        }
        function onLoginFailed() {
            console.warn("SDDM login failed")
            root.loginResult(false)
        }
        function onInformationMessage(message) {
            console.info("SDDM information message:", message)
            if (message && String(message).length)
                root.loginError(String(message))
        }
    }
}
