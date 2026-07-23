import QtQuick
import "core"
import "adapters"

Item {
    id: root
    width: 1920
    height: 1080

    QtObject {
        id: previewSettings
        property bool showInstantly: false
        property bool panelAfterEnterLogin: true
        property int panelWidth: 520
        property int panelHeight: 390
        property int panelXPercent: 50
        property int panelYPercent: 50
        property url backgroundImage: ""
        property int inputHeight: 48
        property int inputFontSize: 16
        property int inputRadius: 6
        property int panelOpacityPercent: 80
        property string panelColor: "#111827"
        property string inputColor: "#f7ffffff"
        property string inputTextColor: "#111827"
        property url panelBackgroundImage: ""
        property url fontSource: ""
        property string fontFamily: ""
        property string titleText: "Welcome"
        property string titleAlignment: "left"
        property int titleFontSize: 28
        property string loginButtonColor: "#2563eb"
        property string loginButtonTextColor: "#ffffff"
        property int loginButtonRadius: 8
        property url loginButtonIcon: ""
        property url loginButtonHoverIcon: ""
        property string sessionColor: "#f7ffffff"
        property string sessionTextColor: "#111827"
        property bool sessionInPowerMenu: false
        property bool imageButtons: false
        property url sessionClosedIcon: ""
        property url sessionOpenIcon: ""
        property url restartIcon: ""
        property url restartHoverIcon: ""
        property url shutdownIcon: ""
        property url shutdownHoverIcon: ""
        property int powerXPercent: 90
        property int powerYPercent: 92
        property var extraActions: null
    }
    // This theme (mode: "custom", see theme/theme.json) draws its own card,
    // inputs and buttons entirely from its own assets/slots — none of the
    // generic panel styling above (panelColor, inputColor, titleText, ...)
    // is actually visible. It's still provided in full because the engine's
    // OverlayHost always instantiates the generic login panel and power
    // menu underneath the custom overlay (just invisible), and expects
    // every one of these properties to exist.
    Image {
        anchors.fill: parent
        source: previewSettings.backgroundImage
        fillMode: Image.PreserveAspectCrop
        visible: source.toString().length > 0
    }
    // Same reasoning as previewSettings above: the fallback Qt Quick 3D
    // scene/lighting pipeline in ThemeRuntime only matters for glTF-based
    // themes. This theme's scene is WebGL (theme/theme.json: scene.format
    // "webgl"), so the Quick3D view stays invisible the entire time and
    // none of this is ever seen — kept only because ThemeRuntime expects a
    // lightingSettings object to exist.
    QtObject {
        id: lighting
        property string environment: "Neutral"
        property url environmentMap: ""
        property string toneMapping: "ACES Filmic"
        property real exposure: 0
        property bool punctualLights: true
        property real ambientIntensity: 0.1
        property color ambientColor: "#ffffff"
        property real directIntensity: 1.0
        property color directColor: "#ffffff"
    }
    SddmAdapter {
        id: adapter
        sddmObject: sddm
        sessionModelSource: sessionModel
        userModelSource: userModel
        keyboardModel: keyboard
        // SDDM's own greeter engine sets this (a plain string context
        // property) when it detects the configured theme failed to load —
        // the same mechanism its own built-in fallback theme uses to show
        // "why". Guarded since older SDDM versions may not register it.
        sddmErrorsSource: typeof __sddm_errors !== "undefined" ? __sddm_errors : ""
    }
    ThemeRuntime {
        anchors.fill: parent
        adapter: adapter
        themeRoot: Qt.resolvedUrl("theme/")
        previewSceneUrl: ""
        animationMapping: ({})
        cameraConfig: ({})
        previewSettings: previewSettings
        lightingSettings: lighting
    }
}
