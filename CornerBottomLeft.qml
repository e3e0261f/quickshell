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

        // 抽屜展開狀態
        property bool wifiExpanded: false
        property bool btExpanded: false

        // 藍牙狀態 (CONN|ON|OFF)
        property string btState: "ON"
        property string btName: "未連線"

        // 寬度 360，高度隨抽屜展開自動彈性伸縮 (400 ~ 520)
        implicitWidth: isOpen ? 360 : themeContext.cornerSize
        implicitHeight: isOpen ? (wifiExpanded ? 520 : (btExpanded ? 500 : 400)) : themeContext.cornerSize
        Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        // 通用指令發射器
        Process {
            id: cmdRunner
            function run(cmd) {
                command = ["sh", "-c", cmd]
                running = false; running = true
            }
        }

        // 熱點掃描數據模型
        ListModel { id: wifiListModel }

        Process {
            id: scanWifiProc
            command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | awk -F: '$2 != \"\"' | head -n 4"]
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
                }
            }
        }

        // 藍牙配對設備模型
        ListModel { id: btListModel }

        Process {
            id: scanBtProc
            command: ["sh", "-c", "bluetoothctl devices Paired 2>/dev/null | head -n 4"]
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
                }
            }
        }

        // 藍牙即時狀態監聽
        Process {
            id: btStatusProc
            command: ["sh", "-c", "PWR=$(bluetoothctl show 2>/dev/null | grep -m1 'Powered:' | awk '{print $2}'); DEV=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d ' ' -f 3-); if [ \"$PWR\" != \"yes\" ]; then echo 'OFF|已關閉'; elif [ -n \"$DEV\" ]; then echo \"CONN|$DEV\"; else echo 'ON|未連線'; fi"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var parts = text.trim().split("|")
                    if (parts.length >= 2) {
                        winBL.btState = parts[0]
                        winBL.btName = parts[1]
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
                    winBL.wifiExpanded = false
                    winBL.btExpanded = false
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
                if (rootContext && !rootContext.caffeineActive) {
                    rootContext.sleepCountdown = 900
                }
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
                    spacing: 10

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

                    // 2. 艙一：☕ 咖啡因 / 15分鐘定時睡眠
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
                                rootContext.sleepCountdown = 900
                                rootContext.saveCoords()
                            }
                        }
                    }

                    // 3. 艙二：🔊 系統主音量無級滑塊
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

                    // 4. 艙三：通訊雙子星 (Wi-Fi 160 + 藍牙 160)
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        // 📶 Wi-Fi 膠囊
                        Rectangle {
                            width: 160
                            height: 32
                            radius: 8
                            color: winBL.wifiExpanded ? "#1e1b4b" : "#27272a"
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
                                    winBL.btExpanded = false
                                    winBL.wifiExpanded = !winBL.wifiExpanded
                                    if (winBL.wifiExpanded) {
                                        scanWifiProc.running = false
                                        scanWifiProc.running = true
                                    }
                                }
                            }
                        }

                        // ᛒ 藍牙膠囊 (CONN青藍 / ON待命 / OFF暗灰)
                        Rectangle {
                            width: 160
                            height: 32
                            radius: 8
                            color: winBL.btExpanded ? "#2e1065" : "#27272a"
                            border.width: 1
                            border.color: (winBL.btState === "CONN") ? themeContext.geminiCyan : ((winBL.btState === "ON") ? themeContext.geminiPurple : "#3f3f46")

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: (winBL.btState === "CONN") ? "🎧" : "ᛒ"
                                    font.pixelSize: 11
                                    color: (winBL.btState === "CONN") ? themeContext.geminiCyan : "#a1a1aa"
                                }
                                Text {
                                    text: winBL.btName
                                    color: (winBL.btState === "CONN") ? "#ffffff" : "#a1a1aa"
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: 115
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        // 右鍵切換藍牙電源開關
                                        cmdRunner.run("bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on")
                                        btStatusProc.running = false; btStatusProc.running = true
                                    } else {
                                        // 左鍵展開配對設備抽屜
                                        winBL.wifiExpanded = false
                                        winBL.btExpanded = !winBL.btExpanded
                                        if (winBL.btExpanded) {
                                            scanBtProc.running = false
                                            scanBtProc.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 5. 原生抽屜：Wi-Fi 熱點雷達列表
                    Rectangle {
                        visible: winBL.wifiExpanded
                        width: parent.width
                        height: 115
                        radius: 8
                        color: "#18181b"
                        border.width: 1
                        border.color: themeContext.geminiGold
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Repeater {
                                model: wifiListModel
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 24
                                    radius: 4
                                    color: model.inUse ? "#1e1b4b" : (itemArea.containsMouse ? "#27272a" : "transparent")
                                    border.width: model.inUse ? 1 : 0
                                    border.color: themeContext.geminiGold

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        spacing: 8
                                        Text { text: "📶"; font.pixelSize: 9 }
                                        Text {
                                            text: model.ssid
                                            color: model.inUse ? themeContext.geminiGold : "#ffffff"
                                            font.pixelSize: 10
                                            font.bold: model.inUse
                                            elide: Text.ElideRight
                                            width: 190
                                        }
                                        Text { text: model.security ? "🔒" : ""; font.pixelSize: 9 }
                                        Text { text: model.signal + "%"; color: "#71717a"; font.pixelSize: 8; font.family: "JetBrains Mono" }
                                    }

                                    MouseArea {
                                        id: itemArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            // 點擊熱點直接切換連接
                                            cmdRunner.run("nmcli connection up '" + model.ssid + "' 2>/dev/null || nmcli dev wifi connect '" + model.ssid + "'")
                                            winBL.wifiExpanded = false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 6. 原生抽屜：藍牙配對設備列表
                    Rectangle {
                        visible: winBL.btExpanded
                        width: parent.width
                        height: 95
                        radius: 8
                        color: "#18181b"
                        border.width: 1
                        border.color: themeContext.geminiPurple
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Repeater {
                                model: btListModel
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 24
                                    radius: 4
                                    color: (winBL.btName === model.name) ? "#2e1065" : (btItemArea.containsMouse ? "#27272a" : "transparent")
                                    border.width: (winBL.btName === model.name) ? 1 : 0
                                    border.color: themeContext.geminiPurple

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        spacing: 8
                                        Text { text: "🎧"; font.pixelSize: 9 }
                                        Text {
                                            text: model.name
                                            color: (winBL.btName === model.name) ? themeContext.geminiCyan : "#ffffff"
                                            font.pixelSize: 10
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
                                        onClicked: {
                                            // 點擊已配對設備切換連接/斷開
                                            cmdRunner.run("bluetoothctl info " + model.mac + " | grep -q 'Connected: yes' && bluetoothctl disconnect " + model.mac + " || bluetoothctl connect " + model.mac)
                                            winBL.btExpanded = false
                                            btStatusProc.running = false
                                            btStatusProc.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 7. 艙四：WORKSPACES 魔術區
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

                    // 8. 艙五：⚡ 電源速控舵
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 160
                            height: 28
                            radius: 6
                            color: "#27272a"
                            border.width: 1
                            border.color: "#3f3f46"
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "💤"; font.pixelSize: 11 }
                                Text { text: "立即睡眠 (Suspend)"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("systemctl suspend")
                            }
                        }

                        Rectangle {
                            width: 160
                            height: 28
                            radius: 6
                            color: "#27272a"
                            border.width: 1
                            border.color: "#3f3f46"
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "🔒"; font.pixelSize: 11 }
                                Text { text: "鎖定屏幕 (Lock)"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("hyprlock || swaylock || loginctl lock-session")
                            }
                        }
                    }

                    // 9. 底部焦點窗口 + ⌨ 輸入法無縫整合
                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: Hyprland.activeToplevel ? ("● " + Hyprland.activeToplevel.title) : "● 桌面就绪 (Desktop Idle)"
                            color: "#71717a"
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            width: parent.width - 88
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // 輸入法精巧微標籤 (點擊切換)
                        Rectangle {
                            width: 80
                            height: 20
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
