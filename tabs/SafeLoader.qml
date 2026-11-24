import QtQuick

Item {
    id: safeLoader
    property string cardTitle: ""
    property url source: ""
    property bool active: false
    readonly property alias item: innerLoader.item

    property var rootContext
    property var themeContext
    property var clockContext
    property var centerWin
    property var scriptRunner
    property var handleHistory
    property var netTelemetryProc
    property var volControl
    property var soundContext

    implicitWidth: innerLoader.item ? innerLoader.item.implicitWidth : 0
    implicitHeight: innerLoader.item ? innerLoader.item.implicitHeight : 0
    height: active ? implicitHeight : 0
    visible: active

    function reloadSource() {
        if (!active || !source || String(source) === "") {
            innerLoader.source = "";
            return;
        }
        innerLoader.setSource(source, {
            "rootContext": safeLoader.rootContext,
            "themeContext": safeLoader.themeContext,
            "clockContext": safeLoader.clockContext,
            "centerWin": safeLoader.centerWin,
            "scriptRunner": safeLoader.scriptRunner,
            "handleHistory": safeLoader.handleHistory,
            "netTelemetryProc": safeLoader.netTelemetryProc,
            "volControl": safeLoader.volControl,
            "soundContext": safeLoader.soundContext
        });
    }

    function syncProps() {
        if (!innerLoader.item) return;
        var it = innerLoader.item;
        if ("rootContext" in it) it.rootContext = safeLoader.rootContext;
        if ("themeContext" in it) it.themeContext = safeLoader.themeContext;
        if ("clockContext" in it) it.clockContext = safeLoader.clockContext;
        if ("centerWin" in it) it.centerWin = safeLoader.centerWin;
        if ("scriptRunner" in it) it.scriptRunner = safeLoader.scriptRunner;
        if ("handleHistory" in it) it.handleHistory = safeLoader.handleHistory;
        if ("netTelemetryProc" in it) it.netTelemetryProc = safeLoader.netTelemetryProc;
        if ("volControl" in it) it.volControl = safeLoader.volControl;
        if ("soundContext" in it) it.soundContext = safeLoader.soundContext;
    }

    onActiveChanged: reloadSource()
    onSourceChanged: reloadSource()
    Component.onCompleted: reloadSource()

    onRootContextChanged: syncProps()
    onThemeContextChanged: syncProps()
    onClockContextChanged: syncProps()
    onCenterWinChanged: syncProps()
    onHandleHistoryChanged: syncProps()
    onVolControlChanged: syncProps()
    onSoundContextChanged: syncProps()

    Loader {
        id: innerLoader
        width: safeLoader.width
        onLoaded: safeLoader.syncProps()
    }
}
