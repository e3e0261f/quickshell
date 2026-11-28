import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray

Item {
    id: tab3
    property var rootContext
    property var themeContext
    property var clockContext
    property var centerWin
    property var scriptRunner
    property var handleHistory
    property var netTelemetryProc
    property var volControl
    property var soundContext

    width: parent ? parent.width : 900
    implicitHeight: Math.max(leftCol.implicitHeight, rightCol.implicitHeight) + 24

    // 原左下角狀態：0=默認, 1=Wi-Fi雷達, 2=藍牙樞紐
    property int stageMode: 0
    property bool showSleepBlockers: false
    property bool wifiScanning: false
    property bool btScanning: false
    property string btState: "ON"
    property string btName: "未連線"
    property bool btDiscoverable: false
    property bool btPairable: false
    property bool hasPairRequest: false
    property string pairReqMac: ""
    property string pairReqPasskey: ""
    property bool trayMenuVisible: false
    property var activeTrayMenu: null
    property bool ptmKeyPickerOpen: false

    function ptmKeyDisplay(raw) {
        var k = String(raw || "v").toLowerCase();
        if (k === "capslock") return "CAPS";
        if (k === "grave") return "`";
        if (k === "space") return "SPC";
        if (k === "mouse4") return "側鍵4";
        if (k === "mouse5") return "側鍵5";
        if (k === "mousemiddle") return "中鍵";
        return k.toUpperCase();
    }

    property var sleepBlockerList: []

    function refreshSleepBlockers() {
        var next = [];
        var gold = themeContext ? String(themeContext.geminiGold) : "#fde047";
        var cyan = themeContext ? String(themeContext.geminiCyan) : "#38bdf8";
        var purple = themeContext ? String(themeContext.geminiPurple) : "#c084fc";

        if (rootContext && rootContext.caffeineActive) {
            next.push({ "icon": "☕", "tag": "手動常亮", "title": "已開啟「破曉無眠」常亮模式", "col": gold });
        }
        if (rootContext && !rootContext.isUserIdle) {
            var rem = Math.max(0, Math.min(2, rootContext.inputCooldownSec));
            next.push({
                "icon": "🖱️",
                "tag": "鍵鼠活動",
                "title": rem > 0 ? ("2秒內有鼠標/鍵盤輸入 (" + rem + "s)") : "檢測鍵鼠空閒狀態中...",
                "col": cyan
            });
        }
        var seenApps = {};
        if (Mpris && Mpris.players && Mpris.players.values) {
            for (var i = 0; i < Mpris.players.values.length; i++) {
                var p = Mpris.players.values[i];
                if (p && p.isPlaying) {
                    var idName = String(p.identity || "MPRIS Player");
                    var isWeb = rootContext && rootContext.isBrowserAudioApp ? rootContext.isBrowserAudioApp(idName, idName) : false;
                    seenApps[idName.toLowerCase()] = true;
                    next.push({
                        "icon": isWeb ? "🌐" : "🎵",
                        "tag": isWeb ? "網頁播放" : "軟件播放",
                        "title": idName + (p.trackTitle ? (" · " + p.trackTitle) : ""),
                        "col": purple
                    });
                }
            }
        }
        if (rootContext && rootContext.activeAudioStreams) {
            for (var j = 0; j < rootContext.activeAudioStreams.length; j++) {
                var st = rootContext.activeAudioStreams[j];
                if (!st) continue;
                var stKey = String(st.app || st.bin || "").toLowerCase();
                if (seenApps[stKey]) continue;
                seenApps[stKey] = true;
                next.push({
                    "icon": st.isBrowser ? "🌐" : "🔊",
                    "tag": st.isBrowser ? "網頁播放" : "軟件播放",
                    "title": (st.app || st.bin || "Audio") + (st.media ? (" · " + st.media) : ""),
                    "col": purple
                });
            }
        }
        if (next.length === 0) {
            next.push({ "icon": "✅", "tag": "倒計時中", "title": "無鍵鼠活動與媒體播放，正在倒計時", "col": "#4ade80" });
        }
        sleepBlockerList = next;
    }

    function formatCountdown() {
        if (!rootContext) return "30:00";
        if (rootContext.caffeineActive) return "∞";
        var sec = Math.max(0, rootContext.sleepCountdown);
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function connectBt(mac) {
        var cmd = "bluetoothctl info " + mac + " | grep -q 'Connected: yes' && bluetoothctl disconnect " + mac + " || (bluetoothctl pair " + mac + " 2>/dev/null; bluetoothctl trust " + mac + " 2>/dev/null; bluetoothctl connect " + mac + ")";
        cmdRunner.run(cmd);
        stageMode = 0;
        btStatusProc.running = false;
        btStatusProc.running = true;
    }

    Process {
        id: cmdRunner
        function run(cmd) {
            command = ["sh", "-c", cmd];
            running = false;
            running = true;
        }
    }

    Process {
        id: pairReqReader
        command: ["sh", "-c", "cat /tmp/bt_pair_request 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                var str = text.trim();
                if (str.length > 0 && str.indexOf("|") !== -1) {
                    var p = str.split("|");
                    tab3.pairReqMac = p[0];
                    tab3.pairReqPasskey = p[1];
                    tab3.hasPairRequest = true;
                } else {
                    tab3.hasPairRequest = false;
                }
            }
        }
    }

    ListModel { id: wifiListModel }

    Process {
        id: scanWifiProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null | awk -F: '$2 != \"\"' | head -n 4"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiListModel.clear();
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var parts = lines[i].split(":");
                    if (parts.length >= 3) {
                        wifiListModel.append({
                            inUse: parts[0] === "*",
                            ssid: parts[1],
                            signal: parseInt(parts[2]) || 50,
                            security: parts[3] || ""
                        });
                    }
                }
                tab3.wifiScanning = false;
            }
        }
    }

    ListModel { id: btListModel }

    Process {
        id: scanBtProc
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | head -n 4"]
        stdout: StdioCollector {
            onStreamFinished: {
                btListModel.clear();
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var p = lines[i].split(" ");
                    if (p.length >= 3 && p[0] === "Device") {
                        btListModel.append({
                            mac: p[1],
                            name: p.slice(2).join(" ")
                        });
                    }
                }
                tab3.btScanning = false;
            }
        }
    }

    Process {
        id: startScanBtProc
        command: ["sh", "-c", "timeout 5 bluetoothctl scan on >/dev/null 2>&1; bluetoothctl devices 2>/dev/null | head -n 4"]
        stdout: StdioCollector {
            onStreamFinished: {
                btListModel.clear();
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var p = lines[i].split(" ");
                    if (p.length >= 3 && p[0] === "Device") {
                        btListModel.append({
                            mac: p[1],
                            name: p.slice(2).join(" ")
                        });
                    }
                }
                tab3.btScanning = false;
            }
        }
    }

    Process {
        id: btStatusProc
        command: ["sh", "-c",
            "PWR=$(bluetoothctl show 2>/dev/null | grep -m1 'Powered:' | awk '{print $2}'); " +
            "DISC=$(bluetoothctl show 2>/dev/null | grep -m1 'Discoverable:' | awk '{print $2}'); " +
            "PAIR=$(bluetoothctl show 2>/dev/null | grep -m1 'Pairable:' | awk '{print $2}'); " +
            "DEV=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d ' ' -f 3-); " +
            "echo \"$PWR|$DISC|$PAIR|$DEV\""
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|");
                if (parts.length >= 3) {
                    var pwr = parts[0];
                    var disc = parts[1];
                    var pair = parts[2];
                    var dev = parts[3] || "";
                    tab3.btDiscoverable = (disc === "yes");
                    tab3.btPairable = (pair === "yes");

                    if (pwr !== "yes") {
                        tab3.btState = "OFF";
                        tab3.btName = "已關閉";
                    } else if (dev !== "") {
                        tab3.btState = "CONN";
                        tab3.btName = dev;
                    } else {
                        tab3.btState = "ON";
                        tab3.btName = "未連線";
                    }
                }
            }
        }
    }

    Connections {
        target: rootContext
        function onIsUserIdleChanged() { tab3.refreshSleepBlockers(); }
        function onInputCooldownSecChanged() { tab3.refreshSleepBlockers(); }
        function onCaffeineActiveChanged() { tab3.refreshSleepBlockers(); }
        function onActiveAudioStreamsChanged() { tab3.refreshSleepBlockers(); }
        function onHasMediaBlockerChanged() { tab3.refreshSleepBlockers(); }
    }

    Timer {
        interval: 500; running: tab3.showSleepBlockers; repeat: true
        onTriggered: tab3.refreshSleepBlockers()
    }

    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            tab3.refreshSleepBlockers();
            if (!btStatusProc.running) btStatusProc.running = true;
            if (!pairReqReader.running) pairReqReader.running = true;
        }
    }

    QsMenuOpener {
        id: trayMenuOpener
        menu: tab3.activeTrayMenu
    }

    Row {
        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 14
        readonly property real colW: (width - spacing) / 2

        // ============================================================
        // 左列：生產力與電源中樞 (原左下角完整保留)
        // ============================================================
        Rectangle {
            id: leftCol
            width: parent.colW
            implicitHeight: leftInner.implicitHeight + 24
            radius: 12; color: "#e6141418"; border.color: "#3f3f46"; border.width: 1

            Column {
                id: leftInner
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
                spacing: 10

                Item {
                    width: parent.width; height: 18
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "⬡ 生產力與電源中樞"
                        color: themeContext ? themeContext.geminiGold : "#fde047"
                        font.pixelSize: 10; font.bold: true
                    }
                    Row {
                        visible: tab3.stageMode !== 0
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Rectangle {
                            visible: tab3.stageMode === 1
                            width: 56; height: 18; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "🔄 重掃"; color: themeContext.geminiGold; font.pixelSize: 9 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tab3.wifiScanning = true;
                                    scanWifiProc.running = false;
                                    scanWifiProc.running = true;
                                }
                            }
                        }
                        Rectangle {
                            visible: tab3.stageMode === 2 && tab3.btState !== "OFF"
                            width: 62; height: 18; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: tab3.btScanning ? "⏳ 探測中" : "🔍 掃描"; color: themeContext.geminiPurple; font.pixelSize: 9 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tab3.btScanning = true;
                                    startScanBtProc.running = false;
                                    startScanBtProc.running = true;
                                }
                            }
                        }
                        Rectangle {
                            width: 56; height: 18; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "返回預設"; color: "#e4e4e7"; font.pixelSize: 9 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tab3.stageMode = 0 }
                        }
                    }
                }

                // 藍牙設備請求授權卡片 (原版 CornerBottomLeft 保留)
                Rectangle {
                    visible: tab3.hasPairRequest
                    width: parent.width; height: 52; radius: 8
                    color: "#2e1065"; border.width: 1; border.color: themeContext.geminiPurple
                    Row {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                        Column {
                            width: parent.width - 120; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text {
                                text: "📱 收到配對請求 (" + tab3.pairReqMac.slice(0, 8) + ")"
                                color: "#ffffff"; font.pixelSize: 10; font.bold: true
                            }
                            Text {
                                text: "密鑰: " + tab3.pairReqPasskey
                                color: themeContext.geminiGold; font.family: "monospace"; font.pixelSize: 10; font.bold: true
                            }
                        }
                        Row {
                            spacing: 6; anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 50; height: 24; radius: 5; color: "#166534"
                                Text { anchors.centerIn: parent; text: "同意"; color: "#86efac"; font.pixelSize: 9; font.bold: true }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cmdRunner.run("echo 'yes' > /tmp/bt_ctl_fifo; bluetoothctl trust " + tab3.pairReqMac + "; rm -f /tmp/bt_pair_request");
                                        tab3.hasPairRequest = false;
                                    }
                                }
                            }
                            Rectangle {
                                width: 50; height: 24; radius: 5; color: "#7f1d1d"
                                Text { anchors.centerIn: parent; text: "拒絕"; color: "#fca5a5"; font.pixelSize: 9; font.bold: true }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cmdRunner.run("echo 'no' > /tmp/bt_ctl_fifo; rm -f /tmp/bt_pair_request");
                                        tab3.hasPairRequest = false;
                                    }
                                }
                            }
                        }
                    }
                }

                // Stage 0：睡眠阻擋診斷 + 咖啡因/定時休眠 + 音量滑塊
                Column {
                    visible: tab3.stageMode === 0
                    width: parent.width; spacing: 8

                    Rectangle {
                        visible: tab3.showSleepBlockers
                        width: parent.width; height: Math.max(46, 24 + tab3.sleepBlockerList.length * 24); radius: 8
                        color: "#121216"; border.color: "#2e2e36"; border.width: 1
                        Column {
                            anchors.fill: parent; anchors.margins: 6; spacing: 4
                            Text { text: "🛡️ 當前阻擋睡眠的動作"; color: "#71717a"; font.pixelSize: 9; font.bold: true }
                            Repeater {
                                model: tab3.sleepBlockerList
                                Rectangle {
                                    required property var modelData
                                    width: parent.width; height: 20; radius: 5; color: "#18181b"
                                    Row {
                                        anchors.fill: parent; anchors.leftMargin: 6; spacing: 6
                                        Text { text: modelData.icon; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                        Rectangle {
                                            width: tagT.implicitWidth + 8; height: 14; radius: 3; color: "#27272a"; anchors.verticalCenter: parent.verticalCenter
                                            Text { id: tagT; anchors.centerIn: parent; text: modelData.tag; color: modelData.col; font.pixelSize: 8; font.bold: true }
                                        }
                                        Text { text: modelData.title; color: "#e4e4e7"; font.pixelSize: 9; width: 180; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }
                        }
                    }

                    // 破曉無眠 & 漏刻入眠
                    Rectangle {
                        width: parent.width; height: 38; radius: 8; color: "#18181b"
                        border.color: tab3.showSleepBlockers ? themeContext.geminiCyan : ((rootContext && rootContext.caffeineActive) ? themeContext.geminiGold : "#27272a")
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { tab3.refreshSleepBlockers(); tab3.showSleepBlockers = !tab3.showSleepBlockers; }
                        }

                        Item {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            Text {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: (tab3.showSleepBlockers ? "▴ " : "▸ ") + ((rootContext && rootContext.caffeineActive) ? "☕ 破曉無眠 (常亮)" : ("🌙 漏刻入眠 (" + (rootContext ? rootContext.sleepMinutes : 30) + "分睡眠)"))
                                color: (rootContext && rootContext.caffeineActive) ? themeContext.geminiGold : "#e4e4e7"
                                font.pixelSize: 11; font.bold: true
                            }
                            Row {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                Rectangle {
                                    width: 34; height: 18; radius: 9
                                    color: (rootContext && rootContext.caffeineActive) ? themeContext.geminiGold : "#3f3f46"
                                    Rectangle {
                                        width: 14; height: 14; radius: 7; color: "#ffffff"; y: 2
                                        x: (rootContext && rootContext.caffeineActive) ? 18 : 2
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!rootContext) return;
                                            rootContext.caffeineActive = !rootContext.caffeineActive;
                                            rootContext.sleepCountdown = rootContext.sleepMinutes * 60;
                                            rootContext.saveCoords();
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 48; height: 20; radius: 5; color: "#27272a"; border.color: "#3f3f46"; border.width: 1
                                    Text {
                                        anchors.centerIn: parent; text: tab3.formatCountdown()
                                        color: (rootContext && rootContext.caffeineActive) ? "#a1a1aa" : themeContext.geminiCyan
                                        font.family: "monospace"; font.pixelSize: 10; font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!rootContext) return;
                                            if (rootContext.caffeineActive) {
                                                rootContext.caffeineActive = false;
                                            } else {
                                                var presets = [5, 10, 15, 30, 60];
                                                var idx = presets.indexOf(rootContext.sleepMinutes);
                                                rootContext.sleepMinutes = presets[(idx + 1) % presets.length];
                                            }
                                            rootContext.sleepCountdown = rootContext.sleepMinutes * 60;
                                            rootContext.saveCoords();
                                        }
                                        onWheel: function(wheel) {
                                            if (!rootContext) return;
                                            rootContext.caffeineActive = false;
                                            var d = wheel.angleDelta.y > 0 ? 1 : -1;
                                            rootContext.sleepMinutes = Math.max(1, Math.min(120, rootContext.sleepMinutes + d));
                                            rootContext.sleepCountdown = rootContext.sleepMinutes * 60;
                                            rootContext.saveCoords();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 音量滑塊
                    Rectangle {
                        width: parent.width; height: 38; radius: 8; color: "#18181b"; border.color: "#27272a"; border.width: 1
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                            Text {
                                text: (rootContext && rootContext.systemMuted) ? "🔇" : "🔊"
                                font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (volControl) volControl.toggleMute()
                                }
                            }
                            Item {
                                id: volTrack
                                width: parent.width - 72; height: 14; anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: "#27272a"
                                    Rectangle {
                                        height: parent.height; radius: 3
                                        width: parent.width * ((rootContext ? rootContext.systemVolume : 50) / 100.0)
                                        color: (rootContext && rootContext.systemMuted) ? "#71717a" : themeContext.geminiCyan
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    function applyVol(mx) {
                                        if (!volControl) return;
                                        volControl.setVolume((mx / volTrack.width) * 100.0);
                                    }
                                    onPressed: function(m) { applyVol(m.x) }
                                    onPositionChanged: function(m) { if (pressed) applyVol(m.x) }
                                }
                            }
                            Text {
                                text: (rootContext ? rootContext.systemVolume : 50) + "%"
                                color: "#a1a1aa"; font.family: "monospace"; font.pixelSize: 10; font.bold: true
                                width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Push-to-Mute 按住靜音開關與鍵位配置
                    Rectangle {
                        readonly property bool ptmOn: !!(rootContext && rootContext.ptmEnabled)
                        readonly property bool ptmRunning: !!(rootContext && rootContext.ptmRunningReal)
                        readonly property bool ptmActiveMute: !!(rootContext && rootContext.ptmMuted)
                        width: parent.width
                        implicitHeight: ptmCol.implicitHeight + 14
                        radius: 8
                        color: ptmActiveMute ? "#2a0a12" : "#18181b"
                        border.color: ptmActiveMute ? "#fb7185" : ((ptmOn && ptmRunning) ? "#34d399" : (ptmOn ? "#f59e0b" : (tab3.ptmKeyPickerOpen ? themeContext.geminiCyan : "#27272a")))
                        border.width: 1

                        Column {
                            id: ptmCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 7; anchors.leftMargin: 10; anchors.rightMargin: 10
                            spacing: 7

                            Item {
                                width: parent.width; height: 24
                                Row {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    Text {
                                        text: (rootContext && rootContext.ptmMuted)
                                            ? "🎙️✕ 麥克風靜音中"
                                            : ((rootContext && rootContext.ptmEnabled)
                                                ? (rootContext.ptmRunningReal ? "🎙️ Push-to-Mute 就緒" : "⚠️ Push-to-Mute 未運行 (點擊重試)")
                                                : "🎙️ Push-to-Mute (按住靜音)")
                                        color: (rootContext && rootContext.ptmMuted)
                                            ? "#fda4af"
                                            : ((rootContext && rootContext.ptmEnabled)
                                                ? (rootContext.ptmRunningReal ? "#6ee7b7" : "#fbbf24")
                                                : "#e4e4e7")
                                        font.pixelSize: 11; font.bold: true
                                        MouseArea {
                                            enabled: !!(rootContext && rootContext.ptmEnabled && !rootContext.ptmRunningReal)
                                            anchors.fill: parent
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: if (rootContext) rootContext.launchPtm()
                                        }
                                    }
                                }

                                Row {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6

                                    Rectangle {
                                        visible: !!(rootContext && rootContext.ptmMuted)
                                        width: 44; height: 20; radius: 5; color: "#4c0519"; border.color: "#fb7185"; border.width: 1
                                        Text { anchors.centerIn: parent; text: "解除"; color: "#ffe4e6"; font.pixelSize: 9; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (rootContext) rootContext.ptmUnmuteNow()
                                        }
                                    }

                                    Rectangle {
                                        width: ptmBadgeTxt.implicitWidth + 14; height: 20; radius: 5
                                        color: tab3.ptmKeyPickerOpen ? "#172554" : "#27272a"
                                        border.color: tab3.ptmKeyPickerOpen ? themeContext.geminiCyan : "#3f3f46"
                                        border.width: 1
                                        Text {
                                            id: ptmBadgeTxt
                                            anchors.centerIn: parent
                                            text: "鍵: " + tab3.ptmKeyDisplay(rootContext ? rootContext.ptmKey : "v") + (tab3.ptmKeyPickerOpen ? " ▴" : " ▾")
                                            color: tab3.ptmKeyPickerOpen ? themeContext.geminiCyan : themeContext.geminiGold
                                            font.family: "monospace"; font.pixelSize: 9; font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: tab3.ptmKeyPickerOpen = !tab3.ptmKeyPickerOpen
                                        }
                                    }

                                    Rectangle {
                                        width: 34; height: 18; radius: 9
                                        color: (rootContext && rootContext.ptmEnabled) ? "#10b981" : "#3f3f46"
                                        Rectangle {
                                            width: 14; height: 14; radius: 7; color: "#ffffff"; y: 2
                                            x: (rootContext && rootContext.ptmEnabled) ? 18 : 2
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (rootContext) rootContext.ptmEnabled = !rootContext.ptmEnabled
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: tab3.ptmKeyPickerOpen
                                width: parent.width
                                implicitHeight: ptmPickerCol.implicitHeight + 12
                                radius: 6; color: "#121216"; border.color: "#2e2e36"; border.width: 1

                                Column {
                                    id: ptmPickerCol
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: 6
                                    spacing: 6

                                    Flow {
                                        width: parent.width; spacing: 4
                                        Repeater {
                                            model: [
                                                { "k": "v", "label": "V" },
                                                { "k": "capslock", "label": "CAPS" },
                                                { "k": "grave", "label": "`" },
                                                { "k": "b", "label": "B" },
                                                { "k": "f4", "label": "F4" },
                                                { "k": "f8", "label": "F8" },
                                                { "k": "ralt", "label": "RALT" },
                                                { "k": "rctrl", "label": "RCTRL" },
                                                { "k": "mouse4", "label": "側鍵4" },
                                                { "k": "mouse5", "label": "側鍵5" },
                                                { "k": "mousemiddle", "label": "中鍵" }
                                            ]
                                            Rectangle {
                                                required property var modelData
                                                readonly property bool activeKey: rootContext && rootContext.ptmKey === modelData.k
                                                width: presetTxt.implicitWidth + 12; height: 20; radius: 5
                                                color: activeKey ? "#064e3b" : "#1f1f24"
                                                border.color: activeKey ? "#34d399" : "#3f3f46"
                                                border.width: 1
                                                Text {
                                                    id: presetTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: activeKey ? "#6ee7b7" : "#d4d4d8"
                                                    font.family: "monospace"; font.pixelSize: 9; font.bold: true
                                                }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (rootContext) rootContext.setPtmKey(modelData.k);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        width: parent.width; height: 24; spacing: 6
                                        Rectangle {
                                            width: parent.width - 52; height: 24; radius: 5
                                            color: "#09090b"; border.color: ptmCustomInput.activeFocus ? themeContext.geminiCyan : "#3f3f46"; border.width: 1
                                            TextInput {
                                                id: ptmCustomInput
                                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: "#f4f4f5"; font.family: "monospace"; font.pixelSize: 10
                                                clip: true; selectByMouse: true
                                                Text {
                                                    visible: ptmCustomInput.text.length === 0
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "自定義: a-z, f1-f12, capslock, mouse4..."
                                                    color: "#52525b"; font.pixelSize: 9
                                                }
                                                onAccepted: {
                                                    if (rootContext && rootContext.setPtmKey(ptmCustomInput.text)) {
                                                        ptmCustomInput.text = "";
                                                    }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            width: 46; height: 24; radius: 5
                                            color: "#065f46"; border.color: "#34d399"; border.width: 1
                                            Text { anchors.centerIn: parent; text: "確定"; color: "#ecfdf5"; font.pixelSize: 9; font.bold: true }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (rootContext && rootContext.setPtmKey(ptmCustomInput.text)) {
                                                        ptmCustomInput.text = "";
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        width: parent.width; height: 20
                                        Text {
                                            anchors.left: parent.left; anchors.right: ptmTestBtn.left; anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            font.family: "monospace"; font.pixelSize: 8
                                            color: (rootContext && rootContext.ptmLastError) ? "#fda4af" : "#71717a"
                                            text: (rootContext && rootContext.ptmLastError)
                                                ? ("ERR: " + rootContext.ptmLastError)
                                                : ((rootContext && rootContext.ptmBackendInfo) ? rootContext.ptmBackendInfo : "等待啟動 Push-to-Mute...")
                                        }
                                        Rectangle {
                                            id: ptmTestBtn
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: 62; height: 18; radius: 4
                                            color: "#27272a"; border.color: "#52525b"; border.width: 1
                                            Text { anchors.centerIn: parent; text: "測試靜音"; color: "#fda4af"; font.pixelSize: 8; font.bold: true }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: if (rootContext) rootContext.testPtmAudioMute()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Stage 1: Wi-Fi 雷達列表 (原版左下角完整行為)
                Rectangle {
                    visible: tab3.stageMode === 1
                    width: parent.width; height: 92; radius: 8; color: "#18181b"; border.color: themeContext.geminiGold; border.width: 1; clip: true

                    Row {
                        visible: tab3.wifiScanning
                        anchors.centerIn: parent; spacing: 8
                        Text { text: "⏳"; font.pixelSize: 12 }
                        Text { text: "正在雷達掃描周邊 Wi-Fi..."; color: themeContext.geminiGold; font.pixelSize: 10; font.bold: true }
                    }

                    Item {
                        visible: !tab3.wifiScanning && wifiListModel.count === 0
                        anchors.fill: parent
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Text { text: "📡"; font.pixelSize: 12 }
                            Text { text: "未發現可用熱點 (點擊重新探測)"; color: "#71717a"; font.pixelSize: 10 }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tab3.wifiScanning = true;
                                scanWifiProc.running = false;
                                scanWifiProc.running = true;
                            }
                        }
                    }

                    Column {
                        visible: !tab3.wifiScanning && wifiListModel.count > 0
                        anchors.fill: parent; anchors.margins: 4; spacing: 2
                        Repeater {
                            model: wifiListModel
                            delegate: Rectangle {
                                width: parent.width; height: 18; radius: 3
                                color: model.inUse ? "#1e1b4b" : (wifiItemArea.containsMouse ? "#27272a" : "transparent")
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 6; spacing: 6
                                    Text { text: "📶"; font.pixelSize: 8 }
                                    Text {
                                        text: model.ssid
                                        color: model.inUse ? themeContext.geminiGold : "#ffffff"
                                        font.pixelSize: 9; font.bold: model.inUse; elide: Text.ElideRight; width: 240
                                    }
                                    Text { text: model.security ? "🔒" : ""; font.pixelSize: 8 }
                                    Text { text: model.signal + "%"; color: "#71717a"; font.pixelSize: 8; font.family: "monospace" }
                                }
                                MouseArea {
                                    id: wifiItemArea
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cmdRunner.run("nmcli connection up '" + model.ssid + "' 2>/dev/null || nmcli dev wifi connect '" + model.ssid + "'");
                                        tab3.stageMode = 0;
                                    }
                                }
                            }
                        }
                    }
                }

                // Stage 2: 藍牙樞紐 (原版左下角完整行為)
                Rectangle {
                    visible: tab3.stageMode === 2
                    width: parent.width; height: 112; radius: 8; color: "#18181b"; border.color: themeContext.geminiPurple; border.width: 1; clip: true
                    Column {
                        anchors.fill: parent; anchors.margins: 6; spacing: 4
                        Item {
                            width: parent.width; height: 16
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                                Row {
                                    spacing: 4
                                    Text { text: (tab3.btState !== "OFF") ? "⚡" : "💤"; font.pixelSize: 9 }
                                    Text {
                                        text: (tab3.btState !== "OFF") ? "射頻開" : "射頻關"
                                        color: (tab3.btState !== "OFF") ? themeContext.geminiPurple : "#71717a"
                                        font.pixelSize: 9; font.bold: true
                                    }
                                    Rectangle {
                                        width: 24; height: 13; radius: 6
                                        color: (tab3.btState !== "OFF") ? themeContext.geminiPurple : "#3f3f46"
                                        Rectangle {
                                            width: 9; height: 9; radius: 4; color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: (tab3.btState !== "OFF") ? (parent.width - width - 2) : 2
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (tab3.btState !== "OFF") {
                                                    tab3.btState = "OFF";
                                                    tab3.btName = "已關閉";
                                                    tab3.btDiscoverable = false;
                                                    tab3.btPairable = false;
                                                    cmdRunner.run("bluetoothctl power off");
                                                } else {
                                                    tab3.btState = "ON";
                                                    tab3.btName = "未連線";
                                                    cmdRunner.run("bluetoothctl power on");
                                                }
                                            }
                                        }
                                    }
                                }
                                Row {
                                    spacing: 4
                                    visible: tab3.btState !== "OFF"
                                    Text { text: tab3.btDiscoverable ? "📡" : "🙈"; font.pixelSize: 9 }
                                    Text {
                                        text: tab3.btDiscoverable ? "廣播開" : "廣播隱"
                                        color: tab3.btDiscoverable ? themeContext.geminiCyan : "#71717a"
                                        font.pixelSize: 9; font.bold: true
                                    }
                                    Rectangle {
                                        width: 24; height: 13; radius: 6
                                        color: tab3.btDiscoverable ? themeContext.geminiCyan : "#3f3f46"
                                        Rectangle {
                                            width: 9; height: 9; radius: 4; color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: tab3.btDiscoverable ? (parent.width - width - 2) : 2
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                tab3.btDiscoverable = !tab3.btDiscoverable;
                                                cmdRunner.run(tab3.btDiscoverable ? "bluetoothctl discoverable on" : "bluetoothctl discoverable off");
                                            }
                                        }
                                    }
                                }
                                Row {
                                    spacing: 4
                                    visible: tab3.btState !== "OFF"
                                    Text { text: tab3.btPairable ? "🤝" : "🔒"; font.pixelSize: 9 }
                                    Text {
                                        text: tab3.btPairable ? "配對允" : "配對拒"
                                        color: tab3.btPairable ? themeContext.geminiGold : "#71717a"
                                        font.pixelSize: 9; font.bold: true
                                    }
                                    Rectangle {
                                        width: 24; height: 13; radius: 6
                                        color: tab3.btPairable ? themeContext.geminiGold : "#3f3f46"
                                        Rectangle {
                                            width: 9; height: 9; radius: 4; color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: tab3.btPairable ? (parent.width - width - 2) : 2
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                tab3.btPairable = !tab3.btPairable;
                                                if (tab3.btPairable) {
                                                    tab3.btDiscoverable = true;
                                                    cmdRunner.run("pgrep -f bt_agent.sh >/dev/null || nohup ~/.config/quickshell/bt_agent.sh >/dev/null 2>&1 &");
                                                } else {
                                                    cmdRunner.run("pkill -f bt_agent.sh; rm -f /tmp/bt_ctl_fifo; bluetoothctl discoverable off; bluetoothctl pairable off");
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle { width: parent.width - 12; height: 1; color: "#27272a"; anchors.horizontalCenter: parent.horizontalCenter }

                        Item {
                            width: parent.width; height: parent.height - 24; clip: true
                            Text {
                                anchors.centerIn: parent
                                visible: tab3.btState === "OFF"
                                text: "💤 藍牙硬件已休眠，開啟射頻後方可探測"
                                color: "#71717a"; font.pixelSize: 9
                            }
                            Column {
                                anchors.centerIn: parent; spacing: 3
                                visible: tab3.btState !== "OFF" && btListModel.count === 0
                                Text {
                                    text: tab3.btScanning ? "📡 正在探測周邊設備..." : "🎧 暫無配對設備"
                                    color: tab3.btScanning ? themeContext.geminiCyan : "#a1a1aa"
                                    font.pixelSize: 9; anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Rectangle {
                                    width: 110; height: 20; radius: 10; color: "#27272a"; border.width: 1; border.color: themeContext.geminiPurple
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Row {
                                        anchors.centerIn: parent; spacing: 4
                                        Text { text: tab3.btScanning ? "⏳" : "🔍"; font.pixelSize: 8 }
                                        Text { text: tab3.btScanning ? "探測中..." : "掃描新設備"; color: "#f3e8ff"; font.pixelSize: 8; font.bold: true }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            tab3.btScanning = true;
                                            startScanBtProc.running = false;
                                            startScanBtProc.running = true;
                                        }
                                    }
                                }
                            }
                            Column {
                                anchors.fill: parent; spacing: 2
                                visible: tab3.btState !== "OFF" && btListModel.count > 0
                                Repeater {
                                    model: btListModel
                                    delegate: Rectangle {
                                        width: parent.width - 12; height: 20; radius: 3; anchors.horizontalCenter: parent.horizontalCenter
                                        color: (tab3.btName === model.name) ? "#2e1065" : (btItemArea.containsMouse ? "#27272a" : "transparent")
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 6; spacing: 6
                                            Text { text: "🎧"; font.pixelSize: 8 }
                                            Text {
                                                text: model.name
                                                color: (tab3.btName === model.name) ? themeContext.geminiCyan : "#ffffff"
                                                font.pixelSize: 9; font.bold: true; elide: Text.ElideRight; width: 240
                                            }
                                        }
                                        MouseArea {
                                            id: btItemArea
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: tab3.connectBt(model.mac)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 通信雙子星 (Wi-Fi & 藍牙)
                Row {
                    width: parent.width; spacing: 8
                    readonly property real halfW: (width - spacing) / 2
                    Rectangle {
                        width: parent.halfW; height: 34; radius: 8
                        color: (tab3.stageMode === 1) ? "#27272a" : "#18181b"
                        border.width: 1; border.color: (tab3.stageMode === 1) ? themeContext.geminiGold : "#27272a"
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "📶"; font.pixelSize: 11 }
                            Text {
                                text: rootContext ? rootContext.currentWifi : "未連接"
                                color: (rootContext && rootContext.currentWifi !== "未連接") ? "#f4f4f5" : "#71717a"
                                font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; width: 120
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tab3.stageMode === 1) {
                                    tab3.stageMode = 0;
                                } else {
                                    tab3.stageMode = 1;
                                    tab3.wifiScanning = true;
                                    scanWifiProc.running = false;
                                    scanWifiProc.running = true;
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.halfW; height: 34; radius: 8
                        color: (tab3.stageMode === 2) ? "#27272a" : "#18181b"
                        border.width: 1; border.color: (tab3.stageMode === 2) ? themeContext.geminiPurple : "#27272a"
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text {
                                text: (tab3.btState === "CONN") ? "🎧" : "ᛒ"
                                font.pixelSize: 11
                                color: (tab3.btState === "CONN") ? themeContext.geminiCyan : ((tab3.btState === "ON") ? "#e4e4e7" : "#71717a")
                            }
                            Text {
                                text: tab3.btName
                                color: (tab3.btState === "CONN") ? "#ffffff" : ((tab3.btState === "ON") ? "#e4e4e7" : "#71717a")
                                font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; width: 120
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tab3.stageMode === 2) {
                                    tab3.stageMode = 0;
                                } else {
                                    tab3.stageMode = 2;
                                    scanBtProc.running = false;
                                    scanBtProc.running = true;
                                    btStatusProc.running = false;
                                    btStatusProc.running = true;
                                }
                            }
                        }
                    }
                }

                // 工作區矩陣 + ✦ 魔術區
                Rectangle {
                    width: parent.width; height: 62; radius: 10; color: "#18181b"; border.color: "#27272a"; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                            Text { text: "WORKSPACES"; color: "#71717a"; font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: 64; height: 18; radius: 9; color: "#2e1065"; border.color: themeContext.geminiPurple; border.width: 1
                                Row {
                                    anchors.centerIn: parent; spacing: 3
                                    Text { text: "✦"; color: themeContext.geminiPurple; font.pixelSize: 9 }
                                    Text { text: "魔術區"; color: "#f3e8ff"; font.pixelSize: 9; font.bold: true }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("togglespecialworkspace magic")
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                            Repeater {
                                model: [1, 2, 3, 4, 5]
                                Rectangle {
                                    required property int modelData
                                    readonly property bool focused: rootContext && rootContext.activeWorkspace === modelData
                                    width: focused ? 26 : 18; height: 18; radius: 9
                                    color: focused ? themeContext.geminiGold : "#27272a"
                                    Behavior on width { NumberAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: String(modelData); color: focused ? "#18181b" : "#a1a1aa"; font.pixelSize: 9; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (rootContext && rootContext.onSelectWorkspace) {
                                                rootContext.onSelectWorkspace(modelData);
                                            } else {
                                                Hyprland.dispatch("workspace " + modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 五鍵電源管理條
                Row {
                    width: parent.width; spacing: 6
                    readonly property real btnW: (width - spacing * 4) / 5
                    Repeater {
                        model: [
                            { label: "💤 睡眠", cmd: "systemctl suspend", danger: false },
                            { label: "🔒 鎖屏", cmd: "hyprlock", danger: false },
                            { label: "🚪 登出", cmd: "hyprctl dispatch exit", danger: false },
                            { label: "🔄 重啟", cmd: "systemctl reboot", danger: false },
                            { label: "⏻ 關機", cmd: "systemctl poweroff", danger: true }
                        ]
                        Rectangle {
                            required property var modelData
                            width: parent.btnW; height: 28; radius: 6
                            color: modelData.danger ? "#2a121b" : "#18181b"
                            border.color: modelData.danger ? "#7f1d1d" : "#27272a"; border.width: 1
                            Text {
                                anchors.centerIn: parent; text: modelData.label
                                color: modelData.danger ? "#fda4af" : "#d4d4d8"; font.pixelSize: 9; font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (scriptRunner) scriptRunner.run(modelData.cmd)
                            }
                        }
                    }
                }

                // 系統托盤圖標 + IME 輸入法微膠囊
                Item {
                    width: parent.width; height: 24
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Repeater {
                            model: SystemTray.items
                            Rectangle {
                                required property var modelData
                                width: 22; height: 22; radius: 5; color: "#18181b"; border.color: "#27272a"; border.width: 1
                                Image { anchors.centerIn: parent; width: 14; height: 14; source: modelData.icon || "" }
                                MouseArea {
                                    anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(m) {
                                        if (m.button === Qt.RightButton && modelData.hasMenu) {
                                            tab3.activeTrayMenu = modelData.menu;
                                            tab3.trayMenuVisible = !tab3.trayMenuVisible;
                                        } else {
                                            modelData.activate();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 82; height: 24; radius: 6; color: "#18181b"; border.color: "#27272a"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "⌨ " + (rootContext ? rootContext.currentIme : "EN (英文)")
                            color: "#e4e4e7"; font.pixelSize: 8; font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (scriptRunner) scriptRunner.run("fcitx5-remote -t")
                        }
                    }
                }

                // 自定義暗色托盤右鍵菜單
                Rectangle {
                    visible: tab3.trayMenuVisible
                    readonly property int menuCount: (trayMenuOpener.children && trayMenuOpener.children.values) ? trayMenuOpener.children.values.length : 0
                    width: 210; height: Math.max(32, menuCount * 24 + 10); radius: 8
                    color: "#18181b"; border.color: themeContext.geminiGold; border.width: 1
                    Column {
                        anchors.fill: parent; anchors.margins: 5; spacing: 2
                        Repeater {
                            model: trayMenuOpener.children
                            Rectangle {
                                required property var modelData
                                width: parent.width; height: modelData.isSeparator ? 5 : 22; radius: 4
                                color: (!modelData.isSeparator && mma.containsMouse) ? "#27272a" : "transparent"
                                Rectangle {
                                    visible: !!modelData.isSeparator
                                    anchors.centerIn: parent; width: parent.width - 8; height: 1; color: "#27272a"
                                }
                                Text {
                                    visible: !modelData.isSeparator
                                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 16; elide: Text.ElideRight
                                    text: modelData.text || ""
                                    color: (modelData.enabled !== false) ? "#f4f4f5" : "#52525b"
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    id: mma
                                    visible: !modelData.isSeparator && (modelData.enabled !== false)
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { modelData.triggered(); tab3.trayMenuVisible = false; }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ============================================================
        // 右列：邊緣光學與感官控制 (原右下角完整保留) + HYPRLAND TELEMETRY
        // ============================================================
        Column {
            id: rightCol
            width: parent.colW
            spacing: 12

            // 原右下角：邊緣光學與感官控制
            Rectangle {
                width: parent.width; height: 176; radius: 12
                color: "#e6141418"
                border.color: themeContext ? themeContext.geminiCoral : "#fb7185"; border.width: 1

                Column {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "⬡ 边缘光学与感官控制"
                        color: themeContext ? themeContext.geminiCoral : "#fb7185"
                        font.pixelSize: 12; font.bold: true
                    }

                    // ⚡ 极光爆发翻倍
                    Item {
                        width: parent.width; height: 24
                        Text {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            text: "⚡ 极光爆发翻倍"
                            color: (rootContext && rootContext.boostGlow) ? themeContext.geminiGold : "#d4d4d8"
                            font.pixelSize: 12; font.bold: true
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 24; radius: 12
                            color: (rootContext && rootContext.boostGlow) ? themeContext.geminiGold : "#3f3f46"
                            Rectangle {
                                width: 20; height: 20; radius: 10; color: "#ffffff"; y: 2
                                x: (rootContext && rootContext.boostGlow) ? 22 : 2
                                Behavior on x { NumberAnimation { duration: 160 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootContext) rootContext.boostGlow = !rootContext.boostGlow;
                                    if (soundContext) soundContext.play(themeContext.soundClick);
                                }
                            }
                        }
                    }

                    // 🔔 整点轻声微音
                    Item {
                        width: parent.width; height: 24
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "🔔 整点轻声微音"; color: "#d4d4d8"; font.pixelSize: 12; font.bold: true }
                        Rectangle {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 24; radius: 12
                            color: (rootContext && rootContext.chimeEnabled) ? "#34c759" : "#3f3f46"
                            Rectangle {
                                width: 20; height: 20; radius: 10; color: "#ffffff"; y: 2
                                x: (rootContext && rootContext.chimeEnabled) ? 22 : 2
                                Behavior on x { NumberAnimation { duration: 160 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootContext) rootContext.chimeEnabled = !rootContext.chimeEnabled;
                                    if (soundContext) soundContext.play(themeContext.soundClick);
                                }
                            }
                        }
                    }

                    // 📍 航标闹钟开关
                    Item {
                        width: parent.width; height: 24
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "📍 航标闹钟开关"; color: themeContext.alarmColor; font.pixelSize: 12; font.bold: true }
                        Rectangle {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 24; radius: 12
                            color: (rootContext && rootContext.alarmEnabled) ? themeContext.alarmColor : "#3f3f46"
                            Rectangle {
                                width: 20; height: 20; radius: 10; color: "#ffffff"; y: 2
                                x: (rootContext && rootContext.alarmEnabled) ? 22 : 2
                                Behavior on x { NumberAnimation { duration: 160 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootContext) rootContext.alarmEnabled = !rootContext.alarmEnabled;
                                    if (soundContext) soundContext.play(themeContext.soundClick);
                                }
                            }
                        }
                    }

                    // 目标时间步进器
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                        Text { text: "目标时间:"; color: "#94a3b8"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }

                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "-"; color: "#ffffff"; font.bold: true; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootContext) rootContext.alarmHour = ((rootContext.alarmHour - themeContext.alarmHourStep) % 12 + 12) % 12;
                                    if (soundContext) soundContext.play(themeContext.soundClick);
                                }
                            }
                        }
                        Text {
                            text: (rootContext && rootContext.alarmHour < 10 ? "0" : "") + (rootContext ? rootContext.alarmHour : 7) + "点"
                            color: themeContext.alarmColor; font.family: "monospace"; font.pixelSize: 12; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "+"; color: "#ffffff"; font.bold: true; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootContext) rootContext.alarmHour = (rootContext.alarmHour + themeContext.alarmHourStep) % 12;
                                    if (soundContext) soundContext.play(themeContext.soundClick);
                                }
                            }
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "-"; color: "#ffffff"; font.bold: true; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootContext) rootContext.alarmMinute = ((rootContext.alarmMinute - themeContext.alarmMinuteStep) % 60 + 60) % 60;
                                    if (soundContext) soundContext.play(themeContext.soundClick);
                                }
                            }
                        }
                        Text {
                            text: (rootContext && rootContext.alarmMinute < 10 ? "0" : "") + (rootContext ? rootContext.alarmMinute : 30) + "分"
                            color: themeContext.alarmColor; font.family: "monospace"; font.pixelSize: 12; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "+"; color: themeContext.geminiGold; font.bold: true; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (rootContext) rootContext.alarmMinute = (rootContext.alarmMinute + themeContext.alarmMinuteStep) % 60;
                                    if (soundContext) soundContext.play(themeContext.soundClick);
                                }
                            }
                        }
                    }
                }
            }

            // HYPRLAND TELEMETRY
            Rectangle {
                width: parent.width; height: 244; radius: 12
                color: "#e6141418"; border.color: "#3f3f46"; border.width: 1

                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                    Item {
                        width: parent.width; height: 20
                        Text {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            text: "HYPRLAND TELEMETRY"
                            color: themeContext ? themeContext.geminiRose : "#f43f5e"
                            font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: curTxt.implicitWidth + 16; height: 20; radius: 10
                            color: "#1e1b4b"; border.color: themeContext.geminiCyan; border.width: 1
                            Text {
                                id: curTxt; anchors.centerIn: parent
                                text: "🖱️ 實時: " + (rootContext ? rootContext.liveCursorPos : "0, 0")
                                color: "#ffffff"; font.family: "monospace"; font.pixelSize: 9; font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 36; radius: 10
                        color: "#3f1d38"; border.color: themeContext.geminiRose; border.width: 1
                        Row {
                            anchors.centerIn: parent; spacing: 10
                            Text { text: rootContext ? rootContext.liveClass : "Desktop"; color: "#ffffff"; font.family: "monospace"; font.pixelSize: 11; font.bold: true }
                            Text { text: rootContext ? rootContext.liveAddr : "0x0"; color: themeContext.geminiGold; font.family: "monospace"; font.pixelSize: 9 }
                            Text { text: rootContext ? rootContext.liveTitle : "Wayland"; color: "#a1a1aa"; font.pixelSize: 10; width: 150; elide: Text.ElideRight }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "RECENT ACTIONS & HANDLES (CLICK TO EXTRACT YDO/CLASS)"
                        color: "#71717a"; font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.5
                    }

                    ListView {
                        width: parent.width; height: parent.height - 102; clip: true; spacing: 4
                        model: handleHistory
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool isClick: modelData.actType === "CLICK"
                            width: ListView.view.width; height: 26; radius: 6
                            color: isClick ? "#172554" : (index === 0 ? "#18181b" : "#141416")
                            border.color: isClick ? themeContext.geminiBlue : (index === 0 ? themeContext.geminiRose : "#27272a"); border.width: 1

                            Row {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                Text { text: modelData.actTime; color: "#71717a"; font.family: "monospace"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 44; height: 16; radius: 4; color: isClick ? "#1e3a8a" : "#4c0519"; anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: isClick ? "🖱️ 點擊" : "🎯 焦點"; color: isClick ? "#93c5fd" : "#fda4af"; font.pixelSize: 8; font.bold: true }
                                }
                                Text {
                                    text: isClick ? (modelData.clickX + ", " + modelData.clickY) : modelData.winClass
                                    color: isClick ? themeContext.geminiGold : (index === 0 ? "#ffffff" : themeContext.geminiCyan)
                                    font.family: "monospace"; font.pixelSize: 9; font.bold: true; width: 88; elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text { text: modelData.winAddr; color: themeContext.geminiGold; font.family: "monospace"; font.pixelSize: 8; width: 64; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.winTitle; color: "#a1a1aa"; font.pixelSize: 9; width: 120; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var payload = isClick ? ("ydotool mousemove -a " + modelData.clickX + " " + modelData.clickY + " && ydotool click 0xC0") : modelData.winClass;
                                    if (scriptRunner) scriptRunner.run("printf '%s' " + JSON.stringify(payload) + " | wl-copy 2>/dev/null || true");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
