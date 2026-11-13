import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Variants {
    id: rootVariant
    required property var rootContext
    required property var themeContext
    required property var clockContext
    required property var volControl

    model: Quickshell.screens
    Scope {
        id: screenScope
        required property var modelData

        property bool isOpen: false
        property bool isLocked: false
        property int stageMode: 0
        property bool wifiScanning: false
        property bool btScanning: false

        // 藍牙狀態
        property string btState: "ON"
        property string btName: "未連線"
        property bool btDiscoverable: false
        property bool btPairable: false

        // 藍牙配對請求彈窗數據
        property bool hasPairRequest: false
        property string pairReqMac: ""
        property string pairReqPasskey: ""

        function openPanel() {
            timerBL.stop();
            btStatusProc.running = false;
            btStatusProc.running = true;
            pairReqReader.running = false;
            pairReqReader.running = true;

            if (!isOpen) {
                isOpen = true;
                isLocked = true;
                lockTimerBL.restart();
            }
        }

        function closeAll() {
            customTrayMenu.visible = false;
            isLocked = false;
            isOpen = false;
            stageMode = 0;
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
                    if (str.length > 0 && str.includes("|")) {
                        var p = str.split("|");
                        screenScope.pairReqMac = p[0];
                        screenScope.pairReqPasskey = p[1];
                        screenScope.hasPairRequest = true;
                    } else {
                        screenScope.hasPairRequest = false;
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
                    screenScope.wifiScanning = false;
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
                    screenScope.btScanning = false;
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
                    screenScope.btScanning = false;
                }
            }
        }

        Process {
            id: btStatusProc
            command: ["sh", "-c", "PWR=$(bluetoothctl show 2>/dev/null | grep -m1 'Powered:' | awk '{print $2}'); " + "DISC=$(bluetoothctl show 2>/dev/null | grep -m1 'Discoverable:' | awk '{print $2}'); " + "PAIR=$(bluetoothctl show 2>/dev/null | grep -m1 'Pairable:' | awk '{print $2}'); " + "DEV=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d ' ' -f 3-); " + "echo \"$PWR|$DISC|$PAIR|$DEV\""]
            stdout: StdioCollector {
                onStreamFinished: {
                    var parts = text.trim().split("|");
                    if (parts.length >= 3) {
                        var pwr = parts[0];
                        var disc = parts[1];
                        var pair = parts[2];
                        var dev = parts[3] || "";
                        screenScope.btDiscoverable = (disc === "yes");
                        screenScope.btPairable = (pair === "yes");

                        if (pwr !== "yes") {
                            screenScope.btState = "OFF";
                            screenScope.btName = "已關閉";
                        } else if (dev !== "") {
                            screenScope.btState = "CONN";
                            screenScope.btName = dev;
                        } else {
                            screenScope.btState = "ON";
                            screenScope.btName = "未連線";
                        }
                    }
                }
            }
        }


        Timer {
            id: lockTimerBL
            interval: 450
            onTriggered: {
                screenScope.isLocked = false;
                if (!winBL.isMouseInsideUI) {
                    timerBL.restart();
                }
            }
        }

        Timer {
            id: timerBL
            interval: 300
            onTriggered: {
                if (!screenScope.isLocked && !winBL.isMouseInsideUI) {
                    screenScope.closeAll();
                }
            }
        }

        // ============================================================
        // 窗口 1：左下角永久觸發熱區（尺寸固定不變，絕不觸發任何窗口動畫）
        // ============================================================
        PanelWindow {
            id: triggerWin
            screen: screenScope.modelData
            anchors {
                bottom: true
                left: true
            }
            implicitWidth: themeContext.cornerSize
            implicitHeight: themeContext.cornerSize
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: screenScope.openPanel()
            }
        }

        // ============================================================
        // 窗口 2：獨立主彈窗（直接通過 visible 控制開關，徹底告別醜陋縮放特效）
        // ============================================================
        PanelWindow {
            id: winBL
            screen: screenScope.modelData
            visible: screenScope.isOpen

            anchors {
                bottom: true
                left: true
                top: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            // 設置一個獨立的 namespace，方便在 Hyprland 裡彻底禁用它的系統級動畫
            WlrLayershell.namespace: "quickshell-corner-popup"
            color: "transparent"

            readonly property real cardHeight: mainCol.implicitHeight + 28

            readonly property bool isMouseInsideUI: {
                if (!screenScope.isOpen)
                    return false;
                var mx = globalTracker.mouseX;
                var my = globalTracker.mouseY;
                var inCard = (mx >= 0 && mx <= mainCard.width && my >= (height - mainCard.height) && my <= height);
                var inMenu = customTrayMenu.visible && (mx >= customTrayMenu.x && mx <= (customTrayMenu.x + customTrayMenu.width) && my >= customTrayMenu.y && my <= (customTrayMenu.y + customTrayMenu.height));
                return inCard || inMenu;
            }

            onIsMouseInsideUIChanged: {
                if (isMouseInsideUI) {
                    timerBL.stop();
                } else if (screenScope.isOpen && !screenScope.isLocked) {
                    timerBL.restart();
                }
            }
            // 全屏透明背景幕布：點擊屏幕任何外部位置立刻秒關
            MouseArea {
                id: globalTracker
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 1
                onClicked: screenScope.closeAll()
            }
            // 菜單打開時的卡片遮罩：點擊卡片空白處也直接關閉
            MouseArea {
                visible: customTrayMenu.visible
                anchors.fill: mainCard
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 998
                onClicked: screenScope.closeAll()
            }
            // 主面板視覺卡片（僅保留極輕柔的透明度淡入，無任何尺寸縮放）
            Rectangle {
                id: mainCard
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: 360
                height: winBL.cardHeight
                z: 10
                color: themeContext.popupBg
                radius: 14
                border.width: 1
                border.color: "#3f3f46"
                // 溫柔絲滑的淡入過渡（僅 120ms 透明度變化）
                opacity: screenScope.isOpen ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutQuad
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            Hyprland.dispatch("workspace e+1");
                        else
                            Hyprland.dispatch("workspace e-1");
                    }
                }
                Column {
                    id: mainCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 10
                    // 1. 表頭時鐘
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            text: clockContext.fullTimeString
                            color: themeContext.geminiGold
                            font.family: "JetBrains Mono"
                            font.bold: true
                            font.pixelSize: 22
                        }
                        Text {
                            text: clockContext.fullDateString
                            color: "#a1a1aa"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    // 藍牙設備請求授權卡片
                    Rectangle {
                        visible: screenScope.hasPairRequest
                        width: parent.width
                        height: 52
                        radius: 8
                        color: "#2e1065"
                        border.width: 1
                        border.color: themeContext.geminiPurple
                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Column {
                                width: parent.width - 120
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: "📱 收到配對請求 (" + screenScope.pairReqMac.slice(0, 8) + ")"
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                                Text {
                                    text: "密鑰: " + screenScope.pairReqPasskey
                                    color: themeContext.geminiGold
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                            Row {
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    width: 50
                                    height: 24
                                    radius: 5
                                    color: "#166534"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "同意"
                                        color: "#86efac"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            cmdRunner.run("echo 'yes' > /tmp/bt_ctl_fifo; bluetoothctl trust " + screenScope.pairReqMac + "; rm -f /tmp/bt_pair_request");
                                            screenScope.hasPairRequest = false;
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 50
                                    height: 24
                                    radius: 5
                                    color: "#7f1d1d"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "拒絕"
                                        color: "#fca5a5"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            cmdRunner.run("echo 'no' > /tmp/bt_ctl_fifo; rm -f /tmp/bt_pair_request");
                                            screenScope.hasPairRequest = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // 2. 固定戰術中台 (84px)
                    Item {
                        width: parent.width
                        height: 84
                        clip: true
                        // 態 0：默認態 (咖啡因 + 音量)
                        Column {
                            anchors.fill: parent
                            spacing: 8
                            visible: screenScope.stageMode === 0
                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: 8
                                color: "#18181b"
                                border.width: 1
                                border.color: rootContext.caffeineActive ? themeContext.geminiGold : "#27272a"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Text {
                                        text: rootContext.caffeineActive ? "☕ 破曉無眠 (常亮)" : "🌙 漏刻入眠 (15分睡眠)"
                                        color: rootContext.caffeineActive ? themeContext.geminiGold : "#e4e4e7"
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle {
                                        width: 34
                                        height: 18
                                        radius: 9
                                        color: rootContext.caffeineActive ? themeContext.geminiGold : "#3f3f46"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: rootContext.caffeineActive ? (parent.width - width - 2) : 2
                                            Behavior on x {
                                                NumberAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: 48
                                        height: 20
                                        radius: 5
                                        color: "#27272a"
                                        border.width: 1
                                        border.color: "#3f3f46"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                if (rootContext.caffeineActive)
                                                    return "∞";
                                                var sec = rootContext.sleepCountdown || 900;
                                                var m = Math.floor(sec / 60);
                                                var s = sec % 60;
                                                return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
                                            }
                                            color: rootContext.caffeineActive ? "#a1a1aa" : themeContext.geminiCyan
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        rootContext.caffeineActive = !rootContext.caffeineActive;
                                        rootContext.saveCoords();
                                    }
                                }
                            }
                            // 音量滑軌
                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: 8
                                color: "#18181b"
                                border.width: 1
                                border.color: "#27272a"
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10
                                    Text {
                                        text: rootContext.systemMuted ? "🔇" : "🔊"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: volControl.toggleMute()
                                        }
                                    }
                                    Rectangle {
                                        id: volTrack
                                        width: parent.width - 78
                                        height: 6
                                        radius: 3
                                        color: "#27272a"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            width: volTrack.width * (rootContext.systemVolume / 100.0)
                                            height: parent.height
                                            radius: 3
                                            color: rootContext.systemMuted ? "#71717a" : themeContext.geminiCyan
                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 80
                                                }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onPositionChanged: mouse => {
                                                var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / volTrack.width) * 100)));
                                                volControl.setVol(pct);
                                            }
                                            onClicked: mouse => {
                                                var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / volTrack.width) * 100)));
                                                volControl.setVol(pct);
                                            }
                                        }
                                    }
                                    Text {
                                        text: rootContext.systemVolume + "%"
                                        color: "#a1a1aa"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                        // 態 1：Wi-Fi 視圖
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "#18181b"
                            border.width: 1
                            border.color: themeContext.geminiGold
                            visible: screenScope.stageMode === 1
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: screenScope.wifiScanning
                                Text {
                                    text: "⏳"
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: "正在雷達掃描周邊 Wi-Fi..."
                                    color: themeContext.geminiGold
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                            Item {
                                anchors.fill: parent
                                visible: !screenScope.wifiScanning && wifiListModel.count === 0
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        text: "📡"
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: "未發現可用熱點 (點擊重新探測)"
                                        color: "#71717a"
                                        font.pixelSize: 10
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        screenScope.wifiScanning = true;
                                        scanWifiProc.running = true;
                                    }
                                }
                            }
                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 2
                                visible: !screenScope.wifiScanning && wifiListModel.count > 0
                                Repeater {
                                    model: wifiListModel
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 18
                                        radius: 3
                                        color: model.inUse ? "#1e1b4b" : (itemArea.containsMouse ? "#27272a" : "transparent")
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 6
                                            spacing: 6
                                            Text {
                                                text: "📶"
                                                font.pixelSize: 8
                                            }
                                            Text {
                                                text: model.ssid
                                                color: model.inUse ? themeContext.geminiGold : "#ffffff"
                                                font.pixelSize: 9
                                                font.bold: model.inUse
                                                elide: Text.ElideRight
                                                width: 220
                                            }
                                            Text {
                                                text: model.security ? "🔒" : ""
                                                font.pixelSize: 8
                                            }
                                            Text {
                                                text: model.signal + "%"
                                                color: "#71717a"
                                                font.pixelSize: 8
                                                font.family: "JetBrains Mono"
                                            }
                                        }
                                        MouseArea {
                                            id: itemArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                cmdRunner.run("nmcli connection up '" + model.ssid + "' 2>/dev/null || nmcli dev wifi connect '" + model.ssid + "'");
                                                screenScope.stageMode = 0;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // 態 2：藍牙中樞
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "#18181b"
                            border.width: 1
                            border.color: themeContext.geminiPurple
                            visible: screenScope.stageMode === 2
                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4
                                Item {
                                    width: parent.width
                                    height: 16
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 12
                                        Row {
                                            spacing: 4
                                            Text {
                                                text: (screenScope.btState !== "OFF") ? "⚡" : "💤"
                                                font.pixelSize: 9
                                            }
                                            Text {
                                                text: (screenScope.btState !== "OFF") ? "射頻開" : "射頻關"
                                                color: (screenScope.btState !== "OFF") ? themeContext.geminiPurple : "#71717a"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            Rectangle {
                                                width: 24
                                                height: 13
                                                radius: 6
                                                color: (screenScope.btState !== "OFF") ? themeContext.geminiPurple : "#3f3f46"
                                                Rectangle {
                                                    width: 9
                                                    height: 9
                                                    radius: 4
                                                    color: "#ffffff"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: (screenScope.btState !== "OFF") ? (parent.width - width - 2) : 2
                                                    Behavior on x {
                                                        NumberAnimation {
                                                            duration: 150
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (screenScope.btState !== "OFF") {
                                                            screenScope.btState = "OFF";
                                                            screenScope.btName = "已關閉";
                                                            screenScope.btDiscoverable = false;
                                                            screenScope.btPairable = false;
                                                            cmdRunner.run("bluetoothctl power off");
                                                        } else {
                                                            screenScope.btState = "ON";
                                                            screenScope.btName = "未連線";
                                                            cmdRunner.run("bluetoothctl power on");
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Row {
                                            spacing: 4
                                            visible: screenScope.btState !== "OFF"
                                            Text {
                                                text: screenScope.btDiscoverable ? "📡" : "🙈"
                                                font.pixelSize: 9
                                            }
                                            Text {
                                                text: screenScope.btDiscoverable ? "廣播開" : "廣播隱"
                                                color: screenScope.btDiscoverable ? themeContext.geminiCyan : "#71717a"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            Rectangle {
                                                width: 24
                                                height: 13
                                                radius: 6
                                                color: screenScope.btDiscoverable ? themeContext.geminiCyan : "#3f3f46"
                                                Rectangle {
                                                    width: 9
                                                    height: 9
                                                    radius: 4
                                                    color: "#ffffff"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: screenScope.btDiscoverable ? (parent.width - width - 2) : 2
                                                    Behavior on x {
                                                        NumberAnimation {
                                                            duration: 150
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        screenScope.btDiscoverable = !screenScope.btDiscoverable;
                                                        cmdRunner.run(screenScope.btDiscoverable ? "bluetoothctl discoverable on" : "bluetoothctl discoverable off");
                                                    }
                                                }
                                            }
                                        }
                                        Row {
                                            spacing: 4
                                            visible: screenScope.btState !== "OFF"
                                            Text {
                                                text: screenScope.btPairable ? "🤝" : "🔒"
                                                font.pixelSize: 9
                                            }
                                            Text {
                                                text: screenScope.btPairable ? "配對允" : "配對拒"
                                                color: screenScope.btPairable ? themeContext.geminiGold : "#71717a"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            Rectangle {
                                                width: 24
                                                height: 13
                                                radius: 6
                                                color: screenScope.btPairable ? themeContext.geminiGold : "#3f3f46"
                                                Rectangle {
                                                    width: 9
                                                    height: 9
                                                    radius: 4
                                                    color: "#ffffff"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: screenScope.btPairable ? (parent.width - width - 2) : 2
                                                    Behavior on x {
                                                        NumberAnimation {
                                                            duration: 150
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        screenScope.btPairable = !screenScope.btPairable;
                                                        if (screenScope.btPairable) {
                                                            screenScope.btDiscoverable = true;
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
                                Rectangle {
                                    width: parent.width - 12
                                    height: 1
                                    color: "#27272a"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Item {
                                    width: parent.width
                                    height: 46
                                    Text {
                                        anchors.centerIn: parent
                                        visible: screenScope.btState === "OFF"
                                        text: "💤 藍牙硬件已休眠，開啟射頻後方可探測"
                                        color: "#71717a"
                                        font.pixelSize: 9
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        visible: screenScope.btState !== "OFF" && btListModel.count === 0
                                        Text {
                                            text: screenScope.btScanning ? "📡 正在探測周邊設備..." : "🎧 暫無配對設備"
                                            color: screenScope.btScanning ? themeContext.geminiCyan : "#a1a1aa"
                                            font.pixelSize: 9
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Rectangle {
                                            width: 110
                                            height: 20
                                            radius: 10
                                            color: "#27272a"
                                            border.width: 1
                                            border.color: themeContext.geminiPurple
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Text {
                                                    text: screenScope.btScanning ? "⏳" : "🔍"
                                                    font.pixelSize: 8
                                                }
                                                Text {
                                                    text: screenScope.btScanning ? "探測中..." : "掃描新設備"
                                                    color: "#f3e8ff"
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    screenScope.btScanning = true;
                                                    startScanBtProc.running = false;
                                                    startScanBtProc.running = true;
                                                }
                                            }
                                        }
                                    }
                                    Column {
                                        anchors.fill: parent
                                        spacing: 2
                                        visible: screenScope.btState !== "OFF" && btListModel.count > 0
                                        Repeater {
                                            model: btListModel
                                            delegate: Rectangle {
                                                width: parent.width - 12
                                                height: 20
                                                radius: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: (screenScope.btName === model.name) ? "#2e1065" : (btItemArea.containsMouse ? "#27272a" : "transparent")
                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 6
                                                    spacing: 6
                                                    Text {
                                                        text: "🎧"
                                                        font.pixelSize: 8
                                                    }
                                                    Text {
                                                        text: model.name
                                                        color: (screenScope.btName === model.name) ? themeContext.geminiCyan : "#ffffff"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        width: 220
                                                    }
                                                }
                                                MouseArea {
                                                    id: btItemArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: screenScope.connectBt(model.mac)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // 3. 通訊雙子星
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 34
                            radius: 8
                            color: (screenScope.stageMode === 1) ? "#27272a" : "#18181b"
                            border.width: 1
                            border.color: (screenScope.stageMode === 1) ? themeContext.geminiGold : "#27272a"
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "📶"
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: rootContext.currentWifi
                                    color: rootContext.currentWifi !== "未連接" ? "#f4f4f5" : "#71717a"
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: 110
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (screenScope.stageMode === 1) {
                                        screenScope.stageMode = 0;
                                    } else {
                                        screenScope.stageMode = 1;
                                        screenScope.wifiScanning = true;
                                        scanWifiProc.running = false;
                                        scanWifiProc.running = true;
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 34
                            radius: 8
                            color: (screenScope.stageMode === 2) ? "#27272a" : "#18181b"
                            border.width: 1
                            border.color: (screenScope.stageMode === 2) ? themeContext.geminiPurple : "#27272a"
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: (screenScope.btState === "CONN") ? "🎧" : "ᛒ"
                                    font.pixelSize: 11
                                    color: (screenScope.btState === "CONN") ? themeContext.geminiCyan : ((screenScope.btState === "ON") ? "#e4e4e7" : "#71717a")
                                }
                                Text {
                                    text: screenScope.btName
                                    color: (screenScope.btState === "CONN") ? "#ffffff" : ((screenScope.btState === "ON") ? "#e4e4e7" : "#71717a")
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: 110
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (screenScope.stageMode === 2) {
                                        screenScope.stageMode = 0;
                                    } else {
                                        screenScope.stageMode = 2;
                                        scanBtProc.running = false;
                                        scanBtProc.running = true;
                                        btStatusProc.running = false;
                                        btStatusProc.running = true;
                                    }
                                }
                            }
                        }
                    }
                    // 4. WORKSPACES 魔術區
                    Rectangle {
                        width: parent.width
                        height: 62
                        radius: 10
                        color: "#18181b"
                        border.width: 1
                        border.color: "#27272a"
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Row {
                                spacing: 10
                                anchors.horizontalCenter: parent.horizontalCenter
                                Text {
                                    text: "WORKSPACES"
                                    color: "#71717a"
                                    font.pixelSize: 9
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: 68
                                    height: 18
                                    radius: 9
                                    color: "#2e1065"
                                    border.width: 1
                                    border.color: themeContext.geminiPurple
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "✦"
                                            color: themeContext.geminiPurple
                                            font.pixelSize: 9
                                        }
                                        Text {
                                            text: "魔術區"
                                            color: "#f3e8ff"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("togglespecialworkspace magic")
                                    }
                                }
                            }
                            Row {
                                spacing: 6
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: Hyprland.workspaces
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: modelData.focused ? 26 : 18
                                        height: 18
                                        radius: 9
                                        color: modelData.focused ? themeContext.geminiGold : "#27272a"
                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 150
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.id
                                            color: modelData.focused ? "#18181b" : "#a1a1aa"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.activate()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // 5. 五聯電源舵
                    Row {
                        width: parent.width
                        spacing: 6
                        Rectangle {
                            width: (parent.width - 24) / 5
                            height: 28
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            Text {
                                anchors.centerIn: parent
                                text: "💤 睡眠"
                                color: "#d4d4d8"
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("systemctl suspend")
                            }
                        }
                        Rectangle {
                            width: (parent.width - 24) / 5
                            height: 28
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            Text {
                                anchors.centerIn: parent
                                text: "🔒 鎖屏"
                                color: "#d4d4d8"
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("hyprlock || swaylock || loginctl lock-session")
                            }
                        }
                        Rectangle {
                            width: (parent.width - 24) / 5
                            height: 28
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            Text {
                                anchors.centerIn: parent
                                text: "🚪 登出"
                                color: "#d4d4d8"
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("hyprctl dispatch exit")
                            }
                        }
                        Rectangle {
                            width: (parent.width - 24) / 5
                            height: 28
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            Text {
                                anchors.centerIn: parent
                                text: "🔄 重啟"
                                color: "#d4d4d8"
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("systemctl reboot")
                            }
                        }
                        Rectangle {
                            width: (parent.width - 24) / 5
                            height: 28
                            radius: 6
                            color: "#2a121b"
                            border.width: 1
                            border.color: "#7f1d1d"
                            Text {
                                anchors.centerIn: parent
                                text: "⏻ 關機"
                                color: "#fda4af"
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("systemctl poweroff")
                            }
                        }
                    }
                    // 6. 後台駐留托盤狀態欄 + 輸入法
                    Row {
                        width: parent.width
                        spacing: 8
                        Flickable {
                            id: trayFlick
                            width: parent.width - 80
                            height: 24
                            contentWidth: trayRow.width
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: trayRow
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    visible: SystemTray.items.length === 0
                                    text: "● 後台無駐留程序"
                                    color: "#52525b"
                                    font.pixelSize: 9
                                }
                                Repeater {
                                    model: SystemTray.items
                                    delegate: Rectangle {
                                        id: trayDelegate
                                        required property var modelData
                                        width: 24
                                        height: 24
                                        radius: 6
                                        color: trayItemArea.containsMouse ? "#27272a" : "transparent"
                                        Image {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            source: modelData.icon || ""
                                        }
                                        MouseArea {
                                            id: trayItemArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    screenScope.closeAll();
                                                    modelData.activate();
                                                } else if (mouse.button === Qt.RightButton) {
                                                    if (modelData.hasMenu && modelData.menu) {
                                                        menuOpener.menu = modelData.menu;
                                                        customTrayMenu.visible = true;
                                                    } else {
                                                        modelData.secondaryActivate();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // 輸入法微標籤
                        Rectangle {
                            width: 72
                            height: 24
                            radius: 6
                            color: "#18181b"
                            border.width: 1
                            border.color: "#27272a"
                            anchors.verticalCenter: parent.verticalCenter
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "⌨"
                                    font.pixelSize: 9
                                    color: "#a1a1aa"
                                }
                                Text {
                                    text: rootContext.currentIme
                                    color: "#e4e4e7"
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("fcitx5-remote -t")
                            }
                        }
                    }
                }
            }
            // 5. 自定義暗黑托盤右鍵菜單
            QsMenuOpener {
                id: menuOpener
            }
            Rectangle {
                id: customTrayMenu
                visible: false
                width: 210
                height: menuCol.implicitHeight + 12
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 44
                anchors.leftMargin: 14
                radius: 8
                color: "#18181b"
                border.width: 1
                border.color: themeContext.geminiGold
                z: 999
                Column {
                    id: menuCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    spacing: 2
                    Repeater {
                        model: menuOpener.children
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: modelData.isSeparator ? 5 : 24
                            radius: 4
                            color: (!modelData.isSeparator && menuBtnArea.containsMouse) ? "#27272a" : "transparent"
                            Rectangle {
                                visible: modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 8
                                height: 1
                                color: "#27272a"
                            }
                            Text {
                                visible: !modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                width: parent.width - 16
                                elide: Text.ElideRight
                                text: modelData.text || ""
                                color: modelData.enabled ? "#f4f4f5" : "#52525b"
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: menuBtnArea
                                visible: !modelData.isSeparator && modelData.enabled
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    modelData.triggered();
                                    screenScope.closeAll();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
