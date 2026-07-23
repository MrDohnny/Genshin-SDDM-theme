import QtQuick
import QtQuick3D
import QtQuick3D.AssetUtils
import QtQuick3D.Helpers
import "../themes/example/scripts"

Item {
    id: root
    signal layoutEditAreaTapped()
    signal sceneLoadFailed(string reason)
    signal sceneLoadSucceeded()
    signal webSceneEventDiscovered(string name)
    // Nothing gated the very first "tap anywhere to reveal the login panel"
    // on the scene actually having finished loading — a click during that
    // window (before any scene content, WebGL or Quick3D, was ready) still
    // fired the reveal/enterLogin sequence, permanently consuming the
    // theme's one-time "first interaction" state even though the user never
    // saw whatever prompt they were supposedly clicking. Scene load failure
    // also flips this so the overlay never becomes permanently unusable if
    // a theme's scene fails outright.
    property bool sceneReady: false
    onSceneLoadSucceeded: root.sceneReady = true
    // Also routed through the eventBus (not just this raw signal) so a
    // custom overlay can react to it generically — e.g. Genshin's overlay
    // shows this as an on-screen warning, since nothing on a real SDDM
    // login screen is ever watching the log this would otherwise only
    // reach.
    onSceneLoadFailed: function(reason) { root.sceneReady = true; events.emit("SceneLoadFailed", { reason: reason }) }
    required property var adapter
    property url themeRoot
    property url previewSceneUrl: ""
    property var manifest: ({})
    readonly property bool previewIsQml: String(previewSceneUrl).toLowerCase().endsWith(".qml")
    readonly property bool webScene: !!(manifest.scene && manifest.scene.format === "webgl")
    property var previewSettings: null
    property bool previewInputEnabled: true
    property var animationMapping: ({})
    property var webMapping: ({})
    property var packageWebMapping: ({})
    readonly property var effectiveWebMapping: Object.keys(webMapping).length > 0 ? webMapping : packageWebMapping
    function loadPackageWebMapping() {
        var request = new XMLHttpRequest()
        request.open("GET", root.themeRoot + "webgl-mapping.json")
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status !== 0 && request.status !== 200) { root.packageWebMapping = ({}); return }
            try { root.packageWebMapping = JSON.parse(request.responseText) }
            catch (error) { console.warn("Invalid webgl-mapping.json:", error); root.packageWebMapping = ({}) }
        }
        request.send()
    }
    property var cameraConfig: ({})
    property bool cameraEditMode: false
    property bool layoutEditMode: false
    property bool worldGridVisible: false
    property bool waitingForDoorAfterInteraction: false
    property var lightingSettings: null
    // Exposure belongs to the scene environment. Applying it to the lights as
    // well makes every positive EV adjustment count twice and clips highlights.
    readonly property real exposureMultiplier: lightingSettings ? Math.pow(2, lightingSettings.exposure) : 1
    property int navigationForward: 0
    property int navigationHorizontal: 0
    property int navigationVertical: 0
    property real navigationSpeedMultiplier: 1.0
    property real cameraYaw: cameraConfig.yaw !== undefined ? cameraConfig.yaw : 0
    property real cameraPitch: cameraConfig.pitch !== undefined ? cameraConfig.pitch : 0
    property real cameraPositionX: cameraConfig.position ? cameraConfig.position.x : (cameraConfig.target ? cameraConfig.target.x : 0)
    property real cameraPositionY: cameraConfig.position ? cameraConfig.position.y : (cameraConfig.target ? cameraConfig.target.y : 0)
    property real cameraPositionZ: cameraConfig.position ? cameraConfig.position.z : ((cameraConfig.target ? cameraConfig.target.z : 0) + (cameraConfig.distance || 600))
    function moveCameraOnScreen(forwardAmount, horizontalAmount, verticalAmount) {
        var speed = Math.max(2, Math.abs(cameraPositionZ) * 0.012) * 0.18 * navigationSpeedMultiplier
        var forward = fallbackCamera.forward
        var right = fallbackCamera.right
        var vx = forward.x * forwardAmount + right.x * horizontalAmount
        var vy = forward.y * forwardAmount + right.y * horizontalAmount + verticalAmount
        var vz = forward.z * forwardAmount + right.z * horizontalAmount
        var length = Math.sqrt(vx * vx + vy * vy + vz * vz)
        if (length > 0) { vx /= length; vy /= length; vz /= length }
        fallbackCamera.position = Qt.vector3d(
            fallbackCamera.position.x + vx * speed,
            fallbackCamera.position.y + vy * speed,
            fallbackCamera.position.z + vz * speed)
    }
    function resetCamera() {
        fallbackCamera.position = Qt.vector3d(0, 0, 600)
        fallbackCamera.setEulerRotation(Qt.vector3d(0, 0, 0))
    }
    Timer {
        interval: 16
        repeat: true
        running: root.cameraEditMode && (root.navigationForward !== 0 || root.navigationHorizontal !== 0 || root.navigationVertical !== 0)
        onTriggered: root.moveCameraOnScreen(root.navigationForward, root.navigationHorizontal, root.navigationVertical)
    }

    ManifestLoader {
        id: manifestLoader
        source: root.themeRoot + "theme.json"
        onLoaded: function(value) {
            root.manifest = value
            if (value.scene.format === "webgl") root.loadPackageWebMapping()
            else root.packageWebMapping = ({})
            // A previously-imported theme's 3D model must not linger once
            // switching to a webgl (or empty) scene. It stays invisible
            // either way (View3D's own "visible: !root.webScene" binding),
            // but leaving it loaded wastes memory and — since View3D has no
            // explicit z while WebSceneRuntime is z: 1 — sits at a lower
            // layer than the new WebGL scene, so any edge case in that
            // visibility binding shows the old scene right through the new
            // one instead of nothing. Previously this reset only happened
            // for format "none", not "webgl", leaving stale buttons/models
            // from the last-imported theme visible behind the new one.
            if (!root.previewSceneUrl) {
                if (value.scene.format !== "webgl" && value.scene.format !== "none")
                    sceneLoader.source = root.themeRoot + value.scene.file
                else
                    sceneLoader.source = ""
            }
            if (value.scene.format === "webgl") webRuntime.source = root.themeRoot + value.scene.file + "?sddm=1"
            else webRuntime.source = ""
            if (value.scene.format === "none") {
                root.sceneLoadSucceeded()
                events.emit("SceneLoaded", { empty: true })
            }
            animations.durations = {
                "LoginFailed": value.animations.LoginFailed.durationMs,
                "AuthenticationProcessing": value.animations.AuthenticationProcessing.durationMs
            }
            events.emit("ThemeLoaded", { name: value.name, version: value.version })
        }
        onFailed: function(message) { console.error("Invalid theme:", message); root.sceneLoadFailed("Invalid theme: " + message) }
    }

    EventBus { id: events }
    PluginRegistry { id: plugins }
    TransitionLayer { id: transition; anchors.fill: parent }

    View3D {
        id: view
        anchors.fill: parent
        visible: !root.webScene
        environment: SceneEnvironment {
            id: sceneEnvironment
            clearColor: "#080b12"
            backgroundMode: root.previewSettings && root.previewSettings.backgroundImage.toString().length > 0 ? SceneEnvironment.Transparent : SceneEnvironment.Color
            tonemapMode: root.lightingSettings && root.lightingSettings.toneMapping === "ACES Filmic"
                         ? SceneEnvironment.TonemapModeAces : SceneEnvironment.TonemapModeLinear
            probeExposure: root.exposureMultiplier
            lightProbe: root.lightingSettings && root.lightingSettings.environment === "Custom HDRI"
                        && root.lightingSettings.environmentMap.toString().length > 0 ? environmentProbe : null
            InfiniteGrid { visible: root.cameraEditMode && root.worldGridVisible; gridInterval: 100; gridAxes: true }
        }
        Texture {
            id: environmentProbe
            source: root.lightingSettings ? root.lightingSettings.environmentMap : ""
            mappingMode: Texture.LightProbe
        }
        PerspectiveCamera {
            id: fallbackCamera
            Component.onCompleted: {
                position = Qt.vector3d(root.cameraPositionX, root.cameraPositionY, root.cameraPositionZ)
                setEulerRotation(Qt.vector3d(root.cameraPitch, root.cameraYaw, 0))
            }
            onPositionChanged: if (root.cameraEditMode) {
                root.cameraPositionX = position.x
                root.cameraPositionY = position.y
                root.cameraPositionZ = position.z
            }
            onEulerRotationChanged: if (root.cameraEditMode) {
                root.cameraPitch = Math.max(-89, Math.min(89, eulerRotation.x))
                root.cameraYaw = eulerRotation.y
            }
        }
        camera: fallbackCamera
        DirectionalLight {
            visible: root.lightingSettings && root.lightingSettings.punctualLights
            brightness: root.lightingSettings ? root.lightingSettings.directIntensity : 1
            color: root.lightingSettings ? root.lightingSettings.directColor : "#ffffff"
            eulerRotation.x: -25; eulerRotation.y: -25
        }
        DirectionalLight {
            visible: root.lightingSettings && root.lightingSettings.punctualLights
            brightness: root.lightingSettings ? root.lightingSettings.ambientIntensity : 0.1
            color: root.lightingSettings ? root.lightingSettings.ambientColor : "#ffffff"
            eulerRotation.x: -15; eulerRotation.y: 145
        }
        DirectionalLight {
            visible: root.lightingSettings && root.lightingSettings.punctualLights
            brightness: root.lightingSettings ? root.lightingSettings.ambientIntensity : 0.1
            color: root.lightingSettings ? root.lightingSettings.ambientColor : "#ffffff"
            eulerRotation.x: -80; eulerRotation.y: 15
        }
        DirectionalLight {
            visible: root.lightingSettings && root.lightingSettings.punctualLights
            brightness: root.lightingSettings ? root.lightingSettings.ambientIntensity : 0.1
            color: root.lightingSettings ? root.lightingSettings.ambientColor : "#ffffff"
            eulerRotation.x: 35; eulerRotation.y: -110
        }
        RuntimeLoader {
            id: sceneLoader
            source: ""
            visible: !root.previewIsQml && !root.webScene
            onBoundsChanged: {
                if (status !== RuntimeLoader.Success || root.previewIsQml) return
                var center = Qt.vector3d((bounds.minimum.x + bounds.maximum.x) / 2,
                                         (bounds.minimum.y + bounds.maximum.y) / 2,
                                         (bounds.minimum.z + bounds.maximum.z) / 2)
                var sizeX = bounds.maximum.x - bounds.minimum.x
                var sizeY = bounds.maximum.y - bounds.minimum.y
                var sizeZ = bounds.maximum.z - bounds.minimum.z
                var diameter = Math.max(sizeX, sizeY, sizeZ, 1)
                position = Qt.vector3d(-center.x, -center.y, -center.z)
                if (!root.cameraConfig.position && !root.cameraConfig.distance) {
                    fallbackCamera.position = Qt.vector3d(0, 0, diameter * 1.8)
                }
                fallbackCamera.clipFar = Math.max(10000, diameter * 10)
            }
            onStatusChanged: {
                if (status === RuntimeLoader.Success) {
                    root.sceneLoadSucceeded()
                    animations.discoverAnimations()
                    events.emit("SceneLoaded")
                    animations.idle()
                } else if (status === RuntimeLoader.Error) {
                    root.sceneLoadFailed(qsTr("O Qt não conseguiu carregar a cena 3D original. Verifique se o arquivo e suas dependências são compatíveis."))
                    console.warn("3D scene could not be loaded; overlay remains usable")
                    events.emit("SceneLoaded", { degraded: true })
                    animations.idle()
                }
            }
        }
        Loader3D {
            id: convertedSceneLoader
            active: root.previewIsQml
            source: root.previewIsQml ? root.previewSceneUrl : ""
            onStatusChanged: {
                if (status === Loader3D.Ready) {
                    root.sceneLoadSucceeded()
                    animations.registerTimelinesFrom(item)
                    events.emit("SceneLoaded", { converted: true })
                    animations.idle()
                }
                else if (status === Loader3D.Error) {
                    var reason = qsTr("O Qt não conseguiu instanciar a cena convertida. O arquivo pode usar um recurso, material ou extensão não suportada.")
                    console.error(reason)
                    root.sceneLoadFailed(reason)
                }
            }
        }
    }
    WebSceneRuntime {
        id: webRuntime
        anchors.fill: parent
        visible: root.webScene
        z: 1
        mapping: root.effectiveWebMapping
        onSceneEvent: function(name) {
            root.webSceneEventDiscovered(name)
            var eventMap = root.effectiveWebMapping.events || ({})
            var logicalName = eventMap[name] || name
            events.emit("WebSceneEvent", { name: name })
            if (logicalName === "SceneReady") {
                root.sceneLoadSucceeded()
                if (overlay.showInstantly) animations.enterLogin()
            }
            if (logicalName === "PanelReveal") {
                animations.panelActive = true
                panelRevealDelay.interval = root.effectiveWebMapping.panelRevealDelayMs !== undefined ? root.effectiveWebMapping.panelRevealDelayMs : 0
                panelRevealDelay.restart()
            }
            if (logicalName === "PanelConceal") overlay.conceal()
        }
        onLoadFailed: function(reason) { root.sceneLoadFailed(reason) }
    }
    Timer {
        id: panelRevealDelay
        interval: 280
        repeat: false
        onTriggered: overlay.reveal()
    }
    SceneAnimationController {
        id: animations
        runtimeLoader: sceneLoader
        webRuntime: webRuntime
        eventBus: events
        timelineMapping: root.webScene ? ({}) : root.animationMapping
    }
    Connections {
        target: animations
        function onFinished(name) {
            if (name === "EnterLogin" && overlay.revealAfterEnterLogin && !root.webScene) overlay.reveal()
        }
    }
    Connections {
        target: events
        function onEvent(name, payload) {
            if (name === "AuthenticationStarted" && root.webScene) overlay.conceal()
            if (name === "LoginFailure" && root.webScene) {
                overlay.conceal()
            }
        }
    }
    SceneApi {
        id: sceneApi
        animationController: animations; sceneRoot: sceneLoader; view: view
        transition: transition; pluginRegistry: plugins
        cameras: ({ "fallback": fallbackCamera })
        objects: ({ "scene": sceneLoader })
    }
    LoginController { id: login; adapter: root.adapter; eventBus: events; animations: animations }
    InputRouter {
        anchors.fill: parent
        z: 2
        enabled: root.previewInputEnabled
        eventBus: events
        animations: animations
        panelActivationRequired: !overlay.showInstantly && !overlay.revealed && root.sceneReady
        onPanelActivationRequested: {
            if (!overlay.revealAfterEnterLogin) overlay.reveal()
            animations.enterLogin()
        }
    }
    Item {
        id: cameraNavigation
        anchors.fill: parent
        z: 1900
        visible: root.cameraEditMode
        enabled: visible
        property bool hasPreviousPoint: false
        property point previousPoint: Qt.point(0, 0)
        DragHandler {
            id: cameraDrag
            target: null
            enabled: root.cameraEditMode
            acceptedButtons: Qt.LeftButton
            onActiveChanged: {
                cameraNavigation.hasPreviousPoint = active
                cameraNavigation.previousPoint = centroid.position
            }
            onCentroidChanged: {
                if (!active || !cameraNavigation.hasPreviousPoint) return
                var current = centroid.position
                var dx = current.x - cameraNavigation.previousPoint.x
                var dy = current.y - cameraNavigation.previousPoint.y
                if (Math.abs(dx) < cameraNavigation.width * 0.45 && Math.abs(dy) < cameraNavigation.height * 0.45) {
                    var rotation = fallbackCamera.eulerRotation
                    fallbackCamera.setEulerRotation(Qt.vector3d(
                        Math.max(-89, Math.min(89, rotation.x - dy * 0.16)),
                        (rotation.y - dx * 0.16) % 360,
                        0))
                }
                cameraNavigation.previousPoint = current
            }
        }
    }
    onCameraEditModeChanged: cameraNavigation.hasPreviousPoint = false
    OverlayHost {
        id: overlay
        z: 3
        anchors.fill: parent; loginController: login; eventBus: events; adapter: root.adapter
        visible: !root.cameraEditMode
        sizeEditable: !(root.manifest.overlay && root.manifest.overlay.sizeEditable === false)
        showInstantly: !root.previewSettings || root.previewSettings.showInstantly
        revealAfterEnterLogin: root.previewSettings && root.previewSettings.panelAfterEnterLogin
        externalRevealControl: root.webScene
        customOverlayComponent: root.manifest.overlay && root.manifest.overlay.component ? root.manifest.overlay.component : ""
        themeRoot: root.themeRoot
        sceneRuntime: webRuntime
        // Who appears logged in initially is always the real system's own
        // last-logged-in user (SDDM's UserModel.lastUser) — never something
        // configured from the theme editor, since the actual account list
        // shown on the login screen is entirely defined by the machine's own
        // users, not by this tool.
        initialUsername: root.adapter && root.adapter.lastUsername ? root.adapter.lastUsername : ""
        panelWidth: root.previewSettings ? root.previewSettings.panelWidth : 520
        panelHeight: root.previewSettings ? root.previewSettings.panelHeight : 390
        panelXPercent: root.previewSettings ? root.previewSettings.panelXPercent : 50
        panelYPercent: root.previewSettings ? root.previewSettings.panelYPercent : 50
        panelColor: root.previewSettings ? root.previewSettings.panelColor : "#111827"
        panelOpacity: root.previewSettings ? root.previewSettings.panelOpacityPercent / 100 : 0.8
        inputColor: root.previewSettings ? root.previewSettings.inputColor : "#f7ffffff"
        inputTextColor: root.previewSettings ? root.previewSettings.inputTextColor : "#111827"
        inputHeight: root.previewSettings ? root.previewSettings.inputHeight : 48
        inputRadius: root.previewSettings ? root.previewSettings.inputRadius : 6
        inputFontSize: root.previewSettings ? root.previewSettings.inputFontSize : 16
        panelBackgroundSource: root.previewSettings ? root.previewSettings.panelBackgroundImage : ""
        fontSource: root.previewSettings ? root.previewSettings.fontSource : ""
        fontFamily: root.previewSettings ? root.previewSettings.fontFamily : ""
        titleText: root.previewSettings ? root.previewSettings.titleText : "Welcome"
        titleAlignment: root.previewSettings ? root.previewSettings.titleAlignment : "left"
        titleFontSize: root.previewSettings ? root.previewSettings.titleFontSize : 28
        loginButtonColor: root.previewSettings ? root.previewSettings.loginButtonColor : "#2563eb"
        loginButtonTextColor: root.previewSettings ? root.previewSettings.loginButtonTextColor : "white"
        loginButtonRadius: root.previewSettings ? root.previewSettings.loginButtonRadius : 8
        loginButtonIcon: root.previewSettings ? root.previewSettings.loginButtonIcon : ""
        loginButtonHoverIcon: root.previewSettings ? root.previewSettings.loginButtonHoverIcon : ""
        sessionColor: root.previewSettings ? root.previewSettings.sessionColor : "#f7ffffff"
        sessionTextColor: root.previewSettings ? root.previewSettings.sessionTextColor : "#111827"
        restartIcon: root.previewSettings ? root.previewSettings.restartIcon : ""
        shutdownIcon: root.previewSettings ? root.previewSettings.shutdownIcon : ""
        imageButtons: root.previewSettings ? root.previewSettings.imageButtons : false
        sessionInPowerMenu: root.previewSettings ? root.previewSettings.sessionInPowerMenu : false
        sessionClosedIcon: root.previewSettings ? root.previewSettings.sessionClosedIcon : ""
        sessionOpenIcon: root.previewSettings ? root.previewSettings.sessionOpenIcon : ""
        extraActions: root.previewSettings ? root.previewSettings.extraActions : null
        editableSettings: root.previewSettings
        editMode: root.layoutEditMode
        onEditAreaTapped: root.layoutEditAreaTapped()
        // Same effect as InputRouter's panelActivationRequested above — a
        // custom overlay's own button (e.g. an "account" corner button) can
        // ask for the real door-animation entry sequence instead of calling
        // reveal()/conceal() directly and skipping it, the same bug fixed
        // earlier for the generic full-screen tap-to-reveal handler.
        onRequestEnterLogin: {
            if (!overlay.revealAfterEnterLogin) overlay.reveal()
            animations.enterLogin()
        }
    }
    ExampleBehavior { scene: sceneApi; events: events }

    onPreviewSceneUrlChanged: {
        if (!previewIsQml && !webScene && previewSceneUrl) sceneLoader.source = previewSceneUrl
        else if (previewIsQml) sceneLoader.source = ""
    }
    Component.onDestruction: { events.emit("SceneUnload"); events.emit("ThemeUnloaded") }
}
