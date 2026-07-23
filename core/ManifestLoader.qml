import QtQuick

QtObject {
    id: root
    property url source
    property var data: ({})
    property string error: ""
    signal loaded(var manifest)
    signal failed(string message)
    onSourceChanged: if (source) load()

    function load() {
        var request = new XMLHttpRequest()
        request.open("GET", source)
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status !== 0 && request.status !== 200) {
                error = "Cannot read theme manifest (HTTP " + request.status + ")"
                failed(error); return
            }
            try {
                var parsed = JSON.parse(request.responseText)
                var required = ["name", "author", "version", "compatibility", "scene", "animations"]
                for (var i = 0; i < required.length; ++i)
                    if (parsed[required[i]] === undefined) throw new Error("Missing field: " + required[i])
                var clips = ["Idle", "EnterLogin", "LoginFailed", "AuthenticationProcessing"]
                for (i = 0; i < clips.length; ++i)
                    if (!parsed.animations[clips[i]]) throw new Error("Missing animation: " + clips[i])
                data = parsed
                loaded(parsed)
            } catch (exception) {
                error = String(exception)
                failed(error)
            }
        }
        request.send()
    }
}
