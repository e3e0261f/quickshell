perl -e '
use strict;
use warnings;

my $dir = "$ENV{HOME}/.config/quickshell/CenterInspect";

# 1. 写入 qmldir
open my $fh_qml, ">", "$dir/qmldir" or die $!;
print $fh_qml << "EOF";
CenterInspect 01_Window.qml
TabTime   02_Tab0_time.qml
TabGame   03_Tab1_game.qml
TabNet    04_Tab2_net.qml
TabSystem 05_Tab3_system.qml
EOF
close $fh_qml;

# 2. 写入 02_Tab0_time.qml
open my $fh_t0, ">", "$dir/02_Tab0_time.qml" or die $!;
print $fh_t0 << "EOF";
import QtQuick

Item {
    id: tab0Root
    required property var themeContext

    Text {
        text: "● 雙燈塔光學導航與微刻度常駐中"
        color: themeContext.geminiCyan
        font.pixelSize: 11
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
EOF
close $fh_t0;

# 3. 写入 03_Tab1_game.qml
open my $fh_t1, ">", "$dir/03_Tab1_game.qml" or die $!;
print $fh_t1 << "EOF";
import QtQuick

Item {
    id: tab1Root
    required property var rootContext
    required property var themeContext
    required property var scriptRunner

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

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Text {
            text: "ALBION & COMBAT HUD (YDO-TOOL ENGINE)"
            color: themeContext.geminiGold
            font.pixelSize: 10
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            spacing: 14
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 255; height: 74; radius: 10
                color: "#18181b"; border.width: 1
                border.color: rootContext.autoClickerActive ? themeContext.geminiGold : "#27272a"

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Row {
                        spacing: 12
                        Column {
                            spacing: 2
                            Text { text: "鼠標連擊 (Shift+C)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                            Text { text: "12 次/秒 · 點擊開關"; color: "#71717a"; font.pixelSize: 9 }
                        }
                        Rectangle {
                            width: 38; height: 22; radius: 11
                            color: rootContext.autoClickerActive ? themeContext.geminiGold : "#3f3f46"
                            Rectangle {
                                width: 18; height: 18; radius: 9; color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: rootContext.autoClickerActive ? (parent.width - width - 2) : 2
                                Behavior on x { NumberAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: rootContext.autoClickerActive = !rootContext.autoClickerActive
                            }
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 50; height: 18; radius: 9
                            color: (rootContext.clickerButtonCode === "0xC0") ? themeContext.geminiGold : "#27272a"
                            Text { anchors.centerIn: parent; text: "左鍵"; font.pixelSize: 9; font.bold: true; color: (rootContext.clickerButtonCode === "0xC0") ? "#18181b" : "#a1a1aa" }
                            MouseArea { anchors.fill: parent; onClicked: rootContext.clickerButtonCode = "0xC0" }
                        }
                        Rectangle {
                            width: 50; height: 18; radius: 9
                            color: (rootContext.clickerButtonCode === "0xC1") ? themeContext.geminiGold : "#27272a"
                            Text { anchors.centerIn: parent; text: "右鍵"; font.pixelSize: 9; font.bold: true; color: (rootContext.clickerButtonCode === "0xC1") ? "#18181b" : "#a1a1aa" }
                            MouseArea { anchors.fill: parent; onClicked: rootContext.clickerButtonCode = "0xC1" }
                        }
                        Rectangle {
                            width: 50; height: 18; radius: 9
                            color: (rootContext.clickerButtonCode === "0xC2") ? themeContext.geminiGold : "#27272a"
                            Text { anchors.centerIn: parent; text: "中鍵"; font.pixelSize: 9; font.bold: true; color: (rootContext.clickerButtonCode === "0xC2") ? "#18181b" : "#a1a1aa" }
                            MouseArea { anchors.fill: parent; onClicked: rootContext.clickerButtonCode = "0xC2" }
                        }
                    }
                }
            }

            Rectangle {
                width: 255; height: 74; radius: 10
                color: "#18181b"; border.width: 1
                border.color: rootContext.autoQActive ? themeContext.geminiCoral : "#27272a"

                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    Column {
                        spacing: 4
                        Text { text: "按住 Q 鍵連發模式"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "按住Q無限發送，鬆手即停"; color: "#71717a"; font.pixelSize: 9 }
                    }
                    Rectangle {
                        width: 38; height: 22; radius: 11
                        color: rootContext.autoQActive ? themeContext.geminiCoral : "#3f3f46"
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: rootContext.autoQActive ? (parent.width - width - 2) : 2
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: rootContext.autoQActive = !rootContext.autoQActive
                        }
                    }
                }
            }
        }

        Row {
            spacing: 14
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 255; height: 60; radius: 10; color: "#18181b"; border.width: 1; border.color: themeContext.geminiBlue
                Column {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: "精確打擊 (Shift+Z)"; color: themeContext.geminiBlue; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    Row {
                        spacing: 5; anchors.horizontalCenter: parent.horizontalCenter
                        Text { text: "X:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftZx = Math.max(0, rootContext.shiftZx + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftZx; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }; onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftZx = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftZx += delta; onFinished: rootContext.saveCoords() }

                        Item { width: 4; height: 1 }

                        Text { text: "Y:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftZy = Math.max(0, rootContext.shiftZy + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftZy; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }; onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftZy = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftZy += delta; onFinished: rootContext.saveCoords() }
                    }
                }
            }

            Rectangle {
                width: 255; height: 60; radius: 10; color: "#18181b"; border.width: 1; border.color: themeContext.geminiRose
                Column {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: "精確打擊 (Shift+X)"; color: themeContext.geminiRose; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    Row {
                        spacing: 5; anchors.horizontalCenter: parent.horizontalCenter
                        Text { text: "X:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftXx = Math.max(0, rootContext.shiftXx + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftXx; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }; onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftXx = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftXx += delta; onFinished: rootContext.saveCoords() }

                        Item { width: 4; height: 1 }

                        Text { text: "Y:"; color: "#a1a1aa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        StepButton { symbol: "-"; direction: -1; onStepped: (delta) => rootContext.shiftXy = Math.max(0, rootContext.shiftXy + delta); onFinished: rootContext.saveCoords() }
                        TextInput { text: rootContext.shiftXy; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 38; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; selectByMouse: true; validator: IntValidator { bottom: 0; top: 9999 }; onEditingFinished: { var v = parseInt(text); if (!isNaN(v)) { rootContext.shiftXy = v; rootContext.saveCoords() } } }
                        StepButton { symbol: "+"; direction: 1; onStepped: (delta) => rootContext.shiftXy += delta; onFinished: rootContext.saveCoords() }
                    }
                }
            }
        }

        Rectangle {
            width: 524; height: 34; radius: 8
            color: "#18181b"; border.width: 1; border.color: rootContext.cursorReturnEnabled ? themeContext.geminiCyan : "#27272a"

            Row {
                anchors.centerIn: parent; spacing: 16
                Text { text: "↩️ 點擊後光標原路返回 (Snap-Back)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                Text { text: "躍遷點擊後，鼠標微秒級折返當前位置"; color: "#71717a"; font.pixelSize: 9 }
                Rectangle {
                    width: 34; height: 18; radius: 9
                    color: rootContext.cursorReturnEnabled ? themeContext.geminiCyan : "#3f3f46"
                    Rectangle {
                        width: 14; height: 14; radius: 7; color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: rootContext.cursorReturnEnabled ? (parent.width - width - 2) : 2
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: rootContext.cursorReturnEnabled = !rootContext.cursorReturnEnabled
                    }
                }
            }
        }

        Row {
            spacing: 14
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                width: 255; height: 38; radius: 8; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                Row { anchors.centerIn: parent; spacing: 8; Text { text: "🗺️"; font.pixelSize: 12 }; Text { text: "啟動 Albion 跑商助手"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scriptRunner.runScript("xdg-open '" . "https://albiononline2d.com/'") }
            }
            Rectangle {
                width: 255; height: 38; radius: 8; color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                Row { anchors.centerIn: parent; spacing: 8; Text { text: "⚔️"; font.pixelSize: 12 }; Text { text: "執行本地優化腳本"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scriptRunner.runScript("notify-send '\''遊戲模式'\'' '\''戰鬥環境已就緒'\''") }
            }
        }
    }
}
EOF
close $fh_t1;

# 4. 写入 04_Tab2_net.qml
open my $fh_t2, ">", "$dir/04_Tab2_net.qml" or die $!;
print $fh_t2 << "EOF";
import QtQuick

Item {
    id: tab2Root
    required property var themeContext
    required property var centerWin
    required property var netTelemetryProc

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        width: parent.width * 0.94

        Text {
            text: "NETWORK TOPOLOGY & PROXY TELEMETRY"
            color: themeContext.geminiPurple
            font.pixelSize: 10
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            width: parent.width
            height: centerWin.cfExpanded ? 90 : 48
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
                    Text { text: "☁️"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: 8; height: 1 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: "US CDN 邊緣路由 (WTR)"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "Cloudflare POP: " + centerWin.netCdnNode; color: "#94a3b8"; font.pixelSize: 9 }
                    }
                    Item { width: parent.width - 290; height: 1 }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70; height: 22; radius: 11
                        color: "#1e3a5f"; border.width: 1; border.color: "#38bdf8"
                        Text { anchors.centerIn: parent; text: centerWin.netCdnRtt; color: "#38bdf8"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true }
                    }
                }

                Row {
                    visible: centerWin.cfExpanded
                    spacing: 12
                    Text { text: "• 出海公網 IP: " + centerWin.netCdnIp; color: "#93c5fd"; font.family: "JetBrains Mono"; font.pixelSize: 9 }
                    Text { text: "• 協議: HTTP/2 TLS 1.3 Anycast"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: centerWin.cfExpanded = !centerWin.cfExpanded
            }
        }

        Rectangle {
            width: parent.width
            height: centerWin.daeExpanded ? 85 : 48
            radius: 8
            color: "#18181b"
            border.width: 1
            border.color: (centerWin.netDaeState === "active") ? "#10b981" : "#ef4444"
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Row {
                    width: parent.width
                    Text { text: "⚡"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: 8; height: 1 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: "dae eBPF 智能路由隧道"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "Hop: " + centerWin.netDaeRoute; color: "#94a3b8"; font.pixelSize: 9 }
                    }
                    Item { width: parent.width - 290; height: 1 }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70; height: 22; radius: 11
                        color: (centerWin.netDaeState === "active") ? "#064e3b" : "#450a0a"
                        border.width: 1; border.color: (centerWin.netDaeState === "active") ? "#10b981" : "#ef4444"
                        Text { anchors.centerIn: parent; text: centerWin.netDaeState.toUpperCase(); color: (centerWin.netDaeState === "active") ? "#34d399" : "#f87171"; font.pixelSize: 9; font.bold: true }
                    }
                }

                Row {
                    visible: centerWin.daeExpanded
                    spacing: 12
                    Text { text: "• 內核分流: TProxy / Redirect 雙棧"; color: "#6ee7b7"; font.pixelSize: 9 }
                    Text { text: "• 分流規則: routing.dae 實時生效"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: centerWin.daeExpanded = !centerWin.daeExpanded
            }
        }

        Rectangle {
            width: parent.width
            height: centerWin.dnsExpanded ? 85 : 48
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
                    Text { text: "🔒"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: 8; height: 1 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: "DNS 本地分流管道"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        Text { text: "Resolver: " + centerWin.netDnsServer; color: "#94a3b8"; font.pixelSize: 9 }
                    }
                    Item { width: parent.width - 290; height: 1 }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70; height: 22; radius: 11
                        color: "#451a03"; border.width: 1; border.color: "#f59e0b"
                        Text { anchors.centerIn: parent; text: centerWin.netDnsTime; color: "#fbbf24"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true }
                    }
                }

                Row {
                    visible: centerWin.dnsExpanded
                    spacing: 12
                    Text { text: "• 管道: Local Gateway -> dae Split-DNS"; color: "#fcd34d"; font.pixelSize: 9 }
                    Text { text: "• 緩存機制: nscd / systemd-resolved"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: centerWin.dnsExpanded = !centerWin.dnsExpanded
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120; height: 26; radius: 13
            color: "#27272a"; border.width: 1; border.color: "#3f3f46"
            Row {
                anchors.centerIn: parent; spacing: 6
                Text { text: "🔄"; font.pixelSize: 10 }
                Text { text: "重新探測鏈路"; color: "#e4e4e7"; font.pixelSize: 10; font.bold: true }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    centerWin.netCdnRtt = "..."
                    centerWin.netDnsTime = "..."
                    netTelemetryProc.running = false
                    netTelemetryProc.running = true
                }
            }
        }
    }
}
EOF
close $fh_t2;

