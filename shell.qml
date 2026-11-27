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
    property bool isUserIdle: idleMon.isIdle
    property int inputCooldownSec: idleMon.isIdle ? 0 : 2
    property var activeAudioStreams: []
    property bool hasMediaBlocker: false

    property int systemVolume: 50
    property bool systemMuted: false
    property string currentWifi: "未連接"
    property string currentIme: "EN (英文)"

    property int activeWorkspace: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
                                  ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    property string wsToastText: ""
    property bool wsToastVisible: false

    Timer {
        id: wsToastTimer
        interval: 1400
        repeat: false
        onTriggered: root.wsToastVisible = false
    }

    Process {
        id: wsSwitchProc
        property int targetWs: 1
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("WHEEL-HYPR", s);
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("WHEEL-ERR", s);
            }
        }
    }

    function onSelectWorkspace(ws) {
        var nextWs = Math.max(1, Math.min(10, parseInt(ws, 10) || 1));
        var hasMon = !!(Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace);
        var cur = hasMon ? Hyprland.focusedMonitor.activeWorkspace.id : root.activeWorkspace;
        appendCombatLog("WHEEL", "onSelectWorkspace 調用: req=" + ws + " nextWs=" + nextWs + " cur=" + cur + " hasMon=" + hasMon + " mon=" + (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "null"));
        if (nextWs === cur) {
            appendCombatLog("WHEEL", "跳過切換: nextWs === cur (" + cur + ")");
            return;
        }
        wsSwitchProc.targetWs = nextWs;
        var hlCmd = "hyprctl dispatch 'hl.dsp.focus({ workspace = " + nextWs + " })'";
        wsSwitchProc.command = [
            "sh", "-c",
            "OUT=$(" + hlCmd + " 2>&1); EC=$?; " +
            "if [ $EC -ne 0 ] || echo \"$OUT\" | grep -qiE 'invalid|error|unknown'; then " +
            "  OUT=\"$OUT | fallback:$(hyprctl dispatch workspace " + nextWs + " 2>&1)\"; EC=$?; " +
            "fi; " +
            "NOW_WS=$(hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(str(d.get(\"id\"))+\"@\"+str(d.get(\"monitor\")))' 2>/dev/null || echo '?'); " +
            "echo \"cmd=" + hlCmd + " ec=$EC out=$OUT now=$NOW_WS\""
        ];
        wsSwitchProc.running = false;
        wsSwitchProc.running = true;
        if (Hyprland.refreshWorkspaces) Hyprland.refreshWorkspaces();
        root.wsToastText = "🖥️ 虛擬桌面 " + nextWs + " / 5";
        root.wsToastVisible = true;
        wsToastTimer.restart();
        soundPlayer.play(theme.soundClick);
    }

    // 遊戲作戰狀態 (支持多點 Alt+Z & Alt+X 精確打擊)
    property bool autoClickerEnabled: false
    property string clickerButtonCode: "0xC1"
    property bool autoQActive: false
    property var spamKeys: ["q"]
    property bool cursorReturnEnabled: true

    function normalizeSpamKey(raw) {
        var k = String(raw || "").trim().toLowerCase();
        if (k === "spc") k = "space";
        if (k === "ret" || k === "return") k = "enter";
        if (k === "escape") k = "esc";
        if (!/^([a-z0-9]|f([1-9]|1[0-2])|space|tab|enter|esc|up|down|left|right)$/.test(k)) {
            return "";
        }
        return k;
    }

    function sanitizeSpamKeys(arr) {
        var out = [];
        var seen = {};
        if (!arr) return out;
        for (var i = 0; i < arr.length; i++) {
            var k = normalizeSpamKey(arr[i]);
            if (!k || seen[k]) continue;
            seen[k] = true;
            out.push(k);
        }
        return out;
    }

    function hasSpamKey(keyName) {
        var k = normalizeSpamKey(keyName);
        return k !== "" && root.spamKeys && root.spamKeys.indexOf(k) !== -1;
    }

    function addSpamKeys(rawText) {
        var tokens = sanitizeSpamKeys(String(rawText || "").split(/[\s,]+/));
        if (tokens.length === 0) {
            appendCombatLog("QSPAM", "⚠️ 無有效按鍵名稱（支援 a-z, 0-9, f1-f12, space, tab, enter, esc, 方向鍵）");
            return false;
        }
        var next = sanitizeSpamKeys(root.spamKeys);
        var added = [];
        for (var i = 0; i < tokens.length; i++) {
            if (next.indexOf(tokens[i]) === -1) {
                next.push(tokens[i]);
                added.push(tokens[i]);
            }
        }
        if (added.length === 0) {
            appendCombatLog("QSPAM", "按鍵已在列表中: [" + next.join(", ") + "]");
            return true;
        }
        root.spamKeys = next;
        saveCoords();
        appendCombatLog("QSPAM", "已添加連發按鍵 [" + added.join(", ") + "] -> [" + root.spamKeys.join(", ") + "]");
        if (root.autoQActive) launchQSpam();
        return true;
    }

    function removeSpamKey(keyName) {
        var k = normalizeSpamKey(keyName);
        if (!k) return;
        var next = [];
        for (var i = 0; i < root.spamKeys.length; i++) {
            var cur = normalizeSpamKey(root.spamKeys[i]);
            if (cur && cur !== k) next.push(cur);
        }
        if (next.length === 0) {
            appendCombatLog("QSPAM", "⚠️ 至少需保留 1 個連發按鍵");
            return;
        }
        root.spamKeys = next;
        saveCoords();
        appendCombatLog("QSPAM", "已移除連發按鍵 [" + k + "] -> [" + root.spamKeys.join(", ") + "]");
        if (root.autoQActive) launchQSpam();
    }

    function toggleSpamKey(keyName) {
        var k = normalizeSpamKey(keyName);
        if (!k) return;
        if (hasSpamKey(k)) {
            removeSpamKey(k);
        } else {
            addSpamKeys(k);
        }
    }

    function setSpamKeysFromText(rawText) {
        var next = sanitizeSpamKeys(String(rawText || "").split(/[\s,]+/));
        if (next.length === 0) {
            appendCombatLog("QSPAM", "⚠️ 無有效按鍵，維持原設定: [" + root.spamKeys.join(", ") + "]");
            return;
        }
        root.spamKeys = next;
        saveCoords();
        appendCombatLog("QSPAM", "連發按鍵列表 -> [" + root.spamKeys.join(", ") + "]");
        if (root.autoQActive) launchQSpam();
    }

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

    // 最近鼠標點擊坐標列表 & 已複製坐標緩存 (默認關閉全局錄製開關以節省性能)
    property bool clickRecordEnabled: false
    property bool screenPickerActive: false
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

    function isBrowserAudioApp(binStr, appStr) {
        var combined = (String(binStr || "") + " " + String(appStr || "")).toLowerCase();
        return /chrom|firefox|brave|vivaldi|opera|edge|zen|librewolf|webkit/.test(combined);
    }

    function refreshMediaState() {
        var playing = (root.activeAudioStreams && root.activeAudioStreams.length > 0);
        if (!playing && Mpris && Mpris.players && Mpris.players.values) {
            for (var i = 0; i < Mpris.players.values.length; i++) {
                var p = Mpris.players.values[i];
                if (p && p.isPlaying) {
                    playing = true;
                    break;
                }
            }
        }
        root.hasMediaBlocker = playing;
    }

    Process {
        id: audioStreamProbeProc
        running: true
        command: [
            "sh", "-c",
            "pactl list sink-inputs 2>/dev/null | awk '" +
            "function flush() { if (id != \"\" && cork == \"no\" && app !~ /canberra/i && bin !~ /canberra/i) { print (bin != \"\" ? bin : \"audio\") \"|\" app \"|\" media } } " +
            "/^Sink Input #/ { flush(); id=$0; cork=\"no\"; app=\"\"; bin=\"\"; media=\"\" } " +
            "/^[[:space:]]*Corked:/ { cork=$2 } " +
            "/application\\.name = / { sub(/^[^\"]*\"/, \"\"); sub(/\"$/, \"\"); app=$0 } " +
            "/application\\.process\\.binary = / { sub(/^[^\"]*\"/, \"\"); sub(/\"$/, \"\"); bin=$0 } " +
            "/media\\.name = / { sub(/^[^\"]*\"/, \"\"); sub(/\"$/, \"\"); media=$0 } " +
            "END { flush() }'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var out = [];
                var seen = {};
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i].trim();
                    if (!ln) continue;
                    var parts = ln.split("|");
                    var bin = parts[0] || "audio";
                    var app = parts[1] || bin;
                    var media = parts[2] || "";
                    var key = (bin + "|" + app).toLowerCase();
                    if (seen[key]) continue;
                    seen[key] = true;
                    out.push({
                        "bin": bin,
                        "app": app,
                        "media": media,
                        "isBrowser": root.isBrowserAudioApp(bin, app)
                    });
                }
                root.activeAudioStreams = out;
                root.refreshMediaState();
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.updateClock();
            root.refreshMediaState();
            root.isUserIdle = idleMon.isIdle;
            if (idleMon.isIdle) {
                root.inputCooldownSec = 0;
            } else if (root.inputCooldownSec > 0) {
                root.inputCooldownSec -= 1;
            }

            if (root.caffeineActive || !root.isUserIdle || root.hasMediaBlocker) {
                root.sleepCountdown = root.sleepMinutes * 60;
            } else if (root.sleepCountdown > 0) {
                root.sleepCountdown -= 1;
                if (root.sleepCountdown === 0) {
                    scriptRunner.run("systemctl suspend");
                }
            }
        }
    }

    // 睡眠空閒檢測 (忽略瀏覽器/遊戲 idle-inhibit 鎖，僅檢測真實鍵鼠活動)
    IdleMonitor {
        id: idleMon
        timeout: 2
        respectInhibitors: false
        onIsIdleChanged: {
            root.isUserIdle = idleMon.isIdle;
            root.inputCooldownSec = idleMon.isIdle ? 0 : 2;
            if (root.inspectMode) {
                appendCombatLog("SLEEP", "IdleMonitor -> isIdle=" + idleMon.isIdle + " hasMedia=" + root.hasMediaBlocker);
            }
        }
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

    function mapBtnToHyprKey(btnCode) {
        if (btnCode === "0xC1") return "mouse:273";
        if (btnCode === "0xC2") return "mouse:274";
        return "mouse:272";
    }

    function executeStrikeSequence(label, points) {
        if (!points || points.length === 0) return;
        var moveDelay = "0.05";
        var holdDelay = "0.05";
        var returnDelay = "0.03";
        var cmds = [];

        if (root.cursorReturnEnabled) {
            cmds.push("CUR=$(hyprctl cursorpos 2>/dev/null | tr -d ' '); CX=${CUR%%,*}; CY=${CUR##*,}");
        }

        for (var i = 0; i < points.length; i++) {
            var pt = points[i];
            var key = mapBtnToHyprKey(pt.btn || "0xC0");
            var moveTarget = "hyprctl dispatch 'hl.dsp.cursor.move({ x = " + pt.x + ", y = " + pt.y + " })'";
            var nudgeHover = "ydotool mousemove -x 1 -y 0 && sleep 0.01 && ydotool mousemove -x -1 -y 0";
            var mouseDown  = "hyprctl dispatch 'hl.dsp.send_key_state({ state = \"down\", mods = \"\", key = \"" + key + "\", window = \"activewindow\" })'";
            var mouseUp    = "hyprctl dispatch 'hl.dsp.send_key_state({ state = \"up\", mods = \"\", key = \"" + key + "\", window = \"activewindow\" })'";
            cmds.push(moveTarget + " && sleep 0.01 && " + nudgeHover + " && sleep " + moveDelay + " && " + mouseDown + " && sleep " + holdDelay + " && " + mouseUp);
            if (i < points.length - 1) cmds.push("sleep 0.04");
        }

        if (root.cursorReturnEnabled) {
            cmds.push("case \"$CX,$CY\" in ''|*,|,*|*[!0-9,-]*) ;; *) sleep " + returnDelay + "; hyprctl dispatch \"hl.dsp.cursor.move({ x = $CX, y = $CY })\" && ydotool mousemove -x 1 -y 0 ;; esac");
        }

        appendCombatLog("STRIKE", label + " -> 執行 " + points.length + " 點打擊");
        strikeExec.command = ["sh", "-c", cmds.join("; ")];
        strikeExec.running = false;
        strikeExec.running = true;
        soundPlayer.play(theme.soundAlarm);
    }

    function pickCurrentCursorCoord(btnCode) {
        pickCoordProc.pendingBtn = btnCode || "0xC0";
        pickCoordProc.running = false;
        pickCoordProc.running = true;
    }

    function clearRecentClicks() {
        root.recentClicks = [];
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
            "spamKeys": root.spamKeys,
            "caffeine": root.caffeineActive,
            "sleepMinutes": root.sleepMinutes
        };
        saveCoordsProc.command = ["sh", "-c", "cat <<'EOF' > \"$HOME/.config/quickshell/coords.json\"\n" + JSON.stringify(payload, null, 2) + "\nEOF"];
        saveCoordsProc.running = false;
        saveCoordsProc.running = true;
    }

    Process {
        id: loadCoordsProc
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/coords.json\" 2>/dev/null || cat ./coords.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var data = text.trim();
                if (!data) return;
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
                    if (obj.spamKeys && obj.spamKeys.length > 0) {
                        var loadedKeys = root.sanitizeSpamKeys(obj.spamKeys);
                        if (loadedKeys.length > 0) root.spamKeys = loadedKeys;
                    }
                    if (obj.caffeine !== undefined) root.caffeineActive = !!obj.caffeine;
                    if (obj.sleepMinutes !== undefined && obj.sleepMinutes >= 1) {
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

    Process {
        id: strikeExec
        stderr: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("STRIKE-ERR", s);
            }
        }
    }

    readonly property string clickerBinPath: Qt.resolvedUrl("albion-clicker").toString().replace(/^file:\/\//, "")
    readonly property string qspamBinPath: Qt.resolvedUrl("albion-qspam").toString().replace(/^file:\/\//, "")

    property var combatDebugLogs: []
    property bool clickerRunningReal: autoClickerRunner.running
    property bool qspamRunningReal: autoQRunner.running

    function appendCombatLog(tag, msg) {
        var line = "[" + clockObj.fullTimeString + "] [" + tag + "] " + String(msg);
        console.warn("[CombatHUD]", line);
        var next = [line];
        for (var i = 0; i < root.combatDebugLogs.length && next.length < 40; i++) {
            next.push(root.combatDebugLogs[i]);
        }
        root.combatDebugLogs = next;
        debugFlushTimer.restart();
    }

    function clearCombatLogs() {
        root.combatDebugLogs = [];
        debugFileWriter.clearFile();
    }

    function runCombatEnvDiagnostics() {
        appendCombatLog("DIAG", "開始檢查 albion-clicker / albion-qspam / 鎖定文件 / /dev/uinput...");
        combatDiagProc.running = false;
        combatDiagProc.running = true;
    }

    Component.onCompleted: {
        scriptRunner.run("rm -f /tmp/q_spam_enabled /tmp/clicker_enabled /tmp/netmon_pin; pkill -x albion-qspam 2>/dev/null || true; pkill -x albion-clicker 2>/dev/null || true; pkill -x focus-netmon 2>/dev/null || true; pkill -f '[s]leep_guard.sh' 2>/dev/null || true");
        appendCombatLog("INIT", "Quickshell 已初始化並清理舊鎖定文件 (/tmp/clicker_enabled, /tmp/q_spam_enabled)");
    }

    Timer {
        id: debugFlushTimer
        interval: 150; repeat: false
        onTriggered: debugFileWriter.flush(root.combatDebugLogs)
    }

    Process {
        id: debugFileWriter
        function flush(lines) {
            var body = lines.slice().reverse().join("\n");
            command = ["sh", "-c", "cat <<'EOF' > /tmp/quickshell_combat_debug.log\n" + body + "\nEOF"];
            running = false;
            running = true;
        }
        function clearFile() {
            command = ["sh", "-c", ": > /tmp/quickshell_combat_debug.log"];
            running = false;
            running = true;
        }
    }

    Process {
        id: combatDiagProc
        command: [
            "sh", "-c",
            "echo \"SHELL_DIR=$(dirname " + JSON.stringify(root.clickerBinPath) + ")\"; " +
            "ls -la " + JSON.stringify(root.clickerBinPath) + " " + JSON.stringify(root.qspamBinPath) + " \"$HOME/.config/quickshell/albion-clicker\" \"$HOME/.config/quickshell/albion-qspam\" 2>&1; " +
            "echo \"LOCK_CLICKER=$( [ -e /tmp/clicker_enabled ] && echo YES || echo NO ) BTN=$(cat /tmp/clicker_btn 2>/dev/null || echo unset) LOCK_Q=$( [ -e /tmp/q_spam_enabled ] && echo YES || echo NO )\"; " +
            "ls -la /dev/uinput /tmp/.ydotool_socket \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket\" 2>&1; " +
            "pgrep -af 'ydotoold|albion-clicker|albion-qspam' 2>&1 || echo 'NO_DAEMON_RUNNING'"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("DIAG", s);
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("DIAG-ERR", s);
            }
        }
    }

    onAutoClickerEnabledChanged: {
        appendCombatLog("CLICKER", "開關切換 -> " + (autoClickerEnabled ? "ON" : "OFF") + " (按鍵=" + clickerButtonCode + " --hold)");
        if (autoClickerEnabled) {
            autoClickerRunner.running = false;
            autoClickerRunner.running = true;
        } else {
            autoClickerRunner.running = false;
            clickerKillProc.running = false;
            clickerKillProc.running = true;
        }
    }

    onClickerButtonCodeChanged: {
        appendCombatLog("CLICKER", "切換連擊按鍵 -> " + clickerButtonCode);
        if (root.autoClickerEnabled) {
            clickerBtnWriter.command = ["sh", "-c", "printf '%s' " + JSON.stringify(root.clickerButtonCode) + " > /tmp/clicker_btn"];
            clickerBtnWriter.running = false;
            clickerBtnWriter.running = true;
        }
    }

    function launchQSpam() {
        var cleanKeys = root.sanitizeSpamKeys(root.spamKeys);
        var keysArg = cleanKeys.length > 0 ? cleanKeys.join(",") : "q";
        autoQRunner.running = false;
        autoQRunner.command = [
            "sh", "-c",
            "pkill -x albion-qspam 2>/dev/null || true; " +
            "touch /tmp/q_spam_enabled && " +
            "BIN=" + JSON.stringify(root.qspamBinPath) + "; " +
            "[ -x \"$BIN\" ] || BIN=\"$HOME/.config/quickshell/albion-qspam\"; " +
            "if [ ! -e \"$BIN\" ]; then echo \"ERR: binary not found at $BIN\" >&2; exit 127; fi; " +
            "if [ ! -x \"$BIN\" ]; then chmod +x \"$BIN\" 2>/dev/null || true; fi; " +
            "echo \"LAUNCH $BIN --flag /tmp/q_spam_enabled --keys " + keysArg + "\"; " +
            "exec \"$BIN\" --flag /tmp/q_spam_enabled --keys " + keysArg + " 2>&1"
        ];
        autoQRunner.running = true;
    }

    onAutoQActiveChanged: {
        appendCombatLog("QSPAM", "開關切換 -> " + (autoQActive ? "ON" : "OFF") + " (按鍵=" + root.spamKeys.join(",") + ")");
        if (autoQActive) {
            launchQSpam();
        } else {
            autoQRunner.running = false;
            qspamKillProc.running = false;
            qspamKillProc.running = true;
        }
    }

    Process { id: clickerBtnWriter }

    Process {
        id: clickerKillProc
        command: ["sh", "-c", "rm -f /tmp/clicker_enabled; pkill -x albion-clicker 2>/dev/null || true"]
    }

    Process {
        id: qspamKillProc
        command: ["sh", "-c", "rm -f /tmp/q_spam_enabled; pkill -x albion-qspam 2>/dev/null || true"]
    }

    Process {
        id: autoClickerRunner
        command: [
            "sh", "-c",
            "pkill -x albion-clicker 2>/dev/null || true; " +
            "printf '%s' " + JSON.stringify(root.clickerButtonCode) + " > /tmp/clicker_btn && " +
            "touch /tmp/clicker_enabled && " +
            "BIN=" + JSON.stringify(root.clickerBinPath) + "; " +
            "[ -x \"$BIN\" ] || BIN=\"$HOME/.config/quickshell/albion-clicker\"; " +
            "if [ ! -e \"$BIN\" ]; then echo \"ERR: binary not found at $BIN\" >&2; exit 127; fi; " +
            "if [ ! -x \"$BIN\" ]; then chmod +x \"$BIN\" 2>/dev/null || true; fi; " +
            "echo \"LAUNCH $BIN --hold (btn=" + root.clickerButtonCode + ")\"; " +
            "exec \"$BIN\" --hold 2>&1"
        ]
        onStarted: root.appendCombatLog("CLICKER", "albion-clicker --hold 已啟動 (/tmp/clicker_enabled 已建立)")
        onExited: function(code, status) {
            root.appendCombatLog("CLICKER", "進程退出 code=" + code + " status=" + status);
            if (root.autoClickerEnabled && code !== 0) {
                root.appendCombatLog("CLICKER", "⚠️ albion-clicker 異常退出，請查看上方日誌或點擊「🩺 診斷環境」");
            }
        }
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("CLICKER-OUT", s);
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("CLICKER-ERR", s);
            }
        }
    }

    Process {
        id: autoQRunner
        onStarted: root.appendCombatLog("QSPAM", "albion-qspam 已啟動 (keys=" + root.spamKeys.join(",") + ")")
        onExited: function(code, status) {
            root.appendCombatLog("QSPAM", "進程退出 code=" + code + " status=" + status);
            if (root.autoQActive && code !== 0) {
                root.appendCombatLog("QSPAM", "⚠️ albion-qspam 異常退出，請查看上方日誌或點擊「🩺 診斷環境」");
            }
        }
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("QSPAM-OUT", s);
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("QSPAM-ERR", s);
            }
        }
    }

    Process {
        id: scriptRunner
        function run(cmdStr) {
            command = ["sh", "-c", cmdStr];
            running = false;
            running = true;
        }
    }

    Process {
        id: clipboardWriter
        function copy(text) {
            command = ["sh", "-c", "printf '%s' " + JSON.stringify(String(text)) + " | wl-copy 2>/dev/null || true"];
            running = false;
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

    onClickRecordEnabledChanged: {
        appendCombatLog("RECORDER", "全局鼠標坐標錄製開關 -> " + (clickRecordEnabled ? "ON (全屏點擊監聽中)" : "OFF (已停止，0性能開銷)"));
    }

    Process {
        id: clickRecorderProc
        running: root.clickRecordEnabled
        command: [
            "python3", "-u", "-c",
            "import os, glob, fcntl, struct, selectors, subprocess, json\n" +
            "EVIOCGNAME = 0x81004506\n" +
            "EVIOCGBIT0 = 0x80084520\n" +
            "EVIOCGBIT1 = 0x80604521\n" +
            "BTN_MAP = {0x110: '0xC0', 0x111: '0xC1', 0x112: '0xC2'}\n" +
            "sel = selectors.DefaultSelector()\n" +
            "opened = []\n" +
            "for p in sorted(glob.glob('/dev/input/event*')):\n" +
            "    try:\n" +
            "        fd = os.open(p, os.O_RDONLY | os.O_NONBLOCK)\n" +
            "        name_b = bytearray(256)\n" +
            "        try:\n" +
            "            fcntl.ioctl(fd, EVIOCGNAME, name_b, True)\n" +
            "            nm = name_b.split(b'\\x00', 1)[0].decode('utf-8', 'ignore').lower()\n" +
            "        except Exception:\n" +
            "            nm = ''\n" +
            "        if any(k in nm for k in ('ydotool', 'albion', 'uinput')):\n" +
            "            os.close(fd); continue\n" +
            "        b0 = bytearray(8)\n" +
            "        fcntl.ioctl(fd, EVIOCGBIT0, b0, True)\n" +
            "        if not (b0[0] & 0x02):\n" +
            "            os.close(fd); continue\n" +
            "        b1 = bytearray(96)\n" +
            "        fcntl.ioctl(fd, EVIOCGBIT1, b1, True)\n" +
            "        if (b1[34] & 0x01):\n" +
            "            sel.register(fd, selectors.EVENT_READ)\n" +
            "            opened.append(fd)\n" +
            "        else:\n" +
            "            os.close(fd)\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "if not opened:\n" +
            "    print('ERR|no_evdev_permission', flush=True)\n" +
            "else:\n" +
            "    EV_FMT = '@llHHi'\n" +
            "    EV_SZ = struct.calcsize(EV_FMT)\n" +
            "    while True:\n" +
            "        for key, _ in sel.select():\n" +
            "            try:\n" +
            "                data = os.read(key.fd, EV_SZ * 16)\n" +
            "            except BlockingIOError:\n" +
            "                continue\n" +
            "            for off in range(0, len(data) - EV_SZ + 1, EV_SZ):\n" +
            "                _, _, typ, code, val = struct.unpack_from(EV_FMT, data, off)\n" +
            "                if typ == 1 and val == 1 and code in BTN_MAP:\n" +
            "                    try:\n" +
            "                        pos = subprocess.check_output(['hyprctl', 'cursorpos'], text=True).strip().split(',')\n" +
            "                        px = int(pos[0].strip()); py = int(pos[1].strip())\n" +
            "                    except Exception:\n" +
            "                        px, py = 0, 0\n" +
            "                    cls, title, addr = 'Desktop', '', '0x0'\n" +
            "                    try:\n" +
            "                        w = json.loads(subprocess.check_output(['hyprctl', 'activewindow', '-j'], text=True))\n" +
            "                        cls = w.get('class') or 'Desktop'\n" +
            "                        title = (w.get('title') or '').replace('|', ' ')[:48]\n" +
            "                        addr = w.get('address') or '0x0'\n" +
            "                    except Exception:\n" +
            "                        pass\n" +
            "                    print(f'{px}|{py}|{BTN_MAP[code]}|{cls}|{title}|{addr}', flush=True)\n"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (!s) return;
                var parts = s.split("|");
                if (parts[0] === "ERR") {
                    root.appendCombatLog("RECORDER-ERR", "無法讀取 /dev/input/event*，請改用「🎯 全屏取點」或確認用戶在 input 組");
                    root.clickRecordEnabled = false;
                    return;
                }
                if (parts.length >= 4) {
                    var px = parseInt(parts[0], 10) || 0;
                    var py = parseInt(parts[1], 10) || 0;
                    var btn = parts[2] || "0xC0";
                    var cls = parts[3] || "Desktop";
                    var title = parts[4] || "";
                    var addr = parts[5] || "0x0";
                    root.recordRecentClick(px, py, btn, cls);
                    if (centerInspect) {
                        centerInspect.pushHandleHistory("CLICK", cls, title, addr, px, py);
                    }
                }
            }
        }
        stderr: SplitParser {
            onRead: function(line) {
                var s = String(line).trim();
                if (s !== "") root.appendCombatLog("RECORDER-ERR", s);
            }
        }
    }

    Process {
        id: pickCoordProc
        property string pendingBtn: "0xC0"
        command: ["sh", "-c", "CUR=$(hyprctl cursorpos 2>/dev/null); echo \"$CUR\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(",");
                if (parts.length >= 2) {
                    var px = parseInt(parts[0].trim(), 10) || 0;
                    var py = parseInt(parts[1].trim(), 10) || 0;
                    var btn = pickCoordProc.pendingBtn || "0xC0";
                    root.recordRecentClick(px, py, btn, "全屏取點 (" + root.liveClass + ")");
                    root.copiedCoord = { "x": px, "y": py, "btn": btn };
                    clipboardWriter.copy(px + ", " + py);
                    soundPlayer.play(theme.soundClick);
                    if (centerInspect) {
                        centerInspect.pushHandleHistory("CLICK", root.liveClass, "全屏取點 (" + btn + ")", root.liveAddr, px, py);
                    }
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
            command = ["canberra-gtk-play", "-i", soundName, "-V", theme.soundVolume];
            running = false;
            running = true;
        }
    }

    Process {
        id: volReader
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pamixer --get-volume 2>/dev/null || echo 'Volume: 0.50'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var str = text.trim();
                root.systemMuted = str.indexOf("MUTED") !== -1;
                var m = str.match(/([0-9]+(\.[0-9]+)?)/);
                if (m) {
                    var val = parseFloat(m[1]);
                    if (val <= 1.0) val = Math.round(val * 100);
                    root.systemVolume = Math.min(100, Math.max(0, Math.round(val)));
                }
            }
        }
    }

    Process {
        id: volWriter
        function setVolume(pct) {
            var clamped = Math.max(0, Math.min(100, Math.round(pct)));
            root.systemVolume = clamped;
            if (clamped > 0 && root.systemMuted) root.systemMuted = false;
            command = ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100.0).toFixed(2) + " 2>/dev/null || pamixer --set-volume " + clamped];
            running = false;
            running = true;
        }
        function toggleMute() {
            root.systemMuted = !root.systemMuted;
            command = ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || pamixer -t"];
            running = false;
            running = true;
        }
    }

    Process {
        id: wifiProcess
        command: ["sh", "-c", "nmcli -t -f TYPE,CONNECTION dev | grep '^wifi:' | cut -d: -f2 | grep -v '^--$' | head -n1 || echo '未連接'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim();
                root.currentWifi = s.length > 0 ? s : "未連接";
            }
        }
    }

    Process {
        id: imeProcess
        command: ["sh", "-c", "STATE=$(fcitx5-remote 2>/dev/null); if [ \"$STATE\" = \"2\" ]; then echo '中 (拼音)'; else echo 'EN (英文)'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var val = text.trim();
                if (val.length > 0) root.currentIme = val;
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
        interval: (root.inspectMode || root.screenPickerActive) ? 250 : 1200
        running: true; repeat: true
        onTriggered: {
            if (root.inspectMode || root.screenPickerActive) {
                if (!cursorTracker.running) cursorTracker.running = true;
                if (!activeWinTracker.running) activeWinTracker.running = true;
            }
            if (!volReader.running) volReader.running = true;
            if (!wifiProcess.running) wifiProcess.running = true;
            if (!imeProcess.running) imeProcess.running = true;
            if (!audioStreamProbeProc.running) audioStreamProbeProc.running = true;
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

    // 桌面左下角滾輪切換虛擬桌面熱區 (僅在非 CenterInspect 界面且全螢幕兼容)
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bottomLeftWheelCorner
            required property var modelData
            screen: modelData
            visible: !root.inspectMode && !root.screenPickerActive
            anchors { bottom: true; left: true }
            implicitWidth: 44
            implicitHeight: 44
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-bottom-left-wheel"
            color: "transparent"

            property double lastWheelMs: 0

            Rectangle {
                anchors.fill: parent
                color: cornerMouse.containsMouse ? "#1a38bdf8" : "#01000000"
                border.width: cornerMouse.containsMouse ? 1 : 0
                border.color: "#66fde047"
                radius: 8

                Text {
                    visible: cornerMouse.containsMouse
                    anchors.centerIn: parent
                    text: "W" + ((Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
                                 ? Hyprland.focusedMonitor.activeWorkspace.id
                                 : root.activeWorkspace)
                    color: theme.geminiGold
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.bold: true
                }

                MouseArea {
                    id: cornerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        var cur = (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
                                  ? Hyprland.focusedMonitor.activeWorkspace.id
                                  : root.activeWorkspace;
                        root.appendCombatLog("WHEEL", "進入左下角熱區 screen=" + (modelData ? modelData.name : "?") + " curWs=" + cur);
                    }
                    onWheel: function(wheel) {
                        wheel.accepted = true;
                        var ay = wheel.angleDelta ? wheel.angleDelta.y : 0;
                        var py = wheel.pixelDelta ? wheel.pixelDelta.y : 0;
                        var cur = (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
                                  ? Hyprland.focusedMonitor.activeWorkspace.id
                                  : root.activeWorkspace;
                        root.appendCombatLog("WHEEL", "onWheel 事件: angleY=" + ay + " pixelY=" + py + " inv=" + (!!wheel.inverted) + " curWs=" + cur);
                        var dy = ay !== 0 ? ay : py;
                        if (dy === 0) {
                            root.appendCombatLog("WHEEL", "忽略 dy=0 的滾輪事件");
                            return;
                        }
                        var now = Date.now();
                        if (now - bottomLeftWheelCorner.lastWheelMs < 120) {
                            root.appendCombatLog("WHEEL", "節流跳過 (<120ms)");
                            return;
                        }
                        bottomLeftWheelCorner.lastWheelMs = now;
                        var nextWs = (dy > 0)
                            ? (cur <= 1 ? 5 : cur - 1)
                            : (cur >= 5 ? 1 : cur + 1);
                        root.onSelectWorkspace(nextWs);
                    }
                }
            }
        }
    }

    // 左下角虛擬桌面切換浮動提示 (穿透鼠標)
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.wsToastVisible && !root.inspectMode && !root.screenPickerActive
            anchors { bottom: true; left: true }
            implicitWidth: wsToastTxt.implicitWidth + 48
            implicitHeight: 90
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 52
                anchors.left: parent.left
                anchors.leftMargin: 12
                width: wsToastTxt.implicitWidth + 24
                height: 28
                radius: 14
                color: "#e618181b"
                border.width: 1
                border.color: theme.geminiGold

                Text {
                    id: wsToastTxt
                    anchors.centerIn: parent
                    text: root.wsToastText
                    color: "#f4f4f5"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }

    // 全屏坐標取點覆蓋層 (按需開啟，零駐留開銷)
    PanelWindow {
        id: screenPickerWin
        visible: root.screenPickerActive
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "#1a000000"

        Item {
            anchors.fill: parent
            focus: root.screenPickerActive
            Keys.onEscapePressed: root.screenPickerActive = false

            // 十字準星線
            Rectangle {
                x: 0; y: pickerMouse.mouseY; width: parent.width; height: 1
                color: "#6638bdf8"
                visible: pickerMouse.containsMouse
            }
            Rectangle {
                x: pickerMouse.mouseX; y: 0; width: 1; height: parent.height
                color: "#6638bdf8"
                visible: pickerMouse.containsMouse
            }

            // 跟隨光標實時坐標膠囊
            Rectangle {
                visible: pickerMouse.containsMouse
                x: Math.min(parent.width - width - 12, pickerMouse.mouseX + 16)
                y: Math.min(parent.height - height - 12, pickerMouse.mouseY + 16)
                width: liveCoordTxt.implicitWidth + 16; height: 24; radius: 6
                color: "#e618181b"; border.color: theme.geminiCyan; border.width: 1
                Text {
                    id: liveCoordTxt
                    anchors.centerIn: parent
                    text: "🎯 " + root.liveCursorPos
                    color: theme.geminiGold; font.family: "monospace"; font.pixelSize: 11; font.bold: true
                }
            }

            // 頂部提示與取消按鈕
            Rectangle {
                anchors.top: parent.top; anchors.topMargin: 18; anchors.horizontalCenter: parent.horizontalCenter
                width: hintRow.implicitWidth + 24; height: 34; radius: 17
                color: "#e618181b"; border.color: theme.geminiCyan; border.width: 1; z: 5
                Row {
                    id: hintRow
                    anchors.centerIn: parent; spacing: 12
                    Text {
                        text: "🎯 全屏取點模式 — 在螢幕任意位置點擊即可記錄並複製坐標 (ESC 取消)"
                        color: "#f4f4f5"; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 54; height: 22; radius: 11; color: "#27272a"; border.color: "#52525b"; border.width: 1
                        Text { anchors.centerIn: parent; text: "取消"; color: "#fda4af"; font.pixelSize: 10; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.screenPickerActive = false
                        }
                    }
                }
            }

            MouseArea {
                id: pickerMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.CrossCursor
                onClicked: function(mouse) {
                    var btn = "0xC0";
                    if (mouse.button === Qt.RightButton) btn = "0xC1";
                    else if (mouse.button === Qt.MiddleButton) btn = "0xC2";
                    root.pickCurrentCursorCoord(btn);
                    root.screenPickerActive = false;
                }
            }
        }
    }
}
