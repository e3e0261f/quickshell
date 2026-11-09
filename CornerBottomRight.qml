import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    required property var rootContext
    required property var themeContext
    required property var clockContext
    required property var soundContext

    model: Quickshell.screens
    PanelWindow {
        id: winBR
        required property var modelData; screen: modelData
        anchors { bottom: true; right: true }
        property bool isOpen: false
        property bool isLocked: false

        implicitWidth: isOpen ? 285 : themeContext.cornerSize
        implicitHeight: isOpen ? 245 : themeContext.cornerSize
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Timer {
            id: lockTimerBR
            interval: 450
            onTriggered: {
                winBR.isLocked = false
                if (!areaBR.containsMouse) {
                    timerBR.restart()
                }
            }
        }

        Timer {
            id: timerBR
            interval: 250
            onTriggered: {
                if (!winBR.isLocked) {
                    winBR.isOpen = false
                }
            }
        }

        MouseArea {
            id: areaBR
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                timerBR.stop()
                if (!winBR.isOpen) {
                    winBR.isOpen = true
                    winBR.isLocked = true
                    lockTimerBR.restart()
                }
            }
            onExited: {
                if (!winBR.isLocked) {
                    timerBR.restart()
                }
            }

            Rectangle {
                anchors.fill: parent
                color: themeContext.popupBg
                radius: 14
                border.width: 1
                border.color: themeContext.geminiCoral
                opacity: winBR.isOpen ? 1.0 : 0.0
                scale: winBR.isOpen ? 1.0 : 0.96
                visible: opacity > 0.0

                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Text {
                        text: "⬡ 边缘光学与感官控制"
                        color: themeContext.geminiCoral
                        font.bold: true
                        font.pixelSize: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        width: parent.width
                        Text {
                            text: "⚡ 极光爆发翻倍"
                            color: rootContext.boostGlow ? themeContext.geminiGold : "#d4d4d8"
                            font.pixelSize: 12; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 140 - 44; height: 1 }
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: rootContext.boostGlow ? themeContext.geminiGold : "#3f3f46"
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Rectangle {
                                width: 20; height: 20; radius: 10; color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: rootContext.boostGlow ? (parent.width - width - 2) : 2
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootContext.boostGlow = !rootContext.boostGlow
                                    soundContext.play("button-pressed")
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            text: "🔔 整点轻声微音"
                            color: "#d4d4d8"
                            font.pixelSize: 12; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 120 - 44; height: 1 }
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: rootContext.chimeEnabled ? "#34c759" : "#3f3f46"
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Rectangle {
                                width: 20; height: 20; radius: 10; color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: rootContext.chimeEnabled ? (parent.width - width - 2) : 2
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootContext.chimeEnabled = !rootContext.chimeEnabled
                                    soundContext.play("button-pressed")
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            text: "📍 航标闹钟开关"
                            color: themeContext.alarmColor
                            font.pixelSize: 12; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 125 - 44; height: 1 }
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: rootContext.alarmEnabled ? themeContext.alarmColor : "#3f3f46"
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Rectangle {
                                width: 20; height: 20; radius: 10; color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: rootContext.alarmEnabled ? (parent.width - width - 2) : 2
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootContext.alarmEnabled = !rootContext.alarmEnabled
                                    soundContext.play("button-pressed")
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: "目标时间:"
                            color: "#94a3b8"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "-"; color: "#ffffff"; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    rootContext.alarmHour = (rootContext.alarmHour + (12 - themeContext.alarmHourStep)) % 12
                                    soundContext.play("button-pressed")
                                }
                            }
                        }
                        Text {
                            text: (rootContext.alarmHour < 10 ? "0" : "") + rootContext.alarmHour + "点"
                            color: themeContext.alarmColor
                            font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "+"; color: "#ffffff"; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    rootContext.alarmHour = (rootContext.alarmHour + themeContext.alarmHourStep) % 12
                                    soundContext.play("button-pressed")
                                }
                            }
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "-"; color: "#ffffff"; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    rootContext.alarmMinute = (rootContext.alarmMinute + (60 - themeContext.alarmMinuteStep)) % 60
                                    soundContext.play("button-pressed")
                                }
                            }
                        }
                        Text {
                            text: (rootContext.alarmMinute < 10 ? "0" : "") + rootContext.alarmMinute + "分"
                            color: themeContext.alarmColor
                            font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 20; height: 20; radius: 4; color: "#27272a"
                            Text { anchors.centerIn: parent; text: "+"; color: themeContext.geminiGold; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    rootContext.alarmMinute = (rootContext.alarmMinute + themeContext.alarmMinuteStep) % 60
                                    soundContext.play("button-pressed")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
