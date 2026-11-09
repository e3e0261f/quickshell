import QtQuick
import Quickshell

ShellRoot {
    id: testRoot

    // 模拟原本需要的上下文数据
    QtObject {
        id: mockClock
        property int totalMinutes: 360 // 模拟中午 6 点
        property int currentHour: 6
        property int currentMinute: 0
        property int currentSecond: 0
    }

    QtObject {
        id: mockTheme
        property color tickColor: "red"
        property color dotColor: "blue"
        property real tickM1_W: 5
        property real tickM1_H: 10
        property real tickM5_W: 10
        property real tickM5_H: 20
        property real tickM10_W: 15
        property real tickM10_H: 30
    }

    // 模拟 rootContext 传递
    property int totalMinutes: mockClock.totalMinutes
    property real fluidShift: 0.0
    property bool inspectMode: false
    property bool boostGlow: false

    Window {
        visible: true
        width: 800
        height: 200
        title: "Scale Debugger"

        Rectangle {
            id: container
            anchors.fill: parent
            color: "#111" // 深色背景方便看红色的刻度

            Text {
                text: "Debug Mode: If you see RED lines, the math is working."
                color: "white"
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // 模拟原本的 Repeater 逻辑
            Repeater {
                model: 37
                Rectangle {
                    // 这里的逻辑必须和 EdgeBottom.qml 完全一致
                    readonly property int targetAbsMin: (index - 18) * 20 
                    readonly property int targetClockMin: ((targetAbsMin % 60) + 60) % 60

                    // 模拟原本的 x 计算
                    x: (1.0 - (targetAbsMin / 720.0)) * container.width - (width / 2.0)
                    anchors.bottom: parent.bottom

                    // 模拟原本的 distRatio 计算 (假设水滴在中心)
                    readonly property real distToCenter: Math.abs(x + (width / 2.0) - (container.width / 2.0))
                    readonly property real distRatio: distToCenter / (container.width / 2.0)

                    // 关键测试点：我们暂时把 visible 设为 true，把 opacity 设为 1
                    visible: true 
                    opacity: 1.0

                    width: (targetClockMin % 10 === 0) ? 15 : 5
                    height: 20
                    color: "red" // 使用醒目的红色
                    antialiasing: false

                    // 打印调试信息到控制台
                    Component.onCompleted: {
                        console.log("Index:", index, "AbsMin:", targetAbsMin, "X:", x, "Ratio:", distRatio)
                    }
                }
            }
        }
    }
}
