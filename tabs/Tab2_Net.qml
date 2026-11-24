import QtQuick

Column {
    id: tab2
    property var rootContext
    property var themeContext
    property var clockContext
    property var centerWin
    property var scriptRunner
    property var handleHistory
    property var netTelemetryProc
    property var volControl
    property var soundContext

    width: parent ? parent.width : 530
    spacing: 10
    padding: 16

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "NETWORK TOPOLOGY & PROXY TELEMETRY"
        color: themeContext ? themeContext.geminiPurple : "#c084fc"
        font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
    }

    // 卡片 1: Cloudflare WTR
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(498, parent.width - 32)
        height: (centerWin && centerWin.cfExpanded) ? 88 : 54
        radius: 8; color: "#18181b"; border.color: "#3b82f6"; border.width: 1
        Behavior on height { NumberAnimation { duration: 150 } }
        clip: true

        Column {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Item {
                width: parent.width; height: 34
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Text { text: "☁️"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Text { text: "US CDN 邊緣路由 (WTR)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "Cloudflare POP: " + (centerWin ? centerWin.netCdnNode : "LAX (US)"); color: "#94a3b8"; font.pixelSize: 9 }
                    }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 68; height: 22; radius: 11; color: "#1e3a5f"; border.color: "#38bdf8"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: (netTelemetryProc && netTelemetryProc.running) ? "..." : (centerWin ? centerWin.netCdnRtt : "68 ms")
                        color: "#38bdf8"; font.family: "monospace"; font.pixelSize: 10; font.bold: true
                    }
                }
            }

            Row {
                visible: centerWin && centerWin.cfExpanded
                spacing: 14
                Text { text: "• 出海公網 IP: " + (centerWin ? centerWin.netCdnIp : "104.28.x.x"); color: "#93c5fd"; font.family: "monospace"; font.pixelSize: 9 }
                Text { text: "• 協議: HTTP/2 TLS 1.3 Anycast"; color: "#94a3b8"; font.pixelSize: 9 }
            }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: if (centerWin) centerWin.cfExpanded = !centerWin.cfExpanded
        }
    }

    // 卡片 2: dae eBPF 智能路由隧道
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(498, parent.width - 32)
        height: (centerWin && centerWin.daeExpanded) ? 88 : 54
        radius: 8; color: "#18181b"
        border.color: (centerWin && centerWin.netDaeState === "active") ? "#10b981" : "#ef4444"; border.width: 1
        Behavior on height { NumberAnimation { duration: 150 } }
        clip: true

        Column {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Item {
                width: parent.width; height: 34
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Text { text: "⚡"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Text { text: "dae eBPF 智能路由隧道"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "Hop: " + (centerWin ? centerWin.netDaeRoute : "US Outbound"); color: "#94a3b8"; font.pixelSize: 9 }
                    }
                }
                Rectangle {
                    readonly property bool isAct: centerWin && centerWin.netDaeState === "active"
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 68; height: 22; radius: 11
                    color: isAct ? "#064e3b" : "#450a0a"
                    border.color: isAct ? "#10b981" : "#ef4444"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: centerWin ? centerWin.netDaeState.toUpperCase() : "ACTIVE"
                        color: isAct ? "#34d399" : "#f87171"; font.pixelSize: 9; font.bold: true
                    }
                }
            }

            Row {
                visible: centerWin && centerWin.daeExpanded
                spacing: 14
                Text { text: "• 內核分流: TProxy / Redirect 雙棧"; color: "#6ee7b7"; font.pixelSize: 9 }
                Text { text: "• 分流規則: routing.dae 實時生效"; color: "#94a3b8"; font.pixelSize: 9 }
            }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: if (centerWin) centerWin.daeExpanded = !centerWin.daeExpanded
        }
    }

    // 卡片 3: DNS 本地分流管道
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(498, parent.width - 32)
        height: (centerWin && centerWin.dnsExpanded) ? 88 : 54
        radius: 8; color: "#18181b"; border.color: "#f59e0b"; border.width: 1
        Behavior on height { NumberAnimation { duration: 150 } }
        clip: true

        Column {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Item {
                width: parent.width; height: 34
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Text { text: "🔒"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Text { text: "DNS 本地分流管道"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "Resolver: " + (centerWin ? centerWin.netDnsServer : "127.0.0.1"); color: "#94a3b8"; font.pixelSize: 9 }
                    }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 68; height: 22; radius: 11; color: "#451a03"; border.color: "#f59e0b"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: (netTelemetryProc && netTelemetryProc.running) ? "..." : (centerWin ? centerWin.netDnsTime : "4 ms")
                        color: "#fbbf24"; font.family: "monospace"; font.pixelSize: 10; font.bold: true
                    }
                }
            }

            Row {
                visible: centerWin && centerWin.dnsExpanded
                spacing: 14
                Text { text: "• 管道: Local Gateway -> dae Split-DNS"; color: "#fcd34d"; font.pixelSize: 9 }
                Text { text: "• 緩存機制: nscd / systemd-resolved"; color: "#94a3b8"; font.pixelSize: 9 }
            }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: if (centerWin) centerWin.dnsExpanded = !centerWin.dnsExpanded
        }
    }

    // 重新探測按鈕
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 130; height: 26; radius: 13
        color: "#27272a"; border.color: "#3f3f46"; border.width: 1
        Text { anchors.centerIn: parent; text: "🔄 重新探測鏈路"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: if (netTelemetryProc) netTelemetryProc.running = true
        }
    }
}
