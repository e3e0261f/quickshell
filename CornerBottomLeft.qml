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

        implicitWidth: isOpen ? 360 : themeContext.cornerSize
        implicitHeight: isOpen ? 400 : themeContext.cornerSize
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        // 專屬系統指令執行器 (具備完全的 sh 執行能力)
        Process {
            id: cmdRunner
            function run(cmd) {
                command = ["sh", "-c", cmd]
                running = false; running = true
            }
        }

        Timer {
            id: lockTimerBL
            interval: 450
            onTriggered: {
                winBL.isLocked = false
                if (!areaBL.containsMouse) {
                    timerBL.restart()
                }
            }
        }

        Timer {
            id: timerBL
            interval: 250
            onTriggered: {
                if (!winBL.isLocked) {
                    winBL.isOpen = false
                }
            }
        }

        MouseArea {
            id: areaBL
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                timerBL.stop()
                if (!winBL.isOpen) {
                    winBL.isOpen = true
                    winBL.isLocked = true
                    lockTimerBL.restart()
                }
            }
            onExited: {
                if (!winBL.isLocked) {
                    timerBL.restart()
                }
            }

            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    Hyprland.dispatch("workspace e+1")
                } else {
                    Hyprland.dispatch("workspace e-1")
                }
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

                    // 2. 艙一：☕ 咖啡因 / 15分鐘定時睡眠雙模膠囊
                    Rectangle {
                        width: parent.width; height: 36; radius: 8
                        color: "#18181b"; border.width: 1
                        border.color: rootContext.caffeineActive ? themeContext.geminiGold : themeContext.geminiCyan

                        Row {
                            anchors.centerIn: parent; spacing: 12
                            Text {
                                text: rootContext.caffeineActive ? "☕ 破曉無眠 (常亮)" : "🌙 漏刻入眠 (15分睡眠)"
                                color: rootContext.caffeineActive ? themeContext.geminiGold : themeContext.geminiCyan
                                font.pixelSize: 11; font.bold: true
                            }
                            Rectangle {
                                width: 34; height: 18; radius: 9
                                color: rootContext.caffeineActive ? themeContext.geminiGold : "#3f3f46"
                                Rectangle {
                                    width: 14; height: 14; radius: 7; color: "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: rootContext.caffeineActive ? (parent.width - width - 2) : 2
                                    Behavior on x { NumberAnimation { duration: 150 } }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                rootContext.caffeineActive = !rootContext.caffeineActive
                                rootContext.saveCoords()
                            }
                        }
                    }

                    // 3. 艙二：🔊 系統主音量無級滑塊 & 靜音切換
                    Rectangle {
                        width: parent.width; height: 38; radius: 8
                        color: "#18181b"; border.width: 1; border.color: "#27272a"

                        Row {
                            anchors.fill: parent; anchors.margins: 8; spacing: 10
                            Text {
                                text: rootContext.systemMuted ? "🔇" : "🔊"
                                font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: volControl.toggleMute()
                                }
                            }
                            Rectangle {
                                id: volTrack
                                width: parent.width - 78; height: 6; radius: 3
                                color: "#27272a"; anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    width: volTrack.width * (rootContext.systemVolume / 100.0)
                                    height: parent.height; radius: 3
                                    color: rootContext.systemMuted ? "#71717a" : themeContext.geminiCyan
                                    Behavior on width { NumberAnimation { duration: 80 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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
                                color: "#a1a1aa"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // 4. 艙三：📶 Wi-Fi 硬件射頻開關 + ⌨ 輸入法切換
                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Wi-Fi 藥丸：點擊切換射頻開關
                        Rectangle {
                            width: 160; height: 32; radius: 8
                            color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "📶"; font.pixelSize: 11 }
                                Text {
                                    text: rootContext.currentWifi
                                    color: "#e4e4e7"; font.pixelSize: 10; font.bold: true
                                    elide: Text.ElideRight; width: 115
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cmdRunner.run("if nmcli radio wifi | grep -q 'enabled'; then nmcli radio wifi off; else nmcli radio wifi on; fi")
                                }
                            }
                        }

                        // 輸入法藥丸：點擊切換中英文 (fcitx5)
                        Rectangle {
                            width: 160; height: 32; radius: 8
                            color: "#27272a"; border.width: 1; border.color: themeContext.geminiCyan
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "⌨"; font.pixelSize: 12; color: themeContext.geminiCyan }
                                Text {
                                    text: rootContext.currentIme
                                    color: "#e4e4e7"; font.pixelSize: 10; font.bold: true
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cmdRunner.run("fcitx5-remote -t")
                                }
                            }
                        }
                    }

                    // 5. 艙四：WORKSPACES 魔術區 (保留原汁原味)
                    Rectangle {
                        width: parent.width; height: 64; radius: 10
                        color: "#18181b"; border.width: 1; border.color: "#27272a"
                        Column {
                            anchors.centerIn: parent; spacing: 6
                            Row {
                                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                                Text { text: "WORKSPACES"; color: "#71717a"; font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 72; height: 18; radius: 9; color: "#2e1065"; border.width: 1; border.color: themeContext.geminiPurple
                                    Row {
                                        anchors.centerIn: parent; spacing: 4
                                        Text { text: "✦"; color: themeContext.geminiPurple; font.pixelSize: 9 }
                                        Text { text: "魔术区"; color: "#f3e8ff"; font.pixelSize: 9; font.bold: true }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { Hyprland.dispatch("togglespecialworkspace magic") }
                                    }
                                }
                            }

                            Row {
                                spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: Hyprland.workspaces
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: modelData.focused ? 26 : 18; height: 18; radius: 9
                                        color: modelData.focused ? themeContext.geminiGold : "#3f3f46"
                                        Behavior on width { NumberAnimation { duration: 150 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            anchors.centerIn: parent; text: modelData.id
                                            color: modelData.focused ? "#18181b" : "#d4d4d8"; font.pixelSize: 9; font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { modelData.activate() }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 6. 艙五：⚡ 電源速控舵 (立即睡眠 | 鎖定屏幕)
                    Row {
                        spacing: 10; anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            width: 160; height: 28; radius: 6; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "💤"; font.pixelSize: 11 }
                                Text { text: "立即睡眠 (Suspend)"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("systemctl suspend")
                            }
                        }
                        Rectangle {
                            width: 160; height: 28; radius: 6; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "🔒"; font.pixelSize: 11 }
                                Text { text: "鎖定屏幕 (Lock)"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: cmdRunner.run("hyprlock || swaylock || loginctl lock-session")
                            }
                        }
                    }

                    // 7. 底部焦點窗口標題
                    Text {
                        text: Hyprland.activeToplevel ? ("● " + Hyprland.activeToplevel.title) : "● 桌面就绪 (Desktop Idle)"
                        color: "#71717a"; font.pixelSize: 9; elide: Text.ElideRight
                        width: parent.width; anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
