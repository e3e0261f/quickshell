import QtQuick

Column {
    id: tab0Root
    property var rootContext
    property var themeContext
    property var centerWin

    readonly property color colCyan: (themeContext && themeContext.geminiCyan !== undefined) ? themeContext.geminiCyan : "#22d3ee"
    readonly property color colGold: (themeContext && themeContext.geminiGold !== undefined) ? themeContext.geminiGold : "#eab308"
    readonly property color colBlue: (themeContext && themeContext.geminiBlue !== undefined) ? themeContext.geminiBlue : "#38bdf8"
    readonly property color colRose: (themeContext && themeContext.geminiRose !== undefined) ? themeContext.geminiRose : "#fb7185"
    readonly property color colHotPink: "#ff2e63"
    readonly property color colAmber: "#ff9f1c"

    readonly property bool monitorEnabled: rootContext ? rootContext.netmonEnabled : false
    readonly property bool pinTarget: rootContext ? rootContext.netmonPin : false
    readonly property int filterLevel: rootContext ? rootContext.netmonLevel : 2
    readonly property string captureMode: rootContext ? rootContext.netmonMode : "stopped"
    readonly property string targetClass: rootContext ? rootContext.netmonClass : "未啟動"
    readonly property int targetPid: rootContext ? rootContext.netmonPid : 0
    readonly property int procCount: rootContext ? rootContext.netmonProcs : 0
    readonly property real txKbps: rootContext ? rootContext.netmonTxKbps : 0
    readonly property real rxKbps: rootContext ? rootContext.netmonRxKbps : 0
    readonly property int txPps: rootContext ? rootContext.netmonTxPps : 0
    readonly property int rxPps: rootContext ? rootContext.netmonRxPps : 0
    readonly property var endpointsModel: rootContext ? rootContext.netmonEndpoints : []
    readonly property var packetsModel: rootContext ? rootContext.netmonPackets : []
    readonly property var anomalyLogModel: rootContext ? rootContext.netmonAnomalyLog : []

    readonly property bool isExpanded: centerWin ? centerWin.cardLarge : false
    readonly property int panelWidth: Math.max(500, width - 28)
    readonly property int extraH: (centerWin && centerWin.expandedContentHeight > 0)
                                  ? Math.max(0, centerWin.expandedContentHeight - 392)
                                  : 0

    width: parent ? parent.width : 560
    spacing: 8

    readonly property var levelNames: [
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
    ]

    function levelColor(lv) {
        if (lv >= 9) return tab0Root.colHotPink
        if (lv >= 8) return tab0Root.colAmber
        if (lv >= 6) return tab0Root.colGold
        if (lv >= 4) return tab0Root.colBlue
        return "#71717a"
    }

    // 頂部狀態與控制欄
    Rectangle {
        width: tab0Root.panelWidth
        height: 48
        radius: 10
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#18181b"
        border.width: 1
        border.color: tab0Root.monitorEnabled ? tab0Root.colCyan : "#27272a"

        Item {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Row {
                    spacing: 6
                    Text {
                        text: "● " + tab0Root.targetClass
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        text: tab0Root.targetPid > 0 ? ("PID:" + tab0Root.targetPid + " · " + tab0Root.procCount + "進程") : ""
                        color: "#a1a1aa"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: modeTxt.implicitWidth + 10
                        height: 15
                        radius: 4
                        color: "#27272a"
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: modeTxt
                            anchors.centerIn: parent
                            text: tab0Root.captureMode
                            color: tab0Root.captureMode === "raw_socket+proc" ? tab0Root.colCyan : "#71717a"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                        }
                    }
                }

                Text {
                    text: "↑ " + tab0Root.txKbps.toFixed(1) + " kbps (" + tab0Root.txPps + " pps)   ↓ " + tab0Root.rxKbps.toFixed(1) + " kbps (" + tab0Root.rxPps + " pps)"
                    color: tab0Root.colCyan
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 60
                    height: 22
                    radius: 11
                    color: tab0Root.pinTarget ? tab0Root.colGold : "#27272a"
                    Text {
                        anchors.centerIn: parent
                        text: tab0Root.pinTarget ? "📌 已鎖定" : "📌 鎖定"
                        color: tab0Root.pinTarget ? "#18181b" : "#a1a1aa"
                        font.pixelSize: 9
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rootContext) rootContext.netmonPin = !rootContext.netmonPin
                        }
                    }
                }

                Rectangle {
                    width: 38
                    height: 22
                    radius: 11
                    color: tab0Root.monitorEnabled ? tab0Root.colCyan : "#3f3f46"
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: tab0Root.monitorEnabled ? (parent.width - width - 2) : 2
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rootContext) rootContext.netmonEnabled = !rootContext.netmonEnabled
                        }
                    }
                }
            }
        }
    }

    // 1~10 級過濾滑塊
    Rectangle {
        width: tab0Root.panelWidth
        height: 44
        radius: 10
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#18181b"
        border.width: 1
        border.color: "#27272a"

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5

            Item {
                width: parent.width
                height: 14
                Text {
                    anchors.left: parent.left
                    text: "異樣過濾級別：" + tab0Root.levelNames[tab0Root.filterLevel]
                    color: tab0Root.levelColor(tab0Root.filterLevel)
                    font.pixelSize: 9
                    font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    text: tab0Root.filterLevel + " / 10"
                    color: "#e4e4e7"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            Item {
                id: sliderTrackWrap
                width: parent.width
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: "#27272a"

                    Rectangle {
                        width: ((tab0Root.filterLevel - 1) / 9.0) * parent.width
                        height: parent.height
                        radius: 2
                        color: tab0Root.levelColor(tab0Root.filterLevel)
                    }
                }

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: "#ffffff"
                    border.width: 2
                    border.color: tab0Root.levelColor(tab0Root.filterLevel)
                    anchors.verticalCenter: parent.verticalCenter
                    x: ((tab0Root.filterLevel - 1) / 9.0) * (sliderTrackWrap.width - width)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function updateFromX(mx) {
                        if (!rootContext) return
                        var ratio = Math.max(0, Math.min(1, mx / width))
                        rootContext.netmonLevel = Math.round(ratio * 9) + 1
                    }
                    onPressed: function(mouse) { updateFromX(mouse.x) }
                    onPositionChanged: function(mouse) { if (pressed) updateFromX(mouse.x) }
                }
            }
        }
    }

    // 專用 20 條異樣包流水日誌
    Rectangle {
        width: tab0Root.panelWidth
        height: 112 + Math.round(tab0Root.extraH * 0.44)
        radius: 10
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#1a1114"
        border.width: 1
        border.color: tab0Root.anomalyLogModel.length > 0 ? tab0Root.colHotPink : "#3f242c"

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Item {
                width: parent.width
                height: 14
                Text {
                    anchors.left: parent.left
                    text: "🚨 異樣包流水日誌 (保留最新 20 條 · 含外來主動/混合異常格式)"
                    color: tab0Root.colHotPink
                    font.pixelSize: 9
                    font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    text: tab0Root.anomalyLogModel.length + " / 20"
                    color: "#fda4af"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 8
                }
            }

            ListView {
                width: parent.width
                height: parent.height - 18
                clip: true
                model: tab0Root.anomalyLogModel
                spacing: 2

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 16
                    radius: 3
                    color: modelData.unsolicited ? "#3f0d1d" : "transparent"

                    readonly property int flexW: Math.max(200, width - 224)

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 3
                        spacing: 5

                        Text {
                            text: modelData.time
                            color: "#71717a"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            width: 62
                        }
                        Text {
                            text: "L" + modelData.level
                            color: tab0Root.levelColor(modelData.level)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            font.bold: true
                            width: 22
                        }
                        Text {
                            text: modelData.unsolicited ? "📥外來" : (modelData.dir === "RX" ? "⬇RX" : "⬆TX")
                            color: modelData.unsolicited ? tab0Root.colHotPink : (modelData.dir === "TX" ? tab0Root.colAmber : tab0Root.colCyan)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            font.bold: true
                            width: 38
                        }
                        Text {
                            text: modelData.host ? modelData.host : modelData.remote
                            color: modelData.unsolicited ? "#ffe4e6" : "#e4e4e7"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            width: Math.min(260, Math.floor(flexW * 0.32))
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.len + "B" + (modelData.dt_ms >= 0 ? (" Δ" + modelData.dt_ms + "ms") : "")
                            color: (modelData.dt_ms >= 0 && modelData.dt_ms <= 2) ? tab0Root.colAmber : "#a1a1aa"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            width: 72
                        }
                        Text {
                            text: "[" + modelData.reason + "] " + modelData.preview
                            color: modelData.unsolicited ? "#ff7597" : tab0Root.levelColor(modelData.level)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            width: flexW - Math.min(260, Math.floor(flexW * 0.32))
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // 活躍外連列表
    Rectangle {
        width: tab0Root.panelWidth
        height: 78 + Math.round(tab0Root.extraH * 0.24)
        radius: 10
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#18181b"
        border.width: 1
        border.color: "#27272a"

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: "活躍外連 (" + tab0Root.endpointsModel.length + ")"
                color: "#a1a1aa"
                font.pixelSize: 9
                font.bold: true
            }

            ListView {
                width: parent.width
                height: parent.height - 16
                clip: true
                model: tab0Root.endpointsModel
                spacing: 2

                delegate: Row {
                    width: ListView.view.width
                    spacing: 6
                    readonly property int flexW: Math.max(200, width - 166)

                    Text {
                        text: "L" + modelData.level
                        color: tab0Root.levelColor(modelData.level)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        font.bold: true
                        width: 22
                    }
                    Text {
                        text: modelData.proto
                        color: "#71717a"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        width: 24
                    }
                    Text {
                        text: modelData.host ? (modelData.host + " (" + modelData.remote + ")") : modelData.remote
                        color: "#e4e4e7"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        width: Math.floor(flexW * 0.68)
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "↑" + modelData.tx_kb + "K ↓" + modelData.rx_kb + "K"
                        color: tab0Root.colCyan
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        width: 96
                    }
                    Text {
                        text: (modelData.tags && modelData.tags.length > 0) ? modelData.tags.join(",") : ""
                        color: tab0Root.levelColor(modelData.level)
                        font.pixelSize: 8
                        elide: Text.ElideRight
                        width: flexW - Math.floor(flexW * 0.68)
                    }
                }
            }
        }
    }

    // 實時數據包流水
    Rectangle {
        width: tab0Root.panelWidth
        height: 84 + Math.round(tab0Root.extraH * 0.32)
        radius: 10
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#18181b"
        border.width: 1
        border.color: "#27272a"

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: "實時包流水 (≥ Lv" + tab0Root.filterLevel + " · 共 " + tab0Root.packetsModel.length + " 條)"
                color: "#a1a1aa"
                font.pixelSize: 9
                font.bold: true
            }

            ListView {
                width: parent.width
                height: parent.height - 16
                clip: true
                model: tab0Root.packetsModel
                spacing: 2

                delegate: Row {
                    width: ListView.view.width
                    spacing: 5
                    readonly property int flexW: Math.max(200, width - 124)

                    Text {
                        text: "L" + modelData.level
                        color: tab0Root.levelColor(modelData.level)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        font.bold: true
                        width: 22
                    }
                    Text {
                        text: modelData.unsolicited ? "📥外來" : (modelData.dir + " " + modelData.proto)
                        color: modelData.unsolicited ? tab0Root.colHotPink : (modelData.dir === "TX" ? tab0Root.colGold : tab0Root.colBlue)
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        font.bold: modelData.unsolicited
                        width: 44
                    }
                    Text {
                        text: modelData.host ? modelData.host : modelData.remote
                        color: "#d4d4d8"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        width: Math.min(260, Math.floor(flexW * 0.32))
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.len + "B"
                        color: "#71717a"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        width: 38
                    }
                    Text {
                        text: modelData.reason ? ("[" + modelData.reason + "] " + modelData.preview) : modelData.preview
                        color: modelData.unsolicited ? tab0Root.colHotPink : (modelData.reason ? tab0Root.levelColor(modelData.level) : "#a1a1aa")
                        font.family: "JetBrains Mono"
                        font.pixelSize: 8
                        width: flexW - Math.min(260, Math.floor(flexW * 0.32))
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
