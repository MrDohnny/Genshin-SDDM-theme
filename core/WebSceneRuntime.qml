import QtQuick
import QtWebEngine

Item {
    id: root
    property url source: ""
    property bool ready: false
    property var mapping: ({})
    signal sceneEvent(string name)
    signal loadFailed(string reason)

    function play(name) {
        if (!ready) return false
        var bridge = mapping.bridgeObject || "sddmScene"
        var method = mapping.commandMethod || "play"
        var actions = mapping.actions || ({})
        var command = actions[name] !== undefined ? actions[name] : name
        // Browsers auto-suspend a page's WebAudio context after a period of
        // silence to save power — after sitting idle through an entire user
        // session, the scene's own sound effects (e.g. a door-opening cue)
        // can end up silently dropped even though everything looks fine,
        // since the context never gets resumed on its own once suspended.
        // A theme can expose window.__sddmResumeAudioContexts to have every command attempt a
        // resume first — a no-op for themes/pages that don't define it.
        webView.runJavaScript("(window.__sddmResumeAudioContexts && window.__sddmResumeAudioContexts()); window[" + JSON.stringify(String(bridge)) + "] && window[" + JSON.stringify(String(bridge)) + "][" + JSON.stringify(String(method)) + "] && window[" + JSON.stringify(String(bridge)) + "][" + JSON.stringify(String(method)) + "](" + JSON.stringify(String(command)) + ")")
        return true
    }
    function setMusicMuted(muted) {
        if (!ready) return false
        var bridge = mapping.bridgeObject || "sddmScene"
        var method = mapping.muteMethod || "setMusicMuted"
        webView.runJavaScript("window[" + JSON.stringify(String(bridge)) + "] && window[" + JSON.stringify(String(bridge)) + "][" + JSON.stringify(String(method)) + "] && window[" + JSON.stringify(String(bridge)) + "][" + JSON.stringify(String(method)) + "](" + (muted ? "true" : "false") + ")")
        return true
    }

    WebEngineView {
        id: webView
        anchors.fill: parent
        url: root.source
        backgroundColor: "#080b12"
        settings.localContentCanAccessFileUrls: true
        settings.localContentCanAccessRemoteUrls: false
        settings.javascriptCanAccessClipboard: false
        settings.fullScreenSupportEnabled: false
        onNavigationRequested: function(request) {
            var destination = String(request.url).split("?")[0]
            var origin = String(root.source).split("?")[0]
            if (request.navigationType !== WebEngineNavigationRequest.ReloadNavigation && destination !== origin)
                request.reject()
        }
        onLoadingChanged: function(info) {
            if (info.status === WebEngineLoadingInfo.LoadStartedStatus) {
                root.ready = false
                sceneReadyFallback.stop()
            }
            if (info.status === WebEngineLoadingInfo.LoadFailedStatus) root.loadFailed(info.errorString)
            if (info.status === WebEngineLoadingInfo.LoadSucceededStatus) {
                var domEvent = root.mapping.eventDomName || "sddm-theme-event"
                webView.runJavaScript("(function(){function sendName(n){if(n)document.title='sddm-event:'+String(n)+':'+Date.now()}function send(e){sendName(e&&e.detail&&(e.detail.name||e.detail))}if(!window.__sddmThemeBridgeInstalled){window.__sddmThemeBridgeInstalled=true;window.addEventListener(" + JSON.stringify(String(domEvent)) + ",send);window.sddmHostEvent=sendName}var backlog=window.__sddmSceneEventBacklog||[];window.__sddmSceneEventBacklog=[];backlog.forEach(sendName)})()")
                // The page's own JS should dispatch "SceneReady" once its assets
                // are loaded, but on a cold first boot it sometimes never fires
                // (slow first-time GPU/shader warm-up inside the sandboxed
                // greeter session) and the white loading screen gets stuck
                // forever. Fake it after a bounded wait so the UI always
                // proceeds — by then the page has had plenty of time to load
                // its own assets in the background regardless.
                sceneReadyFallback.interval = root.mapping.sceneReadyFallbackMs !== undefined ? root.mapping.sceneReadyFallbackMs : 6000
                sceneReadyFallback.restart()
            }
        }
        onTitleChanged: {
            var value = String(title)
            if (value.indexOf("sddm-event:") !== 0) return
            var name = value.split(":")[1]
            if (name === "SceneReady") {
                if (root.ready) return // already handled by the fallback timer
                root.ready = true
                sceneReadyFallback.stop()
            }
            console.info("WebGL scene event:", name)
            root.sceneEvent(name)
        }
    }
    Timer {
        id: sceneReadyFallback
        repeat: false
        onTriggered: {
            if (root.ready) return
            console.info("WebGL scene: SceneReady fallback timeout reached, faking readiness")
            root.ready = true
            // Forcing our own "ready" property only affects the QML overlay
            // (start prompt, ambient button, etc.) — it does nothing for the
            // white "progress-container" loading splash rendered INSIDE the
            // page's own React/Three.js content, which only hides itself once
            // every asset fetch() it kicked off resolves. If something still
            // hangs despite the local Draco/asset embedding, that splash
            // would otherwise stay up forever, so on fallback also reach into
            // the page and force it hidden directly — a genuinely fake
            // dismissal, not a real one.
            webView.runJavaScript("(function(){var el=document.querySelector('.progress-container'); if(!el) return; el.style.setProperty('transition','opacity 0.6s ease','important'); el.style.setProperty('opacity','0','important'); el.style.setProperty('pointer-events','none','important'); setTimeout(function(){ if (el) el.style.setProperty('display','none','important') }, 650)})()")
            root.sceneEvent("SceneReady")
        }
    }
}
