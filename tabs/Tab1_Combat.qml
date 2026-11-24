import QtQuick
import QtQuick.Controls

Column {
    id: tab1
    property var rootContext
    property var themeContext
    property var clockContext
    property var centerWin
    property var scriptRunner
    property var handleHistory
    property var netTelemetryProc
    property var volControl
    property var soundContext

    width: parent ? parent.width : 580
    spacing: 10
    padding: 16

    function btnLabel(code) {
        if (code === "0xC1") return "右鍵";
        if (code === "0xC2") return "中鍵";
        return "左鍵";
    }

    component StepBtn: Rectangle {
        property string sym: "+"
        property int dir: 1
        signal stepped(int delta)

        width: 18; height: 18; radius: 4
        color: ma.pressed ? "#52525b" : (ma.containsMouse ? "#3f3f46" : "#27272a")
        Text { anchors.centerIn: parent; text: sym; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            property int ticks: 0
            Timer {
                id: delayTimer; interval: 320; repeat: false
                onTriggered: repeatTimer.start()
            }
            Timer {
                id: repeatTimer; interval: 70; repeat: true
                onTriggered: {
                    ma.ticks += 1;
                    var mult = ma.ticks > 32 ? 100 : (ma.ticks > 12 ? 10 : (ma.ticks > 4 ? 2 : 1));
                    stepped(dir * mult);
                }
            }
            onPressed: {
                ticks = 0;
                stepped(dir);
                delayTimer.start();
            }
            onReleased: { delayTimer.stop(); repeatTimer.stop(); }
            onCanceled: { delayTimer.stop(); repeatTimer.stop(); }
        }
    }

    component StrikeGroupPanel: Rectangle {
        id: panel
        property string groupKey: "Z"
        property string titleText: "精確打擊 (Alt+Z)"
        property color accent: "#38bdf8"
        property var pointsModel: []

        height: Math.min(248, 40 + (pointsModel ? pointsModel.length : 1) * 56)
        radius: 10; color: "#18181b"; border.color: accent; border.width: 1; clip: true

        Column {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Item {
                width: parent.width; height: 22
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Text {
                        text: panel.titleText
                        color: panel.accent; font.pixelSize: 10; font.bold: true
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (rootContext) rootContext.executeStrikeSequence("Alt+" + panel.groupKey, panel.pointsModel)
                        }
                    }
                    Rectangle {
                        width: cntTxt.implicitWidth + 10; height: 16; radius: 4; color: "#27272a"
                        Text {
                            id: cntTxt; anchors.centerIn: parent
                            text: (panel.pointsModel ? panel.pointsModel.length : 0) + " 點"
                            color: "#e4e4e7"; font.family: "monospace"; font.pixelSize: 9
                        }
                    }
                }

                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Rectangle {
                        width: 20; height: 20; radius: 4
                        color: "#27272a"
                        opacity: (panel.pointsModel && panel.pointsModel.length <= 1) ? 0.4 : 1.0
                        Text { anchors.centerIn: parent; text: "-"; color: "#ffffff"; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (rootContext) rootContext.removePoint(panel.groupKey, undefined)
                        }
                    }
                    Rectangle {
                        width: 20; height: 20; radius: 4; color: "#27272a"
                        Text { anchors.centerIn: parent; text: "+"; color: "#ffffff"; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (rootContext) rootContext.addPoint(panel.groupKey)
                        }
                    }
                }
            }

            ListView {
                width: parent.width; height: parent.height - 30; clip: true; spacing: 6
                model: panel.pointsModel
                delegate: Rectangle {
                    id: pointDelegate
                    required property var modelData
                    required property int index
                    readonly property int ptIndex: index
                    readonly property var ptData: modelData

                    width: ListView.view.width; height: 50; radius: 8
                    color: "#121216"; border.color: "#27272a"; border.width: 1

                    Column {
                        anchors.fill: parent; anchors.margins: 6; spacing: 5
                        // 第一行：序號 + X/Y 坐標微調
                        Row {
                            width: parent.width; spacing: 4
                            Rectangle {
                                width: 24; height: 18; radius: 4; color: "#27272a"
                                Text { anchors.centerIn: parent; text: "#" + (pointDelegate.ptIndex + 1); color: panel.accent; font.family: "monospace"; font.pixelSize: 9; font.bold: true }
                            }
                            Text { text: "X:"; color: "#a1a1aa"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                            StepBtn {
                                sym: "-"; dir: -1
                                onStepped: function(d) { if (rootContext) rootContext.updatePoint(panel.groupKey, pointDelegate.ptIndex, pointDelegate.ptData.x + d, null, null) }
                            }
                            TextInput {
                                width: 38; height: 18; verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                                text: String(pointDelegate.ptData.x); color: "#ffffff"; font.family: "monospace"; font.pixelSize: 11
                                validator: IntValidator { bottom: 0; top: 9999 }
                                onEditingFinished: if (rootContext) rootContext.updatePoint(panel.groupKey, pointDelegate.ptIndex, parseInt(text, 10) || 0, null, null)
                            }
                            StepBtn {
                                sym: "+"; dir: 1
                                onStepped: function(d) { if (rootContext) rootContext.updatePoint(panel.groupKey, pointDelegate.ptIndex, pointDelegate.ptData.x + d, null, null) }
                            }
                            Item { width: 4; height: 1 }
                            Text { text: "Y:"; color: "#a1a1aa"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                            StepBtn {
                                sym: "-"; dir: -1
                                onStepped: function(d) { if (rootContext) rootContext.updatePoint(panel.groupKey, pointDelegate.ptIndex, null, pointDelegate.ptData.y + d, null) }
                            }
                            TextInput {
                                width: 38; height: 18; verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                                text: String(pointDelegate.ptData.y); color: "#ffffff"; font.family: "monospace"; font.pixelSize: 11
                                validator: IntValidator { bottom: 0; top: 9999 }
                                onEditingFinished: if (rootContext) rootContext.updatePoint(panel.groupKey, pointDelegate.ptIndex, null, parseInt(text, 10) || 0, null)
                            }
                            StepBtn {
                                sym: "+"; dir: 1
                                onStepped: function(d) { if (rootContext) rootContext.updatePoint(panel.groupKey, pointDelegate.ptIndex, null, pointDelegate.ptData.y + d, null) }
                            }
                        }

                        // 第二行：鼠標按鍵選擇 + 📋 貼上 + × 刪除
                        Item {
                            width: parent.width; height: 18
                            Row {
                                anchors.left: parent.left; spacing: 4
                                Repeater {
                                    model: [
                                        { code: "0xC0", label: "左鍵" },
                                        { code: "0xC1", label: "右鍵" },
                                        { code: "0xC2", label: "中鍵" }
                                    ]
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool active: modelData.code === pointDelegate.ptData.btn
                                        width: 40; height: 17; radius: 9
                                        color: active ? panel.accent : "#27272a"
                                        Text { anchors.centerIn: parent; text: modelData.label; color: active ? "#ffffff" : "#a1a1aa"; font.pixelSize: 9; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (rootContext) rootContext.updatePoint(panel.groupKey, pointDelegate.ptIndex, null, null, modelData.code)
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right; spacing: 4
                                Rectangle {
                                    width: 56; height: 17; radius: 9
                                    color: (rootContext && rootContext.copiedCoord) ? "#1e1b4b" : "#27272a"
                                    border.color: (rootContext && rootContext.copiedCoord) ? themeContext.geminiCyan : "#3f3f46"; border.width: 1
                                    Text {
                                        anchors.centerIn: parent; text: "📋 貼上"
                                        color: (rootContext && rootContext.copiedCoord) ? themeContext.geminiCyan : "#a1a1aa"
                                        font.pixelSize: 9; font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (rootContext) rootContext.pasteToPoint(panel.groupKey, pointDelegate.ptIndex)
                                    }
                                }
                                Rectangle {
                                    visible: panel.pointsModel.length > 1
                                    width: 17; height: 17; radius: 9; color: "#27272a"
                                    Text { anchors.centerIn: parent; text: "×"; color: "#fda4af"; font.pixelSize: 10; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (rootContext) rootContext.removePoint(panel.groupKey, pointDelegate.ptIndex)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "ALBION & COMBAT HUD (YDO-TOOL ENGINE)"
        color: themeContext ? themeContext.geminiGold : "#fde047"
        font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
    }

    // 第一行：鼠標連擊 + 按住 Q 鍵連發
    Row {
        width: Math.min(920, parent.width - 32); anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
        readonly property real halfW: (width - spacing) / 2

        Rectangle {
            width: parent.halfW; height: 70; radius: 10
            color: "#18181b"
            border.color: (rootContext && rootContext.autoClickerEnabled) ? themeContext.geminiGold : "#27272a"; border.width: 1
            Column {
                anchors.centerIn: parent; width: parent.width - 24; spacing: 6
                Item {
                    width: parent.width; height: 28
                    Column {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        Text { text: "鼠標連擊 (左+右鍵)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "12 次/秒 · 點擊開關"; color: "#71717a"; font.pixelSize: 9 }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 38; height: 22; radius: 11
                        color: (rootContext && rootContext.autoClickerEnabled) ? themeContext.geminiGold : "#3f3f46"
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: "#ffffff"; y: 2
                            x: (rootContext && rootContext.autoClickerEnabled) ? 18 : 2
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (rootContext) rootContext.autoClickerEnabled = !rootContext.autoClickerEnabled
                        }
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                    Repeater {
                        model: [{ code: "0xC0", label: "左鍵" }, { code: "0xC1", label: "右鍵" }, { code: "0xC2", label: "中鍵" }]
                        Rectangle {
                            required property var modelData
                            readonly property bool active: rootContext && rootContext.clickerButtonCode === modelData.code
                            width: 50; height: 18; radius: 9
                            color: active ? themeContext.geminiGold : "#27272a"
                            Text { anchors.centerIn: parent; text: modelData.label; color: active ? "#18181b" : "#a1a1aa"; font.pixelSize: 9; font.bold: true }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (rootContext) { rootContext.clickerButtonCode = modelData.code; rootContext.saveCoords(); }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.halfW; height: 70; radius: 10
            color: "#18181b"
            border.color: (rootContext && rootContext.autoQActive) ? themeContext.geminiCoral : "#27272a"; border.width: 1
            Item {
                anchors.fill: parent; anchors.margins: 18
                Column {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: "按住 Q 鍵連發模式"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                    Text { text: "按住Q無限發送，鬆手即停"; color: "#71717a"; font.pixelSize: 9 }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 22; radius: 11
                    color: (rootContext && rootContext.autoQActive) ? themeContext.geminiCoral : "#3f3f46"
                    Rectangle {
                        width: 18; height: 18; radius: 9; color: "#ffffff"; y: 2
                        x: (rootContext && rootContext.autoQActive) ? 18 : 2
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (rootContext) rootContext.autoQActive = !rootContext.autoQActive
                    }
                }
            }
        }
    }

    // 第二行：多點 Alt+Z & Alt+X 精確打擊
    Row {
        width: Math.min(920, parent.width - 32); anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
        readonly property real halfW: (width - spacing) / 2

        StrikeGroupPanel {
            width: parent.halfW
            groupKey: "Z"
            titleText: "精確打擊 (Alt+Z)"
            accent: themeContext ? themeContext.geminiBlue : "#38bdf8"
            pointsModel: rootContext ? rootContext.zPoints : []
        }

        StrikeGroupPanel {
            width: parent.halfW
            groupKey: "X"
            titleText: "精確打擊 (Alt+X)"
            accent: themeContext ? themeContext.geminiRose : "#f43f5e"
            pointsModel: rootContext ? rootContext.xPoints : []
        }
    }

    // 第三行：Snap-Back 開關
    Rectangle {
        width: Math.min(920, parent.width - 32); anchors.horizontalCenter: parent.horizontalCenter
        height: 34; radius: 8; color: "#18181b"
        border.color: (rootContext && rootContext.cursorReturnEnabled) ? themeContext.geminiCyan : "#27272a"; border.width: 1
        Row {
            anchors.centerIn: parent; spacing: 14
            Text { text: "↩️ 點擊後光標原路返回 (Snap-Back)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
            Text { text: "躍遷點擊後，鼠標微秒級折返當前位置"; color: "#71717a"; font.pixelSize: 9 }
            Rectangle {
                width: 34; height: 18; radius: 9
                color: (rootContext && rootContext.cursorReturnEnabled) ? themeContext.geminiCyan : "#3f3f46"
                Rectangle {
                    width: 14; height: 14; radius: 7; color: "#ffffff"; y: 2
                    x: (rootContext && rootContext.cursorReturnEnabled) ? 18 : 2
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (rootContext) { rootContext.cursorReturnEnabled = !rootContext.cursorReturnEnabled; rootContext.saveCoords(); }
                }
            }
        }
    }

    // 第四行：最近鼠標點擊坐標列表 (點擊複製 · 貼上至任意打擊點)
    Rectangle {
        width: Math.min(920, parent.width - 32); anchors.horizontalCenter: parent.horizontalCenter
        height: 152; radius: 10; color: "#141418"; border.color: "#27272a"; border.width: 1
        Column {
            anchors.fill: parent; anchors.margins: 10; spacing: 6
            Item {
                width: parent.width; height: 22
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Text {
                        text: "🖱️ 最近鼠標點擊坐標 (點擊複製 · 到任意打擊點貼上)"
                        color: themeContext ? themeContext.geminiCyan : "#38bdf8"
                        font.pixelSize: 9; font.bold: true
                    }
                    Rectangle {
                        visible: rootContext && rootContext.copiedCoord !== null
                        width: cpTxt.implicitWidth + 12; height: 18; radius: 9
                        color: "#1e1b4b"; border.color: themeContext.geminiCyan; border.width: 1
                        Text {
                            id: cpTxt; anchors.centerIn: parent
                            text: (rootContext && rootContext.copiedCoord) ? ("已複製: " + rootContext.copiedCoord.x + ", " + rootContext.copiedCoord.y) : ""
                            color: "#7dd3fc"; font.family: "monospace"; font.pixelSize: 9; font.bold: true
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 112; height: 22; radius: 11
                    color: "#1e1b4b"; border.color: themeContext.geminiCyan; border.width: 1
                    Text { anchors.centerIn: parent; text: "🎯 記錄光標坐標"; color: "#7dd3fc"; font.pixelSize: 9; font.bold: true }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (rootContext) rootContext.pickCurrentCursorCoord()
                    }
                }
            }

            ListView {
                width: parent.width; height: parent.height - 28; clip: true; spacing: 4
                model: rootContext ? rootContext.recentClicks : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isCopied: rootContext && rootContext.copiedCoord &&
                                                     rootContext.copiedCoord.x === modelData.x &&
                                                     rootContext.copiedCoord.y === modelData.y
                    width: ListView.view.width; height: 26; radius: 6
                    color: isCopied ? "#172554" : (index === 0 ? "#18181b" : "#121216")
                    border.color: isCopied ? themeContext.geminiCyan : (index === 0 ? "#3f3f46" : "#27272a"); border.width: 1

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text { text: modelData.time || ""; color: "#71717a"; font.family: "monospace"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: 44; height: 16; radius: 4; color: "#1e3a8a"; anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: "🖱️ " + tab1.btnLabel(modelData.btn); color: "#93c5fd"; font.pixelSize: 8; font.bold: true }
                        }
                        Text {
                            text: modelData.x + ", " + modelData.y
                            color: themeContext ? themeContext.geminiGold : "#fde047"
                            font.family: "monospace"; font.pixelSize: 10; font.bold: true; width: 100
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.source || ""
                            color: "#a1a1aa"; font.pixelSize: 9; width: 220; elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: isCopied ? "✓ 已複製" : "📋 點擊複製"
                            color: isCopied ? themeContext.geminiCyan : "#71717a"
                            font.pixelSize: 8; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (rootContext) rootContext.copyRecentClick(modelData)
                    }
                }
            }
        }
    }

    // 第五行：跑商助手與本地優化腳本
    Row {
        width: Math.min(920, parent.width - 32); anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
        readonly property real halfW: (width - spacing) / 2

        Rectangle {
            width: parent.halfW; height: 36; radius: 8; color: "#27272a"; border.color: "#3f3f46"; border.width: 1
            Text { anchors.centerIn: parent; text: "🗺️ 啟動 Albion 跑商助手"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (scriptRunner) scriptRunner.run("xdg-open https://albiononline2d.com/ &")
            }
        }
        Rectangle {
            width: parent.halfW; height: 36; radius: 8; color: "#27272a"; border.color: "#3f3f46"; border.width: 1
            Text { anchors.centerIn: parent; text: "⚔️ 執行本地優化腳本"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (scriptRunner) scriptRunner.run("notify-send 'Albion HUD' '遊戲環境優化腳本已觸發'")
            }
        }
    }
}
