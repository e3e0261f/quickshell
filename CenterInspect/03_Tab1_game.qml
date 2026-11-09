import QtQuick

Item {
    id: tab1Root
    required property var rootContext
    required property var themeContext
    required property var scriptRunner

    component StepButton: Rectangle {
        id: stepBtn
        property string symbol: "+"
        property int direction: 1
        signal stepped(int delta)
        signal finished()

        width: 18; height: 18; radius: 4
        color: mouseArea.pressed ? "#3f3f46" : "#27272a"
        Text { anchors.centerIn: parent; text: stepBtn.symbol; color: "#ffffff"; font.bold: true; font.pixelSize: 11 }

        property int holdTicks: 0

        Timer {
            id: repeatTimer
            interval: 70
            repeat: true
            onTriggered: {
                stepBtn.holdTicks += 1
                var multiplier = 1
                if (stepBtn.holdTicks > 32) multiplier = 100
                else if (stepBtn.holdTicks > 12) multiplier = 10
                else if (stepBtn.holdTicks > 4) multiplier = 2
                stepBtn.stepped(stepBtn.direction * multiplier)
            }
        }

        Timer {
            id: initialDelayTimer
            interval: 320
            onTriggered: repeatTimer.start()
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            onPressed: {
                stepBtn.stepped(stepBtn.direction * 1)
                stepBtn.holdTicks = 0
                initialDelayTimer.restart()
            }
            onReleased: {
                initialDelayTimer.stop()
                repeatTimer.stop()
                stepBtn.finished()
            }
            onCanceled: {
                initialDelayTimer.stop()
                repeatTimer.stop()
                stepBtn.finished()
            }
        }
    }

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Text {
            text: "ALBION & COMBAT HUD (YDO-TOOL ENGINE)"
            color: themeContext.geminiGold
            font.pixelSize: 10
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // 行 1：連點器與按鍵選擇 + Q鍵連發
        Row {
            spacing: 14
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 255; height: 74; radius: 10
                color: "#18181b"; border.width: 1
                border.color: rootContext.autoClickerActive ? themeContext.geminiGold : "#27272a"

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Row {
                        spacing: 12
                        Column {
                            spacing: 2
                            Text { text: "鼠標連擊 (Shift+C)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                            Text { text: "12 次/秒 · 點擊開關"; color: "#71717a"; font.pixelSize: 9 }
                        }
                        Rectangle {
                            width: 38; height: 22; radius: 11
                            color: rootContext.autoClickerActive ? themeContext.geminiGold : "#3f3f46"
                            Rectangle {
                                width: 18; height: 18; radius: 9; color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: rootContext.autoClickerActive ? (parent.width - width - 2) : 2
                                Behavior on x { NumberAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: rootContext.autoClickerActive = !rootContext.autoClickerActive
                            }
                        }
                    }

                    // 連點鍵位選擇膠囊：左鍵 / 右鍵 / 中鍵
                    Row {
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 50; height: 18; radius: 9
                            color: (rootContext.clickerButtonCode === "0xC0") ? themeContext.geminiGold : "#27272a"
                            Text { anchors.centerIn: parent; text: "左鍵"; font.pixelSize: 9; font.bold: true; color: (rootContext.clickerButtonCode === "0xC0") ? "#18181b" : "#a1a1aa" }
                            MouseArea { anchors.fill: parent; onClicked: rootContext.clickerButtonCode = "0xC0" }
                        }
                        Rectangle {
                            width: 50; height: 18; radius: 9
                            color: (rootContext.clickerButtonCode === "0xC1") ? themeContext.geminiGold : "#27272a"
                            Text { anchors.centerIn: parent; text: "右鍵"; font.pixelSize: 9; font.bold: true; color: (rootContext.clickerButtonCode === "0xC1") ? "#18181b" : "#a1a1aa" }
                            MouseArea { anchors.fill: parent; onClicked: rootContext.clickerButtonCode = "0xC1" }
                        }
                        Rectangle {
                            width: 50; height: 18; radius: 9
                            color: (rootContext.clickerButtonCode === "0xC2") ? themeContext.geminiGold : "#27272a"
                            Text { anchors.centerIn: parent; text: "中鍵"; font.pixelSize: 9; font.bold: true; color: (rootContext.clickerButtonCode === "0xC2") ? "#18181b" : "#a1a1aa" }
                            MouseArea { anchors.fill: parent; onClicked: rootContext.clickerButtonCode = "0xC2" }
                        }
                    }
                }
            }

            Rectangle {
                width: 255; height: 74; radius: 10
                color: "#18181b"; border.width: 1
                border.color: rootContext.autoQActive ? themeContext.geminiCoral : "#27272a"

                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    Column {
                        spacing: 4
                        Text { text: "按住 Q 鍵連發模式"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "按住Q無限發送，鬆手即停"; color: "#71717a"; font.pixelSize: 9 }
                    }
                    Rectangle {
                        width: 38; height: 22; radius: 11
                        color: rootContext.autoQActive ? themeContext.geminiCoral : "#3f3f46"
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: rootContext.autoQActive ? (parent.width - width - 2) : 2
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: rootContext.autoQActive = !rootContext.autoQActive
                        }
                    }
                }
            }
        }

        // 行 2：打擊坐標調整面板
        Row {
            spacing: 14
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 255; height: 60; radius: 10; color: "#18181b"; border.width: 1; border.color: themeContext.geminiBlue
                Column {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: "精確打擊 (Shift+Z)"; color: themeContext.geminiBlue; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    Row {
                        spacing: 5; anchors.horizontalCenter: parent.horizontalCenter
                        Text { text: "X:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftZx = Math.max(0, rootContext.shiftZx + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftZx; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }  onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftZx = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftZx += delta; onFinished: rootContext.saveCoords() }

                        Item { width: 4; height: 1 }

                        Text { text: "Y:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftZy = Math.max(0, rootContext.shiftZy + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftZy; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }  onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftZy = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftZy += delta; onFinished: rootContext.saveCoords() }
                    }
                }
            }

            Rectangle {
                width: 255; height: 60; radius: 10; color: "#18181b"; border.width: 1; border.color: themeContext.geminiRose
                Column {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: "精確打擊 (Shift+X)"; color: themeContext.geminiRose; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    Row {
                        spacing: 5; anchors.horizontalCenter: parent.horizontalCenter
                        Text { text: "X:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftXx = Math.max(0, rootContext.shiftXx + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftXx; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }  onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftXx = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftXx += delta; onFinished: rootContext.saveCoords() }

                        Item { width: 4; height: 1 }

                        Text { text: "Y:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftXy = Math.max(0, rootContext.shiftXy + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftXy; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }  onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftXy = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftXy += delta; onFinished: rootContext.saveCoords() }
                    }
                }
            }
        }

        // 行 3.5：拖拽丟棄模式
        Rectangle {
            width: 524; height: 34; radius: 8
            color: "#18181b"; border.width: 1; border.color: rootContext.dragDropEnabled ? themeContext.geminiGold : "#27272a"

            Row {
                anchors.centerIn: parent; spacing: 16
                Text { text: "🤏 拖拽丟棄模式 (Drag & Drop)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                Text { text: "打擊前：在當前位置按住左鍵，拖至目標再鬆開"; color: "#71717a"; font.pixelSize: 9 }
                Rectangle {
                    width: 34; height: 18; radius: 9
                    color: rootContext.dragDropEnabled ? themeContext.geminiGold : "#3f3f46"
                    Rectangle {
                        width: 14; height: 14; radius: 7; color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: rootContext.dragDropEnabled ? (parent.width - width - 2) : 2
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: rootContext.dragDropEnabled = !rootContext.dragDropEnabled
                    }
                }
            }
        }

        // 行 3：【核心新增】：點擊後鼠標原路折返開關
        Rectangle {
            width: 524; height: 34; radius: 8
            color: "#18181b"; border.width: 1; border.color: rootContext.cursorReturnEnabled ? themeContext.geminiCyan : "#27272a"

            Row {
                anchors.centerIn: parent; spacing: 16
                Text { text: "↩️ 點擊後光標原路返回 (Snap-Back)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                Text { text: "躍遷點擊後，鼠標微秒級折返當前位置"; color: "#71717a"; font.pixelSize: 9 }
                Rectangle {
                    width: 34; height: 18; radius: 9
                    color: rootContext.cursorReturnEnabled ? themeContext.geminiCyan : "#3f3f46"
                    Rectangle {
                        width: 14; height: 14; radius: 7; color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: rootContext.cursorReturnEnabled ? (parent.width - width - 2) : 2
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: rootContext.cursorReturnEnabled = !rootContext.cursorReturnEnabled
                    }
                }
            }
        }

        // 行 4：Albion 腳本
        Row {
            spacing: 14
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                width: 255; height: 38; radius: 8; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                Row { anchors.centerIn: parent; spacing: 8; Text { text: "🗺️"; font.pixelSize: 12 } Text { text: "啟動 Albion 跑商助手"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scriptRunner.runScript("xdg-open 'https://albiononline2d.com/'") }
            }
            Rectangle {
                width: 255; height: 38; radius: 8; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                Row { anchors.centerIn: parent; spacing: 8; Text { text: "⚔️"; font.pixelSize: 12 } Text { text: "執行本地優化腳本"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scriptRunner.runScript("notify-send '遊戲模式' '戰鬥環境已就緒'") }
            }
        }
    }
}
