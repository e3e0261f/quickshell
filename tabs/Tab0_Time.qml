import QtQuick

Column {
    id: tab0Root
    property var themeContext
    width: parent ? parent.width : 500
    spacing: 12

    Text {
        text: "● 雙燈塔光學導航與微刻度常駐中"
        color: themeContext.geminiCyan
        font.pixelSize: 11
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
