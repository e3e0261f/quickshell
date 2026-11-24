import QtQuick
import QtQuick.Controls

Column {
    id: tab0
    property var rootContext
    property var themeContext
    property var clockContext
    property var centerWin
    property var scriptRunner
    property var handleHistory
    property var netTelemetryProc
    property var volControl
    property var soundContext

    readonly property int extraH: (centerWin && centerWin.expandedContentHeight > 0)
                                  ? Math.max(0, centerWin.expandedContentHeight - 392) : 0

    width: parent ? parent.width : 540
    spacing: 8
    padding: 14

    function levelName(lv) {
        var names = [
            "",
            "Lv1 全量原始包 (含ACK空包)",
            "Lv2 去空包 (過濾純ACK)",
            "Lv3 去本地組播與回環",
            "Lv4 去常規下行分片",
            "Lv5 關注上行/握手/UDP",
            "Lv6 異端口 / 急發連包 / 上傳偏高",
            "Lv7 無域名直連 / 尺寸突變 / 新目標",
            "Lv8 外來主動包 / 混合異構 / 純上傳",
            "Lv9 偽裝443 / 非80明文",
            "Lv10 高危 (外來SYN/週期心跳/掃描/盲傳)"
        ];
        return names[lv] || ("Lv" + lv);
    }

    function levelColor(lv) {
        if (lv >= 9) return themeContext ? themeContext.geminiRose : "#f43f5e";
        if (lv >= 8) return themeContext ? themeContext.geminiAmber : "#f59e0b";
        if (lv >= 6) return themeContext ? themeContext.geminiGold : "#fde047";
        if (lv >= 4) return themeContext ? themeContext.geminiBlue : "#38bdf8";
        return "#71717a";
    }

    // 頂部狀態與控制欄
    Rectangle {
        width: parent.width - 28; height: 48; radius: 10
        color: "#18181b"
        border.color: rootContext && rootContext.netmonEnabled ? themeContext.geminiCyan : "#27272a"; border.width: 1

        Row {
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Column {
                spacing: 2
                Row {
                    spacing: 6
                    Text {
                        text: "● " + (rootContext && rootContext.netmonEnabled ? rootContext.netmonClass : "未啟動")
                        color: "#ffffff"; font.pixelSize: 11; font.bold: true
                    }
                    Text {
                        visible: rootContext && rootContext.netmonPid > 0
                        text: "PID:" + (rootContext ? rootContext.netmonPid : 0) + " · " + (rootContext ? rootContext.netmonProcs : 0) + "進程"
                        color: "#a1a1aa"; font.family: "monospace"; font.pixelSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: modeTxt.implicitWidth + 10; height: 15; radius: 4; color: "#27272a"
                        Text {
                            id: modeTxt; anchors.centerIn: parent
                            text: rootContext ? rootContext.netmonMode : "stopped"
                            color: (rootContext && rootContext.netmonMode === "raw_socket+proc") ? themeContext.geminiCyan : "#71717a"
                            font.family: "monospace"; font.pixelSize: 8
                        }
                    }
                }
                Text {
                    text: "↑ " + Number(rootContext ? rootContext.netmonTxKbps : 0).toFixed(1) + " kbps (" + (rootContext ? rootContext.netmonTxPps : 0) + " pps)    ↓ " +
                          Number(rootContext ? rootContext.netmonRxKbps : 0).toFixed(1) + " kbps (" + (rootContext ? rootContext.netmonRxPps : 0) + " pps)"
                    color: themeContext ? themeContext.geminiCyan : "#38bdf8"
                    font.family: "monospace"; font.pixelSize: 9
                }
            }
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle {
                width: 68; height: 22; radius: 11
                color: (rootContext && rootContext.netmonPin) ? themeContext.geminiGold : "#27272a"
                Text {
                    anchors.centerIn: parent
                    text: (rootContext && rootContext.netmonPin) ? "📌 已鎖定" : "📌 鎖定"
                    color: (rootContext && rootContext.netmonPin) ? "#18181b" : "#a1a1aa"
                    font.pixelSize: 9; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (rootContext) rootContext.netmonPin = !rootContext.netmonPin
                }
            }

            Rectangle {
                width: 38; height: 22; radius: 11
                color: (rootContext && rootContext.netmonEnabled) ? themeContext.geminiCyan : "#3f3f46"
                Rectangle {
                    width: 18; height: 18; radius: 9; color: "#ffffff"; y: 2
                    x: (rootContext && rootContext.netmonEnabled) ? 18 : 2
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (rootContext) rootContext.netmonEnabled = !rootContext.netmonEnabled
                }
            }
        }
    }

    // 1~10 級別滑塊
    Rectangle {
        width: parent.width - 28; height: 48; radius: 10
        color: "#18181b"; border.color: "#27272a"; border.width: 1
        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 6
            Item {
                width: parent.width; height: 14
                Text {
                    anchors.left: parent.left
                    text: "異樣過濾級別：" + tab0.levelName(rootContext ? rootContext.netmonLevel : 2)
                    color: tab0.levelColor(rootContext ? rootContext.netmonLevel : 2)
                    font.pixelSize: 9; font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    text: (rootContext ? rootContext.netmonLevel : 2) + " / 10"
                    color: "#e4e4e7"; font.family: "monospace"; font.pixelSize: 9; font.bold: true
                }
            }

            Item {
                id: sliderTrack
                width: parent.width; height: 14
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2; color: "#27272a"
                    Rectangle {
                        height: parent.height; radius: 2
                        width: parent.width * (((rootContext ? rootContext.netmonLevel : 2) - 1) / 9.0)
                        color: tab0.levelColor(rootContext ? rootContext.netmonLevel : 2)
                    }
                }
                Rectangle {
                    width: 14; height: 14; radius: 7; color: "#ffffff"
                    border.width: 2; border.color: tab0.levelColor(rootContext ? rootContext.netmonLevel : 2)
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, parent.width * (((rootContext ? rootContext.netmonLevel : 2) - 1) / 9.0) - width / 2))
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    function applyPos(mx) {
                        if (!rootContext) return;
                        var ratio = Math.max(0, Math.min(1, mx / sliderTrack.width));
                        rootContext.netmonLevel = Math.round(1 + ratio * 9);
                    }
                    onPressed: function(m) { applyPos(m.x) }
                    onPositionChanged: function(m) { if (pressed) applyPos(m.x) }
                }
            }
        }
    }

    // 🚨 異樣包流水日誌 (保留最新 20 條)
    Rectangle {
        width: parent.width - 28; height: 112 + Math.round(tab0.extraH * 0.44); radius: 10
        color: "#1a1114"
        border.color: (rootContext && rootContext.netmonAnomalyLog && rootContext.netmonAnomalyLog.length > 0) ? themeContext.geminiRose : "#3f242c"
        border.width: 1; clip: true

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 4
            Item {
                width: parent.width; height: 14
                Text {
                    anchors.left: parent.left
                    text: "🚨 異樣包流水日誌 (保留最新 20 條 · 含外來主動/混合異常格式)"
                    color: themeContext ? themeContext.geminiRose : "#f43f5e"
                    font.pixelSize: 9; font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    text: (rootContext && rootContext.netmonAnomalyLog ? rootContext.netmonAnomalyLog.length : 0) + " / 20"
                    color: "#fda4af"; font.family: "monospace"; font.pixelSize: 8
                }
            }

            ListView {
                width: parent.width; height: parent.height - 18; clip: true; spacing: 2
                model: rootContext ? rootContext.netmonAnomalyLog : []
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width; height: 16; radius: 3
                    color: modelData.unsolicited ? "#3f0d1d" : "transparent"
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 6
                        Text { text: modelData.time || ""; color: "#71717a"; font.family: "monospace"; font.pixelSize: 8; width: 48; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "L" + (modelData.level || 1); color: tab0.levelColor(modelData.level || 1); font.family: "monospace"; font.pixelSize: 8; font.bold: true; width: 20; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: modelData.unsolicited ? "📥外來" : (modelData.dir === "RX" ? "⬇RX" : "⬆TX")
                            color: modelData.unsolicited ? "#f43f5e" : (modelData.dir === "TX" ? "#f59e0b" : "#38bdf8")
                            font.family: "monospace"; font.pixelSize: 8; font.bold: true; width: 38; anchors.verticalCenter: parent.verticalCenter
                        }
                        Text { text: modelData.host || modelData.remote || ""; color: "#e4e4e7"; font.family: "monospace"; font.pixelSize: 8; width: 120; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "[" + (modelData.reason || "") + "] " + (modelData.preview || ""); color: "#fda4af"; font.family: "monospace"; font.pixelSize: 8; width: 180; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }

    // 活躍外連
    Rectangle {
        width: parent.width - 28; height: 78 + Math.round(tab0.extraH * 0.24); radius: 10
        color: "#18181b"; border.color: "#27272a"; border.width: 1; clip: true
        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 4
            Text {
                text: "活躍外連 (" + (rootContext && rootContext.netmonEndpoints ? rootContext.netmonEndpoints.length : 0) + ")"
                color: "#a1a1aa"; font.pixelSize: 9; font.bold: true
            }
            ListView {
                width: parent.width; height: parent.height - 18; clip: true; spacing: 2
                model: rootContext ? rootContext.netmonEndpoints : []
                delegate: Row {
                    required property var modelData
                    width: ListView.view.width; height: 14; spacing: 6
                    Text { text: "L" + (modelData.level || 1); color: tab0.levelColor(modelData.level || 1); font.family: "monospace"; font.pixelSize: 8; font.bold: true; width: 20 }
                    Text { text: modelData.proto || ""; color: "#71717a"; font.family: "monospace"; font.pixelSize: 8; width: 24 }
                    Text { text: modelData.host ? (modelData.host + " (" + modelData.remote + ")") : (modelData.remote || ""); color: "#e4e4e7"; font.family: "monospace"; font.pixelSize: 8; width: 220; elide: Text.ElideRight }
                    Text { text: "↑" + (modelData.tx_kb || 0) + "K ↓" + (modelData.rx_kb || 0) + "K"; color: themeContext.geminiCyan; font.family: "monospace"; font.pixelSize: 8 }
                }
            }
        }
    }

    // 實時包流水
    Rectangle {
        width: parent.width - 28; height: 84 + Math.round(tab0.extraH * 0.32); radius: 10
        color: "#18181b"; border.color: "#27272a"; border.width: 1; clip: true
        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 4
            Text {
                text: "實時包流水 (≥ Lv" + (rootContext ? rootContext.netmonLevel : 2) + ")"
                color: "#a1a1aa"; font.pixelSize: 9; font.bold: true
            }
            ListView {
                width: parent.width; height: parent.height - 18; clip: true; spacing: 2
                model: rootContext ? rootContext.netmonPackets : []
                delegate: Row {
                    required property var modelData
                    visible: (modelData.level || 1) >= (rootContext ? rootContext.netmonLevel : 2)
                    width: ListView.view.width; height: visible ? 14 : 0; spacing: 6
                    Text { text: "L" + (modelData.level || 1); color: tab0.levelColor(modelData.level || 1); font.family: "monospace"; font.pixelSize: 8; font.bold: true; width: 20 }
                    Text { text: modelData.unsolicited ? "📥外來" : ((modelData.dir || "") + " " + (modelData.proto || "")); color: modelData.unsolicited ? "#f43f5e" : themeContext.geminiBlue; font.family: "monospace"; font.pixelSize: 8; width: 44 }
                    Text { text: modelData.host || modelData.remote || ""; color: "#d4d4d8"; font.family: "monospace"; font.pixelSize: 8; width: 130; elide: Text.ElideRight }
                    Text { text: (modelData.len || 0) + "B"; color: "#71717a"; font.family: "monospace"; font.pixelSize: 8; width: 34 }
                    Text { text: modelData.preview || ""; color: "#a1a1aa"; font.family: "monospace"; font.pixelSize: 8; width: 160; elide: Text.ElideRight }
                }
            }
        }
    }
}
