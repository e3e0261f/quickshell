import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

Variants {
    required property var rootContext
    required property var themeContext
    required property var clockContext

    model: Quickshell.screens
    PanelWindow {
        id: topWin

        readonly property bool expandedMode:
            rootContext.inspectMode || rootContext.boostGlow
        required property var modelData; screen: modelData
        anchors { top: true; left: true; right: true }
        
        // 核心修復：只要開啟巡天巨幕（inspectMode）或者點了 2x 按鈕，高度自動切換到 20px 放大模式
        implicitHeight: topWin.expandedMode ? 20 : themeContext.glowDepth
        
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Item {
            id: topContainer
            anchors.fill: parent

            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: 1; antialiasing: false
                opacity: themeContext.trackOpacity
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: themeContext.geminiCyan }
                    GradientStop { position: 1.0; color: themeContext.geminiPurple }
                }
            }

            Repeater {
                model: [clockContext.prevAnchorMin, clockContext.nextAnchorMin]
                Rectangle {
                    readonly property int anchorM: modelData
                    readonly property bool onTop: (anchorM >= 600 || anchorM <= 120)
                    visible: onTop

                    readonly property real normalizedM: (anchorM >= 600) ? (anchorM - 600) : (anchorM + 120)
                    x: (normalizedM / 240.0) * topContainer.width - (width / 2.0)
                    anchors.top: parent.top

                    width: (anchorM % 60 === 0) ? rootContext.tickM60_W : rootContext.tickM30_W
                    height: (anchorM % 60 === 0) ? rootContext.tickM60_H : rootContext.tickM30_H
                    color: (anchorM % 60 === 0) ? themeContext.hourColor : themeContext.halfHourColor
                    opacity: 0.95
                    antialiasing: false
                }
            }

            Rectangle {
                readonly property bool hasAlarm: rootContext.alarmEnabled && (rootContext.alarmHour % 12 === 10 || rootContext.alarmHour % 12 === 11 || rootContext.alarmHour % 12 === 0 || rootContext.alarmHour % 12 === 1)
                visible: hasAlarm
                anchors.top: parent.top
                width: 3; height: 3; radius: 1.5
                color: themeContext.alarmColor; opacity: rootContext.beaconPulse
                x: {
                    var aH = rootContext.alarmHour % 12
                    var hIdx = (aH === 10) ? 0 : ((aH === 11) ? 1 : ((aH === 0) ? 2 : 3))
                    var prog = (hIdx + (rootContext.alarmMinute / 60.0)) / 4.0
                    return prog * topContainer.width - 1.5
                }
            }

            Item {
                id: topBeam
                readonly property int totMin: clockContext.totalMinutes
                readonly property bool inTop: (totMin >= 585 || totMin <= 135)
                visible: inTop
                anchors.top: parent.top
                height: topContainer.height
                
                // 巡天模式或 2x 模式下，光束寬度自動采用 boostLength 放大
                width: (rootContext.inspectMode || rootContext.boostGlow) ? themeContext.beamBoostLength : themeContext.beamBaseLength

                x: {
                    var normalizedM = (totMin >= 585) ? (totMin - 600) : (totMin + 120)
                    var progress = normalizedM / 240.0
                    return progress * topContainer.width - (topBeam.width / 2.0)
                }

                Repeater {
                    model: 37
                    Rectangle {
                        readonly property int deltaMin: index - 18
                        readonly property int targetMin: ((clockContext.currentMinute + deltaMin) % 60 + 60) % 60
                        readonly property real pxPerMin: topContainer.width / 240.0
                        readonly property real xOffset: (deltaMin - (clockContext.currentSecond / 60.0)) * pxPerMin
                        readonly property real distRatio: Math.abs(xOffset) / (topBeam.width / 2.0)
                        readonly property bool isSubMinute: (targetMin % 30 !== 0)

                        visible: isSubMinute && (rootContext.inspectMode || distRatio <= 0.78)
                        opacity: (deltaMin === 0) ? 1.0 : Math.max(0.0, (1.0 - distRatio * 1.1) * 0.75)

                        anchors.top: parent.top
                        x: (topBeam.width / 2.0) + xOffset - (width / 2.0)

                        width: (targetMin % 10 === 0) ? rootContext.tickM10_W : ((targetMin % 5 === 0) ? rootContext.tickM5_W : rootContext.tickM1_W)
                        height: (targetMin % 10 === 0) ? rootContext.tickM10_H :
                                ((targetMin % 5 === 0) ? rootContext.tickM5_H : rootContext.tickM1_H)
                        color: (deltaMin === 0) ? themeContext.dotColor : themeContext.tickColor
                        antialiasing: false

                        Rectangle {
                            visible: deltaMin === 0
                            width: themeContext.dotSize
                            height: themeContext.dotSize
                            radius: width / 2.0
                            color: themeContext.dotColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 1
                        }
                    }
                }

                Shape {
                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    width: topBeam.width
                    height: (rootContext.inspectMode || rootContext.boostGlow) ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                    layer.enabled: true; layer.samples: 4
                    ShapePath {
                        strokeWidth: 0; fillColor: "transparent"; startX: 0; startY: 0
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: topBeam.width; y2: 0
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: Math.max(0.1, 0.35 + rootContext.fluidShift); color: themeContext.geminiPurple }
                            GradientStop { position: Math.min(0.9, 0.65 + rootContext.fluidShift); color: themeContext.geminiGold }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        PathCubic {
                            x: topBeam.width; y: 0
                            control1X: topBeam.width * 0.3
                            control1Y: (rootContext.inspectMode || rootContext.boostGlow) ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                            control2X: topBeam.width * 0.7
                            control2Y: (rootContext.inspectMode || rootContext.boostGlow) ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }

                Rectangle {
                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    width: topBeam.width * 0.85
                    height: (rootContext.inspectMode || rootContext.boostGlow) ? 2 : 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: Math.max(0.05, 0.20 + rootContext.fluidShift); color: themeContext.geminiCyan }
                        GradientStop { position: Math.max(0.15, 0.38 + rootContext.fluidShift); color: themeContext.geminiPurple }
                        GradientStop { position: Math.min(0.85, 0.50 + rootContext.fluidShift); color: themeContext.geminiWhite }
                        GradientStop { position: Math.min(0.90, 0.62 + rootContext.fluidShift); color: themeContext.geminiGold }
                        GradientStop { position: Math.min(0.95, 0.80 + rootContext.fluidShift); color: themeContext.geminiCoral }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }
    }
}
