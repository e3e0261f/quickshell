import QtQuick
import Quickshell

Item {
    id: tab0Root
    required property var rootContext
    required property var themeContext
    required property var clockContext

    anchors.fill: parent

    Column {
        anchors.fill: parent
        anchors.centerIn: parent
        spacing: 20

        // 探針矩陣
        Grid {
            columns: 5
            spacing: 10

            Repeater {
                model: [
                    { name: "Clock: Hour",    val: () => rootContext.clock.currentHour },
                    { name: "Clock: Minute",  val: () => rootContext.clock.currentMinute },
                    { name: "Clock: Second",  val: () => rootContext.clock.currentSecond },
                    { name: "Wifi: SSID",     val: () => rootContext.currentWifi },
                    { name: "IME: Status",    val: () => rootContext.currentIme },
                    { name: "Inspect Mode",   val: () => rootContext.inspectMode ? "ON" : "OFF" },
                    { name: "Boost Mode",     val: () => rootContext.isBoosted ? "ON" : "OFF" },
                    { name: "Drag Mode",      val: () => rootContext.dragDropEnabled ? "ON" : "OFF" },
                    { name: "Return Mode",    val: () => rootContext.cursorReturnEnabled ? "ON" : "OFF" },
                    { name: "Clicker: Active",val: () => rootContext.autoClickerActive ? "ON" : "OFF" },
                    { name: "Clicker: Btn",   val: () => rootContext.clickerButtonCode },
                    { name: "Strike Z: X",    val: () => rootContext.shiftZx },
                    { name: "Strike Z: Y",    val: () => rootContext.shiftZy },
                    { name: "Strike X: X",    val: mostRoot.shiftXx }, // 注意這裡如果不對請改回 rootContext
                    { name: "Strike X: Y",    val: () => rootContext.shiftXy },
                    { name: "Alarm: Enabled", val: () => rootContext.alarmEnabled ? "ON" : "OFF" },
                    { name: "Alarm: Hour",    val: () => rootContext.alarmHour },
                    { name: "Alarm: Minute",  val: () => rootContext.alarmMinute },
                    { name: "Beam: Width",    val: () => rootContext.beamBaseLength },
                    { name: "Beam: Height",   val: () => rootContext.beamBaseHeight }
                ]
                delegate: Item {
                    width: 60
                    height: 60

                    Rectangle {
                        id: probeBox
                        anchors.fill: parent
                        radius: 4
                        
                        property bool isHealthy: {
                            try {
                                var v = modelData.val();
                                return (v !== undefined && v !== null && !isNaN(v) || typeof v === "string");
                            } catch(e) {
                                return false;
                            }
                        }

                        color: isHealthy ? "#22c55e" : "#ef4444"
                        border.color: "white"
                        border.width: 1
                        opacity: 0.8

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: infoTooltip.visible = true
                            onExited: infoTooltip.visible = false
                        }

                        Rectangle {
                            id: infoTooltip
                            visible: mouseArea.containsMouse
                            width: 140
                            height: 40
                            color: "#1e293b"
                            border.color: "#38bdf8"
                            radius: 4
                            z: 100
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 5
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name + ": " + modelData.val()
                                color: "white"
                                font.pixelSize: 10
                            }
                        }
                        MouseArea { id: mouseArea; anchors.fill: parent }
                    }
                }
            }
        }
    }
}
