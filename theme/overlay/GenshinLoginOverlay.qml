import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Item {
    id: root
    property var controller: null
    property var adapter: null
    // Real SDDM sets this itself (via __sddm_errors, see SddmAdapter.qml)
    // when its own engine detects the configured theme failed to load —
    // OverlayHost only assigns "adapter" a moment after this overlay is
    // created, so Component.onCompleted is too early to read it; watch for
    // the assignment instead.
    onAdapterChanged: if (root.adapter && root.adapter.sddmErrors && root.adapter.sddmErrors.length > 0) root.reportWarning(root.adapter.sddmErrors)
    property var events: null
    property var sceneRuntime: null
    property string initialUsername: ""
    property bool usernameLocked: false
    property int selectedSessionIndex: 0
    property url assetRoot: Qt.resolvedUrl("../")
    property bool musicMuted: false
    property bool panelRevealed: false
    // Latches permanently once the click happens — the "Start game" prompt
    // should vanish right when the door animation starts (BeforeEnterLogin),
    // not wait for the panel to actually reveal once the door finishes.
    property bool hasEverRevealed: false
    onPanelRevealedChanged: if (panelRevealed) root.hasEverRevealed = true
    Connections {
        target: root.events
        function onEvent(name, payload) {
            if (name === "BeforeEnterLogin") root.hasEverRevealed = true
            if (name === "SceneLoadFailed") root.reportWarning(payload.reason)
        }
    }
    property bool alternateAccount: initialUsername.length === 0
    // SDDM's UserModel can flag an account as not needing a password
    // (needsPassword role) — skip the password field entirely for those
    // instead of forcing the user to submit an empty field regardless.
    readonly property var currentUserEntry: userEntryByName(username.text)
    readonly property bool currentUserNeedsPassword: !currentUserEntry || currentUserEntry.needsPassword !== false
    // Login card box, set by OverlayHost to the same panelWidth/panelHeight/
    // panelXPercent/panelYPercent geometry the Personalizar drag/resize handles edit.
    // Kept for the shared custom-overlay contract (OverlayHost always sets these),
    // but this theme declares "sizeEditable": false in theme.json and sizes its
    // card from its own content instead — see accountCard.width/height below.
    // Position still honors panelXPercent/panelYPercent (which OverlayHost derives
    // cardX/cardY from), but centered against this card's own width/height instead
    // of the generic login panel's, since they now differ.
    property real cardX: 0
    property real cardY: 0
    property real cardWidth: 520
    property real cardHeight: 390
    property real panelXPercent: 50
    property real panelYPercent: 50
    signal requestConceal()
    signal requestReveal()
    // Optional part of the custom-overlay contract (OverlayHost only wires
    // it up if declared): asks the core to run the real door-animation
    // entry sequence, same as clicking the middle of the screen the first
    // time, instead of jumping straight to reveal() and skipping it.
    signal requestEnterLogin()

    // Elements declared in theme.json's overlay.slots are user-editable via the
    // Personalizar panel and stored in assetImporter.themeAssets; fallbackRelative
    // is the value baked into this theme package when no override was saved.
    // assetImporter only exists in the desktop preview app's QML context — the
    // real installed SDDM greeter has no such object, so every access here must
    // go through "typeof assetImporter !== 'undefined'" first. Referencing the
    // bare name directly throws a ReferenceError under the real greeter, which
    // (since resolveAsset/resolveColor are called from openMenu()/playSound()
    // before the actual action) silently aborted every button's onClicked
    // handler partway through — none of the corner buttons or menus worked.
    function resolveAsset(key, fallbackRelative) {
        var overrides = (typeof assetImporter !== "undefined") ? assetImporter.themeAssets : null
        var value = (overrides && overrides[key]) ? overrides[key] : fallbackRelative
        return root.assetRoot + value
    }
    function resolveColor(key, fallbackColor) {
        var overrides = (typeof assetImporter !== "undefined") ? assetImporter.themeAssets : null
        return (overrides && overrides[key]) ? overrides[key] : fallbackColor
    }
    function resolveNumber(key, fallbackNumber) {
        var value = Number(root.resolveColor(key, String(fallbackNumber)))
        return isNaN(value) ? fallbackNumber : value
    }
    function playSound(key, fallbackRelative) {
        uiSound.stop()
        uiSound.source = root.resolveAsset(key, fallbackRelative)
        uiSound.play()
    }
    function sessionDisplayName(entry) {
        if (entry === undefined || entry === null || entry === "") return qsTr("Default session")
        return entry
    }
    // adapter.sessions is a plain JS array of strings in the preview app
    // (PreviewSddmAdapter), but the real SDDM greeter passes SDDM's own
    // sessionModel — a QAbstractListModel exposing "name"/"file"/etc. roles
    // (confirmed against SDDM's own SessionModel.cpp), with no "count",
    // "get(i)", "[i]" or "modelData" access from script at all. Roles are
    // only reachable from inside a real view delegate via the "model"
    // grouped property. Repeater (not ListView) is used here specifically
    // because it instantiates every delegate unconditionally regardless of
    // its own size/viewport — a zero-size ListView would cull all of them
    // as "not visible" and never populate anything. This cache only backs
    // the ambient button's own label (not inside any delegate, so it can't
    // reach "model" directly) — the visible session list below reads
    // "model" straight from its own delegate instead of depending on this.
    property var sessionNames: []
    function setSessionName(index, name) {
        var arr = root.sessionNames.slice()
        arr[index] = name
        root.sessionNames = arr
    }
    // TEMP DIAGNOSTIC LOGGING — the "Selecionar ambiente" list has been
    // reported empty on the real SDDM greeter despite working fine in the
    // desktop preview. Everything below is deliberately verbose and goes to
    // console.info/warn, which the real greeter's stdout — and therefore
    // `journalctl` — captures (see e.g. the "WebGL scene event: ..." lines
    // already visible there today). Grep for "[GenshinTheme][sessions]" in
    // journalctl after reproducing to see exactly what adapter.sessions
    // actually looks like on the real machine, instead of guessing again.
    onSessionNamesChanged: console.info("[GenshinTheme][sessions] sessionNames cache is now:", JSON.stringify(root.sessionNames))
    Repeater {
        id: sessionRepeater
        model: root.adapter ? root.adapter.sessions : null
        onModelChanged: console.info("[GenshinTheme][sessions] Repeater.model changed — typeof:", typeof model, "value:", model,
            "has .count:", model && model.count !== undefined ? model.count : "(no .count property)")
        delegate: Item {
            id: sessionEntry
            required property int index
            required property var model
            width: 0; height: 0
            readonly property string resolvedName: {
                var raw = sessionEntry.model.modelData
                if (typeof raw === "string" && raw.length > 0) return raw
                var nm = sessionEntry.model.name
                return nm !== undefined ? nm : ""
            }
            onResolvedNameChanged: root.setSessionName(index, resolvedName)
            Component.onCompleted: {
                console.info("[GenshinTheme][sessions] delegate created — index:", index,
                    "modelData:", sessionEntry.model.modelData,
                    "model.name:", sessionEntry.model.name,
                    "model.file:", sessionEntry.model.file,
                    "resolvedName:", resolvedName)
                root.setSessionName(index, resolvedName)
            }
        }
    }
    Component.onCompleted: {
        console.info("[GenshinTheme][sessions] overlay Component.onCompleted — adapter present:", !!root.adapter,
            "adapter.sessions:", root.adapter ? root.adapter.sessions : "(no adapter)",
            "adapter.sessions typeof:", root.adapter ? typeof root.adapter.sessions : "(no adapter)")
        console.info("[GenshinTheme][audio] Known limitation: if you see \"No audio device detected\" nearby in this log, see the comment above the MediaPlayer declarations in GenshinLoginOverlay.qml (audio devices, not this theme, are the cause).")
    }
    // Same cache pattern as sessionNames above, for adapter.users (SDDM's
    // real UserModel — "name"/"realName"/"icon"/"needsPassword" roles) —
    // lets the account switcher show a real user picker (with real avatars,
    // and skip the password field for accounts that don't need one) instead
    // of only free-text entry, when there's more than one system user.
    // Each entry: { name, realName, icon, needsPassword }.
    property var userNames: []
    readonly property var userEntries: userNames
    function setUserName(index, entry) {
        var arr = root.userEntries.slice()
        arr[index] = entry
        root.userNames = arr
    }
    // Looks up the cached entry for whichever username is currently in the
    // username field, so the password field / Start game button can react
    // to that specific account's needsPassword flag.
    function userEntryByName(name) {
        for (var i = 0; i < root.userEntries.length; ++i) {
            if (root.userEntries[i] && root.userEntries[i].name === name) return root.userEntries[i]
        }
        return null
    }
    Repeater {
        model: root.adapter ? root.adapter.users : null
        delegate: Item {
            id: userEntry
            required property int index
            required property var model
            width: 0; height: 0
            readonly property var resolvedEntry: {
                var raw = userEntry.model.modelData
                if (raw && typeof raw === "object") {
                    return {
                        name: raw.name !== undefined ? raw.name : "",
                        realName: raw.realName !== undefined ? raw.realName : "",
                        icon: raw.icon !== undefined ? raw.icon : "",
                        needsPassword: raw.needsPassword !== undefined ? raw.needsPassword : true
                    }
                }
                if (typeof raw === "string" && raw.length > 0) {
                    return { name: raw, realName: raw, icon: "", needsPassword: true }
                }
                return {
                    name: userEntry.model.name !== undefined ? userEntry.model.name : "",
                    realName: userEntry.model.realName !== undefined ? userEntry.model.realName : "",
                    icon: userEntry.model.icon !== undefined ? userEntry.model.icon : "",
                    needsPassword: userEntry.model.needsPassword !== undefined ? userEntry.model.needsPassword : true
                }
            }
            onResolvedEntryChanged: root.setUserName(index, resolvedEntry)
            Component.onCompleted: root.setUserName(index, resolvedEntry)
        }
    }

    FontLoader { id: genshinFont; source: root.resolveAsset("font", "ui-assets/sdk-jp-unity.ttf") }
    // KNOWN LIMITATION, logged here on purpose so it shows up in the real
    // greeter's own journal (journalctl) next to the messages it explains,
    // instead of leaving whoever reads the log guessing:
    //
    // On 2026-07-21, silence across every sound in this theme (music, UI
    // clicks, the door effect) was traced on a real SDDM install to Qt
    // Multimedia failing to detect ANY audio device at all — logged by the
    // greeter itself as "No audio device detected", right after a
    // "spaVisitChoice: parse error" while it was enumerating devices. The
    // trigger was a USB microphone (in that case identified by PipeWire as
    // an "alsa_input.usb-...DRELANMIC..." node) whose format description
    // Qt's PipeWire backend couldn't parse — and because Qt builds one
    // single device list covering both inputs and mics and outputs/speakers
    // together, one malformed entry anywhere in that list took down
    // detection for every device, speakers included, even though they had
    // nothing to do with the microphone. Unplugging the offending USB
    // device and doing a full shutdown+boot (not just a logout, since the
    // greeter's own PipeWire/WirePlumber session — a real, separate
    // instance from the desktop user's — only fully reinitializes on a
    // fresh boot) resolved it on that machine.
    // This is a bug in Qt Multimedia's/PipeWire's device-format parsing
    // (triggered by specific audio hardware), entirely outside this theme's
    // QML code — nothing here can detect a specific bad device or skip it,
    // since Qt never exposes *which* device failed or *why* to QML, only
    // the fact that its own internal enumeration came up empty. If sound
    // is silent again, check `journalctl` for "No audio device detected" /
    // "spaVisitChoice: parse error" right after "Using Qt multimedia" near
    // the greeter's startup — if present, this is that same class of bug,
    // and the fix is identifying/removing whatever audio device triggers it
    // this time, not a theme change (see root's Component.onCompleted below
    // for the one-line pointer to this comment that actually reaches the log).
    MediaPlayer {
        id: uiSound
        audioOutput: AudioOutput { volume: 0.72 }
        onErrorOccurred: function(error, errorString) {
            console.warn("[GenshinTheme][audio] uiSound error:", error, errorString)
            root.reportWarning(qsTr("UI sound playback failed: %1").arg(errorString))
        }
    }
    // Theme song: loops forever, toggled by the mute corner button, editable
    // via the "themeMusic" slot in Personalizar.
    MediaPlayer {
        id: themeMusic
        source: root.resolveAsset("themeMusic", "web/Genshin/BGM.mp3")
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: 0.5; muted: root.musicMuted }
        onSourceChanged: play()
        onErrorOccurred: function(error, errorString) {
            console.warn("[GenshinTheme][audio] themeMusic error:", error, errorString)
            root.reportWarning(qsTr("Theme music playback failed: %1").arg(errorString))
        }
    }
    // Ambient scene sound (e.g. wind) — always audible regardless of the mute
    // button, which only controls the theme song above. No sound ships with
    // this package by default; pick one via the "ambientSound" slot.
    Item {
        id: ambientSoundState
        property string overrideValue: (typeof assetImporter !== "undefined" && assetImporter.themeAssets && assetImporter.themeAssets["ambientSound"]) ? assetImporter.themeAssets["ambientSound"] : ""
    }
    MediaPlayer {
        id: ambientSound
        source: ambientSoundState.overrideValue.length > 0 ? root.assetRoot + ambientSoundState.overrideValue : ""
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: 0.4 }
        onSourceChanged: if (source.toString().length > 0) play()
        onErrorOccurred: function(error, errorString) {
            console.warn("[GenshinTheme][audio] ambientSound error:", error, errorString)
            root.reportWarning(qsTr("Ambient sound playback failed: %1").arg(errorString))
        }
    }
    Timer {
        // On a real SDDM cold boot, the greeter's own isolated audio session
        // sometimes hasn't finished detecting the real sound card yet at the
        // exact moment this overlay loads — Qt Multimedia only sees a
        // fallback "dummy" null sink at that instant and silently gives up
        // ("No audio device detected" in the greeter's own log), with no
        // automatic retry once a real device shows up. Retry shortly after,
        // by which point the audio backend has settled — same category of
        // fix as the WebGL scene/network readiness fallbacks in this theme.
        // (See the Component.onCompleted comment above for the deeper,
        // confirmed cause of "No audio device detected" specifically — this
        // delay does not help with that one, only with the ordinary
        // cold-boot timing race.)
        interval: 1500
        running: true
        onTriggered: {
            console.info("[GenshinTheme][audio] retry timer fired — themeMusic.error:", themeMusic.error, themeMusic.errorString,
                "ambientSound.error:", ambientSound.error, ambientSound.errorString,
                "ambientSound configured:", ambientSound.source.toString().length > 0)
            themeMusic.play()
            if (ambientSound.source.toString().length > 0) ambientSound.play()
        }
    }
    // Real SDDM doesn't spawn a fresh greeter process for every login screen
    // — the same one is kept running and simply regains focus once a user
    // logs out, so the one-shot Timer above (which only ever fires once, at
    // the very first cold boot) never plays music again on that second and
    // later appearances. Window.active reliably toggles on both: the first
    // time the greeter takes focus at boot, and every time it takes focus
    // back after a session ends — so it doubles as the "welcome back" signal
    // this theme has no other native hook for.
    //
    // The window typically goes active within the first instant of cold
    // boot — well before the Timer's 1500ms wait for the real audio device
    // to be detected (see above). Calling play() that early hits the same
    // "dummy sink" trap the Timer exists to avoid, and once a MediaPlayer
    // has locked onto the dummy device it stays silent for the rest of the
    // session — breaking not just the music but every other sound too.
    // Skip the very first activation (the Timer already owns it) and only
    // react on the second and later ones, which is genuinely "back from
    // logout", not cold boot.
    property int windowActivations: 0
    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (!root.Window.window || !root.Window.window.active) return
            root.windowActivations += 1
            if (root.windowActivations <= 1) return
            themeMusic.play()
            if (ambientSound.source.toString().length > 0) ambientSound.play()
        }
    }
    function sound(file) {
        uiSound.stop()
        uiSound.source = root.assetRoot + "sounds/" + file
        uiSound.play()
    }
    function openMenu(menu) {
        playSound("openMenuSound", "sounds/open_win.mp3")
        menu.open()
    }
    function closeMenu(menu) {
        playSound("closeMenuSound", "sounds/close_win.mp3")
        menu.close()
    }
    function submit() {
        errorText.text = ""
        playSound("clickSound", "sounds/switch_task.mp3")
        controller.login(username.text, password.text, selectedSessionIndex)
    }

    function closeAccountPanel() {
        root.playSound("closeMenuSound", "sounds/close_win.mp3")
        root.requestConceal()
    }

    // One-time "click to begin" splash. Shown until the panel is revealed for
    // the first time, then gone for good (see hasEverRevealed above). Split
    // into two crops of the same source image (source pixel bands measured by
    // alpha content: title 0-350, divider+subtitle 350-688 of the 1088x688
    // asset) so only the "CLICK TO BEGIN" half can pulse independently.
    Item {
        id: startGamePrompt
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.02
        width: Math.min(760, root.width * 0.6)
        height: width * (688 / 1088)
        visible: opacity > 0
        // Waits for the WebGL scene's own load (the white loading screen) to
        // finish before showing, on top of the usual one-time latch.
        opacity: (!root.hasEverRevealed && root.sceneRuntime && root.sceneRuntime.ready) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Image {
            anchors.fill: parent
            source: root.resolveAsset("startGamePrompt", "ui-assets/start_game.png")
            fillMode: Image.PreserveAspectFit
        }
        Image {
            anchors.fill: parent
            source: root.resolveAsset("clickToBeginPrompt", "ui-assets/clicktobegin.png")
            fillMode: Image.PreserveAspectFit
            SequentialAnimation on opacity {
                running: startGamePrompt.opacity > 0
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.35; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
            }
        }
        // No tap handler here on purpose: the click needs to fall through to
        // the generic InputRouter below (core/InputRouter.qml, in ThemeRuntime),
        // which calls animations.enterLogin() — for a WebGL theme that plays
        // the scene's "EnterLogin" action (the door-opening animation) and only
        // reveals the panel once the scene reports back DoorReady/DoorClosed
        // (mapped to "PanelReveal" in webgl-mapping.json). Calling
        // requestReveal() directly here skipped that whole sequence.
    }

    Item {
        id: accountCard
        width: Math.min(900, root.width - 24)
        // Grows/shrinks with whatever formColumn actually needs (it swaps between
        // the username+password form and the single last-login row), plus room
        // for the Start game button when it's showing — instead of a fixed size
        // that leaves a gap when the shorter state is active.
        height: logo.height + root.resolveNumber("logoOffsetY", 38) + root.resolveNumber("formTopMargin", 35) + formColumn.height
                + (root.alternateAccount ? 24 + 88 + 40 : 40)
        x: Math.max(0, Math.min(root.width - width, root.width * root.panelXPercent / 100 - width / 2))
        y: Math.max(0, Math.min(root.height - height, root.height * root.panelYPercent / 100 - height / 2))
        clip: true
        // Hidden while the door-opening animation for a login attempt is
        // playing (controller.authenticating) — reappears only if the
        // attempt fails, since a success never flips authenticating back on.
        opacity: (root.panelRevealed && !controller.authenticating) ? 1 : 0
        visible: opacity > 0
        enabled: opacity > 0.99
        Behavior on opacity { NumberAnimation { duration: 220 } }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: root.resolveColor("panelColor", "#fffefd")
            border.color: "#e5e6ea"
            border.width: 1
            layer.enabled: true
        }
        Image {
            anchors.fill: parent
            property string overrideValue: (typeof assetImporter !== "undefined" && assetImporter.themeAssets && assetImporter.themeAssets["cardBackgroundImage"]) ? assetImporter.themeAssets["cardBackgroundImage"] : ""
            source: overrideValue.length > 0 ? root.assetRoot + overrideValue : ""
            visible: overrideValue.length > 0
            fillMode: Image.PreserveAspectCrop
        }
        Image {
            id: logo
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.resolveNumber("logoOffsetX", 0)
            anchors.top: parent.top
            anchors.topMargin: root.resolveNumber("logoOffsetY", 38)
            width: 420; height: 76
            source: root.resolveAsset("logo", "ui-assets/logo_hoyoverse_default.png")
            fillMode: Image.PreserveAspectFit
        }
        Button {
            id: closeButton
            anchors { right: parent.right; top: parent.top; margins: 25 }
            width: 48; height: 48
            contentItem: Image {
                anchors.centerIn: parent; width: 40; height: 40; fillMode: Image.PreserveAspectFit
                source: closeButton.down ? root.resolveAsset("closeButtonIconPressed", "ui-assets/nav_close_pressed.png")
                        : closeButton.hovered ? root.resolveAsset("closeButtonIconHover", "ui-assets/nav_close_hover.png")
                        : root.resolveAsset("closeButtonIcon", "ui-assets/nav_close_default.png")
            }
            background: Item {}
            onClicked: root.closeAccountPanel()
        }
        Button {
            id: backButton
            anchors { left: parent.left; top: parent.top; margins: 25 }
            width: 48; height: 48
            visible: root.alternateAccount && root.initialUsername.length > 0
            contentItem: Image {
                anchors.centerIn: parent; width: 29; height: 46; fillMode: Image.PreserveAspectFit
                source: root.assetRoot + (backButton.down ? "ui-assets/nav_back_pressed.png" : backButton.hovered ? "ui-assets/nav_back_hover.png" : "ui-assets/nav_back_default.png")
            }
            background: Item {}
            onClicked: { root.playSound("closeMenuSound", "sounds/close_win.mp3"); root.alternateAccount = false }
        }
        ColumnLayout {
            id: formColumn
            anchors {
                left: parent.left; right: parent.right; top: logo.bottom
                leftMargin: root.resolveNumber("formSideMargin", 80)
                rightMargin: root.resolveNumber("formSideMargin", 80)
                topMargin: root.resolveNumber("formTopMargin", 35)
            }
            spacing: 24
            TextField {
                id: username
                Layout.fillWidth: true; Layout.preferredHeight: 86
                text: root.initialUsername; readOnly: root.usernameLocked
                visible: root.alternateAccount
                placeholderText: qsTr("Enter username")
                font.family: genshinFont.name; font.pixelSize: 25; font.bold: true
                color: "#303238"; selectByMouse: true; leftPadding: 25; rightPadding: 45
                background: BorderImage { source: root.assetRoot + (username.activeFocus ? "ui-assets/pc_input_bg_hover.png" : "ui-assets/pc_input_bg_default.png"); border { left: 10; top: 10; right: 10; bottom: 10 } }
                onActiveFocusChanged: if (activeFocus) root.events.emit("UsernameFocused")
                FieldClearButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 18 }
                    visible: !username.readOnly && username.text.length > 0
                    onCleared: username.text = ""
                }
            }
            TextField {
                id: password
                Layout.fillWidth: true; Layout.preferredHeight: 86
                visible: root.alternateAccount && root.currentUserNeedsPassword
                placeholderText: qsTr("Enter password")
                echoMode: TextInput.Password; passwordCharacter: "•"; selectByMouse: true
                font.family: genshinFont.name; font.pixelSize: 25; font.bold: true
                color: "#303238"; leftPadding: 25; rightPadding: 76
                background: BorderImage { source: root.assetRoot + (password.activeFocus ? "ui-assets/pc_input_bg_hover.png" : "ui-assets/pc_input_bg_default.png"); border { left: 10; top: 10; right: 10; bottom: 10 } }
                onActiveFocusChanged: if (activeFocus) root.events.emit("PasswordFocused")
                onAccepted: root.submit()
                RowLayout {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 18 }
                    spacing: 10
                    FieldClearButton {
                        visible: password.text.length > 0
                        onCleared: password.text = ""
                    }
                    FieldEyeButton {
                        revealed: password.echoMode === TextInput.Normal
                        onToggled: password.echoMode = (password.echoMode === TextInput.Normal ? TextInput.Password : TextInput.Normal)
                    }
                }
            }
            Label {
                id: capsLockWarning
                Layout.fillWidth: true
                text: qsTr("Caps Lock is on")
                color: "#bd8315"; font.family: genshinFont.name; font.pixelSize: 14; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                visible: root.alternateAccount && root.adapter && root.adapter.keyboard && root.adapter.keyboard.capsLock === true
            }
            Label {
                id: errorText
                Layout.fillWidth: true
                color: "#c45d52"; font.family: genshinFont.name; font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
            }
            Repeater {
                // Lists every real system user right here on the initial
                // screen (SDDM's UserModel via root.userEntries), instead of
                // a single "last login" row plus a separate account-switch
                // popup. Falls back to one synthesized entry from
                // initialUsername when userEntries is empty (preview app
                // with no real userModel, or an adapter that never reports
                // any users), so this never regresses to showing nothing.
                model: root.userEntries.length > 0 ? root.userEntries
                    : (root.initialUsername.length > 0 ? [{ name: root.initialUsername, realName: root.initialUsername, icon: "", needsPassword: true }] : [])
                delegate: Button {
                    id: userRowButton
                    required property int index
                    required property var model
                    readonly property var entry: userRowButton.model.modelData || {}
                    Layout.fillWidth: true; Layout.preferredHeight: 114
                    visible: !root.alternateAccount
                    hoverEnabled: true
                    onClicked: {
                        root.playSound("clickSound", "sounds/switch_task.mp3")
                        username.text = userRowButton.entry.name || ""
                        if (userRowButton.entry.needsPassword === false) {
                            // No password needed (or one already saved by the
                            // system) — skip the password step entirely.
                            // controller.login() itself triggers the door-
                            // opening animation and conceals this panel via
                            // the generic AuthenticationStarted event, same
                            // as a normal password submission.
                            password.text = ""
                            root.submit()
                        } else {
                            root.alternateAccount = true
                            password.forceActiveFocus()
                        }
                    }
                    background: Item {
                        BorderImage { anchors.fill: parent; source: root.assetRoot + "ui-assets/pc_lastlogin_bg_default.png"; border { left: 10; top: 10; right: 10; bottom: 10 } }
                        Rectangle {
                            anchors.fill: parent; radius: 10; color: "#000000"
                            opacity: userRowButton.down ? 0.14 : userRowButton.hovered ? 0.07 : 0
                            Behavior on opacity { NumberAnimation { duration: 90 } }
                        }
                    }
                    contentItem: Item {
                        Rectangle {
                            id: avatarRect
                            x: 32; anchors.verticalCenter: parent.verticalCenter
                            width: 62; height: 62; radius: 31
                            color: "#ffffff"; border.color: "#e5e6ea"; border.width: 2
                            // Real system avatar (SDDM UserModel's "icon" role)
                            // when this account has one on disk, falling back
                            // to the generic placeholder otherwise.
                            readonly property bool hasRealAvatar: userRowButton.entry.icon && userRowButton.entry.icon.length > 0
                            Image {
                                anchors.fill: parent
                                anchors.margins: avatarRect.hasRealAvatar ? 2 : 10
                                // Qt.resolvedUrl (not string-concatenating "file://")
                                // correctly turns an absolute local path into a
                                // file:// URL regardless of whether UserModel's
                                // "icon" role already included one — plain
                                // concatenation produced a broken double-scheme
                                // path ("file://file:///...") on a real SDDM
                                // greeter test.
                                source: avatarRect.hasRealAvatar ? Qt.resolvedUrl(userRowButton.entry.icon) : root.assetRoot + "ui-assets/login_method_email_default.png"
                                fillMode: avatarRect.hasRealAvatar ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                layer.enabled: avatarRect.hasRealAvatar
                            }
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 135; verticalCenter: parent.verticalCenter }
                            text: userRowButton.entry.realName && userRowButton.entry.realName.length > 0 ? userRowButton.entry.realName : userRowButton.entry.name
                            color: "#292a2e"; font.family: genshinFont.name; font.pixelSize: 27; font.bold: true
                        }
                    }
                }
            }
            Button {
                Layout.alignment: Qt.AlignRight
                visible: root.alternateAccount
                text: qsTr("Forgot password?")
                font.family: genshinFont.name; font.pixelSize: 22; font.bold: true
                contentItem: Text { text: parent.text; color: "#d4a62e"; font: parent.font; horizontalAlignment: Text.AlignRight }
                background: Item {}
                onClicked: { root.playSound("clickSound", "sounds/switch_task.mp3"); passwordInfo.open() }
            }
            Button {
                Layout.alignment: Qt.AlignHCenter
                visible: !root.alternateAccount
                text: qsTr("Log in to another account")
                font.family: genshinFont.name; font.pixelSize: 26; font.bold: true
                contentItem: Text { text: parent.text; color: "#bd8315"; font: parent.font; horizontalAlignment: Text.AlignHCenter }
                background: Item {}
                onClicked: {
                    // Every real user is already listed inline above, so this
                    // is only for typing in a username that isn't in that
                    // list (e.g. a system account SDDM's UserModel filters
                    // out) — straight to free-text entry, no picker needed.
                    root.playSound("clickSound", "sounds/switch_task.mp3")
                    root.alternateAccount = true
                    username.text = ""
                    username.forceActiveFocus()
                }
            }
        }
        // Only shown once a password is actually being entered — pinned to the
        // bottom of the card regardless of how much the form above grows.
        Button {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: root.resolveNumber("formSideMargin", 80)
                rightMargin: root.resolveNumber("formSideMargin", 80)
                bottomMargin: 40
            }
            height: 88
            visible: root.alternateAccount
            text: controller.authenticating ? qsTr("Starting…") : qsTr("Start game")
            enabled: !controller.authenticating && username.text.length > 0 && (!root.currentUserNeedsPassword || password.text.length > 0)
            font.family: genshinFont.name; font.pixelSize: 27; font.bold: true
            contentItem: Text { text: parent.text; color: "#eac552"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: BorderImage {
                source: !parent.enabled ? root.resolveAsset("primaryButtonBgDisabled", "ui-assets/pc_btn_primary_disable.png")
                        : parent.down ? root.resolveAsset("primaryButtonBgPressed", "ui-assets/pc_btn_primary_pressed.png")
                        : parent.hovered ? root.resolveAsset("primaryButtonBgHover", "ui-assets/pc_btn_primary_hover.png")
                        : root.resolveAsset("primaryButtonBg", "ui-assets/pc_btn_primary_default.png")
                border { left: 10; top: 10; right: 10; bottom: 10 }
            }
            onClicked: root.submit()
        }
    }

    GenshinSideButton {
        anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
        imageSource: root.resolveAsset("powerButtonIcon", "ui-assets/title-original/UI_IconSmall_Quit.png")
        caption: qsTr("Power")
        onClicked: root.openMenu(shutdownConfirm)
        // Hidden during the door-opening animation for a login attempt;
        // comes back only if the attempt fails.
        opacity: controller.authenticating ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }
    Column {
        // Stacked vertically along the right edge, matching the reference
        // screenshot (was a horizontal row before).
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        spacing: 14
        opacity: controller.authenticating ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        GenshinSideButton {
            imageSource: root.resolveAsset("accountButtonIcon", "ui-assets/title-original/UI_IconSmall_AddAccount.png")
            caption: qsTr("Account")
            onClicked: {
                root.playSound("clickSound", "sounds/switch_task.mp3")
                // First time (door animation hasn't played yet): behave like
                // clicking the middle of the screen, so the door animation
                // still happens instead of being skipped. After that, this
                // button just toggles the panel like any other reveal/hide.
                if (!root.hasEverRevealed) root.requestEnterLogin()
                else if (root.panelRevealed) root.requestConceal()
                else root.requestReveal()
            }
        }
        GenshinSideButton {
            imageSource: root.resolveAsset("noticesButtonIcon", "ui-assets/title-original/UI_IconSmall_Notice.png")
            caption: qsTr("Notices")
            onClicked: root.openMenu(noticesMenu)
        }
        GenshinSideButton {
            imageSource: root.musicMuted ? root.resolveAsset("muteButtonIconMuted", "ui-assets/icon-muted.svg")
                                          : root.resolveAsset("muteButtonIcon", "ui-assets/icon-volume.svg")
            caption: root.musicMuted ? qsTr("Enable music") : qsTr("Mute music")
            onClicked: {
                root.musicMuted = !root.musicMuted
                root.playSound("clickSound", "sounds/switch_task.mp3")
            }
        }
        GenshinSideButton {
            // adapter.canHibernate/canHybridSleep reflect real capability
            // checks (systemd-logind) — some machines have no resume-
            // configured swap and genuinely cannot hibernate, in which case
            // this button did nothing when clicked. Prefer hybrid sleep
            // (suspend to RAM, falls back to disk) when plain hibernate
            // isn't available, and hide the button entirely if neither is.
            readonly property bool useHybridSleep: root.adapter && root.adapter.canHibernate === false && root.adapter.canHybridSleep === true
            visible: !root.adapter || root.adapter.canHibernate !== false || root.adapter.canHybridSleep === true
            imageSource: root.resolveAsset("sleepButtonIcon", "ui-assets/title-original/UI_IconSmall_Hibernate.png")
            caption: qsTr("Hibernate")
            onClicked: {
                root.playSound("clickSound", "sounds/switch_task.mp3")
                if (useHybridSleep) root.adapter.hybridSleep()
                else root.adapter.hibernate()
            }
        }
    }

    // Environment/session picker — replaces the old corner icon button. Shows
    // the currently selected session and opens ambientMenu below.
    Button {
        id: ambientButton
        // Reference screenshot: the region bar is a compact ~24% of screen
        // width sitting well clear of the bottom edge — ours was rendering
        // almost twice that wide.
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.05 }
        // Sized to the source image's own aspect ratio (887x168) so nothing
        // stretches — a fixed target height (independent of width) is what
        // squashed the diamond+check icon last time.
        width: Math.min(420, root.width * 0.24)
        height: width * (168 / 887)
        hoverEnabled: true
        // Same gate as startGamePrompt: hidden until the WebGL scene's own
        // load (the white loading screen) finishes. Also hidden during the
        // door-opening animation for a login attempt, reappearing only if
        // the attempt fails.
        visible: opacity > 0
        opacity: (root.sceneRuntime && root.sceneRuntime.ready && !controller.authenticating) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        background: Item {
            Image {
                anchors.fill: parent
                source: root.resolveAsset("ambientButtonBg", "ui-assets/ambientmodalbutton.png")
                fillMode: Image.Stretch
                opacity: ambientButton.hovered ? 1 : 0.92
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                color: "transparent"; radius: 14
                border.color: "#ffffff"; border.width: ambientButton.hovered ? 2 : 0
                Behavior on border.width { NumberAnimation { duration: 90 } }
            }
        }
        contentItem: Text {
            text: root.sessionDisplayName(root.sessionNames[root.selectedSessionIndex])
            color: "#e7ecf3"; font.family: genshinFont.name; font.pixelSize: 22; font.bold: true
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            leftPadding: ambientButton.width * 0.17
        }
        onClicked: {
            console.info("[GenshinTheme][sessions] ambientButton clicked — sessionNames:", JSON.stringify(root.sessionNames),
                "adapter.sessions:", root.adapter ? root.adapter.sessions : "(no adapter)")
            root.openMenu(ambientMenu)
        }
    }

    // Small "clear field" (×) button, shown inside a text field once it has
    // content. No matching asset in the theme package, so drawn directly.
    component FieldClearButton: Rectangle {
        id: clearButton
        signal cleared()
        width: 22; height: 22; radius: 11
        color: clearArea.containsMouse ? "#d8dade" : "#e6e8ec"
        Text { anchors.centerIn: parent; text: "×"; color: "#8a8f98"; font.pixelSize: 15; font.bold: true }
        MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: clearButton.cleared() }
    }
    // Small eye toggle for the password field. Drawn rather than using an
    // asset: an open almond-shaped eye with a pupil, or a single closed-lid
    // curve, matching the reference mockup's plain gray icon style.
    component FieldEyeButton: Item {
        id: eyeButton
        property bool revealed: false
        signal toggled()
        width: 22; height: 22
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eyeButton.toggled() }
        Canvas {
            id: eyeCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#8a8f98"
                ctx.lineWidth = 1.4
                ctx.lineCap = "round"
                var w = width, h = height, cx = w / 2, cy = h / 2
                if (eyeButton.revealed) {
                    ctx.beginPath()
                    ctx.moveTo(3, cy)
                    ctx.quadraticCurveTo(cx, 4, w - 3, cy)
                    ctx.quadraticCurveTo(cx, h - 4, 3, cy)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(cx, cy, 2.1, 0, Math.PI * 2)
                    ctx.fillStyle = "#8a8f98"
                    ctx.fill()
                } else {
                    ctx.beginPath()
                    ctx.moveTo(3, cy)
                    ctx.quadraticCurveTo(cx, h - 4, w - 3, cy)
                    ctx.stroke()
                }
            }
            Component.onCompleted: requestPaint()
        }
        onRevealedChanged: eyeCanvas.requestPaint()
    }

    // Plain pill button for the shutdown confirmation dialog, matching
    // shutdownmodal.png: an outlined "Cancelar" and a filled dark "OK",
    // both with gold text.
    component GenshinConfirmButton: Button {
        id: confirmBtn
        property bool filled: false
        implicitHeight: 62
        contentItem: Text {
            text: confirmBtn.text; color: "#d9a441"
            font.family: genshinFont.name; font.pixelSize: 20; font.bold: true
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            color: confirmBtn.filled
                ? (confirmBtn.down ? "#1c1c1f" : confirmBtn.hovered ? "#3a3a3f" : "#2e2e33")
                : (confirmBtn.down ? "#f2ead8" : confirmBtn.hovered ? "#faf6ec" : "#ffffff")
            border.color: "#d9a441"; border.width: confirmBtn.filled ? 0 : 2
            Behavior on color { ColorAnimation { duration: 90 } }
        }
    }

    // Pill-shaped dialog action button with a ring-icon badge, matching the
    // "Cancel"/"Confirm" buttons from the reference modal (modalexample.png).
    component GenshinDialogButton: Button {
        id: dialogBtn
        property color accentColor: "#4fd7ff"
        property string iconGlyph: "×"
        property real pillWidth: 230
        implicitWidth: pillWidth
        implicitHeight: 58
        contentItem: Item {
            anchors.fill: parent
            Rectangle {
                id: badgeIcon
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: 38; height: 38; radius: 19
                color: "#242c44"
                border.color: dialogBtn.accentColor; border.width: 2
                Text { anchors.centerIn: parent; text: dialogBtn.iconGlyph; color: dialogBtn.accentColor; font.pixelSize: 19; font.bold: true }
            }
            Text {
                id: labelText
                anchors.centerIn: parent
                text: dialogBtn.text; color: "#f4f1ea"; font.family: genshinFont.name
                font.pixelSize: 20; font.bold: true
            }
        }
        background: Rectangle {
            radius: height / 2
            color: dialogBtn.down ? "#333d55" : dialogBtn.hovered ? "#4c5776" : "#3f4a67"
            border.color: dialogBtn.hovered ? "#6d7ba0" : "#57628a"; border.width: 1
            Behavior on color { ColorAnimation { duration: 90 } }
        }
    }

    component GenshinPopup: Popup {
        id: popup
        anchors.centerIn: Overlay.overlay
        width: Math.min(560, root.width - 50)
        modal: true; focus: true; padding: 0
        closePolicy: Popup.NoAutoClose
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        background: Rectangle { color: root.resolveColor("popupColor", "#f4f1e9"); border.color: "#b9aa8d"; border.width: 1; radius: 4 }
        Overlay.modal: Rectangle { color: "#52091018" }
    }

    GenshinPopup {
        id: passwordInfo
        width: Math.min(680, root.width - 60)
        height: width * (657 / 1024)
        closePolicy: Popup.CloseOnEscape
        background: Image {
            source: root.resolveAsset("modalBackground", "ui-assets/modalbackground.png")
            fillMode: Image.Stretch
        }
        contentItem: Item {
            anchors.fill: parent
            Label {
                anchors { top: parent.top; topMargin: passwordInfo.height * 0.1; horizontalCenter: parent.horizontalCenter }
                text: qsTr("Change system password")
                color: "#3e4657"; font.family: genshinFont.name; font.bold: true
                font.pixelSize: Math.max(17, passwordInfo.height * 0.058)
            }
            Label {
                anchors { centerIn: parent; verticalCenterOffset: -passwordInfo.height * 0.02 }
                width: parent.width * 0.72
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                text: qsTr("The passwd command can only be used here when the greeter is running in the correct privileged root mode.")
                color: "#626978"; font.family: genshinFont.name; font.pixelSize: Math.max(14, passwordInfo.height * 0.038)
            }
            Row {
                anchors { bottom: parent.bottom; bottomMargin: passwordInfo.height * 0.1; horizontalCenter: parent.horizontalCenter }
                spacing: 24
                GenshinDialogButton {
                    pillWidth: passwordInfo.width * 0.34
                    text: qsTr("Cancel"); iconGlyph: "×"; accentColor: "#4fd7ff"
                    onClicked: root.closeMenu(passwordInfo)
                }
                GenshinDialogButton {
                    pillWidth: passwordInfo.width * 0.34
                    text: qsTr("OK"); iconGlyph: "○"; accentColor: "#f0c85a"
                    onClicked: root.closeMenu(passwordInfo)
                }
            }
        }
    }

    // Same look as the "Forgot password?" info popup above, reused to
    // surface anything that would otherwise only ever show up as a CLI/log
    // warning (a failed scene load, a bad theme package, a sound that
    // couldn't play) — since nothing on a real SDDM login screen is ever
    // watching a terminal, these would otherwise be invisible.
    GenshinPopup {
        id: warningPopup
        width: Math.min(680, root.width - 60)
        height: width * (657 / 1024)
        closePolicy: Popup.CloseOnEscape
        property string warningMessage: ""
        background: Image {
            source: root.resolveAsset("modalBackground", "ui-assets/modalbackground.png")
            fillMode: Image.Stretch
        }
        contentItem: Item {
            anchors.fill: parent
            Label {
                anchors { top: parent.top; topMargin: warningPopup.height * 0.1; horizontalCenter: parent.horizontalCenter }
                text: qsTr("Warning")
                color: "#3e4657"; font.family: genshinFont.name; font.bold: true
                font.pixelSize: Math.max(17, warningPopup.height * 0.058)
            }
            Label {
                anchors { centerIn: parent; verticalCenterOffset: -warningPopup.height * 0.02 }
                width: parent.width * 0.72
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                text: warningPopup.warningMessage
                color: "#626978"; font.family: genshinFont.name; font.pixelSize: Math.max(14, warningPopup.height * 0.038)
            }
            GenshinDialogButton {
                anchors { bottom: parent.bottom; bottomMargin: warningPopup.height * 0.1; horizontalCenter: parent.horizontalCenter }
                pillWidth: warningPopup.width * 0.34
                text: qsTr("OK"); iconGlyph: "!"; accentColor: "#f0c85a"
                onClicked: root.closeMenu(warningPopup)
            }
        }
    }
    // Opens warningPopup with the given message — the single entry point
    // every error source below (scene load failures, bad theme.json, sound
    // playback errors) reports through.
    function reportWarning(message) {
        if (!message || !String(message).length) return
        warningPopup.warningMessage = String(message)
        root.openMenu(warningPopup)
    }

    // Journal/notices panel — reproduces the reference screenshot's layout
    // (dark top tab bar, cream sidebar list, off-white article area) using
    // journalbackground.png as the empty frame, with our own content on top.
    readonly property var noticeEntries: [
        {
            title: qsTr("Welcome to Genshin SDDM"),
            body: qsTr("The scene, the door, and the effects are all run by the original WebGL project. Authentication itself happens locally through SDDM, and no credentials are ever sent over the internet.")
        },
        {
            title: qsTr("About this theme"),
            body: qsTr("This login screen is a Genshin Impact-inspired 3D scene built for SDDM, with real system user, session, and power support layered on top of the original WebGL scene.")
        }
    ]
    readonly property var updateEntries: [
        {
            title: qsTr("Initial version"),
            body: qsTr("The first version of this theme only had the scene and the door animation — no customizable login panel, no session picker, no notices panel like this one.")
        },
        {
            title: qsTr("Version 1.1"),
            body: qsTr("Version 1.1 added the interface elements: an editable login panel, a session picker, theme music, and this tabbed notices panel.")
        }
    ]
    // 0 = Notices, 1 = Other themes, 2 = Updates
    property int selectedJournalTab: 0
    property int selectedNoticeIndex: 0
    onSelectedJournalTabChanged: root.selectedNoticeIndex = 0
    readonly property var journalListEntries: selectedJournalTab === 2 ? updateEntries : noticeEntries

    // One tab in the centered top bar: label + orange underline when active.
    // Item, not Column: Column (like Row) is a positioner and silently drops
    // *all* layout for *every* child the moment any one of them uses anchors
    // ("Column will not function") — which is exactly what made these tabs
    // disappear. Item has no such restriction.
    component JournalTab: Item {
        id: tabRoot
        property int tabIndex: 0
        property string label: ""
        implicitWidth: tabLabel.implicitWidth
        implicitHeight: tabLabel.implicitHeight + 8
        Text {
            id: tabLabel
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
            text: tabRoot.label
            color: root.selectedJournalTab === tabRoot.tabIndex ? "#f3f0e6" : "#9aa0ac"
            font.family: genshinFont.name
            font.pixelSize: Math.max(14, noticesMenu.height * 0.032)
            font.bold: root.selectedJournalTab === tabRoot.tabIndex
        }
        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; top: tabLabel.bottom; topMargin: 6 }
            width: tabLabel.width; height: 2
            color: "#e0793f"
            visible: root.selectedJournalTab === tabRoot.tabIndex
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedJournalTab = tabRoot.tabIndex }
    }

    Popup {
        id: noticesMenu
        anchors.centerIn: Overlay.overlay
        width: Math.min(1400, root.width * 0.85)
        // Sum of the two stacked background pieces' own aspect ratios (125px
        // tab strip + 1021px content, both 2048 wide) instead of one guessed
        // combined ratio.
        height: width * ((125 + 1021) / 2048)
        modal: true; focus: true; padding: 0
        closePolicy: Popup.NoAutoClose
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        Overlay.modal: Rectangle { color: "#52091018" }
        background: Item {
            Image {
                id: journalTabBackgroundImage
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: width * (125 / 2048)
                source: root.resolveAsset("journalTabBackground", "ui-assets/journaltabbackground.png")
                fillMode: Image.Stretch
            }
            Image {
                anchors { left: parent.left; right: parent.right; top: journalTabBackgroundImage.bottom; bottom: parent.bottom }
                source: root.selectedJournalTab === 1
                        ? root.resolveAsset("journalBackgroundEmpty", "ui-assets/journalbgempty.png")
                        : root.resolveAsset("journalBackground", "ui-assets/journalbg.png")
                fillMode: Image.Stretch
            }
        }
        contentItem: Item {
            anchors.fill: parent
            // Real bounds of the tab strip background piece above — the tabs
            // and × center against *this*, not a guessed fraction of the
            // whole modal.
            Item {
                id: journalTopStrip
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.width * (125 / 2048)
            }
            Row {
                id: journalTabRow
                anchors.centerIn: journalTopStrip
                anchors.verticalCenterOffset: 10
                spacing: 20
                JournalTab { tabIndex: 0; label: qsTr("Notices") }
                Text { text: "|"; color: "#5a6072"; font.pixelSize: Math.max(14, noticesMenu.height * 0.03); topPadding: 2 }
                JournalTab { tabIndex: 1; label: qsTr("Other themes") }
                Text { text: "|"; color: "#5a6072"; font.pixelSize: Math.max(14, noticesMenu.height * 0.03); topPadding: 2 }
                JournalTab { tabIndex: 2; label: qsTr("Updates") }
            }
            Button {
                anchors {
                    verticalCenter: journalTopStrip.verticalCenter
                    verticalCenterOffset: 10
                    right: parent.right
                    rightMargin: parent.width * 0.025
                }
                width: 34; height: 34
                background: Rectangle { radius: 17; color: "#f4f1ea" }
                contentItem: Text { text: "×"; color: "#3e4657"; font.pixelSize: 19; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.closeMenu(noticesMenu)
            }

            // "Outros temas": no sidebar, just the centered placeholder message.
            // Item, not Column — same "will not function" trap as JournalTab.
            Item {
                anchors.centerIn: parent
                visible: root.selectedJournalTab === 1
                width: Math.max(noAnnouncementsTitle.implicitWidth, noAnnouncementsSubtitle.implicitWidth)
                height: noAnnouncementsTitle.implicitHeight + 10 + noAnnouncementsSubtitle.implicitHeight
                Label {
                    id: noAnnouncementsTitle
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                    text: "No announcements yet"
                    color: "#3e4657"; font.family: genshinFont.name; font.bold: true
                    font.pixelSize: Math.max(20, noticesMenu.height * 0.06)
                }
                Label {
                    id: noAnnouncementsSubtitle
                    anchors { horizontalCenter: parent.horizontalCenter; top: noAnnouncementsTitle.bottom; topMargin: 10 }
                    text: "Let's look somewhere else!"
                    color: "#9aa0ac"; font.family: genshinFont.name
                    font.pixelSize: Math.max(13, noticesMenu.height * 0.03)
                }
            }

            // "Notícias" and "Atualizações": shared sidebar-list + article layout.
            ListView {
                id: noticeList
                visible: root.selectedJournalTab !== 1
                anchors {
                    left: parent.left; top: journalTopStrip.bottom; bottom: parent.bottom
                    leftMargin: parent.width * 0.025; rightMargin: parent.width * 0.02
                    topMargin: 24; bottomMargin: parent.height * 0.04
                }
                width: parent.width * 0.29
                spacing: 10; clip: true
                model: root.journalListEntries
                delegate: Rectangle {
                    width: noticeList.width; height: 62
                    radius: 6
                    color: index === root.selectedNoticeIndex ? "#fbfaf6" : "#f1ede2"
                    border.color: index === root.selectedNoticeIndex ? "#ddd6c4" : "transparent"; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22; rotation: 45
                            color: "transparent"; border.color: "#c0574f"; border.width: 2
                            Text { anchors.centerIn: parent; rotation: -45; text: "!"; color: "#c0574f"; font.bold: true; font.pixelSize: 12 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title; color: "#3e4657"; font.family: genshinFont.name; font.pixelSize: 14; font.bold: true
                            wrapMode: Text.WordWrap
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.selectedNoticeIndex = index }
                }
            }
            ColumnLayout {
                visible: root.selectedJournalTab !== 1
                anchors {
                    left: noticeList.right; right: parent.right; top: journalTopStrip.bottom; bottom: parent.bottom
                    leftMargin: parent.width * 0.025; rightMargin: parent.width * 0.03
                    topMargin: 24; bottomMargin: parent.height * 0.04
                }
                spacing: 14
                Label {
                    Layout.fillWidth: true
                    text: root.journalListEntries[root.selectedNoticeIndex].title
                    color: "#3e4657"; font.family: genshinFont.name; font.pixelSize: Math.max(16, noticesMenu.height * 0.045); font.bold: true
                    wrapMode: Text.WordWrap
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#ded8c8" }
                // Banner only on the Notícias tab, in the same spot the reference
                // mockup shows the "Genshin Impact Traveler Community" banner.
                Image {
                    Layout.fillWidth: true
                    // Capped to a share of the article area's own height instead
                    // of following width*aspect, which made it swallow almost
                    // all the space meant for the body text below it.
                    Layout.preferredHeight: noticesMenu.height * 0.3
                    visible: root.selectedJournalTab === 0 && root.selectedNoticeIndex === 0
                    source: root.resolveAsset("journalBanner", "ui-assets/banner.png")
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }
                Label {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    text: root.journalListEntries[root.selectedNoticeIndex].body
                    color: "#6b7180"; font.family: genshinFont.name; font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignTop
                }
            }
        }
    }
    GenshinPopup {
        id: repairMenu; height: 300
        contentItem: ColumnLayout {
            spacing: 18
            Label { Layout.fillWidth: true; Layout.topMargin: 28; text: qsTr("Verify file integrity"); color: "#3e4657"; font.family: genshinFont.name; font.pixelSize: 21; horizontalAlignment: Text.AlignHCenter }
            Image { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 72; Layout.preferredHeight: 72; source: root.assetRoot + "ui-assets/UI_Img_Repair.png" }
            Label { Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; text: qsTr("The theme's packaged files were found, and the WebGL scene loaded correctly."); color: "#626978"; font.family: genshinFont.name }
            Button { Layout.alignment: Qt.AlignHCenter; text: qsTr("Confirm"); onClicked: root.closeMenu(repairMenu) }
        }
    }
    // Environment/session picker modal — styled after the reference "select
    // ambient" screenshot rather than the shared GenshinPopup look.
    Popup {
        id: ambientMenu
        anchors.centerIn: Overlay.overlay
        width: Math.min(760, root.width - 80)
        height: width * (780 / 1221)
        modal: true; focus: true; padding: 0
        closePolicy: Popup.NoAutoClose
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        Overlay.modal: Rectangle { color: "#52091018" }
        background: Image {
            source: root.resolveAsset("ambientModalBg", "ui-assets/ambientmodal.png")
            fillMode: Image.Stretch
        }
        contentItem: Item {
            anchors.fill: parent
            Text {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: parent.height * 0.085 }
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Select session")
                color: "#e4c98a"; font.family: genshinFont.name; font.pixelSize: Math.max(20, parent.height * 0.045); font.bold: true
            }
            Button {
                id: ambientCloseButton
                anchors { top: parent.top; right: parent.right; topMargin: parent.height * 0.035; rightMargin: parent.width * 0.03 }
                width: 44; height: 44
                hoverEnabled: true
                opacity: ambientCloseButton.hovered ? 0.9 : 0.3
                Behavior on opacity { NumberAnimation { duration: 90 } }
                contentItem: Image {
                    anchors.centerIn: parent; width: 26; height: 26; fillMode: Image.PreserveAspectFit
                    source: root.resolveAsset("ambientModalCloseIcon", "ui-assets/ambientmodalclosebtn.png")
                }
                background: Item {}
                onClicked: root.closeMenu(ambientMenu)
            }
            ListView {
                id: ambientList
                anchors {
                    left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom
                    leftMargin: parent.width * 0.07; rightMargin: parent.width * 0.07
                    topMargin: parent.height * 0.19; bottomMargin: parent.height * 0.06
                }
                spacing: 12; clip: true
                model: root.adapter ? root.adapter.sessions : null
                onCountChanged: console.info("[GenshinTheme][sessions] ambientList (ListView) count changed:", count)
                delegate: Item {
                    id: optionRow
                    required property int index
                    required property var model
                    width: ambientList.width; height: 78
                    property bool hovered: false
                    readonly property string resolvedName: {
                        var raw = optionRow.model.modelData
                        if (typeof raw === "string" && raw.length > 0) return raw
                        var nm = optionRow.model.name
                        return nm !== undefined ? nm : ""
                    }
                    Component.onCompleted: console.info("[GenshinTheme][sessions] ambientList delegate created — index:", index,
                        "modelData:", optionRow.model.modelData, "model.name:", optionRow.model.name, "resolvedName:", resolvedName)
                    // Rests slightly inset and expands to the delegate's own full
                    // size on hover, instead of growing past it — growing past it
                    // let the border get cut off / covered by the next row, since
                    // it went beyond the space the ListView actually allocates.
                    BorderImage {
                        anchors.fill: parent
                        anchors.margins: optionRow.hovered ? 0 : 5
                        source: root.resolveAsset("ambientOptionBg", "ui-assets/ambient_modal_option.png")
                        border { left: 100; top: 10; right: 10; bottom: 10 }
                        Behavior on anchors.margins { NumberAnimation { duration: 90 } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: optionRow.hovered ? 0 : 5
                        color: "transparent"; radius: 8
                        border.color: "#e8c35a"; border.width: optionRow.hovered ? 2 : 0
                        Behavior on anchors.margins { NumberAnimation { duration: 90 } }
                    }
                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: root.sessionDisplayName(optionRow.resolvedName)
                        color: index === root.selectedSessionIndex ? "#f3dfa6" : "#e6ebf3"
                        font.family: genshinFont.name; font.pixelSize: 22; font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: optionRow.hovered = true
                        onExited: optionRow.hovered = false
                        onClicked: { root.selectedSessionIndex = index; root.playSound("clickSound", "sounds/switch_task.mp3"); root.closeMenu(ambientMenu) }
                    }
                }
            }
        }
    }
    GenshinPopup {
        id: shutdownConfirm
        width: Math.min(460, root.width - 80)
        closePolicy: Popup.CloseOnEscape
        background: Rectangle { color: "#ffffff"; radius: 18 }
        contentItem: ColumnLayout {
            spacing: 26
            Label {
                Layout.fillWidth: true; Layout.topMargin: 34; Layout.leftMargin: 30; Layout.rightMargin: 30
                text: qsTr("Shut down the computer?")
                color: "#2b2f38"; font.family: genshinFont.name; font.bold: true; font.pixelSize: 26
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 30; Layout.rightMargin: 30; Layout.bottomMargin: 30
                spacing: 16
                GenshinConfirmButton {
                    Layout.fillWidth: true; text: qsTr("Cancel"); filled: false
                    onClicked: root.closeMenu(shutdownConfirm)
                }
                GenshinConfirmButton {
                    Layout.fillWidth: true; text: qsTr("OK"); filled: true
                    onClicked: {
                        root.playSound("clickSound", "sounds/switch_task.mp3")
                        root.adapter.powerOff()
                        root.closeMenu(shutdownConfirm)
                    }
                }
            }
        }
    }
    Connections { target: controller; function onError(message) { errorText.text = message; password.selectAll(); password.forceActiveFocus() } }
}
