import QtQuick

Column {
    id: tab1Root
    property var rootContext
    property var themeContext
    property var scriptRunner

    width: parent ? parent.width : 580
    spacing: 12

    // 步進按鈕組件
    component StepButton: Rectangle {
        id: stepBtn
        property string symbol: "+"
        property int direction: 1
        signal stepped(int delta)
        signal finished()

        width: 18
        height: 18
        radius: 4
        color: mouseArea.pressed ? "#3f3f46" : "#27272a"

        Text {
            anchors.centerIn: parent
            text: stepBtn.symbol
            color: "#ffffff"
            font.bold: true
            font.pixelSize: 11
        }

        property int holdTicks: 0

        Timer {
            id: repeatTimer
            interval: 70
            repeat: true
            onTriggered: {
                stepBtn.holdTicks += 1
                var mult = stepBtn.holdTicks > 32 ? 100 : (stepBtn.holdTicks > 12 ? 10 : (stepBtn.holdTicks > 4 ? 2 : 1))
                stepBtn.stepped(stepBtn.direction * mult)
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

    Text {
        text: "ALBION & COMBAT HUD (YDO-TOOL ENGINE)"
        color: themeContext ? themeContext.geminiGold : "#eab308"
        font.pixelSize: 10
        font.bold: true
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // 行 1：連點器與按鍵選擇 + Q鍵連發
    Row {
        spacing: 14
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            width: 255
            height: 74
            radius: 10
            color: "#18181b"
            border.width: 1
            border.color: rootContext && rootContext.autoClickerActive ? themeContext.geminiGold : "#27272a"

            Column {
                anchors.centerIn: parent
                spacing: 6

                Row {
                    spacing: 12
                    Column {
                        spacing: 2
                        Text {
                            text: "鼠標連擊 (Shift+C)"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            text: "12 次/秒 · 點擊開關"
                            color: "#71717a"
                            font.pixelSize: 9
                        }
                    }
                    Rectangle {
                        width: 38
                        height: 22
                        radius: 11
                        color: rootContext && rootContext.autoClickerActive ? themeContext.geminiGold : "#3f3f46"
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: rootContext && rootContext.autoClickerActive ? (parent.width - width - 2) : 2
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) rootContext.autoClickerActive = !rootContext.autoClickerActive
                            }
                        }
                    }
                }

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.clickerButtonCode === "0xC0") ? themeContext.geminiGold : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "左鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.clickerButtonCode === "0xC0") ? "#18181b" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.clickerButtonCode = "0xC0"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.clickerButtonCode === "0xC1") ? themeContext.geminiGold : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "右鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.clickerButtonCode === "0xC1") ? "#18181b" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.clickerButtonCode = "0xC1"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.clickerButtonCode === "0xC2") ? themeContext.geminiGold : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "中鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.clickerButtonCode === "0xC2") ? "#18181b" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.clickerButtonCode = "0xC2"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 255
            height: 74
            radius: 10
            color: "#18181b"
            border.width: 1
            border.color: rootContext && rootContext.autoQActive ? themeContext.geminiCoral : "#27272a"

            Row {
                anchors.centerIn: parent
                spacing: 14

                Column {
                    spacing: 4
                    Text {
                        text: "按住 Q 鍵連發模式"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        text: "按住Q無限發送，鬆手即停"
                        color: "#71717a"
                        font.pixelSize: 9
                    }
                }
                Rectangle {
                    width: 38
                    height: 22
                    radius: 11
                    color: rootContext && rootContext.autoQActive ? themeContext.geminiCoral : "#3f3f46"
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: rootContext && rootContext.autoQActive ? (parent.width - width - 2) : 2
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rootContext) {
                                rootContext.autoQActive = !rootContext.autoQActive
                                if (scriptRunner) {
                                    if (rootContext.autoQActive) scriptRunner.runScript("touch /tmp/q_spam_enabled")
                                    else scriptRunner.runScript("rm -f /tmp/q_spam_enabled")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 行 2：打擊坐標調整與三鍵自選
    Row {
        spacing: 14
        anchors.horizontalCenter: parent.horizontalCenter

        // Shift+Z 面板
        Rectangle {
            width: 255
            height: 86
            radius: 10
            color: "#18181b"
            border.width: 1
            border.color: themeContext ? themeContext.geminiBlue : "#38bdf8"

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "精確打擊 (Shift+Z)"
                    color: themeContext ? themeContext.geminiBlue : "#38bdf8"
                    font.pixelSize: 10
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "X:"
                        color: "#a1a1aa"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StepButton {
                        symbol: "-"
                        direction: -1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftZx = Math.max(0, rootContext.shiftZx + d)
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    TextInput {
                        text: rootContext ? rootContext.shiftZx : 500
                        color: "#ffffff"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        width: 38
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 9999 }
                        onEditingFinished: {
                            var v = parseInt(text)
                            if (!isNaN(v) && rootContext) {
                                rootContext.shiftZx = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftZx += d
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }

                    Item { width: 4; height: 1 }

                    Text {
                        text: "Y:"
                        color: "#a1a1aa"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StepButton {
                        symbol: "-"
                        direction: -1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftZy = Math.max(0, rootContext.shiftZy + d)
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    TextInput {
                        text: rootContext ? rootContext.shiftZy : 500
                        color: "#ffffff"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        width: 38
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 9999 }
                        onEditingFinished: {
                            var v = parseInt(text)
                            if (!isNaN(v) && rootContext) {
                                rootContext.shiftZy = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftZy += d
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                }

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.shiftZBtn === "0xC0") ? themeContext.geminiBlue : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "左鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.shiftZBtn === "0xC0") ? "#ffffff" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.shiftZBtn = "0xC0"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.shiftZBtn === "0xC1") ? themeContext.geminiBlue : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "右鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.shiftZBtn === "0xC1") ? "#ffffff" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.shiftZBtn = "0xC1"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.shiftZBtn === "0xC2") ? themeContext.geminiBlue : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "中鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.shiftZBtn === "0xC2") ? "#ffffff" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.shiftZBtn = "0xC2"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Shift+X 面板
        Rectangle {
            width: 255
            height: 86
            radius: 10
            color: "#18181b"
            border.width: 1
            border.color: themeContext ? themeContext.geminiRose : "#fb7185"

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "精確打擊 (Shift+X)"
                    color: themeContext ? themeContext.geminiRose : "#fb7185"
                    font.pixelSize: 10
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "X:"
                        color: "#a1a1aa"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StepButton {
                        symbol: "-"
                        direction: -1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftXx = Math.max(0, rootContext.shiftXx + d)
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    TextInput {
                        text: rootContext ? rootContext.shiftXx : 800
                        color: "#ffffff"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        width: 38
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 9999 }
                        onEditingFinished: {
                            var v = parseInt(text)
                            if (!isNaN(v) && rootContext) {
                                rootContext.shiftXx = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftXx += d
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }

                    Item { width: 4; height: 1 }

                    Text {
                        text: "Y:"
                        color: "#a1a1aa"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StepButton {
                        symbol: "-"
                        direction: -1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftXy = Math.max(0, rootContext.shiftXy + d)
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    TextInput {
                        text: rootContext ? rootContext.shiftXy : 500
                        color: "#ffffff"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                        width: 38
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 9999 }
                        onEditingFinished: {
                            var v = parseInt(text)
                            if (!isNaN(v) && rootContext) {
                                rootContext.shiftXy = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftXy += d
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                }

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.shiftXBtn === "0xC0") ? themeContext.geminiRose : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "左鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.shiftXBtn === "0xC0") ? "#ffffff" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.shiftXBtn = "0xC0"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.shiftXBtn === "0xC1") ? themeContext.geminiRose : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "右鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.shiftXBtn === "0xC1") ? "#ffffff" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.shiftXBtn = "0xC1"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 50
                        height: 18
                        radius: 9
                        color: rootContext && (rootContext.shiftXBtn === "0xC2") ? themeContext.geminiRose : "#27272a"
                        Text {
                            anchors.centerIn: parent
                            text: "中鍵"
                            font.pixelSize: 9
                            font.bold: true
                            color: rootContext && (rootContext.shiftXBtn === "0xC2") ? "#ffffff" : "#a1a1aa"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) {
                                    rootContext.shiftXBtn = "0xC2"
                                    rootContext.saveCoords()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 行 3：原路折返開關
    Rectangle {
        width: 524
        height: 34
        radius: 8
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#18181b"
        border.width: 1
        border.color: rootContext && rootContext.cursorReturnEnabled ? themeContext.geminiCyan : "#27272a"

        Row {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "↩️ 點擊後光標原路返回 (Snap-Back)"
                color: "#ffffff"
                font.pixelSize: 11
                font.bold: true
            }
            Text {
                text: "躍遷點擊後，鼠標微秒級折返當前位置"
                color: "#71717a"
                font.pixelSize: 9
            }
            Rectangle {
                width: 34
                height: 18
                radius: 9
                color: rootContext && rootContext.cursorReturnEnabled ? themeContext.geminiCyan : "#3f3f46"
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: rootContext && rootContext.cursorReturnEnabled ? (parent.width - width - 2) : 2
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rootContext) {
                            rootContext.cursorReturnEnabled = !rootContext.cursorReturnEnabled
                            rootContext.saveCoords()
                        }
                    }
                }
            }
        }
    }

    // 行 4：腳本按鈕
    Row {
        spacing: 14
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            width: 255
            height: 38
            radius: 8
            color: "#27272a"
            border.width: 1
            border.color: "#3f3f46"

            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: "🗺️"
                    font.pixelSize: 12
                }
                Text {
                    text: "啟動 Albion 跑商助手"
                    color: "#e4e4e7"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (scriptRunner) scriptRunner.runScript("xdg-open 'https://albiononline2d.com/'")
                }
            }
        }

        Rectangle {
            width: 255
            height: 38
            radius: 8
            color: "#27272a"
            border.width: 1
            border.color: "#3f3f46"

            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: "⚔️"
                    font.pixelSize: 12
                }
                Text {
                    text: "執行本地優化腳本"
                    color: "#e4e4e7"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (scriptRunner) scriptRunner.runScript("notify-send '遊戲模式' '戰鬥環境已就緒'")
                }
            }
        }
    }
}