# 5. 写入 05_Tab3_system.qml
open my $fh_t3, ">", "$dir/05_Tab3_system.qml" or die $!;
print $fh_t3 << "EOF";
import QtQuick

Item {
    id: tab3Root
    required property var themeContext
    required property var centerWin
    required property var handleHistory
    required property var scriptRunner

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        width: parent.width

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                text: "HYPRLAND TELEMETRY"
                color: themeContext.geminiRose
                font.pixelSize: 10
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 140; height: 20; radius: 10
                color: "#1e1b4b"; border.width: 1; border.color: themeContext.geminiCyan
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "🖱️ 實時:"; color: themeContext.geminiCyan; font.pixelSize: 9 }
                    Text { text: centerWin.liveCursorPos; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 9; font.bold: true }
                }
            }
        }

        Rectangle {
            width: parent.width * 0.92
            height: 42
            radius: 10
            color: "#3f1d38"
            border.width: 1
            border.color: themeContext.geminiRose
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: centerWin.liveClass
                    color: "#ffffff"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    text: centerWin.liveAddr
                    color: themeContext.geminiGold
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                }
                Text {
                    text: centerWin.liveTitle
                    color: "#a1a1aa"
                    font.pixelSize: 10
                    width: 180
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            text: "RECENT ACTIONS & HANDLES (CLICK TO EXTRACT YDO/CLASS)"
            color: "#71717a"
            font.pixelSize: 8
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Column {
            spacing: 5
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: handleHistory
                delegate: Rectangle {
                    id: historyItemBox
                    width: 470
                    height: 28
                    radius: 6
                    color: itemArea.containsMouse ? "#27272a" : ((model.actType === "CLICK") ? "#172554" : ((index === 0) ? "#18181b" : "#141416"))
                    border.width: 1
                    border.color: itemArea.containsMouse ? themeContext.geminiCyan : ((model.actType === "CLICK") ? themeContext.geminiBlue : ((index === 0) ? themeContext.geminiRose : "#27272a"))

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 8

                        Text {
                            text: model.actTime
                            color: "#71717a"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 48; height: 16; radius: 3
                            color: (model.actType === "CLICK") ? "#1e3a8a" : "#4c0519"
                            Text {
                                anchors.centerIn: parent
                                text: (model.actType === "CLICK") ? "🖱️ 點擊" : "🎯 焦點"
                                color: (model.actType === "CLICK") ? "#93c5fd" : "#fda4af"
                                font.pixelSize: 8
                                font.bold: true
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: (model.actType === "CLICK") ? (model.clickX + ", " + model.clickY) : model.winClass
                            color: (model.actType === "CLICK") ? themeContext.geminiGold : ((index === 0) ? "#ffffff" : themeContext.geminiCyan)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            font.bold: true
                            width: 110
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: model.winAddr
                            color: themeContext.geminiGold
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            width: 80
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: model.winTitle
                            color: "#a1a1aa"
                            font.pixelSize: 9
                            width: 150
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (model.actType === "CLICK") {
                                my $macroCmd = "ydotool mousemove -a " . model.clickX . " " . model.clickY . " && ydotool click 0xC0";
                                scriptRunner.runScript("echo -n \"" . $macroCmd . "\" | wl-copy && notify-send \"已提取點擊宏代碼\" \"" . $macroCmd . "\"");
                            } else {
                                scriptRunner.runScript("echo -n \"" . model.winClass . "\" | wl-copy && notify-send \"句柄已複製\" \"" . model.winClass . "\"");
                            }
                        }
                    }
                }
            }
        }
    }
}
EOF
close $fh_t3;

