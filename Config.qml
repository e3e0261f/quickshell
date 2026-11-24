import QtQuick

QtObject {
    id: config

    // ========================================================
    // 壹、 基礎幾何與窗口深度
    // ========================================================
    property int baseThickness: 1
    property int glowDepth: 14
    property int boostGlowDepth: 20
    property real trackOpacity: 0.18
    property int cornerSize: 24

    // ========================================================
    // 貳、 刻度矩陣與【紅珀尋標星】
    // ========================================================
    property int m1_h: 5;          property int m1_w: 1
    property int m5_h: 6;          property int m5_w: 1
    property int m10_h: 7;         property int m10_w: 1
    property int m30_h: 5;         property int m30_w: 2
    property int m60_h: 6;         property int m60_w: 2

    // ⚡ 2x 翻倍尺寸
    property int boost_m1_h: 7;    property int boost_m1_w: 1
    property int boost_m5_h: 8;    property int boost_m5_w: 1
    property int boost_m10_h: 9;   property int boost_m10_w: 1
    property int boost_m30_h: 7;   property int boost_m30_w: 2
    property int boost_m60_h: 8;   property int boost_m60_w: 3

    property color tickColor: "#94a3b8"
    property color hourColor: "#ffffff"
    property color halfHourColor: "#fde047"

    property int dotSize: 3
    property int inspectDotSize: 9
    property color dotColor: "#ef4444"

    // ========================================================
    // 叁、 時針流體水滴與【流光翻倍】開關
    // ========================================================
    property bool boostGlowDefault: false
    property string labelBoost: "⚡ 流光翻倍"
    property string labelAlarm: "📍 航標時鐘"

    property int beamBaseLength: 320
    property int beamBoostLength: 580
    property real beamBaseCurveHeight: 6.0
    property real beamBoostCurveHeight: 11.0

    property int wavePeriod1: 3200
    property int wavePeriod2: 1900
    property real waveAmp1: 0.09
    property real waveAmp2: 0.05

    // ========================================================
    // 肆、 航標時鐘
    // ========================================================
    property bool alarmEnabledDefault: true
    property int defaultAlarmHour: 7
    property int defaultAlarmMinute: 30
    property int alarmHourStep: 1
    property int alarmMinuteStep: 5
    property color alarmColor: "#38bdf8"

    // ========================================================
    // 伍、 音律韶樂配置
    // ========================================================
    property bool chimeEnabledDefault: true
    property string soundAlarm: "bell"
    property string soundChime: "audio-volume-change"
    property string soundClick: "button-pressed"
    property string soundVolume: "-12.0"

    // ========================================================
    // 陸、 色譜大觀
    // ========================================================
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

    // ========================================================
    // 柒、 中央巡天視界配置（默認放大尺寸）
    // ========================================================
    property color popupBg: "#cc141418"
    property bool defaultCardLarge: true
    property int centerHudW: 1040
    property int centerHudH: 720
}
