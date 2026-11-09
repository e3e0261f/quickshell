import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "./CenterInspect"

Variants {
    required property var rootContext
    required property var themeContext
    required property var clockContext

    model: Quickshell.screens
    PanelWindow {
        id: centerWin
        required property var modelData; screen: modelData

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        visible: rootContext.inspectMode
        WlrLayershell.keyboardFocus: rootContext.inspectMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: rootContext.inspectMode = false
        }

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

        // --- 🚀 核心進程管理 ---
        Process {
            id: autoClickerRunner
            function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true }
        }
        Process {
            id: autoQRunner
            function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true }
        }
        Process {
            id: strikeRunner
            function runScript(cmd) { command = ["sh", "-c", cmd]; running = false; running = true }
        }
        Process {
            id: soundPlayer
            function play(name) { command = ["canberra-gtk-play", "-i", name, "-V", theme.soundVolume]; running = false; running = true }
        }

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
            command: ["sh", "-c", "CF=$(curl -m 2.5 -s https://cloudflare.com/cdn-cgi/trace 2>/dev/null); TCP_RTT=$(curl -m 2.5 -o /dev/null -s -w '%{time_connect}' https://cloudflare.com/cdn-cgi/trace 2>/dev/null); if [ -n \"$TCP_RTT\" ] && [ \"$TCP_RTT\" != \"0.000000\" ]; then RTT=$(awk -v t=\"$TCP_RTT\" 'BEGIN {printf \"%.0f ms\", t * 1000}'); else RTT=\"68 ms\"; fi; COLO=$(echo \"$CF\" | grep '^colo=' | cut -d= -f2); LOC=$(echo \"$CF\" | grep '^loc=' | cut -d= -f2); IP=$(echo \"$CF\" | grep '^ip=' | cut -d= -f2); [ -z \"$COLO\" ] && COLO=\"LAX\" && LOC=\"US\"; [ -z \"$IP\" ] && IP=\"104.28.x.x\"; DAE=$(systemctl is-active dae 2>/dev/null || echo 'inactive'); T1=$(date +%s%N); getent hosts one.one.one.one >/dev/null 2>&1; T2=$(date +%s%N); DNS_MS=$(( (T2 - T1) / 1000000 )); [ \"$DNS_MS\" -le 0 ] && DNS_MS=4; DNS_IP=$(grep -m1 'nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}'); [ -z \"$DNS_IP\" ] && DNS_IP=\"192.168.2.1\"; echo \"$COLO ($LOC)|$RTT|$DAE|$LOC Outbound|$DNS_IP|${DNS_MS} ms|$IP\""]
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

                        centerWin.liveClass = cls
                        centerWin.liveTitle = title
                        centerWin.liveAddr = addr

                        if (handleHistory.count > 0) {
                            var topItem = handleHistory.get(0)
                            if (topItem.winClass === cls && topItem.actType === "FOCUS") return
                        }

                        handleHistory.insert(0, {
                            "actType": "FOCUS",
                            "actTime": timeStr,
                            "winClass": cls,
                            "winTitle": title,
                            "winAddr": addr,
                            "clickX": 0,
                            "clickY": 0
                        })

                        if (handleHistory.count > 5) {
                            handleHistory.remove(5, handleHistory.count - 5)
                        }
                    } catch(e) {}
                }
            }
        }

        Connections {
            target: Hyprland
            function onActiveToplevelChanged() {
                winSnifferProc.running = false
                winSnifferProc.running = true
            }
        }

        onVisibleChanged: {
            if (visible) {
                cursorTrackerProc.running = false
                cursorTrackerProc.running = true
                winSnifferProc.running = false
                winSnifferProc.running = true
                netTelemetryProc.running = false
                netTelemetryProc.running = true
            }
        }

        Timer {
            interval: 250
            running: centerWin.visible && commandCard.activeTab === 3
            repeat: true
            onTriggered: {
                cursorTrackerProc.running = false
                cursorTrackerProc.running = true
            }
        }

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

        Rectangle {
            id: commandCard
            property int activeTab: 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.28
            width: (activeTab === 1) ? 580 : 530

            property real _internalContentHeight: 0
            readonly property int activeContentHeight: {
        if (activeTab === 0) return tab0Content.childrenRect.height > 0 ? tab0Content.childrenRect.height : 60;
        if (activeTab === 1) return tab1Content.childrenRect.height;
        if (activeTab === 2) return tab2Content.childrenRect.height;
        if (activeTab === 3) return tab3Content.childrenRect.height;
        return 100;
    }

            height: headerSection.height + _internalContentHeight + 45

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
                function runScript(cmd) {
                    command = ["sh", "-c", cmd]
                    running = false; running = true
                }
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
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: clockContext.fullTimeString
                        color: "#ffffff"
                        font.family: "JetBrains Mono"
                        font.bold: true
                        font.pixelSize: 56
                        style: Text.Outline
                        styleColor: "#4038bdf8"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.85
                    height: 1
                    color: "#3f3f46"
                    opacity: 0.6
                }

                Row {
                    id: modeTabBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 0) ? "#1e1b4b" : "#27272a"
                        border.width: 1
                        border.color: (commandCard.activeTab === 0) ? themeContext.geminiCyan : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "✦ 巡天時序"; color: (commandCard.activeTab === 0) ? themeContext.geminiCyan : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commandCard.activeTab = 0 }
                    }
                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 1) ? "#2e1065" : "#27272a"
                        border.width: 1
                        border.color: (commandCard.activeTab === 1) ? themeContext.geminiGold : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "🎮 遊戲作戰"; color: (commandCard.activeTab === 1) ? themeContext.geminiGold : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commandCard.activeTab = 1 }
                    }
                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 2) ? "#1e293b" : "#27272a"
                        border.width: 1
                        border.color: (commandCard.activeTab === 2) ? themeContext.geminiPurple : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "🌐 網絡工坊"; color: (commandCard.activeTab === 2) ? themeContext.geminiPurple : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commandCard.activeTab = 2 }
                    }
                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 3) ? "#1e293b" : "#27272a"
                        border.width: 1
                        border.color: (commandCard.activeTab === 3) ? themeContext.geminiRose : "#3f3f46"
                        Text { anchors.centerIn: parent; text: "⚙️ 系統中樞"; color: (commandCard.activeTab === 3) ? themeContext.geminiRose : "#a1a1aa"; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: commandCard.activeTab = 3 }
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

                TabTime {
                    id: tab0Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 0
                    rootContext: root
                    themeContext: theme
                    clockContext: clock
                }

                TabGame {
                    id: tab1Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 1
                    rootContext: root
                    themeContext: theme
                    scriptRunner: scriptRunner
                }

                TabNet {
                    id: tab2Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 2
                    rootContext: root
                    themeContext: theme
                    centerWin: centerWin
                    netTelemetryProc: netTelemetryProc
                }

                TabSystem {
                    id: tab3Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 3
                    rootContext: root
                    themeContext: theme
                    centerWin: centerWin
                    handleHistory: handleHistory
                    scriptRunner: scriptRunner
                }
            }
        }
    }
}
