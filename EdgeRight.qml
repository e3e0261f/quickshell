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
        id: rightWin

        readonly property bool expandedMode:
            rootContext.inspectMode || rootContext.boostGlow
        required property var modelData; screen: modelData
        anchors { right: true; top: true; bottom: true }
        implicitWidth: rightWin.expandedMode ? 20 : themeContext.glowDepth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Item {
            id: rightContainer
            anchors.fill: parent

            Rectangle {
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 1; antialiasing: false
                opacity: themeContext.trackOpacity
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: themeContext.geminiPurple }
                    GradientStop { position: 1.0; color: themeContext.geminiCoral }
                }
            }

            Repeater {
                model: [clockContext.prevAnchorMin, clockContext.nextAnchorMin]
                Rectangle {
                    readonly property int anchorM: modelData
                    readonly property bool onRight: (anchorM >= 120 && anchorM <= 240)
                    visible: onRight

                    y: ((anchorM - 120) / 120.0) * rightContainer.height - (height / 2.0)
                    anchors.right: parent.right

                    height: (anchorM % 60 === 0) ? rootContext.tickM60_W : rootContext.tickM30_W
                    width: (anchorM % 60 === 0) ? rootContext.tickM60_H : rootContext.tickM30_H
                    color: (anchorM % 60 === 0) ? themeContext.hourColor : themeContext.halfHourColor
                    opacity: 0.95
                    antialiasing: false
                }
            }

            Rectangle {
                readonly property bool hasAlarm: rootContext.alarmEnabled && (rootContext.alarmHour % 12 === 2 || rootContext.alarmHour % 12 === 3)
                visible: hasAlarm
                anchors.right: parent.right
                width: 3; height: 3; radius: 1.5
                color: themeContext.alarmColor; opacity: rootContext.beaconPulse
                y: {
                    var aH = rootContext.alarmHour % 12
                    var hIdx = (aH === 2) ? 0 : 1
                    var prog = (hIdx + (rootContext.alarmMinute / 60.0)) / 2.0
                    return prog * rightContainer.height - 1.5
                }
            }

            Item {
                id: rightBeam
                readonly property int totMin: clockContext.totalMinutes
                readonly property bool inRight: (totMin >= 105 && totMin <= 255)
                visible: inRight
                anchors.right: parent.right
                width: rightContainer.width
                height: rightWin.expandedMode ? themeContext.beamBoostLength : themeContext.beamBaseLength

                y: {
                    var progress = (totMin - 120 + clockContext.currentSecond / 60.0) / 120.0
                    return progress * rightContainer.height - (rightBeam.height / 2.0)
                }

                Shape {
                    id: rightCurve
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: rightWin.expandedMode ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                    height: rightBeam.height
                    layer.enabled: true; layer.samples: 4
                    ShapePath {
                        strokeWidth: 0; fillColor: "transparent"; startX: rightCurve.width; startY: 0
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 0; y2: rightBeam.height
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: Math.max(0.1, 0.35 + rootContext.fluidShift); color: themeContext.geminiPurple }
                            GradientStop { position: Math.min(0.9, 0.65 + rootContext.fluidShift); color: themeContext.geminiGold }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        PathCubic {
                            x: rightCurve.width; y: rightCurve.height
                            control1X: 0
                            control1Y: rightBeam.height * 0.3
                            control2X: 0
                            control2Y: rightBeam.height * 0.7
                        }
                        PathLine { x: rightCurve.width; y: 0 }
                    }
                }

                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    height: rightBeam.height * 0.85; width: rightWin.expandedMode ? 2 : 1
                    gradient: Gradient {
                        orientation: Gradient.Vertical
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

            // 右边绝对静止刻度
            Repeater {
                model: 37
                Rectangle {
                    readonly property int centerMinuteOnEdge: (clockContext.currentHour % 12 - 2) * 60 + clockContext.currentMinute
                    readonly property int targetAbsMin: centerMinuteOnEdge + (index - 18)
                    readonly property int targetClockMin: ((targetAbsMin % 60) + 60) % 60

                    y: (targetAbsMin / 120.0) * rightContainer.height - (height / 2.0)
                    anchors.right: parent.right

                    readonly property real distToBeam: Math.abs(y + (height / 2.0) - (rightBeam.y + rightBeam.height / 2.0))
                    readonly property real distRatio: distToBeam / (rightBeam.height / 2.0)

                    readonly property bool inEdge: (targetAbsMin >= 0 && targetAbsMin <= 120)
                    readonly property bool isSubMinute: (targetClockMin % 30 !== 0)
                    visible: inEdge && isSubMinute && (rootContext.inspectMode || distRatio <= 0.85)
                    opacity: rootContext.inspectMode ? 0.85 : Math.max(0.0, (1.0 - distRatio * 1.1) * 0.75)

                    width: (targetClockMin % 10 === 0) ? rootContext.tickM10_H :
                            ((targetClockMin % 5 === 0) ? rootContext.tickM5_H : rootContext.tickM1_H)
                    height: (targetClockMin % 10 === 0) ? rootContext.tickM10_W : ((targetClockMin % 5 === 0) ? rootContext.tickM5_W : rootContext.tickM1_W)
                    color: themeContext.tickColor
                    antialiasing: false

                    Rectangle {
                        visible: index === 18
                        width: rootContext.inspectMode ? themeContext.inspectDotSize : themeContext.dotSize
                        height: rootContext.inspectMode ? themeContext.inspectDotSize : themeContext.dotSize
                        radius: width / 2.0
                        color: themeContext.dotColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.left
                        anchors.rightMargin: 1
                    }
                }
            }
        }
    }
}
