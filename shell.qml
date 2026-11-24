import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    Theme { id: theme }
    Config { id: config }

    // ========================================================
    // 全局狀態與數據中樞
    // ========================================================
    property bool inspectMode: false
    property bool boostGlow: config.boostGlowDefault
    property bool chimeEnabled: config.chimeEnabledDefault
    property bool alarmEnabled: config.alarmEnabledDefault
    property int alarmHour: theme.defaultAlarmHour
    property int alarmMinute: theme.defaultAlarmMinute

    property bool caffeineActive: false
    property int sleepMinutes: 30
    property int sleepCountdown: 1800
    property bool isUserIdle: false

    property int systemVolume: 50
    property bool systemMuted: false
    property string currentWifi: "未連接"
    property string currentIme: "EN (英文)"

    property int activeWorkspace: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
                                  ? Hyprland.focusedMonitor.activeWorkspace.id : 1

    // 遊戲作戰狀態 (支持多點 Alt+Z & Alt+X 精確打擊)
    property bool autoClickerEnabled: false
    property string clickerButtonCode: "0xC1"
    property bool autoQActive: false
    property bool cursorReturnEnabled: true

    property var zPoints: [
        { "x": 880, "y": 988, "btn": "0xC2" }
    ]
    property var xPoints: [
        { "x": 1200, "y": 1085, "btn": "0xC1" }
    ]

    // 兼容量化舊字段 (與數組第 1 點保持同步)
    property int zTargetX: zPoints.length > 0 ? zPoints[0].x : 880
    property int zTargetY: zPoints.length > 0 ? zPoints[0].y : 988
    property string zButtonCode: zPoints.length > 0 ? zPoints[0].btn : "0xC2"
    property int xTargetX: xPoints.length > 0 ? xPoints[0].x : 1200
    property int xTargetY: xPoints.length > 0 ? xPoints[0].y : 1085
    property string xButtonCode: xPoints.length > 0 ? xPoints[0].btn : "0xC1"

    // 最近鼠標點擊坐標列表 & 已複製坐標緩存
    property var recentClicks: [
        { "time": "03:03:40", "x": 880, "y": 988, "btn": "0xC2", "source": "預設 Alt+Z 打擊點" },
        { "time": "03:03:42", "x": 1200, "y": 1085, "btn": "0xC1", "source": "預設 Alt+X 打擊點" }
    ]
    property var copiedCoord: null

    // Hyprland 遙測實時數據
    property string liveCursorPos: "0, 0"
    property string liveClass: "Desktop"
    property string liveTitle: "Wayland Compositor"
    property string liveAddr: "0x0"

    // Focus-NetMon 實時流量監控狀態
    property bool netmonEnabled: false
    property bool netmonPin: false
    property int netmonLevel: 2
    property string netmonMode: "stopped"
    property string netmonClass: "未啟動"
    property int netmonPid: 0
    property int netmonProcs: 0
    property real netmonTxKbps: 0
    property real netmonRxKbps: 0
    property int netmonTxPps: 0
    property int netmonRxPps: 0
    property var netmonEndpoints: []
    property var netmonPackets: []
    property var netmonAnomalyLog: []

    // Edge 刻度尺寸 (響應流光翻倍)
    readonly property int tickM1_H: boostGlow ? theme.boost_m1_h : theme.m1_h
    readonly property int tickM1_W: boostGlow ? theme.boost_m1_w : theme.m1_w
    readonly property int tickM5_H: boostGlow ? theme.boost_m5_h : theme.m5_h
    readonly property int tickM5_W: boostGlow ? theme.boost_m5_w : theme.m5_w
    readonly property int tickM10_H: boostGlow ? theme.boost_m10_h : theme.m10_h
    readonly property int tickM10_W: boostGlow ? theme.boost_m10_w : theme.m10_w
    readonly property int tickM30_H: boostGlow ? theme.boost_m30_h : theme.m30_h
    readonly property int tickM30_W: boostGlow ? theme.boost_m30_w : theme.m30_w
    readonly property int tickM60_H: boostGlow ? theme.boost_m60_h : theme.m60_h
    readonly property int tickM60_W: boostGlow ? theme.boost_m60_w : theme.m60_w

    // 雙諧波流體偏移 & 鬧鐘閃爍脈衝
    property real wavePhase1: 0.0
    property real wavePhase2: 0.0
    readonly property real fluidShift: (Math.sin(wavePhase1) * config.waveAmp1) + (Math.cos(wavePhase2) * config.waveAmp2)
    property real beaconPulse: 1.0

    NumberAnimation on wavePhase1 {
        from: 0; to: Math.PI * 2; duration: config.wavePeriod1; loops: Animation.Infinite; running: true
    }
    NumberAnimation on wavePhase2 {
        from: 0; to: Math.PI * 2; duration: config.wavePeriod2; loops: Animation.Infinite; running: true
    }
    SequentialAnimation on beaconPulse {
        loops: Animation.Infinite; running: root.alarmEnabled
        NumberAnimation { to: 0.28; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
    }

    // 時鐘上下文
    QtObject {
        id: clockObj
        property int currentHour: 0
        property int currentMinute: 0
        property int currentSecond: 0
        property real minuteProgress: 0.0
        property string fullTimeString: "00:00:00"
        property string fullDateString: "1970-01-01 星期四"
        property int totalMinutes: 0
        property int prevAnchorMin: 0
        property int nextAnchorMin: 30
    }

    function pad2(n) { return n < 10 ? "0" + n : "" + n; }

    function updateClock() {
        var now = new Date();
        var h24 = now.getHours();
        var m = now.getMinutes();
        var s = now.getSeconds();
        clockObj.currentHour = h24 % 12;
        clockObj.currentMinute = m;
        clockObj.currentSecond = s;
        clockObj.minuteProgress = (m * 60 + s) / 3600.0;
        clockObj.totalMinutes = clockObj.currentHour * 60 + m;
        clockObj.prevAnchorMin = Math.floor(clockObj.totalMinutes / 30) * 30;
        clockObj.nextAnchorMin = (clockObj.prevAnchorMin + 30) % 720;

        var weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
        clockObj.fullTimeString = pad2(h24) + ":" + pad2(m) + ":" + pad2(s);
        clockObj.fullDateString = now.getFullYear() + "-" + pad2(now.getMonth() + 1) + "-" + pad2(now.getDate()) + " " + weekdays[now.getDay()];

        // 整點輕聲微音
        if (root.chimeEnabled && m === 0 && s === 0) {
            soundPlayer.play(theme.soundChime);
        }
        // 航標鬧鐘觸發
        if (root.alarmEnabled && clockObj.currentHour === ((root.alarmHour % 12) + 12) % 12 && m === root.alarmMinute && s === 0) {
            soundPlayer.play(theme.soundAlarm);
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.updateClock();
            if (root.caffeineActive || !root.isUserIdle) {
                root.sleepCountdown = root.sleepMinutes * 60;
            } else if (root.sleepCountdown > 0) {
                root.sleepCountdown -= 1;
                if (root.sleepCountdown === 0) {
                    scriptRunner.run("systemctl suspend");
                }
            }
        }
    }

    // 睡眠空閒檢測
    IdleMonitor {
        id: idleMon
        timeout: 2
        onIsIdleChanged: root.isUserIdle = idleMon.isIdle
    }

    // ========================================================
    // 多點精確打擊點數組與最近點擊管理函數
    // ========================================================
    function clonePoints(arr) {
        var out = [];
        for (var i = 0; i < arr.length; i++) {
            out.push({ "x": Number(arr[i].x) || 0, "y": Number(arr[i].y) || 0, "btn": String(arr[i].btn || "0xC0") });
        }
        return out;
    }

    function addPoint(group) {
        var src = (group === "Z") ? root.zPoints : root.xPoints;
        var next = clonePoints(src);
        var last = next.length > 0 ? next[next.length - 1] : { "x": 960, "y": 540, "btn": "0xC0" };
        next.push({ "x": last.x, "y": last.y, "btn": last.btn });
        if (group === "Z") root.zPoints = next; else root.xPoints = next;
        saveCoords();
    }

    function removePoint(group, index) {
        var src = (group === "Z") ? root.zPoints : root.xPoints;
        if (src.length <= 1) return;
        var next = clonePoints(src);
        var idx = (index === undefined || index < 0 || index >= next.length) ? next.length - 1 : index;
        next.splice(idx, 1);
        if (group === "Z") root.zPoints = next; else root.xPoints = next;
        saveCoords();
    }

    function updatePoint(group, index, xVal, yVal, btnVal) {
        var src = (group === "Z") ? root.zPoints : root.xPoints;
        if (index < 0 || index >= src.length) return;
        var next = clonePoints(src);
        if (xVal !== undefined && xVal !== null) next[index].x = Math.max(0, Math.min(9999, parseInt(xVal, 10) || 0));
        if (yVal !== undefined && yVal !== null) next[index].y = Math.max(0, Math.min(9999, parseInt(yVal, 10) || 0));
        if (btnVal !== undefined && btnVal !== null) next[index].btn = String(btnVal);
        if (group === "Z") root.zPoints = next; else root.xPoints = next;
        saveCoords();
    }

    function recordRecentClick(xVal, yVal, btnVal, sourceLabel) {
        var next = [];
        next.push({
            "time": clockObj.fullTimeString,
            "x": parseInt(xVal, 10) || 0,
            "y": parseInt(yVal, 10) || 0,
            "btn": String(btnVal || "0xC0"),
            "source": String(sourceLabel || root.liveClass || "Desktop")
        });
        for (var i = 0; i < root.recentClicks.length && next.length < 10; i++) {
            next.push(root.recentClicks[i]);
        }
        root.recentClicks = next;
    }

    function copyRecentClick(rec) {
        root.copiedCoord = { "x": rec.x, "y": rec.y, "btn": rec.btn };
        clipboardWriter.copy(rec.x + ", " + rec.y);
        soundPlayer.play(theme.soundClick);
    }

    function pasteToPoint(group, index) {
        if (root.copiedCoord) {
            updatePoint(group, index, root.copiedCoord.x, root.copiedCoord.y, null);
            soundPlayer.play(theme.soundClick);
            return;
        }
        clipboardReader.pendingGroup = group;
        clipboardReader.pendingIndex = index;
        clipboardReader.running = true;
    }

    function executeStrikeSequence(label, points) {
        if (!points || points.length === 0) return;
        var cmds = [];
        if (root.cursorReturnEnabled) {
            cmds.push("CUR=$(hyprctl cursorpos); CX=$(echo $CUR | cut -d',' -f1 | tr -d ' '); CY=$(echo $CUR | cut -d',' -f2 | tr -d ' ')");
        }
        for (var i = 0; i < points.length; i++) {
            var pt = points[i];
            cmds.push("ydotool mousemove -a " + pt.x + " " + pt.y + " && ydotool click " + pt.btn);
            if (i < points.length - 1) cmds.push("sleep 0.04");
        }
        if (root.cursorReturnEnabled) {
            cmds.push("ydotool mousemove -a $CX $CY");
        }
        strikeExec.command = ["sh", "-c", cmds.join("; ")];
        strikeExec.running = true;
        soundPlayer.play(theme.soundAlarm);
    }

    function pickCurrentCursorCoord() {
        pickCoordProc.running = true;
    }

    // ========================================================
    // 持久化配置讀寫 (coords.json)
    // ========================================================
    function saveCoords() {
        var firstZ = root.zPoints.length > 0 ? root.zPoints[0] : { "x": 880, "y": 988, "btn": "0xC2" };
        var firstX = root.xPoints.length > 0 ? root.xPoints[0] : { "x": 1200, "y": 1085, "btn": "0xC1" };
        var payload = {
            "zx": firstZ.x,
            "zy": firstZ.y,
            "zbtn": firstZ.btn,
            "xx": firstX.x,
            "xy": firstX.y,
            "xbtn": firstX.btn,
            "zPoints": root.zPoints,
            "xPoints": root.xPoints,
            "snap": root.cursorReturnEnabled,
            "clickerBtn": root.clickerButtonCode,
            "caffeine": root.caffeineActive,
            "sleepMinutes": root.sleepMinutes
        };
        saveCoordsProc.command = ["sh", "-c", "cat <<'EOF' > \"$HOME/.config/quickshell/coords.json\"\n" + JSON.stringify(payload, null, 2) + "\nEOF"];
        saveCoordsProc.running = true;
    }

    Process {
        id: loadCoordsProc
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/coords.json\" 2>/dev/null || cat ./coords.json 2>/dev/null"]
        running: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                if (!data || data.trim() === "") return;
                try {
                    var obj = JSON.parse(data);
                    if (obj.zPoints && obj.zPoints.length > 0) {
                        root.zPoints = obj.zPoints;
                    } else if (obj.zx !== undefined) {
                        root.zPoints = [{ "x": Number(obj.zx), "y": Number(obj.zy || 0), "btn": String(obj.zbtn || "0xC2") }];
                    }
                    if (obj.xPoints && obj.xPoints.length > 0) {
                        root.xPoints = obj.xPoints;
                    } else if (obj.xx !== undefined) {
                        root.xPoints = [{ "x": Number(obj.xx), "y": Number(obj.xy || 0), "btn": String(obj.xbtn || "0xC1") }];
                    }
                    if (obj.snap !== undefined) root.cursorReturnEnabled = !!obj.snap;
                    if (obj.clickerBtn) root.clickerButtonCode = String(obj.clickerBtn);
                    if (obj.caffeine !== undefined) root.caffeineActive = !!obj.caffeine;
                    if (obj.sleepMinutes !== undefined) {
                        root.sleepMinutes = Number(obj.sleepMinutes);
                        root.sleepCountdown = root.sleepMinutes * 60;
                    }
                } catch(e) {}
            }
        }
    }

    Process { id: saveCoordsProc }

    // ========================================================
    // 全局快捷鍵與外設執行器
    // ========================================================
    GlobalShortcut {
        name: "inspect_time"
        description: "Toggle CenterInspect HUD"
        onPressed: root.inspectMode = !root.inspectMode
    }

    GlobalShortcut {
        name: "inspect_hud"
        description: "Toggle CenterInspect HUD (Alias)"
        onPressed: root.inspectMode = !root.inspectMode
    }

    GlobalShortcut {
        name: "strike_z"
        description: "Execute Multi-Point Precision Strike Alt+Z"
        onPressed: root.executeStrikeSequence("Alt+Z", root.zPoints)
    }

    GlobalShortcut {
        name: "strike_x"
        description: "Execute Multi-Point Precision Strike Alt+X"
        onPressed: root.executeStrikeSequence("Alt+X", root.xPoints)
    }

    Process { id: strikeExec }

    Process {
        id: autoClickerRunner
        command: ["sh", "-c", "while true; do ydotool click " + root.clickerButtonCode + "; sleep 0.08; done"]
        running: root.autoClickerEnabled
    }

    Process {
        id: autoQRunner
        command: ["sh", "-c", "$HOME/.config/quickshell/albion-qspam || ./albion-qspam"]
        running: root.autoQActive
    }

    Process {
        id: scriptRunner
        function run(cmdStr) {
            command = ["sh", "-c", cmdStr];
            running = true;
        }
    }

    Process {
        id: clipboardWriter
        function copy(text) {
            command = ["sh", "-c", "printf '%s' " + JSON.stringify(String(text)) + " | wl-copy 2>/dev/null || true"];
            running = true;
        }
    }

    Process {
        id: clipboardReader
        property string pendingGroup: ""
        property int pendingIndex: -1
        command: ["sh", "-c", "wl-paste -n 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: function(line) {
                var m = String(line).match(/(\d{1,4})\s*[,\s]\s*(\d{1,4})/);
                if (m && clipboardReader.pendingGroup !== "" && clipboardReader.pendingIndex >= 0) {
                    var px = Math.min(9999, parseInt(m[1], 10));
                    var py = Math.min(9999, parseInt(m[2], 10));
                    root.copiedCoord = { "x": px, "y": py, "btn": "0xC0" };
                    root.updatePoint(clipboardReader.pendingGroup, clipboardReader.pendingIndex, px, py, null);
                    soundPlayer.play(theme.soundClick);
                }
                clipboardReader.pendingGroup = "";
                clipboardReader.pendingIndex = -1;
            }
        }
    }

    Process {
        id: pickCoordProc
        command: ["sh", "-c", "CUR=$(hyprctl cursorpos); echo \"$CUR\""]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = String(line).trim().split(",");
                if (parts.length >= 2) {
                    var px = parseInt(parts[0].trim(), 10) || 0;
                    var py = parseInt(parts[1].trim(), 10) || 0;
                    root.recordRecentClick(px, py, "0xC0", "光標拾取 (" + root.liveClass + ")");
                    root.copiedCoord = { "x": px, "y": py, "btn": "0xC0" };
                    clipboardWriter.copy(px + ", " + py);
                    soundPlayer.play(theme.soundClick);
                }
            }
        }
    }

    // ========================================================
    // 音頻、音效、Wi-Fi、輸入法與 Hyprland 遙測守護
    // ========================================================
    Process {
        id: soundPlayer
        function play(soundName) {
            if (!soundName) return;
            command = ["sh", "-c", "canberra-gtk-play -i " + soundName + " -V " + theme.soundVolume + " 2>/dev/null || true"];
            running = true;
        }
    }

    Process {
        id: volReader
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var m = String(line).match(/Volume:\s*([0-9.]+)/);
                if (m) root.systemVolume = Math.round(parseFloat(m[1]) * 100);
                root.systemMuted = String(line).indexOf("[MUTED]") !== -1;
            }
        }
    }

    Process {
        id: volWriter
        function setVolume(pct) {
            var clamped = Math.max(0, Math.min(100, Math.round(pct)));
            root.systemVolume = clamped;
            if (clamped > 0 && root.systemMuted) root.systemMuted = false;
            command = ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100.0).toFixed(2)];
            running = true;
        }
        function toggleMute() {
            root.systemMuted = !root.systemMuted;
            command = ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"];
            running = true;
        }
    }

    Process {
        id: wifiProcess
        command: ["sh", "-c", "SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep -i '^yes:' | head -n1 | cut -d: -f2-); [ -z \"$SSID\" ] && SSID=$(iwgetid -r 2>/dev/null); echo \"$SSID\""]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                root.currentWifi = s !== "" ? s : "未連接";
            }
        }
    }

    Process {
        id: imeProcess
        command: ["sh", "-c", "S=$(fcitx5-remote 2>/dev/null); [ \"$S\" = \"2\" ] && echo '中 (拼音)' || echo 'EN (英文)'"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.currentIme = s;
            }
        }
    }

    Process {
        id: cursorTracker
        command: ["sh", "-c", "hyprctl cursorpos 2>/dev/null"]
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.liveCursorPos = s;
            }
        }
    }

    Process {
        id: activeWinTracker
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) {
                try {
                    var w = JSON.parse(data);
                    if (w && w.class) {
                        var changed = (w.address !== root.liveAddr || w.class !== root.liveClass);
                        root.liveClass = w.class || "Desktop";
                        root.liveTitle = w.title || "Wayland";
                        root.liveAddr = w.address || "0x0";
                        if (changed && centerInspect) {
                            centerInspect.pushHandleHistory("FOCUS", root.liveClass, root.liveTitle, root.liveAddr, 0, 0);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: root.inspectMode ? 250 : 1200
        running: true; repeat: true
        onTriggered: {
            cursorTracker.running = true;
            activeWinTracker.running = true;
            volReader.running = true;
            wifiProcess.running = true;
            imeProcess.running = true;
        }
    }

    // Focus-NetMon 流監視進程
    Process {
        id: netmonProc
        command: [
            "sh", "-c",
            "($HOME/.config/quickshell/focus-netmon || ./focus-netmon) --level " + root.netmonLevel + (root.netmonPin ? " --pin" : "")
        ]
        running: root.netmonEnabled
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var obj = JSON.parse(line);
                    if (obj.mode) root.netmonMode = obj.mode;
                    if (obj.class) root.netmonClass = obj.class;
                    if (obj.pid !== undefined) root.netmonPid = obj.pid;
                    if (obj.procs !== undefined) root.netmonProcs = obj.procs;
                    if (obj.tx_kbps !== undefined) root.netmonTxKbps = obj.tx_kbps;
                    if (obj.rx_kbps !== undefined) root.netmonRxKbps = obj.rx_kbps;
                    if (obj.tx_pps !== undefined) root.netmonTxPps = obj.tx_pps;
                    if (obj.rx_pps !== undefined) root.netmonRxPps = obj.rx_pps;
                    if (obj.endpoints) root.netmonEndpoints = obj.endpoints;
                    if (obj.packets) root.netmonPackets = obj.packets;
                    if (obj.anomalyLog) root.netmonAnomalyLog = obj.anomalyLog;
                } catch(e) {}
            }
        }
    }

    // ========================================================
    // 四邊 12 小時光譜邊界時鐘（已移除四角獨立彈窗，整合至 CenterInspect）
    // ========================================================
    EdgeTop    { rootContext: root; themeContext: theme; clockContext: clockObj }
    EdgeRight  { rootContext: root; themeContext: theme; clockContext: clockObj }
    EdgeBottom { rootContext: root; themeContext: theme; clockContext: clockObj }
    EdgeLeft   { rootContext: root; themeContext: theme; clockContext: clockObj }

    CenterInspect {
        id: centerInspect
        rootContext: root
        themeContext: theme
        clockContext: clockObj
        volControl: volWriter
        soundContext: soundPlayer
    }
}
