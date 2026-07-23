import QtQuick
import "../../../core"

ThemeScript {
    function onThemeEvent(name, payload) {
        if (name === "LoginFailure") scene.fade(0.22, 80)
        if (name === "BeforeIdle") scene.fade(0, 350)
    }
}
