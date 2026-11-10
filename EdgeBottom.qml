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
        id: bottomWin

        readonly property bool expandedMode:
            rootContext.inspectMode || rootContext.boostGlow
        required property var modelData; screen: modelData
        anchors { bottom: true; left: true; right: true }
        implicitHeight: bottomWin.expandedMode ? 20 : themeContext.glowDepth
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        Item {
            id: bottomContainer
            anchors.fill: parent

            Rectangle {
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                height: 1; antialiasing: false
                opacity: themeContext.trackOpacity
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: themeContext.geminiGold }
                    GradientStop { position: 1.0; color: themeContext.geminiCoral }
                }
            }

            // 前後雙燈塔錨點
            Repeater {
                model: [clockContext.prevAnchorMin, clockContext.nextAnchorMin]
                Rectangle {
                    readonly property int anchorM: modelData
                    readonly property bool onBottom: (anchorM >= 240 && anchorM <= 480)
                    visible: onBottom

                    x: (1.0 - ((anchorM - 240) / 240.0)) * bottomContainer.width - (width / 2.0)
                    anchors.bottom: parent.bottom

                    width: (anchorM % 60 === 0) ? rootContext.tickM60_W : rootContext.tickM30_W
                    height: (anchorM % 60 === 0) ? rootContext.tickM60_H : rootContext.tickM30_H
                    color: (anchorM % 60 === 0) ? themeContext.hourColor : themeContext.halfHourColor
                    opacity: 0.95
                    antialiasing: false
                }
            }

            // 鬧鐘信標
            Rectangle {
                readonly property bool hasAlarm: rootContext.alarmEnabled && (rootContext.alarmHour % 12 >= 4 && rootContext.alarmHour % 12 <= 7)
                visible: hasAlarm
                anchors.bottom: parent.bottom
                width: 3; height: 3; radius: 1.5
                color: themeContext.alarmColor; opacity: rootContext.beaconPulse
                x: {
                    var aH = rootContext.alarmHour % 12
                    var hIdx = aH - 4
                    var prog = (hIdx + (rootContext.alarmMinute / 60.0)) / 4.0
                    return (1.0 - prog) * bottomContainer.width - 1.5
                }
            }

            // 時針流體水滴
            Item {
                id: bottomBeam
                readonly property int totMin: clockContext.totalMinutes
                readonly property bool inBottom: (totMin >= 225 && totMin <= 495)
                visible: inBottom
                anchors.bottom: parent.bottom
                height: bottomContainer.height
                width: bottomWin.expandedMode ? themeContext.beamBoostLength : themeContext.beamBaseLength

                x: {
                    var progress = (totMin - 240 + clockContext.currentSecond / 60.0) / 240.0
                    return (1.0 - progress) * bottomContainer.width - (bottomBeam.width / 2.0)
                }

                Shape {
                    id: bottomCurve
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: bottomBeam.width
                    height: bottomWin.expandedMode ? themeContext.beamBoostCurveHeight : themeContext.beamBaseCurveHeight
                    layer.enabled: true; layer.samples: 4
                    ShapePath {
                        strokeWidth: 0; fillColor: "transparent"; startX: 0; startY: bottomCurve.height
                        fillGradient: LinearGradient {
                            x1: bottomBeam.width; y1: 0; x2: 0; y2: 0
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: Math.max(0.1, 0.35 + rootContext.fluidShift); color: themeContext.geminiCoral }
                            GradientStop { position: Math.min(0.9, 0.65 + rootContext.fluidShift); color: themeContext.geminiGold }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        PathCubic {
                            x: bottomCurve.width; y: bottomCurve.height
                            control1X: bottomCurve.width * 0.3; control1Y: 0
                            control2X: bottomCurve.width * 0.7; control2Y: 0
                        }
                        PathLine { x: 0; y: bottomCurve.height }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: bottomBeam.width * 0.85; height: bottomWin.expandedMode ? 2 : 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: Math.max(0.05, 0.20 + rootContext.fluidShift); color: themeContext.geminiCoral }
                        GradientStop { position: Math.max(0.15, 0.38 + rootContext.fluidShift); color: themeContext.geminiGold }
                        GradientStop { position: Math.min(0.85, 0.50 + rootContext.fluidShift); color: themeContext.geminiWhite }
                        GradientStop { position: Math.min(0.90, 0.62 + rootContext.fluidShift); color: themeContext.geminiPurple }
                        GradientStop { position: Math.min(0.95, 0.80 + rootContext.fluidShift); color: themeContext.geminiCyan }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // ========================================================
            // 【底邊刻度矩陣】：巡天全開顯影 + 紅珀微星巨化 (唯一無重疊屬性)
            // ========================================================
            Repeater {
                model: 37
                Rectangle {
                    readonly property int deltaMin: index - 18
                    readonly property int centerMinuteOnEdge: (clockContext.currentHour % 12 - 4) * 60 + clockContext.currentMinute
                    readonly property int targetAbsMin: centerMinuteOnEdge + (index - 18)
                    readonly property int targetClockMin: ((targetAbsMin % 60) + 60) % 60

                    x: (1.0 - (targetAbsMin / 240.0)) * bottomContainer.width - (width / 2.0)
                    anchors.bottom: parent.bottom

                    readonly property real distToBeam: Math.abs(x + (width / 2.0) - (bottomBeam.x + bottomBeam.width / 2.0))
                    readonly property real distRatio: distToBeam / (bottomBeam.width / 2.0)

                    readonly property bool inEdge: (targetAbsMin >= 0 && targetAbsMin <= 240)
                    readonly property bool isSubMinute: (targetClockMin % 30 !== 0)

                    // 唯一 visible 屬性：巡天模式下無條件全開！
                    visible: inEdge && isSubMinute && (rootContext.inspectMode || distRatio <= 0.85)

                    // 唯一 opacity 屬性
                    opacity: rootContext.inspectMode ? 0.85 : Math.max(0.0, (1.0 - distRatio * 1.1) * 0.75)

                    width: (targetClockMin % 10 === 0) ? rootContext.tickM10_W : ((targetClockMin % 5 === 0) ? rootContext.tickM5_W : rootContext.tickM1_W)
                    height: (targetClockMin % 10 === 0) ? rootContext.tickM10_H :
                            ((targetClockMin % 5 === 0) ? rootContext.tickM5_H : rootContext.tickM1_H)
                    color: (deltaMin === 0) ? themeContext.dotColor : themeContext.tickColor
                    antialiasing: false

                    // 紅珀尋標微星：巡天模式下直徑瞬間擴展至 9px 巨星！
                    Rectangle {
                        visible: index === 18
                        width: rootContext.inspectMode ? themeContext.inspectDotSize : themeContext.dotSize
                        height: width
                        radius: width / 2.0
                        color: themeContext.dotColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 1
                    }
                }
            }
        }
    }
}