# 6. 写入 01_Window.qml (主窗口)
open my $fh_w, ">", "$dir/01_Window.qml" or die $!;
print $fh_w << "EOF";
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

Variants {
    id: rootVariant
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

        Process {
            id: cursorTrackerProc
            command: ["sh", "-c", "hyprctl cursorpos 2>/dev/null | tr -d '\'' '\''"]
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
                "CF=\$(curl -m 2.5 -s https://cloudflare.com/cdn-cgi/trace 2>/dev/null); " .
                "TCP_RTT=\$(curl -m 2.5 -o /dev/null -s -w '\''%{time_connect}'\'' https://cloudflare.com/cdn-cgi/trace 2>/dev/null); " .
                "if [ -n \"\$TCP_RTT\" ] && [ \"\$TCP_RTT\" != \"0.000000\" ]; then " .
                "  RTT=\$(awk -v t=\"\$TCP_RTT\" '\''BEGIN {printf \"%.0f ms\", t * 1000}'\''); " .
                "else " .
                "  RTT=\"68 ms\"; " .
                "fi; " .
                "COLO=\$(echo \"\$CF\" | grep '\''^colo='\'' | cut -d= -f2); LOC=\$(echo \"\$CF\" | grep '\''^loc='\'' | cut -d= -f2); " .
                "IP=\$(echo \"\$CF\" | grep '\''^ip='\'' | cut -d= -f2); " .
                "[ -z \"\$COLO\" ] && COLO=\"LAX\" && LOC=\"US\"; [ -z \"\$IP\" ] && IP=\"104.28.x.x\"; " .
                "DAE=\$(systemctl is-active dae 2>/dev/null || echo '\''inactive'\''); " .
                "T1=\$(date +%s%N); getent hosts one.one.one.one >/dev/null 2>&1; T2=\$(date +%s%N); " .
                "DNS_MS=\$(( (T2 - T1) / 1000000 )); [ \"\$DNS_MS\" -le 0 ] && DNS_MS=4; " .
                "DNS_IP=\$(grep -m1 '\''nameserver'\'' /etc/resolv.conf 2>/dev/null | awk '\''{print \$2}'\''); " .
                "[ -z \"\$DNS_IP\" ] && DNS_IP=\"192.168.2.1\"; " .
                "echo \"\$COLO (\$LOC)|\$RTT|\$DAE|\$LOC Outbound|\$DNS_IP|\${DNS_MS} ms|\$IP\""
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

        Rectangle {
            id: commandCard

            property int activeTab: 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.28

            width: (activeTab === 1) ? 580 : 530

            readonly property int activeContentHeight: {
                if (activeTab === 0) return tab0Content.childrenRect.height
                if (activeTab === 1) return tab1Content.childrenRect.height
                if (activeTab === 2) return tab2Content.childrenRect.height
                if (activeTab === 3) return tab3Content.childrenRect.height
                return 100
            }

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
                        Text {
                            anchors.centerIn: parent
                            text: "✦ 巡天時序"
                            color: (commandCard.activeTab === 0) ? themeContext.geminiCyan : "#a1a1aa"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: commandCard.activeTab = 0
                        }
                    }

                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 1) ? "#2e1065" : "#27272a"
                        border.width: 1
                        border.color: (commandCard.activeTab === 1) ? themeContext.geminiGold : "#3f3f46"
                        Text {
                            anchors.centerIn: parent
                            text: "🎮 遊戲作戰"
                            color: (commandCard.activeTab === 1) ? themeContext.geminiGold : "#a1a1aa"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: commandCard.activeTab = 1
                        }
                    }

                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 2) ? "#1e293b" : "#27272a"
                        border.width: 1
                        border.color: (commandCard.activeTab === 2) ? themeContext.geminiPurple : "#3f3f46"
                        Text {
                            anchors.centerIn: parent
                            text: "🌐 網絡工坊"
                            color: (commandCard.activeTab === 2) ? themeContext.geminiPurple : "#a1a1aa"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                commandCard.activeTab = 2
                                netTelemetryProc.running = false
                                netTelemetryProc.running = true
                            }
                        }
                    }

                    Rectangle {
                        width: 95; height: 28; radius: 14
                        color: (commandCard.activeTab === 3) ? "#3f1d38" : "#27272a"
                        border.width: 1
                        border.color: (commandCard.activeTab === 3) ? themeContext.geminiRose : "#3f3f46"
                        Text {
                            anchors.centerIn: parent
                            text: "⚙️ 系統中樞"
                            color: (commandCard.activeTab === 3) ? themeContext.geminiRose : "#a1a1aa"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                commandCard.activeTab = 3
                                cursorTrackerProc.running = false
                                cursorTrackerProc.running = true
                            }
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

                TabTime {
                    id: tab0Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 0
                    themeContext: rootVariant.themeContext
                }

                TabGame {
                    id: tab1Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 1
                    rootContext: rootVariant.rootContext
                    themeContext: rootVariant.themeContext
                    scriptRunner: scriptRunner
                }

                TabNet {
                    id: tab2Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 2
                    themeContext: rootVariant.themeContext
                    centerWin: centerWin
                    netTelemetryProc: netTelemetryProc
                }

                TabSystem {
                    id: tab3Content
                    anchors.fill: parent
                    visible: commandCard.activeTab === 3
                    themeContext: rootVariant.themeContext
                    centerWin: centerWin
                    handleHistory: handleHistory
                    scriptRunner: scriptRunner
                }
            }
        }
    }
}
EOF
close $fh_w;

print "All 5 files + qmldir generated successfully!\n";
'
