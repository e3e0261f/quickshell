import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "./CenterInspect"

ShellRoot {
    id: root

    Theme { id: theme }

    // --- 基礎狀態屬性 ---
    property bool chimeEnabled: true
    property int lastChimedHour: -1
    property bool alarmEnabled: true
    property int alarmHour: theme.defaultAlarmHour
    property int alarmMinute: theme.defaultAlarmMinute
    property bool boostGlow: false
    property bool inspectMode: false
    property bool isBoosted: boostGlow || inspectMode

    property string currentWifi: "检测中..."
    property string currentIme: "EN"

    // --- 座標屬性 ---
    property int shiftZx: 500
    property int shiftZy: 500
    property int shiftXx: 800
    property int shiftXy: 500

    // --- 🚀 連擊引擎核心屬性 ---
    property bool cursorReturnEnabled: true
    property bool dragDropEnabled: false
    property string clickerButtonCode: "0xC0"
    property bool autoClickerActive: false
    property bool autoQActive: false

    onAutoClickerActiveChanged: {
        if (autoClickerActive) {
            autoClickerRunner.runScript("touch /tmp/clicker_active")
        } else {
            autoClickerRunner.runScript("rm -f /tmp/clicker_active /tmp/clicker.lock")
        }
    }

    onClickerButtonCodeChanged: {
        autoClickerRunner.runScript("echo '" + clickerButtonCode + "' > /tmp/clicker_btn")
    }

    GlobalShortcut {
        name: "toggle_clicker"
        onPressed: {
            if (root.autoClickerActive) {
                autoClickerRunner.runScript("if [ -f /tmp/clicker.lock ]; then rm -f /tmp/clicker.lock; else touch /tmp/clicker.lock; fi")
                soundPlayer.play("audio-volume-change")
            }
        }
    }

    // --- 快捷鍵綁定 ---
    GlobalShortcut {
        name: "strike_z"
        onPressed: {
            autoClickerRunner.runScript("~/.config/quickshell/combat_engine.sh strike " + root.shiftZx + " " + root.shiftZy + " " + root.dragDropEnabled + " " + root.cursorReturnEnabled)
            soundPlayer.play("bell")
        }
    }

    GlobalShortcut {
        name: "strike_x"
        onPressed: {
            autoClickerRunner.runScript("~/.config/quickshell/combat_engine.sh strike " + root.shiftXx + " " + root.shiftXy + " " + root.dragDropEnabled + " " + root.cursorReturnEnabled)
            soundPlayer.play("bell")
        }
    }

    GlobalShortcut {
        name: "inspect_time"
        onPressed: root.inspectMode = !root.inspectMode
    }

    // --- 🚀 核心進程管理 ---
    Process { id: autoClickerRunner; function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true } }
    Process { id: autoQRunner; function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true } }
    Process { id: strikeRunner; function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true } }
    Process { id: soundPlayer; function play(name) { command = ["canberra-gtk-play", "-i", name, "-V", theme.soundVolume]; running = false; running = true } }

    Process {
        id: loadCoordsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/coords.json 2>/dev/null || echo '{\"zx\":500,\"zy\":500,\"xx\":800,\"xy\":500}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    if (d.zx !== undefined) root.shiftZx = d.zx
                    if (d.zy !== undefined) root.shiftZy = d.zy
                    if (d.xx !== undefined) root.shiftXx = d.xx
                    if (d.xy !== undefined) root.shiftXy = d.xy
                } catch(e) {}
            }
        }
    }

    Process { id: saveCoordsProc }

    function saveCoords() {
        var json = JSON.stringify({ zx: root.shiftZx, zy: root.shiftZy, xx: root.shiftXx, xy: root.shiftXy })
        saveCoordsProc.command = ["sh", "-c", "echo '" + json + "' > ~/.config/quickshell/coords.json"]
        saveCoordsProc.running = false
        saveCoordsProc.running = true
    }

    Component.onCompleted: {
        loadCoordsProc.running = true
    }

    // --- 🚀 視覺與動畫屬性 ---
    property real minuteBlink: 1.0
    SequentialAnimation on minuteBlink {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 0.15; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
    }

    property real waveHarmonic1: 0.0
    property real waveHarmonic2: 0.0
    readonly property real fluidShift: (waveHarmonic1 * 0.09) + (waveHarmonic2 * 0.05)

    SequentialAnimation on waveHarmonic1 {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 1.0; duration: 3200; easing.type: Easing.InOutSine }
        NumberAnimation { to: -1.0; duration: 3200; easing.type: Easing.InOutSine }
    }

    SequentialAnimation on waveHarmonic2 {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 1.0; duration: 1900; easing.type: Easing.InOutQuad }
        NumberAnimation { to: -1.0; duration: 1900; easing.type: Easing.InOutQuad }
    }

    property real beaconPulse: 0.8
    SequentialAnimation on beaconPulse {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
    }

    QtObject {
        id: clock
        property int currentHour: 0
        property int currentMinute: 0
        property int currentSecond: 0
        property real minuteProgress: 0.0
        property string fullTimeString: ""
        property string fullDateString: ""
        readonly property int totalMinutes: (currentHour % 12) * 60 + currentMinute
        readonly property int prevAnchorMin: Math.floor(totalMinutes / 30) * 30
        readonly property int nextAnchorMin: (prevAnchorMin + 30) % 720
    }

    // --- 系統監控進程 ---
    Process {
        id: wifiProcess
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2 2>/dev/null || echo '未連接'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim()
                root.currentWifi = s.length > 0 ? s : "未連接"
            }
        }
    }

    Process {
        id: imeProcess
        command: ["sh", "-c", "STATE=$(fcitx5-remote 2>/dev/null); if [ \"$STATE\" = \"2\" ]; then echo '中 (拼音)'; else echo 'EN (英文)'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = text.trim()
                if (val.length > 0) root.currentIme = val
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            var h = now.getHours()
            var m = now.getMinutes()
            var s = now.getSeconds()
            clock.currentHour = h % 12
            clock.currentMinute = m
            clock.currentSecond = s
            clock.minuteProgress = (m * 60 + s) / 3600.0
            clock.fullTimeString = Qt.formatDateTime(now, "hh:mm:ss")
            clock.fullDateString = Qt.formatDateTime(now, "yyyy-MM-dd dddd")
            if (root.chimeEnabled && m === 0 && s === 0 && root.lastChimedHour !== h) {
                root.lastChimedHour = h
                soundPlayer.play(theme.soundChime)
            }
            if (root.alarmEnabled && clock.currentHour === (root.alarmHour % 12) && m === root.alarmMinute && s === 0) {
                soundPlayer.play(theme.soundAlarm)
            }
            if (s % 2 === 0) {
                wifiProcess.running = false; wifiProcess.running = true
                imeProcess.running = false; imeProcess.running = true
            }
        }
    }

    // --- 渲染組件 ---
    EdgeTop    { rootContext: root; themeContext: theme; clockContext: clock }
    EdgeRight  { rootContext: root; themeContext: theme; clockContext: clock }
    EdgeBottom { rootContext: root; themeContext: theme; clockContext: clock }
    EdgeLeft   { rootContext: root; themeContext: theme; clockContext: clock }

    CornerBottomLeft  { rootContext: root; themeContext: theme; clockContext: clock }
    CornerBottomRight { rootContext: root; themeContext: theme; clockContext: clock; soundContext: soundPlayer }
    CenterInspect     { rootContext: root; themeContext: theme; clockContext: clock }
}
