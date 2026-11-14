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

        // 窗口全屏與自由縮放狀態
        property bool cardLarge: false
        property bool cardFullscreen: false
        property int customCardWidth: 0
        property int customCardHeight: 0
        readonly property int expandedContentHeight: cardFullscreen
            ? Math.max(392, height - 215)
            : (customCardHeight > 0
               ? Math.max(392, customCardHeight - 205)
               : (cardLarge ? Math.max(392, Math.min(720, height - 80) - 205) : 0))

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
            property bool isResizing: false

            anchors.horizontalCenter: parent.horizontalCenter
            y: centerWin.cardFullscreen
               ? 16
               : Math.max(16, Math.min(parent.height * 0.24, (parent.height - height) / 2))

            width: centerWin.cardFullscreen
                   ? (parent.width - 32)
                   : (centerWin.customCardWidth > 0
                      ? Math.max(520, Math.min(parent.width - 24, centerWin.customCardWidth))
                      : (centerWin.cardLarge
                         ? Math.min(1040, parent.width - 80)
                         : ((activeTab === 1) ? 580 : (activeTab === 0 ? 560 : 530))))

            readonly property int activeContentHeight: tabSandbox.implicitHeight > 0 ? tabSandbox.implicitHeight : 60
            readonly property int naturalHeight: headerSection.height + activeContentHeight + 45

            height: centerWin.cardFullscreen
                    ? (parent.height - 32)
                    : (centerWin.customCardHeight > 0
                       ? Math.max(360, Math.min(parent.height - 24, centerWin.customCardHeight))
                       : (centerWin.cardLarge
                          ? Math.min(720, parent.height - 80)
                          : Math.min(parent.height - 32, naturalHeight)))

            Behavior on width  { enabled: !commandCard.isResizing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !commandCard.isResizing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y      { enabled: !commandCard.isResizing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            color: themeContext.popupBg
            radius: centerWin.cardFullscreen ? 14 : 20
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
                anchors.topMargin: centerWin.cardFullscreen ? 12 : 22
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: centerWin.cardFullscreen ? 10 : 16
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
                        font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: centerWin.cardFullscreen ? 40 : 56
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
                anchors.bottomMargin: 14
                clip: true

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

            // 右上角：重置大小 & 全屏/還原按鈕
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 12
                anchors.rightMargin: 14
                spacing: 6
                z: 20

                Rectangle {
                    visible: !centerWin.cardFullscreen && (centerWin.customCardWidth > 0 || centerWin.customCardHeight > 0)
                    width: 46; height: 22; radius: 11
                    color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                    Text { anchors.centerIn: parent; text: "↺ 重置"; color: "#a1a1aa"; font.pixelSize: 9; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            centerWin.customCardWidth = 0
                            centerWin.customCardHeight = 0
                        }
                    }
                }

                Rectangle {
                    width: 54; height: 22; radius: 11
                    color: centerWin.cardLarge ? themeContext.geminiBlue : "#27272a"
                    border.width: 1; border.color: centerWin.cardLarge ? themeContext.geminiBlue : "#3f3f46"
                    Text {
                        anchors.centerIn: parent
                        text: centerWin.cardLarge ? "⤡ 還原" : "⤢ 放大"
                        color: centerWin.cardLarge ? "#18181b" : "#e4e4e7"
                        font.pixelSize: 9; font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            centerWin.cardFullscreen = false
                            centerWin.customCardWidth = 0
                            centerWin.customCardHeight = 0
                            centerWin.cardLarge = !centerWin.cardLarge
                        }
                    }
                }

                Rectangle {
                    width: 54; height: 22; radius: 11
                    color: centerWin.cardFullscreen ? themeContext.geminiCyan : "#27272a"
                    border.width: 1; border.color: centerWin.cardFullscreen ? themeContext.geminiCyan : "#3f3f46"
                    Text {
                        anchors.centerIn: parent
                        text: centerWin.cardFullscreen ? "⤡ 還原" : "⛶ 全屏"
                        color: centerWin.cardFullscreen ? "#18181b" : "#e4e4e7"
                        font.pixelSize: 9; font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { centerWin.cardLarge = false; centerWin.cardFullscreen = !centerWin.cardFullscreen }
                    }
                }
            }

            // 右下角：自由拖拽調整大小手柄（雙擊還原默認）
            Item {
                id: resizeGrip
                width: 24; height: 24
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                z: 20

                Text {
                    anchors.centerIn: parent
                    text: "◢"
                    color: resizeArea.pressed || resizeArea.containsMouse ? themeContext.geminiCyan : "#52525b"
                    font.pixelSize: 11
                }

                MouseArea {
                    id: resizeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeFDiagCursor

                    property real startMouseX: 0
                    property real startMouseY: 0
                    property real startW: 0
                    property real startH: 0

                    onPressed: function(mouse) {
                        var p = mapToItem(centerWin, mouse.x, mouse.y)
                        startMouseX = p.x
                        startMouseY = p.y
                        startW = commandCard.width
                        startH = commandCard.height
                        centerWin.cardLarge = false
                        centerWin.cardFullscreen = false
                        commandCard.isResizing = true
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed) return
                        var p = mapToItem(centerWin, mouse.x, mouse.y)
                        centerWin.customCardWidth = Math.max(520, Math.min(centerWin.width - 24, Math.round(startW + (p.x - startMouseX) * 2)))
                        centerWin.customCardHeight = Math.max(360, Math.min(centerWin.height - 24, Math.round(startH + (p.y - startMouseY))))
                    }
                    onReleased: commandCard.isResizing = false
                    onCanceled: commandCard.isResizing = false
                    onDoubleClicked: {
                        centerWin.cardFullscreen = false
                        centerWin.customCardWidth = 0
                        centerWin.customCardHeight = 0
                    }
                }
            }
        }
    }
}
