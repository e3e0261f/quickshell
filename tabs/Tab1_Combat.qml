import QtQuick

Column {
    id: tab1Root
    property var rootContext
    property var themeContext
    property var scriptRunner

    // 統一主題色安全讀取，避免 themeContext 為空時報 TypeError
    readonly property color colGold:  (themeContext && themeContext.geminiGold  !== undefined) ? themeContext.geminiGold  : "#eab308"
    readonly property color colCoral: (themeContext && themeContext.geminiCoral !== undefined) ? themeContext.geminiCoral : "#f97316"
    readonly property color colBlue:  (themeContext && themeContext.geminiBlue  !== undefined) ? themeContext.geminiBlue  : "#38bdf8"
    readonly property color colRose:  (themeContext && themeContext.geminiRose  !== undefined) ? themeContext.geminiRose  : "#fb7185"
    readonly property color colCyan:  (themeContext && themeContext.geminiCyan  !== undefined) ? themeContext.geminiCyan  : "#22d3ee"

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
                // 先搶佔焦點，讓尚未確認的 TextInput 觸發 onEditingFinished 完成提交
                stepBtn.forceActiveFocus()
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

    // 坐標輸入組件（自動恢復綁定，支援 Enter 確認與無效輸入回滾）
    component CoordInput: TextInput {
        id: coordInput
        property int coordValue: 0
        signal committed(int newValue)

        text: String(coordValue)
        color: "#ffffff"
        font.family: "JetBrains Mono"
        font.pixelSize: 11
        width: 38
        horizontalAlignment: Text.AlignHCenter
        selectByMouse: true
        validator: IntValidator { bottom: 0; top: 9999 }

        Keys.onReturnPressed: focus = false
        Keys.onEnterPressed: focus = false

        onEditingFinished: {
            var v = parseInt(text, 10)
            if (!isNaN(v)) {
                v = Math.max(0, Math.min(9999, v))
                committed(v)
            }
            text = Qt.binding(function() { return String(coordInput.coordValue) })
        }
    }

    Text {
        text: "ALBION & COMBAT HUD (YDO-TOOL ENGINE)"
        color: tab1Root.colGold
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
            border.color: rootContext && rootContext.autoClickerEnabled ? tab1Root.colGold : "#27272a"

            Column {
                anchors.centerIn: parent
                spacing: 6

                Row {
                    spacing: 12
                    Column {
                        spacing: 2
                        Text {
                            text: "鼠標連擊 (Alt+C)"
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
                        color: rootContext && rootContext.autoClickerEnabled ? tab1Root.colGold : "#3f3f46"
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: rootContext && rootContext.autoClickerEnabled ? (parent.width - width - 2) : 2
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rootContext) rootContext.autoClickerEnabled = !rootContext.autoClickerEnabled
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
                        color: rootContext && (rootContext.clickerButtonCode === "0xC0") ? tab1Root.colGold : "#27272a"
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
                        color: rootContext && (rootContext.clickerButtonCode === "0xC1") ? tab1Root.colGold : "#27272a"
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
                        color: rootContext && (rootContext.clickerButtonCode === "0xC2") ? tab1Root.colGold : "#27272a"
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
            border.color: rootContext && rootContext.autoQActive ? tab1Root.colCoral : "#27272a"

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
                    color: rootContext && rootContext.autoQActive ? tab1Root.colCoral : "#3f3f46"
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

    // 行 2：打擊坐標調整與三鍵自選（註：後端屬性仍沿用 shiftZ*/shiftX* 命名以保持相容）
    Row {
        spacing: 14
        anchors.horizontalCenter: parent.horizontalCenter

        // Alt+Z 面板
        Rectangle {
            width: 255
            height: 86
            radius: 10
            color: "#18181b"
            border.width: 1
            border.color: tab1Root.colBlue

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "精確打擊 (Alt+Z)"
                    color: tab1Root.colBlue
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
                            if (rootContext) rootContext.shiftZx = Math.max(0, Math.min(9999, rootContext.shiftZx + d))
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    CoordInput {
                        anchors.verticalCenter: parent.verticalCenter
                        coordValue: rootContext ? rootContext.shiftZx : 500
                        onCommitted: function(v) {
                            if (rootContext) {
                                rootContext.shiftZx = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftZx = Math.max(0, Math.min(9999, rootContext.shiftZx + d))
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
                            if (rootContext) rootContext.shiftZy = Math.max(0, Math.min(9999, rootContext.shiftZy + d))
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    CoordInput {
                        anchors.verticalCenter: parent.verticalCenter
                        coordValue: rootContext ? rootContext.shiftZy : 500
                        onCommitted: function(v) {
                            if (rootContext) {
                                rootContext.shiftZy = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftZy = Math.max(0, Math.min(9999, rootContext.shiftZy + d))
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
                        color: rootContext && (rootContext.shiftZBtn === "0xC0") ? tab1Root.colBlue : "#27272a"
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
                        color: rootContext && (rootContext.shiftZBtn === "0xC1") ? tab1Root.colBlue : "#27272a"
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
                        color: rootContext && (rootContext.shiftZBtn === "0xC2") ? tab1Root.colBlue : "#27272a"
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

        // Alt+X 面板
        Rectangle {
            width: 255
            height: 86
            radius: 10
            color: "#18181b"
            border.width: 1
            border.color: tab1Root.colRose

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "精確打擊 (Alt+X)"
                    color: tab1Root.colRose
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
                            if (rootContext) rootContext.shiftXx = Math.max(0, Math.min(9999, rootContext.shiftXx + d))
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    CoordInput {
                        anchors.verticalCenter: parent.verticalCenter
                        coordValue: rootContext ? rootContext.shiftXx : 800
                        onCommitted: function(v) {
                            if (rootContext) {
                                rootContext.shiftXx = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftXx = Math.max(0, Math.min(9999, rootContext.shiftXx + d))
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
                            if (rootContext) rootContext.shiftXy = Math.max(0, Math.min(9999, rootContext.shiftXy + d))
                        }
                        onFinished: function() {
                            if (rootContext) rootContext.saveCoords()
                        }
                    }
                    CoordInput {
                        anchors.verticalCenter: parent.verticalCenter
                        coordValue: rootContext ? rootContext.shiftXy : 500
                        onCommitted: function(v) {
                            if (rootContext) {
                                rootContext.shiftXy = v
                                rootContext.saveCoords()
                            }
                        }
                    }
                    StepButton {
                        symbol: "+"
                        direction: 1
                        onStepped: function(d) {
                            if (rootContext) rootContext.shiftXy = Math.max(0, Math.min(9999, rootContext.shiftXy + d))
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
                        color: rootContext && (rootContext.shiftXBtn === "0xC0") ? tab1Root.colRose : "#27272a"
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
                        color: rootContext && (rootContext.shiftXBtn === "0xC1") ? tab1Root.colRose : "#27272a"
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
                        color: rootContext && (rootContext.shiftXBtn === "0xC2") ? tab1Root.colRose : "#27272a"
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
        border.color: rootContext && rootContext.cursorReturnEnabled ? tab1Root.colCyan : "#27272a"

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
                color: rootContext && rootContext.cursorReturnEnabled ? tab1Root.colCyan : "#3f3f46"
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
