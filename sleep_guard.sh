#!/bin/bash
LOCK="/tmp/caffeine_active"
IDLE_COUNT=0
THRESHOLD=900  # 15 分鐘 = 900 秒 (每 5 秒檢測一次)

LAST_POS=""
LAST_WIN=""

# 檢測是否正在播放音視頻的函數
is_media_playing() {
    # 1. 檢測 MPRIS 媒體狀態 (支持 Chrome/Firefox/mpv/VLC 等)
    if command -v playerctl >/dev/null 2>&1; then
        if playerctl status 2>/dev/null | grep -q "Playing"; then
            return 0
        fi
    fi

    # 2. 兜底檢測：檢測 PipeWire/PulseAudio 是否有活躍的音頻輸出流 (防止部分網頁不註冊 MPRIS)
    if command -v pactl >/dev/null 2>&1; then
        if pactl list sink-inputs 2>/dev/null | grep -q "Corked: no"; then
            return 0
        fi
    fi

    return 1
}

while true; do
    sleep 5

    # 若咖啡因開啟 (常醒無眠)，計時歸零，絕不睡眠
    if [ -f "$LOCK" ]; then
        IDLE_COUNT=0
        continue
    fi

    # 若正在播放視頻或音頻，計時歸零，絕不睡眠
    if is_media_playing; then
        IDLE_COUNT=0
        continue
    fi

    # 檢測當前鼠標指針座標與焦點窗口句柄
    CUR_POS=$(hyprctl cursorpos 2>/dev/null)
    CUR_WIN=$(hyprctl activewindow -j 2>/dev/null | grep -m1 '"address"' | cut -d: -f2)

    # 若連續 15 分鐘完全沒有移動指針、沒有切換窗口，執行睡眠
    if [ "$CUR_POS" == "$LAST_POS" ] && [ "$CUR_WIN" == "$LAST_WIN" ]; then
        IDLE_COUNT=$((IDLE_COUNT + 5))
        if [ $IDLE_COUNT -ge $THRESHOLD ]; then
            IDLE_COUNT=0
            systemctl suspend
        fi
    else
        IDLE_COUNT=0
        LAST_POS="$CUR_POS"
        LAST_WIN="$CUR_WIN"
    fi
done
