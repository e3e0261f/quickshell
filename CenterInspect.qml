import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./tabs"

PanelWindow {
    id: centerWin
    required property var rootContext
    required property var themeContext
    required property var clockContext
    required property var volControl
    required property var soundContext

    visible: rootContext.inspectMode && !rootContext.screenPickerActive

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "#55000000"

    onVisibleChanged: {
        if (visible) {
            rootFocusScope.forceActiveFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: centerWin.visible
        onActivated: rootContext.inspectMode = false
    }

    // 默認使用放大後的大尺寸
    property int activeTab: 0
    property bool cardLarge: true
    property bool cardFullscreen: false
    property int customCardWidth: 0
    property int customCardHeight: 0

    // 網絡工坊遙測狀態 (Tab2_Net 綁定)
    property bool cfExpanded: false
    property bool daeExpanded: false
    property bool dnsExpanded: false
    property string netCdnNode: "LAX (US)"
    property string netCdnRtt: "68 ms"
    property string netDaeState: "active"
    property string netDaeRoute: "US Outbound"
    property string netDnsServer: "127.0.0.1"
    property string netDnsTime: "4 ms"
    property string netCdnIp: "104.28.x.x"

    // Hyprland 焦點與點擊歷史 (使用 JS 數組確保 Qt6 Repeater/ListView modelData 穩定可用)
    property var handleHistory: [
        {
            "actType": "FOCUS",
            "actTime": "03:03:40",
            "winClass": "Albion-Online",
            "winTitle": "Albion Online Client",
            "winAddr": "0x564a9e8b2100",
            "clickX": 0,
            "clickY": 0
        }
    ]

    function pushHandleHistory(actType, winClass, winTitle, winAddr, clickX, clickY) {
        var next = [{
            "actType": String(actType),
            "actTime": clockContext.fullTimeString,
            "winClass": String(winClass || "Desktop"),
            "winTitle": String(winTitle || ""),
            "winAddr": String(winAddr || "0x0"),
            "clickX": Number(clickX) || 0,
            "clickY": Number(clickY) || 0
        }];
        for (var i = 0; i < handleHistory.length && next.length < 6; i++) {
            next.push(handleHistory[i]);
        }
        handleHistory = next;
    }

    readonly property int expandedContentHeight:
        cardFullscreen ? Math.max(392, centerWin.height - 215) :
        (customCardHeight > 0 ? Math.max(392, customCardHeight - 205) :
        (cardLarge ? Math.max(392, Math.min(720, centerWin.height - 80) - 205) : 0))

    Process {
        id: scriptRunner
        function run(cmdStr) {
            command = ["sh", "-c", cmdStr];
            running = false;
            running = true;
        }
    }

    Process {
        id: netTelemetryProc
        command: ["sh", "-c",
            "CF=$(curl -s --max-time 2 https://cloudflare.com/cdn-cgi/trace 2>/dev/null); " +
            "COLO=$(echo \"$CF\" | grep '^colo=' | cut -d= -f2); " +
            "LOC=$(echo \"$CF\" | grep '^loc=' | cut -d= -f2); " +
            "IP=$(echo \"$CF\" | grep '^ip=' | cut -d= -f2); " +
            "DAE=$(systemctl is-active dae 2>/dev/null || echo inactive); " +
            "echo \"CF_NODE=${COLO:-LAX} (${LOC:-US});CF_IP=${IP:-104.28.x.x};DAE=${DAE}\""
        ]
        stdout: SplitParser {
            onRead: function(line) {
                var mNode = line.match(/CF_NODE=([^;]+)/);
                var mIp = line.match(/CF_IP=([^;]+)/);
                var mDae = line.match(/DAE=([^;\n]+)/);
                if (mNode) centerWin.netCdnNode = mNode[1];
                if (mIp) centerWin.netCdnIp = mIp[1];
                if (mDae) centerWin.netDaeState = mDae[1].trim();
            }
        }
    }

    FocusScope {
        id: rootFocusScope
        anchors.fill: parent
        focus: centerWin.visible
        Keys.onEscapePressed: function(event) {
            event.accepted = true;
            rootContext.inspectMode = false;
        }

    MouseArea {
        anchors.fill: parent
        onClicked: rootContext.inspectMode = false
    }

    Rectangle {
        id: commandCard
        anchors.centerIn: parent
        width: centerWin.cardFullscreen ? (centerWin.width - 32) :
               (centerWin.customCardWidth > 0 ? Math.max(520, Math.min(centerWin.width - 24, centerWin.customCardWidth)) :
               (centerWin.cardLarge ? Math.min(1040, centerWin.width - 80) :
               (centerWin.activeTab === 3 ? Math.min(920, centerWin.width - 60) :
               (centerWin.activeTab === 1 ? 580 : (centerWin.activeTab === 0 ? 560 : 530)))))

        height: centerWin.cardFullscreen ? (centerWin.height - 32) :
                (centerWin.customCardHeight > 0 ? Math.max(360, Math.min(centerWin.height - 24, centerWin.customCardHeight)) :
                (centerWin.cardLarge ? Math.min(720, centerWin.height - 80) :
                Math.min(centerWin.height - 32, headerArea.implicitHeight + contentArea.implicitHeight + 36)))

        radius: centerWin.cardFullscreen ? 14 : 20
        color: themeContext.popupBg
        border.width: 1
        border.color: centerWin.activeTab === 0 ? themeContext.geminiCyan :
                      (centerWin.activeTab === 1 ? themeContext.geminiGold :
                      (centerWin.activeTab === 2 ? themeContext.geminiPurple : themeContext.geminiRose))

        MouseArea { anchors.fill: parent }

        // 右上角視窗控制按鈕組
        Row {
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: 12; anchors.rightMargin: 14
            spacing: 6; z: 10

            Rectangle {
                visible: !centerWin.cardFullscreen && (centerWin.customCardWidth > 0 || centerWin.customCardHeight > 0)
                width: 48; height: 22; radius: 11
                color: "#27272a"; border.color: "#3f3f46"; border.width: 1
                Text { anchors.centerIn: parent; text: "↺ 重置"; color: "#a1a1aa"; font.pixelSize: 9; font.bold: true }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        centerWin.customCardWidth = 0;
                        centerWin.customCardHeight = 0;
                        centerWin.cardLarge = true;
                    }
                }
            }

            Rectangle {
                width: 54; height: 22; radius: 11
                color: centerWin.cardLarge ? themeContext.geminiBlue : "#27272a"
                border.color: centerWin.cardLarge ? themeContext.geminiBlue : "#3f3f46"; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: centerWin.cardLarge ? "⤡ 還原" : "⤢ 放大"
                    color: centerWin.cardLarge ? "#18181b" : "#e4e4e7"
                    font.pixelSize: 9; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        centerWin.cardFullscreen = false;
                        centerWin.customCardWidth = 0;
                        centerWin.customCardHeight = 0;
                        centerWin.cardLarge = !centerWin.cardLarge;
                    }
                }
            }

            Rectangle {
                width: 54; height: 22; radius: 11
                color: centerWin.cardFullscreen ? themeContext.geminiCyan : "#27272a"
                border.color: centerWin.cardFullscreen ? themeContext.geminiCyan : "#3f3f46"; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: centerWin.cardFullscreen ? "⤡ 還原" : "⛶ 全屏"
                    color: centerWin.cardFullscreen ? "#18181b" : "#e4e4e7"
                    font.pixelSize: 9; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        centerWin.cardLarge = false;
                        centerWin.cardFullscreen = !centerWin.cardFullscreen;
                    }
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.topMargin: centerWin.cardFullscreen ? 12 : 18
            spacing: 12

            // 頂部時鐘與分頁欄
            Column {
                id: headerArea
                width: parent.width
                spacing: centerWin.cardFullscreen ? 8 : 12

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clockContext.fullDateString
                        color: themeContext.geminiCyan
                        font.family: "monospace"; font.pixelSize: 12; font.letterSpacing: 2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clockContext.fullTimeString
                        color: "#ffffff"
                        font.family: "monospace"; font.bold: true
                        font.pixelSize: centerWin.cardFullscreen ? 38 : 48
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.85; height: 1; color: "#3f3f46"
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Repeater {
                        model: [
                            { id: 0, label: "✦ 巡天時序", activeBg: "#1e1b4b", col: themeContext.geminiCyan },
                            { id: 1, label: "🎮 遊戲作戰", activeBg: "#2e1065", col: themeContext.geminiGold },
                            { id: 2, label: "🌐 網絡工坊", activeBg: "#1e293b", col: themeContext.geminiPurple },
                            { id: 3, label: "⚙️ 系統中樞", activeBg: "#3f1d38", col: themeContext.geminiRose }
                        ]
                        Rectangle {
                            required property var modelData
                            readonly property bool isActive: centerWin.activeTab === modelData.id
                            width: 95; height: 28; radius: 14
                            color: isActive ? modelData.activeBg : "#27272a"
                            border.color: isActive ? modelData.col : "#3f3f46"; border.width: 1
                            Text {
                                anchors.centerIn: parent; text: modelData.label
                                color: isActive ? modelData.col : "#a1a1aa"
                                font.pixelSize: 11; font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    centerWin.activeTab = modelData.id;
                                    if (modelData.id === 2) {
                                        netTelemetryProc.running = false;
                                        netTelemetryProc.running = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 內容滾動區
            ScrollView {
                id: contentScroll
                width: parent.width
                height: commandCard.height - headerArea.implicitHeight - (centerWin.cardFullscreen ? 26 : 34)
                clip: true

                Column {
                    id: contentArea
                    width: contentScroll.availableWidth

                    SafeLoader {
                        width: contentArea.width
                        cardTitle: "巡天時序"
                        source: centerWin.activeTab === 0 ? Qt.resolvedUrl("./tabs/Tab0_Time.qml") : ""
                        active: centerWin.activeTab === 0
                        rootContext: centerWin.rootContext
                        themeContext: centerWin.themeContext
                        clockContext: centerWin.clockContext
                        centerWin: centerWin
                        scriptRunner: scriptRunner
                        handleHistory: centerWin.handleHistory
                        netTelemetryProc: netTelemetryProc
                        volControl: centerWin.volControl
                        soundContext: centerWin.soundContext
                    }

                    SafeLoader {
                        width: contentArea.width
                        cardTitle: "遊戲作戰"
                        source: centerWin.activeTab === 1 ? Qt.resolvedUrl("./tabs/Tab1_Combat.qml") : ""
                        active: centerWin.activeTab === 1
                        rootContext: centerWin.rootContext
                        themeContext: centerWin.themeContext
                        clockContext: centerWin.clockContext
                        centerWin: centerWin
                        scriptRunner: scriptRunner
                        handleHistory: centerWin.handleHistory
                        netTelemetryProc: netTelemetryProc
                        volControl: centerWin.volControl
                        soundContext: centerWin.soundContext
                    }

                    SafeLoader {
                        width: contentArea.width
                        cardTitle: "網絡工坊"
                        source: centerWin.activeTab === 2 ? Qt.resolvedUrl("./tabs/Tab2_Net.qml") : ""
                        active: centerWin.activeTab === 2
                        rootContext: centerWin.rootContext
                        themeContext: centerWin.themeContext
                        clockContext: centerWin.clockContext
                        centerWin: centerWin
                        scriptRunner: scriptRunner
                        handleHistory: centerWin.handleHistory
                        netTelemetryProc: netTelemetryProc
                        volControl: centerWin.volControl
                        soundContext: centerWin.soundContext
                    }

                    SafeLoader {
                        width: contentArea.width
                        cardTitle: "系統中樞"
                        source: centerWin.activeTab === 3 ? Qt.resolvedUrl("./tabs/Tab3_System.qml") : ""
                        active: centerWin.activeTab === 3
                        rootContext: centerWin.rootContext
                        themeContext: centerWin.themeContext
                        clockContext: centerWin.clockContext
                        centerWin: centerWin
                        scriptRunner: scriptRunner
                        handleHistory: centerWin.handleHistory
                        netTelemetryProc: netTelemetryProc
                        volControl: centerWin.volControl
                        soundContext: centerWin.soundContext
                    }
                }
            }
        }

        // 右下角自由拖拽縮放柄
        Item {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            width: 24; height: 24; z: 20
            Text {
                anchors.centerIn: parent; text: "◢"
                color: resizeMouse.containsMouse ? themeContext.geminiCyan : "#52525b"
                font.pixelSize: 11
            }
            MouseArea {
                id: resizeMouse
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
                property real startX: 0
                property real startY: 0
                property real startW: 0
                property real startH: 0

                onPressed: function(mouse) {
                    var pt = mapToItem(centerWin.contentItem, mouse.x, mouse.y);
                    startX = pt.x; startY = pt.y;
                    startW = commandCard.width; startH = commandCard.height;
                    centerWin.cardLarge = false;
                    centerWin.cardFullscreen = false;
                }
                onPositionChanged: function(mouse) {
                    if (!pressed) return;
                    var pt = mapToItem(centerWin.contentItem, mouse.x, mouse.y);
                    centerWin.customCardWidth = Math.max(520, Math.min(centerWin.width - 24, Math.round(startW + (pt.x - startX) * 2)));
                    centerWin.customCardHeight = Math.max(360, Math.min(centerWin.height - 24, Math.round(startH + (pt.y - startY) * 2)));
                }
                onDoubleClicked: {
                    centerWin.cardFullscreen = false;
                    centerWin.customCardWidth = 0;
                    centerWin.customCardHeight = 0;
                    centerWin.cardLarge = true;
                }
            }
        }
    }
    }
}
