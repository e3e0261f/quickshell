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
    property bool trayMenuVisible: false
    property var activeTrayMenu: null

    property var wifiList: []
    property var btDeviceList: []
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
            next.push({ "icon": "🖱️", "tag": "鍵鼠活動", "title": "2秒內有鼠標/鍵盤輸入", "col": cyan });
        }
        if (Mpris && Mpris.players && Mpris.players.values) {
            for (var i = 0; i < Mpris.players.values.length; i++) {
                var p = Mpris.players.values[i];
                if (p && p.isPlaying) {
                    next.push({ "icon": "🎵", "tag": "媒體播放", "title": p.identity || "MPRIS Player", "col": purple });
                }
            }
        }
        if (next.length === 0) {
            next.push({ "icon": "✅", "tag": "倒計時中", "title": "無任何阻擋，正在推進睡眠倒計時", "col": "#4ade80" });
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

    property string wifiBuf: ""
    property string btStatusBuf: ""
    property string btDevsBuf: ""

    Process {
        id: wifiScanProc
        property bool forceRescan: false
        command: ["sh", "-c", forceRescan
            ? "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan yes 2>/dev/null | head -n 15"
            : "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | head -n 15"]
        onRunningChanged: {
            if (running) tab3.wifiBuf = "";
            else {
                var next = [];
                var seen = {};
                var lines = tab3.wifiBuf.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var raw = lines[i].replace(/\\:/g, "\u0000");
                    var parts = raw.split(":");
                    if (parts.length >= 3) {
                        var inUse = parts[0].trim() === "*";
                        var ssid = parts[1].replace(/\u0000/g, ":").trim();
                        if (ssid === "" || seen[ssid]) continue;
                        seen[ssid] = true;
                        next.push({
                            "inUse": inUse,
                            "ssid": ssid,
                            "signal": parseInt(parts[2], 10) || 0,
                            "security": (parts[3] || "").trim()
                        });
                    }
                }
                tab3.wifiList = next;
                tab3.wifiScanning = false;
                wifiScanProc.forceRescan = false;
            }
        }
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) { tab3.wifiBuf += String(data); }
        }
    }

    Process {
        id: wifiConnectProc
        function connectTo(ssid) {
            if (rootContext) rootContext.currentWifi = ssid;
            command = ["sh", "-c", "nmcli device wifi connect " + JSON.stringify(String(ssid)) + " 2>/dev/null"];
            running = true;
        }
        onRunningChanged: {
            if (!running) {
                tab3.wifiScanning = false;
                wifiScanProc.running = true;
            }
        }
    }

    Process {
        id: btStatusProc
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null; echo '---DEVS---'; bluetoothctl devices Connected 2>/dev/null"]
        running: true
        onRunningChanged: {
            if (running) tab3.btStatusBuf = "";
            else {
                var txt = tab3.btStatusBuf;
                if (txt.indexOf("Powered: yes") !== -1) {
                    tab3.btDiscoverable = txt.indexOf("Discoverable: yes") !== -1;
                    tab3.btPairable = txt.indexOf("Pairable: yes") !== -1;
                    var after = txt.split("---DEVS---")[1] || "";
                    var m = after.match(/Device\s+([0-9A-Fa-f:]+)\s+(.+)/);
                    if (m) {
                        tab3.btState = "CONN";
                        tab3.btName = m[2].trim();
                    } else {
                        tab3.btState = "ON";
                        tab3.btName = "未連線";
                    }
                } else if (txt.trim() !== "") {
                    tab3.btState = "OFF";
                    tab3.btName = "已關閉";
                    tab3.btDiscoverable = false;
                    tab3.btPairable = false;
                }
            }
        }
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) { tab3.btStatusBuf += String(data); }
        }
    }

    Process {
        id: btDevicesProc
        command: ["sh", "-c", "bluetoothctl devices Paired 2>/dev/null; bluetoothctl devices 2>/dev/null"]
        running: true
        onRunningChanged: {
            if (running) tab3.btDevsBuf = "";
            else {
                var next = [];
                var seenMac = {};
                var lines = tab3.btDevsBuf.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var m = lines[i].match(/Device\s+([0-9A-Fa-f:]+)\s+(.+)/);
                    if (m && !seenMac[m[1]]) {
                        seenMac[m[1]] = true;
                        next.push({ "mac": m[1], "name": m[2].trim() });
                    }
                }
                tab3.btDeviceList = next;
                tab3.btScanning = false;
            }
        }
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(data) { tab3.btDevsBuf += String(data); }
        }
    }

    Process {
        id: btActionProc
        function exec(cmdStr) {
            command = ["sh", "-c", cmdStr];
            running = true;
        }
        onRunningChanged: {
            if (!running) {
                btStatusProc.running = true;
                btDevicesProc.running = true;
            }
        }
    }

    Process {
        id: btScanProc
        command: ["sh", "-c", "bluetoothctl --timeout 6 scan on >/dev/null 2>&1 || true"]
        onRunningChanged: {
            if (!running) {
                tab3.btScanning = false;
                btDevicesProc.running = true;
            }
        }
    }

    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            tab3.refreshSleepBlockers();
            if (!btActionProc.running) btStatusProc.running = true;
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
                                    wifiScanProc.forceRescan = true;
                                    wifiScanProc.running = true;
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
                }

                // Stage 1: Wi-Fi 雷達列表 (原版左下角完整行為)
                Rectangle {
                    visible: tab3.stageMode === 1
                    width: parent.width; height: 92; radius: 8; color: "#18181b"; border.color: themeContext.geminiGold; border.width: 1; clip: true

                    Row {
                        visible: tab3.wifiScanning
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "⏳"; font.pixelSize: 10 }
                        Text { text: "正在雷達掃描周邊 Wi-Fi..."; color: themeContext.geminiGold; font.pixelSize: 10; font.bold: true }
                    }

                    Item {
                        visible: !tab3.wifiScanning && tab3.wifiList.length === 0
                        anchors.fill: parent
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "📡"; font.pixelSize: 10 }
                            Text { text: "未發現可用熱點 (點擊重新探測)"; color: "#71717a"; font.pixelSize: 10 }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tab3.wifiScanning = true;
                                wifiScanProc.forceRescan = true;
                                wifiScanProc.running = true;
                            }
                        }
                    }

                    ListView {
                        visible: !tab3.wifiScanning && tab3.wifiList.length > 0
                        anchors.fill: parent; anchors.margins: 6; spacing: 2; clip: true
                        model: tab3.wifiList
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width; height: 20; radius: 4
                            color: modelData.inUse ? "#1e1b4b" : "transparent"
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
                                Text { text: "📶"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.ssid; color: modelData.inUse ? themeContext.geminiGold : "#ffffff"; font.pixelSize: 9; font.bold: modelData.inUse; width: 220; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.security !== "" ? "🔒" : ""; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.signal + "%"; color: "#71717a"; font.family: "monospace"; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wifiConnectProc.connectTo(modelData.ssid);
                                    tab3.stageMode = 0;
                                }
                            }
                        }
                    }
                }

                // Stage 2: 藍牙樞紐 (原版左下角完整行為)
                Rectangle {
                    visible: tab3.stageMode === 2
                    width: parent.width; height: 96; radius: 8; color: "#18181b"; border.color: themeContext.geminiPurple; border.width: 1; clip: true
                    Column {
                        anchors.fill: parent; anchors.margins: 6; spacing: 5
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                            Item {
                                width: btPwrRow.implicitWidth; height: 18
                                Row {
                                    id: btPwrRow; anchors.centerIn: parent; spacing: 4
                                    Text { text: tab3.btState !== "OFF" ? "⚡" : "💤"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: tab3.btState !== "OFF" ? "射頻開" : "射頻關"
                                        color: tab3.btState !== "OFF" ? themeContext.geminiPurple : "#71717a"
                                        font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle {
                                        width: 24; height: 13; radius: 6.5; anchors.verticalCenter: parent.verticalCenter
                                        color: tab3.btState !== "OFF" ? themeContext.geminiPurple : "#3f3f46"
                                        Rectangle {
                                            width: 9; height: 9; radius: 4.5; color: "#ffffff"; y: 2
                                            x: tab3.btState !== "OFF" ? 13 : 2
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var turnOn = (tab3.btState === "OFF");
                                        if (turnOn) {
                                            tab3.btState = "ON";
                                            tab3.btName = "開啟中...";
                                            btActionProc.exec("rfkill unblock bluetooth 2>/dev/null; sleep 0.25; bluetoothctl power on");
                                        } else {
                                            tab3.btState = "OFF";
                                            tab3.btName = "已關閉";
                                            tab3.btDiscoverable = false;
                                            tab3.btPairable = false;
                                            btActionProc.exec("bluetoothctl power off");
                                        }
                                    }
                                }
                            }
                            Item {
                                visible: tab3.btState !== "OFF"
                                width: btDiscRow.implicitWidth; height: 18
                                Row {
                                    id: btDiscRow; anchors.centerIn: parent; spacing: 3
                                    Text { text: tab3.btDiscoverable ? "📡" : "🙈"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: tab3.btDiscoverable ? "廣播開" : "廣播隱"
                                        color: tab3.btDiscoverable ? themeContext.geminiCyan : "#71717a"
                                        font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var next = !tab3.btDiscoverable;
                                        tab3.btDiscoverable = next;
                                        btActionProc.exec("bluetoothctl discoverable " + (next ? "on" : "off"));
                                    }
                                }
                            }
                            Item {
                                visible: tab3.btState !== "OFF"
                                width: btPairRow.implicitWidth; height: 18
                                Row {
                                    id: btPairRow; anchors.centerIn: parent; spacing: 3
                                    Text { text: tab3.btPairable ? "🤝" : "🔒"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: tab3.btPairable ? "配對允" : "配對拒"
                                        color: tab3.btPairable ? themeContext.geminiGold : "#71717a"
                                        font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var next = !tab3.btPairable;
                                        tab3.btPairable = next;
                                        if (next) tab3.btDiscoverable = true;
                                        btActionProc.exec(next
                                            ? "bluetoothctl discoverable on; bluetoothctl pairable on"
                                            : "bluetoothctl pairable off");
                                    }
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: "#27272a" }

                        Item {
                            width: parent.width; height: parent.height - 26

                            Text {
                                visible: tab3.btState === "OFF"
                                anchors.centerIn: parent
                                text: "💤 藍牙硬件已休眠，開啟射頻後方可探測"
                                color: "#71717a"; font.pixelSize: 9
                            }

                            Column {
                                visible: tab3.btState !== "OFF" && tab3.btDeviceList.length === 0
                                anchors.centerIn: parent; spacing: 4
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tab3.btScanning ? "📡 正在探測周邊設備..." : "🎧 暫無配對設備"
                                    color: tab3.btScanning ? themeContext.geminiCyan : "#a1a1aa"
                                    font.pixelSize: 9
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 88; height: 20; radius: 10; color: "#27272a"; border.color: themeContext.geminiPurple; border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: tab3.btScanning ? "⏳ 探測中..." : "🔍 掃描新設備"
                                        color: "#f3e8ff"; font.pixelSize: 8; font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            tab3.btScanning = true;
                                            btScanProc.running = true;
                                        }
                                    }
                                }
                            }

                            ListView {
                                visible: tab3.btState !== "OFF" && tab3.btDeviceList.length > 0
                                anchors.fill: parent; clip: true; spacing: 2
                                model: tab3.btDeviceList
                                footer: Rectangle {
                                    width: ListView.view.width; height: 20; radius: 4; color: "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: tab3.btScanning ? "⏳ 正在探測周邊設備..." : "🔍 掃描更多新設備"
                                        color: tab3.btScanning ? themeContext.geminiCyan : themeContext.geminiPurple
                                        font.pixelSize: 8; font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            tab3.btScanning = true;
                                            btScanProc.running = true;
                                        }
                                    }
                                }
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool isConn: tab3.btState === "CONN" && tab3.btName === modelData.name
                                    width: ListView.view.width; height: 20; radius: 4
                                    color: isConn ? "#2e1065" : "transparent"
                                    Row {
                                        anchors.fill: parent; anchors.leftMargin: 6; spacing: 6
                                        Text { text: isConn ? "🔊" : "🎧"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                        Text {
                                            text: modelData.name
                                            color: isConn ? themeContext.geminiCyan : "#ffffff"
                                            font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (isConn) {
                                                btActionProc.exec("bluetoothctl disconnect " + modelData.mac);
                                            } else {
                                                btActionProc.exec("bluetoothctl connect " + modelData.mac);
                                            }
                                            tab3.stageMode = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 通信雙子 (Wi-Fi & 藍牙)
                Row {
                    width: parent.width; spacing: 8
                    readonly property real halfW: (width - spacing) / 2
                    Rectangle {
                        width: parent.halfW; height: 34; radius: 8
                        color: tab3.stageMode === 1 ? "#27272a" : "#18181b"
                        border.color: tab3.stageMode === 1 ? themeContext.geminiGold : "#27272a"; border.width: 1
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "📶"; font.pixelSize: 11 }
                            Text { text: rootContext ? rootContext.currentWifi : "未連接"; color: (rootContext && rootContext.currentWifi !== "未連接") ? "#f4f4f5" : "#71717a"; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; width: 120 }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tab3.stageMode === 1) tab3.stageMode = 0;
                                else {
                                    tab3.stageMode = 1;
                                    tab3.wifiScanning = true;
                                    wifiScanProc.forceRescan = false;
                                    wifiScanProc.running = true;
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.halfW; height: 34; radius: 8
                        color: tab3.stageMode === 2 ? "#27272a" : "#18181b"
                        border.color: tab3.stageMode === 2 ? themeContext.geminiPurple : "#27272a"; border.width: 1
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text {
                                text: tab3.btState === "CONN" ? "🎧" : "ᛒ"
                                color: tab3.btState === "CONN" ? themeContext.geminiCyan : (tab3.btState === "ON" ? "#e4e4e7" : "#71717a")
                                font.pixelSize: 11
                            }
                            Text {
                                text: tab3.btName
                                color: tab3.btState === "CONN" ? "#ffffff" : (tab3.btState === "ON" ? "#e4e4e7" : "#71717a")
                                font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; width: 120
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tab3.stageMode = (tab3.stageMode === 2 ? 0 : 2);
                                if (tab3.stageMode === 2) {
                                    btStatusProc.running = true;
                                    btDevicesProc.running = true;
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
                                        onClicked: Hyprland.dispatch("workspace " + modelData)
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
                                width: parent.width; height: 22; radius: 4; color: mma.containsMouse ? "#27272a" : "transparent"
                                Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.text || ""; color: "#f4f4f5"; font.pixelSize: 10 }
                                MouseArea {
                                    id: mma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
