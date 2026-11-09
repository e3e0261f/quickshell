import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Variants {
    required property var rootContext
    required property var themeContext
    required property var clockContext

    model: Quickshell.screens
    PanelWindow {
        id: winBL
        required property var modelData; screen: modelData
        anchors { bottom: true; left: true }
        property bool isOpen: false
        property bool isLocked: false

        implicitWidth: isOpen ? 320 : themeContext.cornerSize
        implicitHeight: isOpen ? 280 : themeContext.cornerSize
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Timer {
            id: lockTimerBL
            interval: 450
            onTriggered: {
                winBL.isLocked = false
                if (!areaBL.containsMouse) {
                    timerBL.restart()
                }
            }
        }

        Timer {
            id: timerBL
            interval: 250
            onTriggered: {
                if (!winBL.isLocked) {
                    winBL.isOpen = false
                }
            }
        }

        MouseArea {
            id: areaBL
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                timerBL.stop()
                if (!winBL.isOpen) {
                    winBL.isOpen = true
                    winBL.isLocked = true
                    lockTimerBL.restart()
                }
            }
            onExited: {
                if (!winBL.isLocked) {
                    timerBL.restart()
                }
            }

            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    Hyprland.dispatch("workspace e+1")
                } else {
                    Hyprland.dispatch("workspace e-1")
                }
            }

            Rectangle {
                anchors.fill: parent
                color: themeContext.popupBg
                radius: 14
                border.width: 1
                border.color: themeContext.geminiGold
                opacity: winBL.isOpen ? 1.0 : 0.0
                scale: winBL.isOpen ? 1.0 : 0.96
                visible: opacity > 0.0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            text: clockContext.fullTimeString
                            color: themeContext.geminiGold
                            font.family: "JetBrains Mono"
                            font.bold: true
                            font.pixelSize: 22
                        }
                        Text {
                            text: clockContext.fullDateString
                            color: "#a1a1aa"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 135; height: 34; radius: 8
                            color: "#27272a"; border.width: 1; border.color: "#3f3f46"
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "📶"; font.pixelSize: 11 }
                                Text {
                                    text: rootContext.currentWifi
                                    color: "#e4e4e7"; font.pixelSize: 11; font.bold: true
                                    elide: Text.ElideRight; width: 90
                                }
                            }
                        }

                        Rectangle {
                            width: 135; height: 34; radius: 8
                            color: "#27272a"; border.width: 1; border.color: themeContext.geminiCyan
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "⌨"; font.pixelSize: 12; color: themeContext.geminiCyan }
                                Text {
                                    text: rootContext.currentIme
                                    color: "#e4e4e7"; font.pixelSize: 11; font.bold: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 68; radius: 10
                        color: "#18181b"; border.width: 1; border.color: "#27272a"
                        Column {
                            anchors.centerIn: parent; spacing: 8
                            Row {
                                spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                                Text { text: "WORKSPACES"; color: "#71717a"; font.pixelSize: 9; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 72; height: 18; radius: 9; color: "#2e1065"; border.width: 1; border.color: themeContext.geminiPurple
                                    Row {
                                        anchors.centerIn: parent; spacing: 4
                                        Text { text: "✦"; color: themeContext.geminiPurple; font.pixelSize: 9 }
                                        Text { text: "魔术区"; color: "#f3e8ff"; font.pixelSize: 9; font.bold: true }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { Hyprland.dispatch("togglespecialworkspace magic") }
                                    }
                                }
                            }

                            Row {
                                spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: Hyprland.workspaces
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: modelData.focused ? 28 : 20; height: 20; radius: 10
                                        color: modelData.focused ? themeContext.geminiGold : "#3f3f46"
                                        Behavior on width { NumberAnimation { duration: 150 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text {
                                            anchors.centerIn: parent; text: modelData.id
                                            color: modelData.focused ? "#18181b" : "#d4d4d8"; font.pixelSize: 10; font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { modelData.activate() }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: Hyprland.activeToplevel ? ("● " + Hyprland.activeToplevel.title) : "● 桌面就绪 (Desktop Idle)"
                        color: "#a1a1aa"; font.pixelSize: 10; elide: Text.ElideRight
                        width: parent.width; anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
