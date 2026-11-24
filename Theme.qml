import QtQuick

QtObject {
    id: theme

    // 基礎尺寸
    property int baseThickness: 1
    property int glowDepth: 14
    property real trackOpacity: 0.18
    property color alarmColor: "#38bdf8"

    // ========================================================
    // 【全局音效配置中心】：在這裏自由指定鬧鐘、整點和按鍵聲音！
    // ========================================================
    property string soundAlarm: "bell"                  // 鬧鐘相撞提示音
    property string soundChime: "audio-volume-change"   // 整點氣泡微音
    property string soundClick: "button-pressed"        // 按鍵機械觸感音
    property string soundVolume: "-12.0"                // 提示音量 (分貝)

    // ========================================================
    // 刻度尺寸與紅寶石尋標器（絕對物理靜止）
    // ========================================================
    property int m1_h: 5;         property int m1_w: 1
    property int m5_h: 6;         property int m5_w: 1
    property int m10_h: 7;        property int m10_w: 1
    property int m30_h: 5;        property int m30_w: 2
    property int m60_h: 6;        property int m60_w: 2

    // ⚡ 2x 翻倍尺寸
    property int boost_m1_h: 7;   property int boost_m1_w: 1
    property int boost_m5_h: 8;   property int boost_m5_w: 1
    property int boost_m10_h: 9;  property int boost_m10_w: 1
    property int boost_m30_h: 7;  property int boost_m30_w: 2
    property int boost_m60_h: 8;  property int boost_m60_w: 3

    // 紅寶石尋標圓點
    property int dotSize: 3
    property int inspectDotSize: 9
    property color dotColor: "#ef4444"

    property color tickColor: "#94a3b8"
    property color hourColor: "#ffffff"
    property color halfHourColor: "#fde047"

    // 鬧鐘參數
    property int defaultAlarmHour: 7
    property int defaultAlarmMinute: 30
    property int alarmHourStep: 1
    property int alarmMinuteStep: 5

    // 時針光體尺寸
    property int beamBaseLength: 320
    property int beamBoostLength: 580
    property real beamBaseCurveHeight: 6.0
    property real beamBoostCurveHeight: 11.0

    // Gemini 極光色系
    property color geminiCyan: "#38bdf8"
    property color geminiPurple: "#c084fc"
    property color geminiDark: "#27272a"
    property color geminiBlue: "#38bdf8"
    property color geminiIndigo: "#6366f1"
    property color geminiRose: "#f43f5e"
    property color geminiAmber: "#f59e0b"
    property color geminiWhite: "#ffffff"
    property color geminiGold: "#fde047"
    property color geminiCoral: "#fb7185"

    property int cornerSize: 24
    property int popupWidth: 280
    property int popupHeight: 240
    property color popupBg: "#cc141418"
}
