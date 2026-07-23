import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: root
    required property var controller
    required property var events
    property var sessions: []
    property string initialUsername: ""
    property bool usernameLocked: false
    property color panelColor: "#111827"
    property real panelOpacity: 0.8
    property color inputColor: "#f7ffffff"
    property color inputTextColor: "#111827"
    property int inputHeight: 48
    property int inputRadius: 6
    property int inputFontSize: 16
    property url panelBackgroundSource: ""
    readonly property bool animatedPanelBackground: /\.gif($|\?)/i.test(panelBackgroundSource.toString())
    property url fontSource: ""
    property string fontFamily: ""
    property string titleText: qsTr("Welcome")
    property string titleAlignment: "left"
    property int titleFontSize: 28
    property color loginButtonColor: "#2563eb"
    property color loginButtonTextColor: "white"
    property int loginButtonRadius: 8
    property url loginButtonIcon: ""
    property url loginButtonHoverIcon: ""
    readonly property alias loginButtonControl: loginButton
    property color sessionColor: inputColor
    property color sessionTextColor: inputTextColor
    property bool sessionSelectorExternal: false
    property int selectedSessionIndex: 0
    FontLoader { id: customFont; source: root.fontSource }
    readonly property string selectedFontFamily: customFont.status === FontLoader.Ready ? customFont.name : root.fontFamily
    padding: 24
    background: Rectangle {
        radius: 14; color: root.panelColor; opacity: root.panelOpacity
        border.color: "#4080a0c0"; clip: true
        Image {
            anchors.fill: parent; source: root.panelBackgroundSource
            fillMode: Image.PreserveAspectCrop
            visible: source.toString().length > 0 && !root.animatedPanelBackground
        }
        AnimatedImage {
            anchors.fill: parent; source: root.animatedPanelBackground ? root.panelBackgroundSource : ""
            fillMode: Image.PreserveAspectCrop; playing: visible
            visible: root.animatedPanelBackground
        }
        Rectangle { anchors.fill: parent; color: root.panelColor; opacity: root.panelOpacity; visible: root.panelBackgroundSource.toString().length > 0 }
    }

    ColumnLayout {
        anchors.fill: parent
        Label {
            Layout.fillWidth: true; text: root.titleText; font.pixelSize: root.titleFontSize; color: "white"
            font.family: root.selectedFontFamily
            horizontalAlignment: root.titleAlignment === "center" ? Text.AlignHCenter : root.titleAlignment === "right" ? Text.AlignRight : Text.AlignLeft
        }
        TextField {
            id: username; Layout.fillWidth: true; Layout.preferredHeight: root.inputHeight; placeholderText: qsTr("Username")
            text: root.initialUsername; readOnly: root.usernameLocked; font.pixelSize: root.inputFontSize; font.family: root.selectedFontFamily; color: root.inputTextColor
            background: Rectangle { color: root.inputColor; radius: root.inputRadius; border.color: username.activeFocus ? "#60a5fa" : "#506070" }
            onActiveFocusChanged: if (activeFocus) events.emit("UsernameFocused")
            onTextChanged: events.emit("FieldChanged", { field: "username" })
        }
        TextField {
            id: password; Layout.fillWidth: true; Layout.preferredHeight: root.inputHeight; placeholderText: qsTr("Password"); echoMode: TextInput.Password
            font.pixelSize: root.inputFontSize; font.family: root.selectedFontFamily; color: root.inputTextColor
            background: Rectangle { color: root.inputColor; radius: root.inputRadius; border.color: password.activeFocus ? "#60a5fa" : "#506070" }
            onActiveFocusChanged: if (activeFocus) events.emit("PasswordFocused")
            onTextChanged: events.emit("FieldChanged", { field: "password" })
            onAccepted: submit()
        }
        ComboBox {
            id: session; Layout.fillWidth: true; model: root.sessions
            visible: !root.sessionSelectorExternal
            Layout.preferredHeight: root.inputHeight
            font.family: root.selectedFontFamily; font.pixelSize: root.inputFontSize
            contentItem: Text { text: session.displayText; color: root.sessionTextColor; font: session.font; verticalAlignment: Text.AlignVCenter; leftPadding: 14; rightPadding: 42; elide: Text.ElideRight }
            indicator: Rectangle {
                x: session.width - width - 8; y: (session.height - height) / 2
                width: 30; height: 30; radius: 7; color: session.down ? "#2563eb" : "#334155"
                Text { anchors.centerIn: parent; text: "▾"; color: "white"; font.pixelSize: 18; font.bold: true }
            }
            background: Rectangle {
                color: root.sessionColor; radius: Math.max(8, root.inputRadius)
                border.color: session.activeFocus || session.down ? "#60a5fa" : "#64748b"
                border.width: session.activeFocus || session.down ? 2 : 1
            }
        }
        Label { id: error; Layout.fillWidth: true; color: "#ff8a8a"; visible: text.length > 0 }
        Button {
            id: loginButton
            Layout.fillWidth: true; text: controller.authenticating ? qsTr("Authenticating…") : qsTr("Login")
            enabled: !controller.authenticating
            font.family: root.selectedFontFamily
            contentItem: Item {
                Image {
                    anchors.fill: parent; anchors.margins: 4
                    source: loginButton.hovered && root.loginButtonHoverIcon.toString().length
                            ? root.loginButtonHoverIcon : root.loginButtonIcon
                    fillMode: Image.PreserveAspectFit
                    visible: source.toString().length > 0
                }
                Text {
                    anchors.fill: parent; text: loginButton.text; color: root.loginButtonTextColor
                    font: loginButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    visible: root.loginButtonIcon.toString().length === 0
                }
            }
            background: Rectangle { color: root.loginButtonColor; radius: root.loginButtonRadius; opacity: parent.enabled ? 1 : 0.5 }
            onClicked: submit()
        }
    }
    function submit() { error.text = ""; controller.login(username.text, password.text, root.sessionSelectorExternal ? root.selectedSessionIndex : session.currentIndex) }
    Connections { target: controller; function onError(message) { error.text = message; password.selectAll(); password.forceActiveFocus() } }
}
