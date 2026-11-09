component TabCard {
    id: tabCard
    required property string title
    required property string icon
    required property bool expanded
    required property var contentVisible

    property string borderColor: "#3f3f46"
    property string accentColor: "#a1a1aa"

    width: parent.width
    height: expanded ? (contentVisible.childrenRect.height + 30) : 48
    radius: 8
    color: "#18181b"
    border.width: 1
    border.color: borderColor
    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    clip: true

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Row {
            width: parent.width
            Text { text: icon; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 8; height: 1 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: title; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
            }
            Item { width: parent.width - 290; height: 1 }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 70; height: 22; radius: 11
                color: "#1e3a5f"; border.width: 1; border.color: accentColor
                Text { anchors.centerIn: parent; text: "---"; color: accentColor; font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true }
            }
        }

        Item { id: content; anchors.fill: parent; visible: expanded; clip: true }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tabCard.expanded = !tabCard.expanded
    }
}
