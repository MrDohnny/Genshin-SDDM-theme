import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: buttonRow.implicitWidth
    implicitHeight: 56
    required property var adapter
    property url restartIcon: ""
    property url shutdownIcon: ""
    property url restartHoverIcon: ""
    property url shutdownHoverIcon: ""
    property bool imageButtons: false
    property bool sessionInPowerMenu: false
    property url sessionClosedIcon: ""
    property url sessionOpenIcon: ""
    property int currentSessionIndex: 0
    property bool editMode: false
    property var settings: null
    property var extraActions: null
    property string fontFamily: ""
    signal imageRequested(string key)
    signal sessionSelected(int index)

    function sessionLabel(index) {
        if (!adapter || !adapter.sessions || index < 0) return qsTr("Sessão")
        var entry = adapter.sessions[index]
        if (entry === undefined && adapter.sessions.get) entry = adapter.sessions.get(index)
        if (typeof entry === "string") return entry
        return entry && (entry.name || entry.display || entry.label) ? (entry.name || entry.display || entry.label) : qsTr("Sessão")
    }

    RowLayout {
        id: buttonRow
        height: parent.height
        spacing: 8

        Button {
            id: sessionButton
            visible: root.sessionInPowerMenu
            Layout.preferredWidth: root.imageButtons ? 56 : Math.max(104, implicitWidth)
            Layout.preferredHeight: 56
            text: root.imageButtons ? "" : root.sessionLabel(root.currentSessionIndex)
            font.family: root.fontFamily
            contentItem: Item {
                Image {
                    anchors.fill: parent; anchors.margins: 5
                    source: sessionPopup.opened ? root.sessionOpenIcon : root.sessionClosedIcon
                    fillMode: Image.PreserveAspectFit
                    visible: root.imageButtons && source.toString().length > 0
                }
                Text {
                    anchors.fill: parent; text: sessionButton.text; color: sessionButton.palette.buttonText
                    font: sessionButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight; visible: !root.imageButtons
                }
            }
            onClicked: if (!root.editMode) sessionPopup.opened ? sessionPopup.close() : sessionPopup.open()
        }
        Button {
            id: restartButton
            Layout.preferredWidth: root.imageButtons ? 56 : 104; Layout.preferredHeight: 56
            text: root.imageButtons ? "" : qsTr("Reiniciar")
            font.family: root.fontFamily
            contentItem: Item {
                Image { anchors.fill: parent; anchors.margins: 5; source: restartButton.hovered && root.restartHoverIcon.toString().length ? root.restartHoverIcon : root.restartIcon; fillMode: Image.PreserveAspectFit; visible: root.imageButtons && source.toString().length > 0 }
                Text { anchors.fill: parent; text: restartButton.text; color: restartButton.palette.buttonText; font: restartButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; visible: !root.imageButtons }
            }
            onClicked: if (!root.editMode) root.adapter.reboot()
            ImagePickerButton { anchors.centerIn: parent; visible: root.editMode && root.imageButtons; z: 10; onClicked: root.imageRequested("restartIcon") }
        }
        Button {
            id: shutdownButton
            Layout.preferredWidth: root.imageButtons ? 56 : 104; Layout.preferredHeight: 56
            text: root.imageButtons ? "" : qsTr("Desligar")
            font.family: root.fontFamily
            contentItem: Item {
                Image { anchors.fill: parent; anchors.margins: 5; source: shutdownButton.hovered && root.shutdownHoverIcon.toString().length ? root.shutdownHoverIcon : root.shutdownIcon; fillMode: Image.PreserveAspectFit; visible: root.imageButtons && source.toString().length > 0 }
                Text { anchors.fill: parent; text: shutdownButton.text; color: shutdownButton.palette.buttonText; font: shutdownButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; visible: !root.imageButtons }
            }
            onClicked: if (!root.editMode) root.adapter.powerOff()
            ImagePickerButton { anchors.centerIn: parent; visible: root.editMode && root.imageButtons; z: 10; onClicked: root.imageRequested("shutdownIcon") }
        }
        Repeater {
            model: root.extraActions
            delegate: Button {
                required property string label
                required property string actionName
                required property string iconSource
                Layout.preferredHeight: 56
                text: root.imageButtons ? "" : label
                icon.source: root.imageButtons ? iconSource : ""
                font.family: root.fontFamily
                onClicked: {
                    if (actionName === "suspend") root.adapter.suspend()
                    else if (actionName === "hibernate") root.adapter.hibernate()
                    else if (actionName === "reboot") root.adapter.reboot()
                    else if (actionName === "powerOff") root.adapter.powerOff()
                }
            }
        }
    }

    Popup {
        id: sessionPopup
        parent: root
        x: sessionButton.x
        y: -height - 8
        width: Math.max(220, sessionButton.width)
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#ee172230"; border.color: "#64748b"; radius: 10 }
        contentItem: ColumnLayout {
            spacing: 4
            Repeater {
                model: root.adapter ? root.adapter.sessions : null
                delegate: Button {
                    required property int index
                    Layout.fillWidth: true
                    text: root.sessionLabel(index)
                    highlighted: index === root.currentSessionIndex
                    onClicked: { root.sessionSelected(index); sessionPopup.close() }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent; visible: root.editMode; color: "transparent"; border.color: "#ffcc36"; border.width: 2; z: 20
        DragHandler {
            target: null
            property real startCenterX: 0
            property real startCenterY: 0
            onActiveChanged: if (active) { startCenterX = root.x + root.width / 2; startCenterY = root.y + root.height / 2 }
            onTranslationChanged: {
                if (!active || !root.settings) return
                root.settings.powerXPercent = Math.round(Math.max(0, Math.min(100, (startCenterX + translation.x) / root.parent.width * 100)))
                root.settings.powerYPercent = Math.round(Math.max(0, Math.min(100, (startCenterY + translation.y) / root.parent.height * 100)))
            }
        }
    }
}
