import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    required property var rootContext
    required property var themeContext

    model: Quickshell.screens
    PanelWindow {
        id: winTL
        required property var modelData; screen: modelData
        anchors { top: true; left: true }
        property bool isOpen: false
        property bool isLocked: false

        implicitWidth: isOpen ? 260 : themeContext.cornerSize
        implicitHeight: isOpen ? 180 : themeContext.cornerSize
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Timer {
            id: lockTimerTL
            interval: 450
            onTriggered: {
                winTL.isLocked = false
                if (!areaTL.containsMouse) {
                    timerTL.restart()
                }
            }
        }

        Timer {
            id: timerTL
            interval: 280
            onTriggered: {
                if (!winTL.isLocked) {
                    winTL.isOpen = false
                }
            }
        }

        MouseArea {
            id: areaTL
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                timerTL.stop()
                if (!winTL.isOpen) {
                    winTL.isOpen = true
                    winTL.isLocked = true
                    lockTimerTL.restart()
                }
            }
            onExited: {
                if (!winTL.isLocked) {
                    timerTL.restart()
                }
            }

            Rectangle {
                anchors.fill: parent
                color: themeContext.popupBg
                radius: 10
                border.width: 1
                border.color: themeContext.geminiCyan
                opacity: winTL.isOpen ? 1.0 : 0.0
                scale: winTL.isOpen ? 1.0 : 0.96
                visible: opacity > 0.0

                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "⬡ 快捷应用启动 (10点)"
                        color: themeContext.geminiCyan
                        font.bold: true
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
