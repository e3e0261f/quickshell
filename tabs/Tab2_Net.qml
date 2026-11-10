import QtQuick

Column {
    id: tab2Root
    property var themeContext
    property var centerWin
    property var netTelemetryProc

    width: parent ? parent.width : 530
    spacing: 10

    Text {
        text: "NETWORK TOPOLOGY & PROXY TELEMETRY"
        color: themeContext ? themeContext.geminiPurple : "#c084fc"
        font.pixelSize: 10
        font.bold: true
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // 卡片 1: Cloudflare WTR
    Rectangle {
        width: parent.width * 0.94
        anchors.horizontalCenter: parent.horizontalCenter
        height: centerWin && centerWin.cfExpanded ? 90 : 48
        radius: 8
        color: "#18181b"
        border.width: 1
        border.color: "#3b82f6"
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Row {
                width: parent.width
                Text {
                    text: "☁️"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: 8; height: 1 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "US CDN 邊緣路由 (WTR)"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        text: "Cloudflare POP: " + (centerWin ? centerWin.netCdnNode : "---")
                        color: "#94a3b8"
                        font.pixelSize: 9
                    }
                }
                Item { width: parent.width - 290; height: 1 }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    height: 22
                    radius: 11
                    color: "#1e3a5f"
                    border.width: 1
                    border.color: "#38bdf8"
                    Text {
                        anchors.centerIn: parent
                        text: centerWin ? centerWin.netCdnRtt : "--- ms"
                        color: "#38bdf8"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Row {
                visible: centerWin ? centerWin.cfExpanded : false
                spacing: 12
                Text {
                    text: "• 出海公網 IP: " + (centerWin ? centerWin.netCdnIp : "---")
                    color: "#93c5fd"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                }
                Text {
                    text: "• 協議: HTTP/2 TLS 1.3 Anycast"
                    color: "#94a3b8"
                    font.pixelSize: 9
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (centerWin) centerWin.cfExpanded = !centerWin.cfExpanded
            }
        }
    }

    // 卡片 2: dae eBPF 內核隧道
    Rectangle {
        width: parent.width * 0.94
        anchors.horizontalCenter: parent.horizontalCenter
        height: centerWin && centerWin.daeExpanded ? 85 : 48
        radius: 8
        color: "#18181b"
        border.width: 1
        border.color: centerWin && (centerWin.netDaeState === "active") ? "#10b981" : "#ef4444"
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Row {
                width: parent.width
                Text {
                    text: "⚡"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: 8; height: 1 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "dae eBPF 智能路由隧道"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        text: "Hop: " + (centerWin ? centerWin.netDaeRoute : "---")
                        color: "#94a3b8"
                        font.pixelSize: 9
                    }
                }
                Item { width: parent.width - 290; height: 1 }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    height: 22
                    radius: 11
                    color: centerWin && (centerWin.netDaeState === "active") ? "#064e3b" : "#450a0a"
                    border.width: 1
                    border.color: centerWin && (centerWin.netDaeState === "active") ? "#10b981" : "#ef4444"
                    Text {
                        anchors.centerIn: parent
                        text: centerWin ? centerWin.netDaeState.toUpperCase() : "CHECK"
                        color: centerWin && (centerWin.netDaeState === "active") ? "#34d399" : "#f87171"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }

            Row {
                visible: centerWin ? centerWin.daeExpanded : false
                spacing: 12
                Text {
                    text: "• 內核分流: TProxy / Redirect 雙棧"
                    color: "#6ee7b7"
                    font.pixelSize: 9
                }
                Text {
                    text: "• 分流規則: routing.dae 實時生效"
                    color: "#94a3b8"
                    font.pixelSize: 9
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (centerWin) centerWin.daeExpanded = !centerWin.daeExpanded
            }
        }
    }

    // 卡片 3: DNS 管道
    Rectangle {
        width: parent.width * 0.94
        anchors.horizontalCenter: parent.horizontalCenter
        height: centerWin && centerWin.dnsExpanded ? 85 : 48
        radius: 8
        color: "#18181b"
        border.width: 1
        border.color: "#f59e0b"
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Row {
                width: parent.width
                Text {
                    text: "🔒"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: 8; height: 1 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "DNS 本地分流管道"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        text: "Resolver: " + (centerWin ? centerWin.netDnsServer : "---")
                        color: "#94a3b8"
                        font.pixelSize: 9
                    }
                }
                Item { width: parent.width - 290; height: 1 }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    height: 22
                    radius: 11
                    color: "#451a03"
                    border.width: 1
                    border.color: "#f59e0b"
                    Text {
                        anchors.centerIn: parent
                        text: centerWin ? centerWin.netDnsTime : "--- ms"
                        color: "#fbbf24"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Row {
                visible: centerWin ? centerWin.dnsExpanded : false
                spacing: 12
                Text {
                    text: "• 管道: Local Gateway -> dae Split-DNS"
                    color: "#fcd34d"
                    font.pixelSize: 9
                }
                Text {
                    text: "• 緩存機制: nscd / systemd-resolved"
                    color: "#94a3b8"
                    font.pixelSize: 9
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (centerWin) centerWin.dnsExpanded = !centerWin.dnsExpanded
            }
        }
    }

    // 卡片 4: 重新探測按鈕
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 120
        height: 26
        radius: 13
        color: "#27272a"
        border.width: 1
        border.color: "#3f3f46"

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: "🔄"
                font.pixelSize: 10
            }
            Text {
                text: "重新探測鏈路"
                color: "#e4e4e7"
                font.pixelSize: 10
                font.bold: true
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (centerWin) {
                    centerWin.netCdnRtt = "..."
                    centerWin.netDnsTime = "..."
                }
                if (netTelemetryProc) {
                    netTelemetryProc.running = false
                    netTelemetryProc.running = true
                }
            }
        }
    }
}
