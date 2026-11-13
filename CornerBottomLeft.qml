import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Variants {
    id: rootVariant
    required property var rootContext
    required property var themeContext
    required property var clockContext
    required property var volControl

    model: Quickshell.screens
    PanelWindow {
        id: winBL
        required property var modelData; screen: modelData
        anchors { bottom: true; left: true }

        property bool isOpen: false
        property bool isLocked: false

        property int stageMode: 0
        property bool wifiScanning: false
        property bool btScanning: false

        property string btState: "ON"
        property string btName: "未連線"
        property bool btDiscoverable: false
        property bool btPairable: false

        function connectBt(mac) {
            var cmd = "bluetoothctl info " + mac + " | grep -q 'Connected: yes' && bluetoothctl disconnect " + mac + " || (bluetoothctl pair " + mac + " 2>/dev/null; bluetoothctl trust " + mac + " 2>/dev/null; bluetoothctl connect " + mac + ")"
            cmdRunner.run(cmd)
            winBL.stageMode = 0
            btStatusProc.running = false
            btStatusProc.running = true
        }

        implicitWidth: isOpen ? 360 : themeContext.cornerSize
        implicitHeight: isOpen ? 435 : themeContext.cornerSize

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Process {
            id: cmdRunner
            function run(cmd) {
                command = ["sh", "-c", cmd]
                running = false; running = true
            }
        }

        ListModel { id: taskbarModel }

        Process {
            id: taskbarProc
            command: ["sh", "-c", "hyprctl clients -j 2>/dev/null || echo '[]'"]
            stdout: StdioCollector {
                onStreamFinished: {
                    taskbarModel.clear()
                    try {
                        var clients = JSON.parse(text)
                        for (var i = 0; i < clients.length; i++) {
                            var c = clients[i]
                            if (!c.class || c.class === "quickshell") continue
                            taskbarModel.append({
                                address: c.address,
                                winClass: c.class,
                                title: c.title || "",
                                initialClass: c.initialClass || c.class,
                                wsId: c.workspace ? c.workspace.id : 1
                            })
                        }
                    } catch(e) {}
                }
            }
        }

        Connections {
            target: Hyprland
            function onActiveToplevelChanged() { taskbarProc.running = false; taskbarProc.running = true }
            function onFocusedWorkspaceChanged() { taskbarProc.running = false; taskbarProc.running = true }
        }

        ListModel { id: wifiListModel }

        Process {
            id: scanWifiProc
            command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null | awk -F: '$2 != \"\"' | head -n 4"]
            stdout: StdioCollector {
                onStreamFinished: {
                    wifiListModel.clear()
                    var lines = text.trim().split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        if (!lines[i]) continue
                        var parts = lines[i].split(":")
                        if (parts.length >= 3) {
                            wifiListModel.append({
                                inUse: parts[0] === "*",
                                ssid: parts[1],
                                signal: parseInt(parts[2]) || 50,
                                security: parts[3] || ""
                            })
                        }
                    }
                    winBL.wifiScanning = false
                }
            }
        }

        ListModel { id: btListModel }

        Process {
            id: scanBtProc
            command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | head -n 4"]
            stdout: StdioCollector {
                onStreamFinished: {
                    btListModel.clear()
                    var lines = text.trim().split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        if (!lines[i]) continue
                        var p = lines[i].split(" ")
                        if (p.length >= 3 && p[0] === "Device") {
                            btListModel.append({
                                mac: p[1],
                                name: p.slice(2).join(" ")
                            })
                        }
                    }
                    winBL.btScanning = false
                }
            }
        }

        Process {
            id: startScanBtProc
            command: ["sh", "-c", "timeout 5 bluetoothctl scan on >/dev/null 2>&1; bluetoothctl devices 2>/dev/null | head -n 4"]
            stdout: StdioCollector {
                onStreamFinished: {
                    btListModel.clear()
                    var lines = text.trim().split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        if (!lines[i]) continue
                        var p = lines[i].split(" ")
                        if (p.length >= 3 && p[0] === "Device") {
                            btListModel.append({
                                mac: p[1],
                                name: p.slice(2).join(" ")
                            })
                        }
                    }
                    winBL.btScanning = false
                }
            }
        }

        Process {
            id: btStatusProc
            command: [
                "sh", "-c",
                "PWR=$(bluetoothctl show 2>/dev/null | grep -m1 'Powered:' | awk '{print $2}'); " +
                "DISC=$(bluetoothctl show 2>/dev/null | grep -m1 'Discoverable:' | awk '{print $2}'); " +
                "PAIR=$(bluetoothctl show 2>/dev/null | grep -m1 'Pairable:' | awk '{print $2}'); " +
                "DEV=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d ' ' -f 3-); " +
                "echo \"$PWR|$DISC|$PAIR|$DEV\""
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    var parts = text.trim().split("|")
                    if (parts.length >= 3) {
                        var pwr = parts[0]
                        var disc = parts[1]
                        var pair = parts[2]
                        var dev = parts[3] || ""
                        winBL.btDiscoverable = (disc === "yes")
                        winBL.btPairable = (pair === "yes")

                        if (pwr !== "yes") {
                            winBL.btState = "OFF"
                            winBL.btName = "已關閉"
                        } else if (dev !== "") {
                            winBL.btState = "CONN"
                            winBL.btName = dev
                        } else {
                            winBL.btState = "ON"
                            winBL.btName = "未連線"
                        }
                    }
                }
            }
        }

        Timer {
            id: lockTimerBL
            interval: 450
            onTriggered: {
                winBL.isLocked = false
                if (!areaBL.containsMouse) timerBL.restart()
            }
        }

        Timer {
            id: timerBL
            interval: 250
            onTriggered: {
                if (!winBL.isLocked) {
                    winBL.isOpen = false
                    winBL.stageMode = 0
                }
            }
        }

        MouseArea {
            id: areaBL
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                timerBL.stop()
                btStatusProc.running = false
                btStatusProc.running = true
                taskbarProc.running = false
                taskbarProc.running = true

                if (!winBL.isOpen) {
                    winBL.isOpen = true
                    winBL.isLocked = true
                    lockTimerBL.restart()
                }
            }
            onExited: {
                if (!winBL.isLocked) timerBL.restart()
            }

            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) Hyprland.dispatch("workspace e+1")
                else Hyprland.dispatch("workspace e-1")
            }

            Rectangle {
                anchors.fill: parent
                color: themeContext.popupBg
                radius: 14
                border.width: 1
                border.color: themeContext.geminiGold
                opacity: winBL.isOpen ? 1.0 : 0.0
                scale: winBL.isOpen ? 1.0 : 0.96
                visible: opacity > 0.0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 9

                    // 1. 表頭時鐘
                    Row {
                        spacing: 12
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

                    // 2. 🌟 固定戰術中台 (86px)
                    Item {
                        width: parent.width
                        height: 86
                        clip: true

                        // 態 0：默認 (咖啡因 + 音量)
                        Column {
                            anchors.fill: parent
                            spacing: 8
                            visible: winBL.stageMode === 0

                            Rectangle {
                                width: parent.width
                                height: 36
                                radius: 8
                                color: "#18181b"
                                border.width: 1
                                border.color: rootContext.caffeineActive ? themeContext.geminiGold : themeContext.geminiCyan

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Text {
                                        text: rootContext.caffeineActive ? "☕ 破曉無眠 (常亮)" : "🌙 漏刻入眠 (15分睡眠)"
                                        color: rootContext.caffeineActive ? themeContext.geminiGold : themeContext.geminiCyan
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
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                    }

                                    Rectangle {
                                        width: 48
                                        height: 20
                                        radius: 5
                                        color: rootContext.caffeineActive ? "#27272a" : "#164e63"
                                        border.width: 1
                                        border.color: rootContext.caffeineActive ? "#3f3f46" : themeContext.geminiCyan
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                if (rootContext.caffeineActive) return "∞"
                                                var sec = rootContext.sleepCountdown || 900
                                                var m = Math.floor(sec / 60)
                                                var s = sec % 60
                                                return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
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
                                        rootContext.caffeineActive = !rootContext.caffeineActive
                                        rootContext.saveCoords()
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
                                            Behavior on width { NumberAnimation { duration: 80 } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onPositionChanged: (mouse) => {
                                                var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / volTrack.width) * 100)))
                                                volControl.setVol(pct)
                                            }
                                            onClicked: (mouse) => {
                                                var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / volTrack.width) * 100)))
                                                volControl.setVol(pct)
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
                            visible: winBL.stageMode === 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: winBL.wifiScanning
                                Text { text: "⏳"; font.pixelSize: 12 }
                                Text { text: "正在雷達掃描周邊 Wi-Fi..."; color: themeContext.geminiGold; font.pixelSize: 10; font.bold: true }
                            }

                            Item {
                                anchors.fill: parent
                                visible: !winBL.wifiScanning && wifiListModel.count === 0
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: "📡"; font.pixelSize: 12 }
                                    Text { text: "未發現可用熱點 (點擊重新探測)"; color: "#71717a"; font.pixelSize: 10 }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { winBL.wifiScanning = true; scanWifiProc.running = true }
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 2
                                visible: !winBL.wifiScanning && wifiListModel.count > 0

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
                                            Text { text: "📶"; font.pixelSize: 8 }
                                            Text {
                                                text: model.ssid
                                                color: model.inUse ? themeContext.geminiGold : "#ffffff"
                                                font.pixelSize: 9
                                                font.bold: model.inUse
                                                elide: Text.ElideRight
                                                width: 220
                                            }
                                            Text { text: model.security ? "🔒" : ""; font.pixelSize: 8 }
                                            Text { text: model.signal + "%"; color: "#71717a"; font.pixelSize: 8; font.family: "JetBrains Mono" }
                                        }

                                        MouseArea {
                                            id: itemArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                cmdRunner.run("nmcli connection up '" + model.ssid + "' 2>/dev/null || nmcli dev wifi connect '" + model.ssid + "'")
                                                winBL.stageMode = 0
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 態 2：藍牙中樞 (修復 Row 警告 + 授權代理防呆)
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "#18181b"
                            border.width: 1
                            border.color: themeContext.geminiPurple
                            visible: winBL.stageMode === 2

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                // 頂部開關容器 (使用 Item 避免 Row 內部錨點違規警告)
                                Item {
                                    width: parent.width
                                    height: 16

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 12

                                        // 供電開關
                                        Row {
                                            spacing: 4
                                            Text { text: (winBL.btState !== "OFF") ? "⚡" : "💤"; font.pixelSize: 9 }
                                            Text { text: (winBL.btState !== "OFF") ? "射頻開" : "射頻關"; color: (winBL.btState !== "OFF") ? themeContext.geminiPurple : "#71717a"; font.pixelSize: 9; font.bold: true }
                                            Rectangle {
                                                width: 24; height: 13; radius: 6; color: (winBL.btState !== "OFF") ? themeContext.geminiPurple : "#3f3f46"
                                                Rectangle { width: 9; height: 9; radius: 4; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; x: (winBL.btState !== "OFF") ? (parent.width - width - 2) : 2; Behavior on x { NumberAnimation { duration: 150 } } }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (winBL.btState !== "OFF") {
                                                            winBL.btState = "OFF"; winBL.btName = "已關閉"; winBL.btDiscoverable = false; winBL.btPairable = false
                                                            cmdRunner.run("bluetoothctl power off")
                                                        } else {
                                                            winBL.btState = "ON"; winBL.btName = "未連線"
                                                            cmdRunner.run("bluetoothctl power on")
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 廣播可見開關
                                        Row {
                                            spacing: 4
                                            visible: winBL.btState !== "OFF"
                                            Text { text: winBL.btDiscoverable ? "📡" : "🙈"; font.pixelSize: 9 }
                                            Text { text: winBL.btDiscoverable ? "廣播開" : "廣播隱"; color: winBL.btDiscoverable ? themeContext.geminiCyan : "#71717a"; font.pixelSize: 9; font.bold: true }
                                            Rectangle {
                                                width: 24; height: 13; radius: 6; color: winBL.btDiscoverable ? themeContext.geminiCyan : "#3f3f46"
                                                Rectangle { width: 9; height: 9; radius: 4; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; x: winBL.btDiscoverable ? (parent.width - width - 2) : 2; Behavior on x { NumberAnimation { duration: 150 } } }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        winBL.btDiscoverable = !winBL.btDiscoverable
                                                        cmdRunner.run(winBL.btDiscoverable ? "bluetoothctl discoverable on" : "bluetoothctl discoverable off")
                                                    }
                                                }
                                            }
                                        }

                                        // 配對授權開關
                                        Row {
                                            spacing: 4
                                            visible: winBL.btState !== "OFF"
                                            Text { text: winBL.btPairable ? "🤝" : "🔒"; font.pixelSize: 9 }
                                            Text { text: winBL.btPairable ? "配對允" : "配對拒"; color: winBL.btPairable ? themeContext.geminiGold : "#71717a"; font.pixelSize: 9; font.bold: true }
                                            Rectangle {
                                                width: 24; height: 13; radius: 6; color: winBL.btPairable ? themeContext.geminiGold : "#3f3f46"
                                                Rectangle { width: 9; height: 9; radius: 4; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; x: winBL.btPairable ? (parent.width - width - 2) : 2; Behavior on x { NumberAnimation { duration: 150 } } }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        winBL.btPairable = !winBL.btPairable
                                                        if (winBL.btPairable) {
                                                            winBL.btDiscoverable = true
                                                            cmdRunner.run("pgrep -f bt_agent.sh >/dev/null || nohup ~/.config/quickshell/bt_agent.sh >/dev/null 2>&1 &")
                                                        } else {
                                                            cmdRunner.run("pkill -f bt_agent.sh; rm -f /tmp/bt_ctl_fifo; bluetoothctl discoverable off; bluetoothctl pairable off")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { width: parent.width - 12; height: 1; color: "#27272a"; anchors.horizontalCenter: parent.horizontalCenter }

                                Item {
                                    width: parent.width
                                    height: 48

                                    Text {
                                        anchors.centerIn: parent
                                        visible: winBL.btState === "OFF"
                                        text: "💤 藍牙硬件已休眠，開啟射頻後方可探測"
                                        color: "#71717a"; font.pixelSize: 9
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        visible: winBL.btState !== "OFF" && btListModel.count === 0

                                        Text { text: winBL.btScanning ? "📡 正在探測周邊設備..." : "🎧 暫無配對設備"; color: winBL.btScanning ? themeContext.geminiCyan : "#a1a1aa"; font.pixelSize: 9; anchors.horizontalCenter: parent.horizontalCenter }
                                        Rectangle {
                                            width: 110; height: 20; radius: 10; color: "#27272a"; border.width: 1; border.color: themeContext.geminiPurple
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Text { text: winBL.btScanning ? "⏳" : "🔍"; font.pixelSize: 8 }
                                                Text { text: winBL.btScanning ? "探測中..." : "掃描新設備"; color: "#f3e8ff"; font.pixelSize: 8; font.bold: true }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { winBL.btScanning = true; startScanBtProc.running = false; startScanBtProc.running = true }
                                            }
                                        }
                                    }

                                    Column {
                                        anchors.fill: parent
                                        spacing: 2
                                        visible: winBL.btState !== "OFF" && btListModel.count > 0

                                        Repeater {
                                            model: btListModel
                                            delegate: Rectangle {
                                                width: parent.width - 12
                                                height: 20
                                                radius: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: (winBL.btName === model.name) ? "#2e1065" : (btItemArea.containsMouse ? "#27272a" : "transparent")

                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 6
                                                    spacing: 6
                                                    Text { text: "🎧"; font.pixelSize: 8 }
                                                    Text { text: model.name; color: (winBL.btName === model.name) ? themeContext.geminiCyan : "#ffffff"; font.pixelSize: 9; font.bold: true; elide: Text.ElideRight; width: 220 }
                                                }

                                                MouseArea {
                                                    id: btItemArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: winBL.connectBt(model.mac)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. 🌟 通訊雙子星 (絕對固定)
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 160
                            height: 32
                            radius: 8
                            color: (winBL.stageMode === 1) ? "#1e1b4b" : "#27272a"
                            border.width: 1
                            border.color: rootContext.currentWifi !== "未連接" ? themeContext.geminiGold : "#3f3f46"

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "📶"; font.pixelSize: 11 }
                                Text {
                                    text: rootContext.currentWifi
                                    color: "#e4e4e7"
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: 115
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (winBL.stageMode === 1) {
                                        winBL.stageMode = 0
                                    } else {
                                        winBL.stageMode = 1
                                        winBL.wifiScanning = true
                                        scanWifiProc.running = false
                                        scanWifiProc.running = true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 160
                            height: 32
                            radius: 8
                            color: (winBL.stageMode === 2) ? "#2e1065" : "#27272a"
                            border.width: 1
                            border.color: (winBL.btState === "CONN") ? themeContext.geminiCyan : ((winBL.btState === "ON") ? themeContext.geminiPurple : "#3f3f46")

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: (winBL.btState === "CONN") ? "🎧" : "ᛒ"
                                    font.pixelSize: 11
                                    color: (winBL.btState === "CONN") ? themeContext.geminiCyan : ((winBL.btState === "ON") ? themeContext.geminiPurple : "#a1a1aa")
                                }
                                Text {
                                    text: winBL.btName
                                    color: (winBL.btState === "CONN") ? "#ffffff" : ((winBL.btState === "ON") ? "#f3e8ff" : "#71717a")
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: 115
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (winBL.stageMode === 2) {
                                        winBL.stageMode = 0
                                    } else {
                                        winBL.stageMode = 2
                                        scanBtProc.running = false
                                        scanBtProc.running = true
                                        btStatusProc.running = false
                                        btStatusProc.running = true
                                    }
                                }
                            }
                        }
                    }

                    // 4. 🌟 WORKSPACES 魔術區 (絕對固定)
                    Rectangle {
                        width: parent.width
                        height: 64
                        radius: 10
                        color: "#18181b"
                        border.width: 1
                        border.color: "#27272a"

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Row {
                                spacing: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                Text {
                                    text: "WORKSPACES"
                                    color: "#71717a"
                                    font.pixelSize: 9
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: 72
                                    height: 18
                                    radius: 9
                                    color: "#2e1065"
                                    border.width: 1
                                    border.color: themeContext.geminiPurple
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "✦"; color: themeContext.geminiPurple; font.pixelSize: 9 }
                                        Text { text: "魔术区"; color: "#f3e8ff"; font.pixelSize: 9; font.bold: true }
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
                                        color: modelData.focused ? themeContext.geminiGold : "#3f3f46"
                                        Behavior on width { NumberAnimation { duration: 150 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.id
                                            color: modelData.focused ? "#18181b" : "#d4d4d8"
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

                    // 5. 🌟 五聯電源舵：睡眠 | 鎖屏 | 登出 | 重啟 | 關機
                    Row {
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 62; height: 26; radius: 6; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Text { anchors.centerIn: parent; text: "💤 睡眠"; color: "#e4e4e7"; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cmdRunner.run("systemctl suspend") }
                        }
                        Rectangle {
                            width: 62; height: 26; radius: 6; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Text { anchors.centerIn: parent; text: "🔒 鎖屏"; color: "#e4e4e7"; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cmdRunner.run("hyprlock || swaylock || loginctl lock-session") }
                        }
                        Rectangle {
                            width: 62; height: 26; radius: 6; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Text { anchors.centerIn: parent; text: "🚪 登出"; color: "#f87171"; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cmdRunner.run("hyprctl dispatch exit") }
                        }
                        Rectangle {
                            width: 62; height: 26; radius: 6; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Text { anchors.centerIn: parent; text: "🔄 重啟"; color: themeContext.geminiGold; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cmdRunner.run("systemctl reboot") }
                        }
                        Rectangle {
                            width: 62; height: 26; radius: 6; color: "#3f1d38"; border.width: 1; border.color: themeContext.geminiRose
                            Text { anchors.centerIn: parent; text: "⏻ 關機"; color: "#f43f5e"; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cmdRunner.run("systemctl poweroff") }
                        }
                    }

                    // 6. 🌟 任務欄 Dock (點擊跨工作區秒切窗口 + 瞬移光標跳出鼠標搶奪)
                    Row {
                        width: parent.width
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        Flickable {
                            id: taskFlick
                            width: parent.width - 80
                            height: 24
                            contentWidth: taskRow.width
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter
                            boundsBehavior: Flickable.StopAtBounds

                            Row {
                                id: taskRow
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: taskbarModel
                                    delegate: Rectangle {
                                        readonly property bool isCurrent: Hyprland.activeToplevel && (Hyprland.activeToplevel.address === model.address)

                                        width: 24
                                        height: 24
                                        radius: 6
                                        color: isCurrent ? "#38bdf825" : (appArea.containsMouse ? "#27272a" : "transparent")
                                        border.width: isCurrent ? 1 : 0
                                        border.color: themeContext.geminiCyan

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Image {
                                            id: appIcon
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            source: Quickshell.iconPath(model.winClass, true) || Quickshell.iconPath(model.initialClass, true) || ""
                                            visible: status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !appIcon.visible
                                            text: model.winClass ? model.winClass.charAt(0).toUpperCase() : "●"
                                            color: isCurrent ? themeContext.geminiCyan : "#a1a1aa"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: appArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                // 🌟 關鍵三連擊：切工作區 + 聚焦窗口 + 鼠標強制移入窗口中心打破角落搶奪！
                                                cmdRunner.run("hyprctl dispatch workspace " + model.wsId + " && hyprctl dispatch focuswindow address:" + model.address)
                                                winBL.isOpen = false
                                                winBL.isLocked = false
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 72
                            height: 22
                            radius: 5
                            color: "#27272a"
                            border.width: 1
                            border.color: themeContext.geminiCyan
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: "⌨"; font.pixelSize: 9; color: themeContext.geminiCyan }
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
        }
    }
}
