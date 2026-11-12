import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    Theme { id: theme }

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

    // 咖啡因與音量總線
    property bool caffeineActive: true
    property int sleepCountdown: 900
    property int systemVolume: 50
    property bool systemMuted: false

    onCaffeineActiveChanged: {
        if (caffeineActive) {
            strikeRunner.runScript("touch /tmp/caffeine_active")
        } else {
            strikeRunner.runScript("rm -f /tmp/caffeine_active")
        }
    }

    property int shiftZx: 500
    property int shiftZy: 500
    property string shiftZBtn: "0xC0"

    property int shiftXx: 800
    property int shiftXy: 500
    property string shiftXBtn: "0xC0"

    property bool cursorReturnEnabled: true
    property string clickerButtonCode: "0xC0"
    property bool autoClickerActive: false
    property bool autoQActive: false

    onAutoClickerActiveChanged: {
        if (autoClickerActive) {
            autoClickerRunner.runScript("while true; do ydotool click " + root.clickerButtonCode + "; sleep 0.08; done")
        } else {
            autoClickerRunner.runScript("pkill -f 'ydotool click'")
        }
    }

    onAutoQActiveChanged: {
        if (autoQActive) {
            autoQRunner.runScript("stdbuf -oL libinput debug-events 2>/dev/null | grep --line-buffered 'KEY_Q.*pressed' | while read -r _; do ydotool key 16:1 16:0; done")
        } else {
            autoQRunner.runScript("pkill -f 'libinput debug-events'")
        }
    }

    GlobalShortcut {
        name: "press_q"
        onPressed: {
            soundPlayer.play("bell")
            strikeRunner.runScript("ydotool click 0xC0")
        }
    }

    GlobalShortcut {
        name: "toggle_clicker"
        onPressed: {
            root.autoClickerActive = !root.autoClickerActive
            soundPlayer.play("audio-volume-change")
        }
    }

    GlobalShortcut {
        name: "strike_z"
        onPressed: {
            var btn = root.shiftZBtn || "0xC0"
            var script = ""
            if (root.cursorReturnEnabled) {
                script = "CUR=$(hyprctl cursorpos 2>/dev/null | tr -d ' '); CX=$(echo $CUR | cut -d, -f1); CY=$(echo $CUR | cut -d, -f2); " +
                         "ydotool mousemove -a " + root.shiftZx + " " + root.shiftZy + " && ydotool click " + btn + "; " +
                         "ydotool mousemove -a $CX $CY"
            } else {
                script = "ydotool mousemove -a " + root.shiftZx + " " + root.shiftZy + " && ydotool click " + btn
            }
            soundPlayer.play("bell")
            strikeRunner.runScript(script)
        }
    }

    GlobalShortcut {
        name: "strike_x"
        onPressed: {
            var btn = root.shiftXBtn || "0xC0"
            var script = ""
            if (root.cursorReturnEnabled) {
                script = "CUR=$(hyprctl cursorpos 2>/dev/null | tr -d ' '); CX=$(echo $CUR | cut -d, -f1); CY=$(echo $CUR | cut -d, -f2); " +
                         "ydotool mousemove -a " + root.shiftXx + " " + root.shiftXy + " && ydotool click " + btn + "; " +
                         "ydotool mousemove -a $CX $CY"
            } else {
                script = "ydotool mousemove -a " + root.shiftXx + " " + root.shiftXy + " && ydotool click " + btn
            }
            soundPlayer.play("bell")
            strikeRunner.runScript(script)
        }
    }

    Process {
        id: volReader
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pamixer --get-volume 2>/dev/null || echo 'Volume: 0.50'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var str = text.trim()
                root.systemMuted = str.includes("MUTED")
                var m = str.match(/([0-9]+(\.[0-9]+)?)/)
                if (m) {
                    var val = parseFloat(m[1])
                    if (val <= 1.0) val = Math.round(val * 100)
                    root.systemVolume = Math.min(100, Math.max(0, Math.round(val)))
                }
            }
        }
    }

    Process {
        id: volWriter
        function setVol(pct) {
            root.systemVolume = pct
            command = ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (pct / 100.0) + " 2>/dev/null || pamixer --set-volume " + pct]
            running = false; running = true
        }
        function toggleMute() {
            command = ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || pamixer -t"]
            running = false; running = true
            volReader.running = false; volReader.running = true
        }
    }

    // 倒計時讀取進程 (實時同步守護進程計算好的真實剩餘秒數)
    Process {
        id: countdownReader
        command: ["sh", "-c", "cat /tmp/sleep_countdown 2>/dev/null || echo '900'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(text.trim())
                if (!isNaN(v)) root.sleepCountdown = v
            }
        }
    }

    Process { id: autoClickerRunner; function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true } }
    Process { id: autoQRunner; function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true } }
    Process { id: strikeRunner; function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true } }

    Process {
        id: loadCoordsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/coords.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    if (d.zx !== undefined) root.shiftZx = d.zx
                    if (d.zy !== undefined) root.shiftZy = d.zy
                    if (d.zbtn !== undefined) root.shiftZBtn = d.zbtn

                    if (d.xx !== undefined) root.shiftXx = d.xx
                    if (d.xy !== undefined) root.shiftXy = d.xy
                    if (d.xbtn !== undefined) root.shiftXBtn = d.xbtn

                    if (d.snap !== undefined) root.cursorReturnEnabled = d.snap
                    if (d.clickerBtn !== undefined) root.clickerButtonCode = d.clickerBtn
                    if (d.caffeine !== undefined) root.caffeineActive = d.caffeine
                } catch(e) {}
            }
        }
    }

    Process { id: saveCoordsProc }

    function saveCoords() {
        var data = {
            zx: root.shiftZx, zy: root.shiftZy, zbtn: root.shiftZBtn,
            xx: root.shiftXx, xy: root.shiftXy, xbtn: root.shiftXBtn,
            snap: root.cursorReturnEnabled,
            clickerBtn: root.clickerButtonCode,
            caffeine: root.caffeineActive
        }
        var json = JSON.stringify(data)
        saveCoordsProc.command = ["sh", "-c", "echo '" + json + "' > ~/.config/quickshell/coords.json"]
        saveCoordsProc.running = false
        saveCoordsProc.running = true
    }

    Component.onCompleted: {
        loadCoordsProc.running = true
        volReader.running = true
        strikeRunner.runScript("pgrep -f sleep_guard.sh >/dev/null || nohup ~/.config/quickshell/sleep_guard.sh >/dev/null 2>&1 &")
    }

    GlobalShortcut {
        name: "inspect_time"
        onPressed: root.inspectMode = !root.inspectMode
    }

    readonly property int tickM1_H: root.isBoosted ? theme.boost_m1_h : theme.m1_h
    readonly property int tickM1_W: root.isBoosted ? theme.boost_m1_w : theme.m1_w
    readonly property int tickM5_H: root.isBoosted ? theme.boost_m5_h : theme.m5_h
    readonly property int tickM5_W: root.isBoosted ? theme.boost_m5_w : theme.m5_w
    readonly property int tickM10_H: root.isBoosted ? theme.boost_m10_h : theme.m10_h
    readonly property int tickM10_W: root.isBoosted ? theme.boost_m10_w : theme.m10_w
    readonly property int tickM30_H: root.isBoosted ? theme.boost_m30_h : theme.m30_h
    readonly property int tickM30_W: root.isBoosted ? theme.boost_m30_w : theme.m30_w
    readonly property int tickM60_H: root.isBoosted ? theme.boost_m60_h : theme.m60_h
    readonly property int tickM60_W: root.isBoosted ? theme.boost_m60_w : theme.m60_w

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

    Process {
        id: soundPlayer
        function play(name) {
            command = ["canberra-gtk-play", "-i", name, "-V", theme.soundVolume]
            running = false; running = true
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            soundPlayer.play(theme.soundClick)
        }
    }

    Process {
        id: wifiProcess
        command: ["sh", "-c", "nmcli -t -f TYPE,CONNECTION dev | grep '^wifi:' | cut -d: -f2 | grep -v '^--$' | head -n1 || echo '未連接'"]
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

            // 定期刷新心跳 (同步睡眠倒計時、音量與 Wi-Fi)
            countdownReader.running = false; countdownReader.running = true
            if (s % 2 === 0) {
                wifiProcess.running = false; wifiProcess.running = true
                imeProcess.running = false; imeProcess.running = true
                volReader.running = false; volReader.running = true
            }
        }
    }

    EdgeTop    { rootContext: root; themeContext: theme; clockContext: clock }
    EdgeRight  { rootContext: root; themeContext: theme; clockContext: clock }
    EdgeBottom { rootContext: root; themeContext: theme; clockContext: clock }
    EdgeLeft   { rootContext: root; themeContext: theme; clockContext: clock }

    CornerBottomLeft  { rootContext: root; themeContext: theme; clockContext: clock; volControl: volWriter }
    CornerBottomRight { rootContext: root; themeContext: theme; clockContext: clock; soundContext: soundPlayer }
    CenterInspect     { rootContext: root; themeContext: theme; clockContext: clock }
}
