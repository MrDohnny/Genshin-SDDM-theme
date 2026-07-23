import QtQuick

QtObject {
    id: root
    required property var runtimeLoader
    required property var eventBus
    property string state: "Loading"
    property var players: ({})
    property var durations: ({ "LoginFailed": 1400 })
    property var timelineMapping: ({})
    property var timelines: ({})
    property var activeTimeline: null
    property bool panelActive: false
    property var webRuntime: null
    signal finished(string name)
    onTimelineMappingChanged: {
        if (state === "Idle2ActivePanel") {
            var activeIdle = timelineMapping["Idle2ActivePanel"]
            if (!activeIdle || !activeIdle.enabled) idle()
            else play(state)
        } else if (state === "Idle" || state === "EnterLogin") play(state)
    }

    function discoverAnimations() {
        // RuntimeLoader intentionally exposes no animation player. Theme-side
        // controllers (or the future C++ glTF bridge) register clip adapters here.
        return Object.keys(players)
    }
    function registerPlayer(name, player) {
        if (!name || !player || typeof player.start !== "function") return false
        var copy = Object.assign({}, players)
        copy[name] = player
        players = copy
        return true
    }
    function registerTimeline(name, timeline) {
        if (!name || !timeline) return false
        var copy = Object.assign({}, timelines)
        copy[name] = timeline
        timelines = copy
        return true
    }
    function registerTimelinesFrom(rootObject) {
        var seen = []
        function visit(object) {
            if (!object || seen.indexOf(object) >= 0) return
            seen.push(object)
            if (object.objectName && object.startFrame !== undefined && object.endFrame !== undefined)
                registerTimeline(object.objectName, object)
            var lists = [object.data, object.children, object.resources]
            for (var listIndex = 0; listIndex < lists.length; ++listIndex) {
                var list = lists[listIndex]
                if (!list) continue
                for (var i = 0; i < list.length; ++i) visit(list[i])
            }
        }
        visit(rootObject)
        console.info("Registered timeline clips:", Object.keys(timelines).join(", "))
    }
    function hasRequiredAnimations() {
        return ["Idle", "EnterLogin", "LoginFailed", "AuthenticationProcessing"].every(function (name) { return !!players[name] })
    }
    function durationFor(name) {
        var mappingEntry = timelineMapping[name]
        var clipName = mappingEntry && typeof mappingEntry === "object" ? mappingEntry.clip : (mappingEntry || name)
        var timeline = timelines[clipName]
        if (timeline)
            return Math.max(1, (timeline.endFrame - timeline.startFrame) / (timeline.framesPerSecond || 1000) * 1000)
        return durations[name] || 1000
    }
    function play(name, loops) {
        var player = players[name]
        state = name
        var mappingEntry = timelineMapping[name]
        var clipName = mappingEntry && typeof mappingEntry === "object" ? mappingEntry.clip : (mappingEntry || name)
        var shouldLoop = mappingEntry && typeof mappingEntry === "object" ? mappingEntry.loop : (name === "Idle" || loops === -1)
        if (name === "LoginFailed") shouldLoop = false
        // AuthenticationProcessing is deliberately finite: LoginController waits
        // for this fake processing step before asking SDDM to validate the password.
        if (name === "AuthenticationProcessing") shouldLoop = false
        if (name === "EnterLogin") {
            var activeIdle = timelineMapping["Idle2ActivePanel"]
            if (activeIdle && activeIdle.enabled) shouldLoop = false
        }
        var timeline = timelines[clipName]
        if (webRuntime && webRuntime.ready) {
            webRuntime.play(name)
            console.info("Playing WebGL scene state:", name)
        } else if (timeline) {
            timelinePlayer.stop()
            for (var key in timelines) timelines[key].enabled = false
            activeTimeline = timeline
            timeline.enabled = true
            timeline.currentFrame = timeline.startFrame
            timelinePlayer.from = timeline.startFrame
            timelinePlayer.to = timeline.endFrame
            timelinePlayer.duration = Math.max(1, (timeline.endFrame - timeline.startFrame) / (timeline.framesPerSecond || 1000) * 1000)
            timelinePlayer.loops = shouldLoop ? Animation.Infinite : 1
            timelinePlayer.restart()
            console.info("Playing mapped animation:", name, "->", clipName, shouldLoop ? "(loop)" : "(finite)")
        } else if (player) {
            if (typeof player.stop === "function") player.stop()
            player.start(shouldLoop ? -1 : 1)
            console.info("Playing mapped animation player:", name, "->", clipName, shouldLoop ? "(loop)" : "(finite)")
        }
        else console.warn("Mapped animation clip unavailable:", name, "->", clipName)
        if (shouldLoop) completionTimer.stop()
        else if (name !== "Idle") completionTimer.restartFor(name, durationFor(name))
        return true
    }
    function stop(name) {
        if (!players[name] || typeof players[name].stop !== "function") return false
        players[name].stop()
        return true
    }
    function enterLogin() {
        if (state === "EnterLogin") return
        panelActive = true
        eventBus.emit("BeforeEnterLogin")
        play("EnterLogin")
    }
    function idle() { eventBus.emit("BeforeIdle"); play("Idle", -1) }
    function activePanelIdle() {
        var entry = timelineMapping["Idle2ActivePanel"]
        if (entry && entry.enabled && entry.clip) {
            eventBus.emit("BeforeIdle", { activePanel: true })
            play("Idle2ActivePanel")
        } else idle()
    }
    function completeFiniteAnimation(done) {
        root.finished(done)
        if (done === "EnterLogin") root.eventBus.emit("AfterEnterLogin")
        if (done === "EnterLogin" || (done === "LoginFailed" && root.panelActive)) root.activePanelIdle()
        else if (done === "LoginFailed") root.idle()
    }

    property Timer completionTimer: Timer {
        property string animationName
        repeat: false
        function restartFor(name, ms) { animationName = name; interval = ms; restart() }
        onTriggered: {
            var done = animationName
            root.completeFiniteAnimation(done)
        }
    }
    property NumberAnimation timelinePlayer: NumberAnimation {
        target: root.activeTimeline
        property: "currentFrame"
        easing.type: Easing.Linear
        onFinished: {
            if (loops !== 1 || !completionTimer.running) return
            var done = completionTimer.animationName
            completionTimer.stop()
            root.completeFiniteAnimation(done)
        }
    }
}
