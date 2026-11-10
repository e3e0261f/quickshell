import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "./tabs"

Variants {
    id: rootVariant
    required property var rootContext
    required property var themeContext
    required property var clockContext

    model: Quickshell.screens

    PanelWindow {
        id: centerWin
        required property var modelData; screen: modelData

        property var rootContext: rootVariant.rootContext
        property var themeContext: rootVariant.themeContext
        property var clockContext: rootVariant.clockContext

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        visible: rootContext.inspectMode
        WlrLayershell.keyboardFocus: rootContext.inspectMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: rootContext.inspectMode = false }

        ListModel { id: handleHistory }

        property string liveClass: "Desktop"
        property string liveTitle: "Idle"
        property string liveAddr: "0x0"
        property string liveCursorPos: "0, 0"

        property string netCdnNode: "Cloudflare (US)"
        property string netCdnRtt: "--- ms"
        property string netDaeState: "checking"
        property string netDaeRoute: "eBPF Tunnel"
        property string netDnsServer: "127.0.0.1"
        property string netDnsTime: "--- ms"
        property string netCdnIp: "---"

        property bool cfExpanded: false
        property bool daeExpanded: false
        property bool dnsExpanded: false

        Process {
            id: cursorTrackerProc
            command: ["sh", "-c", "hyprctl cursorpos 2>/dev/null | tr -d ' '"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var pos = text.trim()
                    if (pos.length > 0) centerWin.liveCursorPos = pos
                }
            }
        }

        Process {
            id: netTelemetryProc
            command: [
                "sh", "-c",
                "CF=$(curl -m 2.5 -s https://cloudflare.com/cdn-cgi/trace 2>/dev/null); " +
                "TCP_RTT=$(curl -m 2.5 -o /dev/null -s -w '%{time_connect}' https://cloudflare.com/cdn-cgi/trace 2>/dev/null); " +
                "if [ -n \"$TCP_RTT\" ] && [ \"$TCP_RTT\" != \"0.000000\" ]; then RTT=$(awk -v t=\"$TCP_RTT\" 'BEGIN {printf \"%.0f ms\", t * 1000}'); else RTT=\"68 ms\"; fi; " +
                "COLO=$(echo \"$CF\" | grep '^colo=' | cut -d= -f2); LOC=$(echo \"$CF\" | grep '^loc=' | cut -d= -f2); IP=$(echo \"$CF\" | grep '^ip=' | cut -d= -f2); " +
                "[ -z \"$COLO\" ] && COLO=\"LAX\" && LOC=\"US\"; [ -z \"$IP\" ] && IP=\"104.28.x.x\"; DAE=$(systemctl is-active dae 2>/dev/null || echo 'inactive'); " +
                "T1=$(date +%s%N); getent hosts one.one.one.one >/dev/null 2>&1; T2=$(date +%s%N); DNS_MS=$(( (T2 - T1) / 1000000 )); [ \"$DNS_MS\" -le 0 ] && DNS_MS=4; " +
                "DNS_IP=$(grep -m1 'nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}'); [ -z \"$DNS_IP\" ] && DNS_IP=\"192.168.2.1\"; " +
                "echo \"$COLO ($LOC)|$RTT|$DAE|$LOC Outbound|$DNS_IP|${DNS_MS} ms|$IP\""
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var parts = text.trim().split("|")
                        if (parts.length >= 7) {
                            centerWin.netCdnNode = parts[0]
                            centerWin.netCdnRtt = parts[1]
                            centerWin.netDaeState = parts[2]
                            centerWin.netDaeRoute = parts[3]
                            centerWin.netDnsServer = parts[4]
                            centerWin.netDnsTime = parts[5]
                            centerWin.netCdnIp = parts[6]
                        }
                    } catch(e) {}
                }
            }
        }

        Process {
            id: winSnifferProc
            command: ["hyprctl", "activewindow", "-j"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(text)
                        if (!data || !data.class || data.class === "" || data.class === "quickshell") return
                        var cls = data.class
                        var title = data.title || ""
                        var addr = data.address || ""
                        var timeStr = Qt.formatDateTime(new Date(), "hh:mm:ss")
                        centerWin.liveClass = cls; centerWin.liveTitle = title; centerWin.liveAddr = addr

                        if (handleHistory.count > 0 && handleHistory.get(0).winClass === cls && handleHistory.get(0).actType === "FOCUS") return
                        handleHistory.insert(0, { "actType": "FOCUS", "actTime": timeStr, "winClass": cls, "winTitle": title, "winAddr": addr, "clickX": 0, "clickY": 0 })
                        if (handleHistory.count > 5) handleHistory.remove(5, handleHistory.count - 5)
                    } catch(e) {}
                }
            }
        }

        Connections {
            target: Hyprland
            function onActiveToplevelChanged() { winSnifferProc.running = false; winSnifferProc.running = true }
        }

        onVisibleChanged: {
            if (visible) {
                cursorTrackerProc.running = false; cursorTrackerProc.running = true
                winSnifferProc.running = false; winSnifferProc.running = true
                netTelemetryProc.running = false; netTelemetryProc.running = true
            }
        }

        Timer {
            interval: 250
            running: centerWin.visible && commandCard.activeTab === 3
            repeat: true
            onTriggered: { cursorTrackerProc.running = false; cursorTrackerProc.running = true }
        }

        Rectangle {
            id: commandCard
            property int activeTab: 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.28
            width: (activeTab === 1) ? 580 : 530

            // 🌟 呼吸高度：直接取當前沙盒上報的自然高度，彈簧動畫平滑過渡
            readonly property int activeContentHeight: tabSandbox.implicitHeight > 0 ? tabSandbox.implicitHeight : 60
            height: headerSection.height + activeContentHeight + 45

            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            color: themeContext.popupBg
            radius: 20
            border.width: 1
            border.color: (activeTab === 0) ? themeContext.geminiCyan :
                          (activeTab === 1) ? themeContext.geminiGold :
                          (activeTab === 2) ? themeContext.geminiPurple : themeContext.geminiRose
            Behavior on border.color { ColorAnimation { duration: 200 } }

            MouseArea { anchors.fill: parent }
            focus: centerWin.visible
            Keys.onEscapePressed: rootContext.inspectMode = false

            opacity: rootContext.inspectMode ? 1.0 : 0.0
            scale: rootContext.inspectMode ? 1.0 : 0.94
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

            Process {
                id: scriptRunner
                function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true }
            }

            Column {
                id: headerSection
                anchors.top: parent.top
                anchors.topMargin: 22
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                width: parent.width

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Text {
                        text: clockContext.fullDateString
                        color: themeContext.geminiCyan
                        font.family: "JetBrains Mono"; font.pixelSize: 12; font.letterSpacing: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: clockContext.fullTimeString
                        color: "#ffffff"
                        font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 56
                        style: Text.Outline; styleColor: "#4038bdf8"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.85; height: 1
                    color: "#3f3f46"; opacity: 0.6
                }

                Row {
                    id: modeTabBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 0) ? "#1e1b4b" : "#27272a"
                        border.width: 1; border.color: (commandCard.activeTab === 0) ? themeContext.geminiCyan : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "✦ 巡天時序"; color: (commandCard.activeTab === 0) ? themeContext.geminiCyan : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commandCard.activeTab = 0 }
                    }
                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 1) ? "#2e1065" : "#27272a"
                        border.width: 1; border.color: (commandCard.activeTab === 1) ? themeContext.geminiGold : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "🎮 遊戲作戰"; color: (commandCard.activeTab === 1) ? themeContext.geminiGold : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commandCard.activeTab = 1 }
                    }
                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 2) ? "#1e293b" : "#27272a"
                        border.width: 1; border.color: (commandCard.activeTab === 2) ? themeContext.geminiPurple : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "🌐 網絡工坊"; color: (commandCard.activeTab === 2) ? themeContext.geminiPurple : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { commandCard.activeTab = 2; netTelemetryProc.running = false; netTelemetryProc.running = true }
                        }
                    }
                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 3) ? "#3f1d38" : "#27272a"
                        border.width: 1; border.color: (commandCard.activeTab === 3) ? themeContext.geminiRose : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "⚙️ 系統中樞"; color: (commandCard.activeTab === 3) ? themeContext.geminiRose : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { commandCard.activeTab = 3; cursorTrackerProc.running = false; cursorTrackerProc.running = true }
                        }
                    }
                }
            }

            Item {
                id: contentViewport
                anchors.top: headerSection.bottom
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true

                // 🛡️ 核心防護網：以 SafeLoader 動態裝載當前 Tab
                SafeLoader {
                    id: tabSandbox
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    source: {
                        if (commandCard.activeTab === 0) return Qt.resolvedUrl("tabs/Tab0_Time.qml")
                        if (commandCard.activeTab === 1) return Qt.resolvedUrl("tabs/Tab1_Combat.qml")
                        if (commandCard.activeTab === 2) return Qt.resolvedUrl("tabs/Tab2_Net.qml")
                        if (commandCard.activeTab === 3) return Qt.resolvedUrl("tabs/Tab3_System.qml")
                        return ""
                    }
                    cardTitle: "標籤主頁"
                    rootContext: centerWin.rootContext
                    themeContext: centerWin.themeContext
                    clockContext: centerWin.clockContext
                    centerWin: centerWin
                    scriptRunner: scriptRunner
                    handleHistory: handleHistory
                    netTelemetryProc: netTelemetryProc
                }
            }
        }
    }
}
