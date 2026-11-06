import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../ui"

Item {
    id: overlayHost
    required property var loginController
    required property var eventBus
    required property var adapter
    property var layoutConfig: ({})
    property bool showInstantly: true
    property bool revealAfterEnterLogin: false
    property bool externalRevealControl: false
    property string customOverlayComponent: ""
    // Set once a scene-load failure is reported (see the eventBus
    // Connections below) — overrides customOverlayComponent so the plain,
    // reliable default login panel and power menu take over even when a
    // custom overlay is/was active, instead of leaving whatever that
    // overlay's own (possibly also broken, since it may share the same
    // failed assets) login card was showing.
    property bool forceGenericFallback: false
    property url themeRoot: ""
    property var sceneRuntime: null
    property bool sizeEditable: true
    property bool revealed: showInstantly
    function reveal() { revealed = true }
    function conceal() { revealed = false }
    property string initialUsername: ""
    property bool usernameLocked: false
    property int panelWidth: 520
    property int panelHeight: 390
    property int panelXPercent: 50
    property int panelYPercent: 50
    property color panelColor: "#111827"
    property real panelOpacity: 0.8
    property color inputColor: "#f7ffffff"
    property color inputTextColor: "#111827"
    property int inputHeight: 48
    property int inputRadius: 6
    property int inputFontSize: 16
    property url panelBackgroundSource: ""
    property url fontSource: ""
    property string fontFamily: ""
    property string titleText: "Welcome"
    property string titleAlignment: "left"
    property int titleFontSize: 28
    property color loginButtonColor: "#2563eb"
    property color loginButtonTextColor: "white"
    property int loginButtonRadius: 8
    property url loginButtonIcon: ""
    property url loginButtonHoverIcon: ""
    property color sessionColor: inputColor
    property color sessionTextColor: inputTextColor
    property url restartIcon: ""
    property url shutdownIcon: ""
    property bool imageButtons: false
    property bool sessionInPowerMenu: false
    property url sessionClosedIcon: ""
    property url sessionOpenIcon: ""
    property int selectedSessionIndex: 0
    property var extraActions: null
    property var editableSettings: null
    property bool editMode: false
    signal editAreaTapped()
    TapHandler {
        enabled: overlayHost.editMode
        gesturePolicy: TapHandler.DragThreshold
        onTapped: overlayHost.editAreaTapped()
    }
    property string directImageTarget: ""
    FileDialog {
        id: directImageDialog
        title: qsTr("Selecionar imagem")
        nameFilters: directImageTarget === "panelBackgroundImage"
                     ? [qsTr("Imagens e GIF (*.png *.jpg *.jpeg *.webp *.gif)")]
                     : [qsTr("Imagens (*.svg *.png *.webp *.jpg *.jpeg)")]
        onAccepted: if (overlayHost.editableSettings && overlayHost.directImageTarget.length)
                        overlayHost.editableSettings[overlayHost.directImageTarget] = selectedFile
    }
    function chooseDirectImage(key) {
        directImageTarget = key
        directImageDialog.open()
    }

    LoginOverlay {
        id: loginPanel
        width: Math.min(parent.width, parent.panelWidth)
        height: Math.min(parent.height, parent.panelHeight)
        x: Math.max(0, Math.min(parent.width - width, parent.width * parent.panelXPercent / 100 - width / 2))
        y: Math.max(0, Math.min(parent.height - height, parent.height * parent.panelYPercent / 100 - height / 2))
        controller: loginController
        events: eventBus
        sessions: adapter.sessions
        visible: (parent.customOverlayComponent.length === 0 || parent.forceGenericFallback) && (parent.revealed || opacity > 0)
        opacity: (parent.customOverlayComponent.length === 0 || parent.forceGenericFallback) && parent.revealed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        initialUsername: parent.initialUsername
        usernameLocked: parent.usernameLocked
        panelColor: parent.panelColor; panelOpacity: parent.panelOpacity
        inputColor: parent.inputColor; inputTextColor: parent.inputTextColor
        inputHeight: parent.inputHeight; inputRadius: parent.inputRadius; inputFontSize: parent.inputFontSize
        panelBackgroundSource: parent.panelBackgroundSource
        fontSource: parent.fontSource; fontFamily: parent.fontFamily; titleText: parent.titleText; titleAlignment: parent.titleAlignment; titleFontSize: parent.titleFontSize
        loginButtonColor: parent.loginButtonColor; loginButtonTextColor: parent.loginButtonTextColor; loginButtonRadius: parent.loginButtonRadius; loginButtonIcon: parent.loginButtonIcon
        loginButtonHoverIcon: parent.loginButtonHoverIcon
        sessionColor: parent.sessionColor; sessionTextColor: parent.sessionTextColor
        sessionSelectorExternal: parent.sessionInPowerMenu
        selectedSessionIndex: parent.selectedSessionIndex
    }
    Loader {
        id: customLoginPanel
        anchors.fill: parent
        source: overlayHost.customOverlayComponent.length ? overlayHost.themeRoot + overlayHost.customOverlayComponent : ""
        visible: status === Loader.Ready && !overlayHost.forceGenericFallback
        onLoaded: {
            item.controller = overlayHost.loginController
            item.events = overlayHost.eventBus
            item.adapter = overlayHost.adapter
            item.sceneRuntime = overlayHost.sceneRuntime
            item.initialUsername = overlayHost.initialUsername
            item.usernameLocked = overlayHost.usernameLocked
            item.selectedSessionIndex = overlayHost.selectedSessionIndex
            item.panelRevealed = Qt.binding(function() { return overlayHost.revealed })
            // Same box the generic loginPanel occupies (driven by panelWidth/panelHeight/
            // panelXPercent/panelYPercent), so the edit-mode drag/resize handles below —
            // which always track loginPanel's geometry — actually control what's on screen
            // when a custom overlay component is active. Part of the custom-overlay
            // contract, same as controller/events/adapter below.
            item.cardX = Qt.binding(function() { return loginPanel.x })
            item.cardY = Qt.binding(function() { return loginPanel.y })
            item.cardWidth = Qt.binding(function() { return loginPanel.width })
            item.cardHeight = Qt.binding(function() { return loginPanel.height })
            // Raw percentages, for overlays that declare "sizeEditable": false
            // and size their own panel, needing to center it themselves
            // instead of reusing loginPanel's pixel box, which assumes panelWidth/
            // panelHeight — settings such an overlay doesn't use for sizing.
            item.panelXPercent = Qt.binding(function() { return overlayHost.editableSettings ? overlayHost.editableSettings.panelXPercent : 50 })
            item.panelYPercent = Qt.binding(function() { return overlayHost.editableSettings ? overlayHost.editableSettings.panelYPercent : 50 })
            item.requestConceal.connect(overlayHost.conceal)
            item.requestReveal.connect(overlayHost.reveal)
            if (item.requestEnterLogin) item.requestEnterLogin.connect(overlayHost.requestEnterLogin)
        }
    }
    // Custom overlays (e.g. a corner "account" button) can ask to run the
    // real door-animation entry sequence instead of jumping straight to
    // reveal()/conceal() — same effect as clicking the middle of the
    // screen the first time, instead of bypassing the animation entirely.
    // ThemeRuntime (which owns SceneAnimationController) listens for this.
    signal requestEnterLogin()
    Rectangle {
        x: loginPanel.x; y: loginPanel.y; width: loginPanel.width; height: loginPanel.height
        visible: overlayHost.editMode
        color: "transparent"; z: 100
        Canvas {
            anchors.fill: parent
            anchors.margins: 3
            onPaint: {
                var context = getContext("2d")
                context.clearRect(0, 0, width, height)
                context.strokeStyle = "#b836e1ff"
                context.lineWidth = 1
                context.setLineDash([6, 5])
                context.strokeRect(0.5, 0.5, width - 1, height - 1)
            }
        }
        DragHandler {
            target: null
            enabled: !resizeArea.pressed
            property real startCenterX: 0
            property real startCenterY: 0
            onActiveChanged: if (active) {
                startCenterX = loginPanel.x + loginPanel.width / 2
                startCenterY = loginPanel.y + loginPanel.height / 2
            }
            onTranslationChanged: {
                if (!active || !overlayHost.editableSettings) return
                var cx = startCenterX + translation.x
                var cy = startCenterY + translation.y
                overlayHost.editableSettings.panelXPercent = Math.round(Math.max(0, Math.min(100, cx / overlayHost.width * 100)))
                overlayHost.editableSettings.panelYPercent = Math.round(Math.max(0, Math.min(100, cy / overlayHost.height * 100)))
            }
        }
        Rectangle {
            visible: overlayHost.sizeEditable
            width: 18; height: 18; anchors { right: parent.right; bottom: parent.bottom; margins: 1 }
            color: "#cc143244"; border.color: "#36e1ff"; border.width: 1; radius: 3; z: 10
            Text { anchors.centerIn: parent; text: "↘"; color: "#ffffff"; font.pixelSize: 13; font.bold: true }
            MouseArea {
                id: resizeArea
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor
                preventStealing: true
                propagateComposedEvents: false
                property real pressX: 0
                property real pressY: 0
                property real startWidth: 0
                property real startHeight: 0
                onPressed: function(mouse) {
                    pressX = mouse.x; pressY = mouse.y
                    startWidth = loginPanel.width; startHeight = loginPanel.height
                    mouse.accepted = true
                }
                onPositionChanged: function(mouse) {
                    if (!pressed || !overlayHost.editableSettings) return
                    overlayHost.editableSettings.panelWidth = Math.round(Math.max(280, Math.min(1000, startWidth + mouse.x - pressX)))
                    overlayHost.editableSettings.panelHeight = Math.round(Math.max(250, Math.min(900, startHeight + mouse.y - pressY)))
                }
            }
        }
        ImagePickerButton {
            anchors { left: parent.left; top: parent.top; margins: 5 }
            z: 12
            ToolTip.visible: hovered; ToolTip.text: qsTr("Definir imagem do painel")
            onClicked: overlayHost.chooseDirectImage("panelBackgroundImage")
        }
    }
    ImagePickerButton {
        visible: overlayHost.editMode && loginPanel.visible
        x: {
            var point = loginPanel.loginButtonControl.mapToItem(overlayHost, 0, 0)
            return point.x + loginPanel.loginButtonControl.width - width - 5
        }
        y: {
            var point = loginPanel.loginButtonControl.mapToItem(overlayHost, 0, 0)
            return point.y + (loginPanel.loginButtonControl.height - height) / 2
        }
        z: 120
        ToolTip.visible: hovered; ToolTip.text: qsTr("Definir imagem do botão de login")
        onClicked: overlayHost.chooseDirectImage("loginButtonIcon")
    }
    PowerMenu {
        id: powerMenu
        visible: parent.customOverlayComponent.length === 0 || parent.forceGenericFallback
        x: parent.width * ((parent.editableSettings ? parent.editableSettings.powerXPercent : 90) / 100) - width / 2
        y: parent.height * ((parent.editableSettings ? parent.editableSettings.powerYPercent : 92) / 100) - height / 2
        adapter: parent.adapter
        restartIcon: parent.restartIcon; shutdownIcon: parent.shutdownIcon; extraActions: parent.extraActions
        restartHoverIcon: parent.editableSettings ? parent.editableSettings.restartHoverIcon : ""
        shutdownHoverIcon: parent.editableSettings ? parent.editableSettings.shutdownHoverIcon : ""
        imageButtons: parent.imageButtons
        sessionInPowerMenu: parent.sessionInPowerMenu
        sessionClosedIcon: parent.sessionClosedIcon
        sessionOpenIcon: parent.sessionOpenIcon
        currentSessionIndex: parent.selectedSessionIndex
        onSessionSelected: function(index) { overlayHost.selectedSessionIndex = index }
        editMode: parent.editMode; settings: parent.editableSettings
        onImageRequested: function(key) { overlayHost.chooseDirectImage(key) }
    }
    Connections {
        target: eventBus
        function onEvent(name, payload) {
            if (name === "BeforeEnterLogin" && !overlayHost.revealAfterEnterLogin) overlayHost.reveal()
            if (name === "AfterEnterLogin" && overlayHost.revealAfterEnterLogin && !overlayHost.externalRevealControl) overlayHost.reveal()
            // Any scene-load failure — theme.json itself unreadable (e.g.
            // missing QML_XHR_ALLOW_FILE_READ), a converted-scene error, or
            // the webgl scene never confirming it's ready to reveal its own
            // panel — falls back to the plain default panel and power menu
            // unconditionally, even if a custom overlay (e.g. Genshin's) did
            // mount. Its own login card may depend on the very same assets
            // that just failed, so it isn't necessarily any more trustworthy
            // than showing nothing; the generic panel below only depends on
            // the real system's own user/session/power adapter, not on
            // anything theme-specific that could also be broken.
            if (name === "SceneLoadFailed" || name === "ScenePanelFailsafe") {
                diagnosticsPopup.reasonText = (name === "SceneLoadFailed" && payload && payload.reason) ? String(payload.reason) : ""
                overlayHost.forceGenericFallback = true
                // Nothing about the plain fallback panel prompts the user to
                // click first (that "click to begin" affordance only exists
                // inside a custom overlay, which is now hidden) — reveal it
                // immediately instead of waiting on the usual
                // click-then-animation-finishes chain.
                overlayHost.reveal()
                diagnosticsPopup.open()
            }
        }
    }
    onShowInstantlyChanged: revealed = showInstantly

    // Theme-agnostic troubleshooting popup — see the Connections block above
    // for exactly when this is shown instead of a custom overlay's own.
    Popup {
        id: diagnosticsPopup
        anchors.centerIn: Overlay.overlay
        width: Math.min(720, overlayHost.width - 60)
        modal: true; focus: true; padding: 0
        closePolicy: Popup.NoAutoClose
        z: 1000
        property string reasonText: ""
        background: Rectangle { color: "#1c2029"; border.color: "#3a4152"; border.width: 1; radius: 8 }
        Overlay.modal: Rectangle { color: "#66000000" }
        contentItem: ColumnLayout {
            width: diagnosticsPopup.width
            spacing: 14
            Label {
                Layout.fillWidth: true; Layout.topMargin: 24; Layout.leftMargin: 28; Layout.rightMargin: 28
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: qsTr("3D scene didn't load")
                color: "#f2f3f5"; font.bold: true; font.pixelSize: 20
            }
            Label {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                text: qsTr("You can still log in below. This is usually caused by one of two things on the machine running this greeter:")
                color: "#c2c6cf"; font.pixelSize: 13
            }
            Label {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28
                visible: text.length > 0
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                text: diagnosticsPopup.reasonText
                color: "#e0a04a"; font.pixelSize: 12; font.italic: true
            }
            Label {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.topMargin: 2
                wrapMode: Text.WordWrap
                text: qsTr("1. Missing Qt6 modules — install them (Debian/Ubuntu):")
                color: "#f2f3f5"; font.bold: true; font.pixelSize: 13
            }
            Rectangle {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28
                Layout.preferredHeight: aptCommandText.implicitHeight + 20
                color: "#12151a"; radius: 6
                Text {
                    id: aptCommandText
                    anchors { fill: parent; margins: 10 }
                    text: "sudo apt install qml6-module-qtquick3d qml6-module-qtquick3d-assetutils qml6-module-qtquick3d-helpers qml6-module-qtwebengine libqt6webenginequick6 qml6-module-qtmultimedia"
                    color: "#9fe6a0"; font.family: "monospace"; font.pixelSize: 11
                    wrapMode: Text.WrapAnywhere
                }
            }
            Label {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.topMargin: 2
                wrapMode: Text.WordWrap
                text: qsTr("2. Missing greeter environment flags — create a file under /etc/sddm.conf.d/ with:")
                color: "#f2f3f5"; font.bold: true; font.pixelSize: 13
            }
            Rectangle {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28
                Layout.preferredHeight: envCommandText.implicitHeight + 20
                color: "#12151a"; radius: 6
                Text {
                    id: envCommandText
                    anchors { fill: parent; margins: 10 }
                    text: "[General]\nGreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1,QTWEBENGINE_CHROMIUM_FLAGS=--allow-file-access-from-files --disable-web-security --autoplay-policy=no-user-gesture-required --force-color-profile=srgb"
                    color: "#9fe6a0"; font.family: "monospace"; font.pixelSize: 11
                    wrapMode: Text.WrapAnywhere
                }
            }
            Label {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                text: qsTr("Then restart SDDM (or reboot).")
                color: "#c2c6cf"; font.pixelSize: 13
            }
            Button {
                Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 24; Layout.topMargin: 4
                text: qsTr("OK")
                onClicked: diagnosticsPopup.close()
            }
        }
    }
}
