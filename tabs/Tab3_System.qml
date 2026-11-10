import QtQuick

Column {
    id: tab3Root
    property var themeContext
    property var centerWin
    property var handleHistory
    property var scriptRunner

    width: parent ? parent.width : 530
    spacing: 8

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Text {
            text: "HYPRLAND TELEMETRY"
            color: themeContext ? themeContext.geminiRose : "#fb7185"
            font.pixelSize: 10
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 140
            height: 20
            radius: 10
            color: "#1e1b4b"
            border.width: 1
            border.color: themeContext ? themeContext.geminiCyan : "#38bdf8"

            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "🖱️ 實時:"
                    color: themeContext ? themeContext.geminiCyan : "#38bdf8"
                    font.pixelSize: 9
                }
                Text {
                    text: centerWin ? centerWin.liveCursorPos : "0, 0"
                    color: "#ffffff"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    Rectangle {
        width: parent.width * 0.92
        height: 42
        radius: 10
        color: "#3f1d38"
        border.width: 1
        border.color: themeContext ? themeContext.geminiRose : "#fb7185"
        anchors.horizontalCenter: parent.horizontalCenter

        Row {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: centerWin ? centerWin.liveClass : "---"
                color: "#ffffff"
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.bold: true
            }
            Text {
                text: centerWin ? centerWin.liveAddr : "0x0"
                color: themeContext ? themeContext.geminiGold : "#eab308"
                font.family: "JetBrains Mono"
                font.pixelSize: 9
            }
            Text {
                text: centerWin ? centerWin.liveTitle : "---"
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
                width: 470
                height: 28
                radius: 6
                color: itemArea.containsMouse ? "#27272a" : ((model.actType === "CLICK") ? "#172554" : ((index === 0) ? "#18181b" : "#141416"))
                border.width: 1
                border.color: itemArea.containsMouse ? (themeContext ? themeContext.geminiCyan : "#38bdf8") : ((model.actType === "CLICK") ? (themeContext ? themeContext.geminiBlue : "#3b82f6") : ((index === 0) ? (themeContext ? themeContext.geminiRose : "#fb7185") : "#27272a"))

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
                        width: 48
                        height: 16
                        radius: 3
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
                        color: (model.actType === "CLICK") ? (themeContext ? themeContext.geminiGold : "#eab308") : ((index === 0) ? "#ffffff" : (themeContext ? themeContext.geminiCyan : "#38bdf8"))
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        font.bold: true
                        width: 110
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: model.winAddr
                        color: themeContext ? themeContext.geminiGold : "#eab308"
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
                        if (scriptRunner) {
                            if (model.actType === "CLICK") {
                                var macro = "ydotool mousemove -a " + model.clickX + " " + model.clickY + " && ydotool click 0xC0"
                                scriptRunner.runScript("echo -n '" + macro + "' | wl-copy && notify-send '已提取點擊宏代碼' '" + macro + "'")
                            } else {
                                scriptRunner.runScript("echo -n '" + model.winClass + "' | wl-copy && notify-send '句柄已複製' '" + model.winClass + "'")
                            }
                        }
                    }
                }
            }
        }
    }
}
