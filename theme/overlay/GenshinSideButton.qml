import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Button {
    id: root
    property url imageSource: ""
    property string symbol: ""
    property string caption: ""
    width: 58
    height: 58
    hoverEnabled: true
    contentItem: Item {
        Image {
            id: cornerIcon
            anchors.centerIn: parent
            width: 34; height: 34
            source: root.imageSource
            fillMode: Image.PreserveAspectFit
            // Several of the extracted game icons (Quit/AddAccount/Notice)
            // are pure white silhouettes meant to sit on the game's own dark
            // UI — invisible against this button's light cream background.
            // Tint them dark so they're visible without needing new assets.
            visible: false
            opacity: root.enabled ? 0.92 : 0.4
        }
        MultiEffect {
            anchors.fill: cornerIcon
            source: cornerIcon
            visible: cornerIcon.source.toString().length > 0
            opacity: cornerIcon.opacity
            colorization: 1.0
            colorizationColor: "#4f586b"
        }
        Text {
            anchors.centerIn: parent
            text: root.symbol
            visible: root.imageSource.toString().length === 0
            color: root.hovered ? "#3b4255" : "#566077"
            font.pixelSize: 27
            font.family: "sans-serif"
        }
    }
    background: Rectangle {
        radius: width / 2
        color: root.down ? "#e2d6bd" : root.hovered ? "#fffdf7" : "#edf0f4"
        border.color: root.hovered ? "#c9a96b" : "#b9c0ca"
        border.width: root.hovered ? 2 : 1
        Behavior on color { ColorAnimation { duration: 90 } }
    }
    ToolTip.visible: hovered
    ToolTip.text: caption
    ToolTip.delay: 250
}
