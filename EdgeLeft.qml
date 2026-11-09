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
        id: leftWin

        readonly property bool expandedMode:
            rootContext.inspectMode || rootContext.boostGlow
        required property var modelData; screen: modelData
        anchors { left: true; top: true; bottom: true }
        implicitWidth: leftWin.expandedMode ? 20 : themeContext.glowDepth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Item {
            id: leftContainer
            anchors.fill: parent

            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 1; antialiasing: false
                opacity: themeContext.trackOpacity
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: themeContext.geminiCyan }
                    GradientStop { position: 1.0; color: themeContext.geminiGold }
                }
            }

            Repeater {
                model: [clockContext.prevAnchorMin, clockContext.nextAnchorMin]
                Rectangle {
                    readonly property int anchorM: modelData
                    readonly property bool onLeft: (anchorM >= 480 && anchorM <= 600)
                    visible: onLeft

                    y: (1.0 - ((anchorM - 480) / 120.0)) * leftContainer.height - (height / 2.0)
                    anchors.left: parent.left

                    height: (anchorM % 60 === 0) ? rootContext.tickM60_W : rootContext.tickM30_W
                    width: (anchorM % 60 === 0) ? rootContext.tickM60_H : rootContext.tickM30_H
                    color: (anchorM % 60 === 0) ? themeContext.hourColor : themeContext.halfHourColor
                    opacity: 0.95
                    antialiasing: false
                }
            }

            Rectangle {
                readonly property bool hasAlarm: rootContext.alarmEnabled && (rootContext.alarmHour % 12 === 8 || rootContext.alarmHour % 12 === 9)
                visible: hasAlarm
                anchors.left: parent.left
                width: 3; height: 3; radius: 1.5
                color: themeContext.alarmColor; opacity: rootContext.beaconPulse
                y: {
                    var aH = rootContext.alarmHour % 12
                    var hIdx = (aH === 8) ? 0 : 1
                    var prog = (hIdx + (rootContext.alarmMinute / 60.0)) / 2.0
                    return (1.0 - prog) * leftContainer.height - 1.5
                }
            }

            Item {
                id: leftBeam
                readonly property int totMin: clockContext.totalMinutes
                readonly property bool inLeft: (totMin >= 465 && totMin <= 615)
                visible: inLeft
                anchors.left: parent.left
                width: leftContainer.width
                height: leftWin.expandedMode ? themeContext.beamBoostLength : themeContext.beamBaseLength

                y: {
                    var progress = (totMin - 480 + clockContext.currentSecond / 60.0) / 120.0
                    return (1.0 - progress) * leftContainer.height - (leftBeam.height / 2.0)
                }

                Shape {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: leftWin.expandedMode ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                    height: leftBeam.height
                    layer.enabled: true; layer.samples: 4
                    ShapePath {
                        strokeWidth: 0; fillColor: "transparent"; startX: 0; startY: leftBeam.height
                        fillGradient: LinearGradient {
                            x1: 0; y1: leftBeam.height; x2: 0; y2: 0
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: Math.max(0.1, 0.35 + rootContext.fluidShift); color: themeContext.geminiCyan }
                            GradientStop { position: Math.min(0.9, 0.65 + rootContext.fluidShift); color: themeContext.geminiGold }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        PathCubic {
                            x: 0; y: 0
                            control1X: leftWin.expandedMode ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                            control1Y: leftBeam.height * 0.7
                            control2X: leftWin.expandedMode ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                            control2Y: leftBeam.height * 0.3
                        }
                        PathLine { x: 0; y: leftBeam.height }
                    }
                }

                Rectangle {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    height: leftBeam.height * 0.85; width: leftWin.expandedMode ? 2 : 1
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

            // 左边绝对静止刻度
            Repeater {
                model: 37
                Rectangle {
                    readonly property int centerMinuteOnEdge: (clockContext.currentHour % 12 - 8) * 60 + clockContext.currentMinute
                    readonly property int targetAbsMin: centerMinuteOnEdge + (index - 18)
                    readonly property int targetClockMin: ((targetAbsMin % 60) + 60) % 60

                    y: (1.0 - (targetAbsMin / 120.0)) * leftContainer.height - (height / 2.0)
                    anchors.left: parent.left

                    readonly property real distToBeam: Math.abs(y + (height / 2.0) - (leftBeam.y + leftBeam.height / 2.0))
                    readonly property real distRatio: distToBeam / (leftBeam.height / 2.0)

                    readonly property bool inEdge: (targetAbsMin >= 0 && targetAbsMin <= 120)
                    readonly property bool isSubMinute: (targetClockMin % 30 !== 0)
                    visible: inEdge && isSubMinute && (distRatio <= 0.85)
                    opacity: Math.max(0.0, (1.0 - distRatio * 1.1) * 0.75)

                    width: (targetClockMin % 10 === 0) ? rootContext.tickM10_H :
                            ((targetClockMin % 5 === 0) ? rootContext.tickM5_H : rootContext.tickM1_H)
                    height: (targetClockMin % 10 === 0) ? rootContext.tickM10_W : ((targetClockMin % 5 === 0) ? rootContext.tickM5_W : rootContext.tickM1_W)
                    color: themeContext.tickColor
                    antialiasing: false

                    Rectangle {
                        visible: index === 18
                        width: themeContext.dotSize
                        height: themeContext.dotSize
                        radius: width / 2.0
                        color: themeContext.dotColor
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.right
                        anchors.leftMargin: 1
                    }
                }
            }
        }
    }
}
