import QtQuick

Item {
    id: safeRoot
    property string source: ""
    property string cardTitle: "功能標籤"
    property var rootContext
    property var themeContext
    property var clockContext
    property var centerWin
    property var scriptRunner
    property var handleHistory
    property var netTelemetryProc

    width: parent ? parent.width : 530

    // 自然呼吸高度：就緒時取子項高度，出錯時取 46px 容錯框高
    implicitHeight: {
        if (loader.status === Loader.Ready && loader.item) {
            return loader.item.implicitHeight > 0 ? loader.item.implicitHeight : (loader.item.childrenRect.height > 0 ? loader.item.childrenRect.height : loader.item.height)
        }
        if (loader.status === Loader.Error) return 46
        return 0
    }

    Loader {
        id: loader
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        source: safeRoot.source

        // 成功載入才注入依賴，出錯絕不引發連環車禍
        onLoaded: {
            if (item) {
                if ("rootContext" in item) item.rootContext = safeRoot.rootContext;
                if ("themeContext" in item) item.themeContext = safeRoot.themeContext;
                if ("clockContext" in item) item.clockContext = safeRoot.clockContext;
                if ("centerWin" in item) item.centerWin = safeRoot.centerWin;
                if ("scriptRunner" in item) item.scriptRunner = safeRoot.scriptRunner;
                if ("handleHistory" in item) item.handleHistory = safeRoot.handleHistory;
                if ("netTelemetryProc" in item) item.netTelemetryProc = safeRoot.netTelemetryProc;
            }
        }
    }

    // 容錯降級界面：代碼有錯只亮此框，主體與時鐘絕不閃退
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.95
        height: 44
        radius: 8
        color: "#18181b"
        border.color: "#ef4444"
        border.width: 1
        visible: loader.status === Loader.Error

        Row {
            anchors.centerIn: parent
            spacing: 8
            Text { text: "⚠️"; font.pixelSize: 13 }
            Text {
                text: safeRoot.cardTitle + " 模組語法異常已自動隔離（主體正常運行中）"
                color: "#f87171"
                font.pixelSize: 10
                font.bold: true
            }
        }
    }
}
