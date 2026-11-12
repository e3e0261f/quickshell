#!/bin/bash
LOCK="/tmp/caffeine_active"
COUNTDOWN_FILE="/tmp/sleep_countdown"
IDLE_COUNT=0
THRESHOLD=900  # 15 分鐘 = 900 秒

LAST_POS=""
LAST_WIN=""

# 內核級 + 應用級雙重媒體巡檢
is_media_active() {
    # 1. 內核級聲卡 PCM 流檢測 (只要耳機/喇叭有聲音輸出，必然為 RUNNING)
    if grep -q "state: RUNNING" /proc/asound/card*/pcm*p/sub*/status 2>/dev/null; then
        return 0
    fi

    # 2. MPRIS 播放器檢測 (Chrome / Firefox / MPV / VLC)
    if command -v playerctl >/dev/null 2>&1; then
        if playerctl -a status 2>/dev/null | grep -q "Playing"; then
            return 0
        fi
    fi

    return 1
}

while true; do
    sleep 2

    # 咖啡因開啟 (常醒無眠)，計時凍結
    if [ -f "$LOCK" ]; then
        IDLE_COUNT=0
        echo "900" > "$COUNTDOWN_FILE"
        continue
    fi

    # 媒體播放中 (YouTube / MPV / 語音)，計時凍結
    if is_media_active; then
        IDLE_COUNT=0
        echo "900" > "$COUNTDOWN_FILE"
        continue
    fi

    # 檢測鼠標指針座標與焦點窗口
    CUR_POS=$(hyprctl cursorpos 2>/dev/null)
    CUR_WIN=$(hyprctl activewindow -j 2>/dev/null | grep -m1 '"address"' | cut -d: -f2)

    if [ "$CUR_POS" == "$LAST_POS" ] && [ "$CUR_WIN" == "$LAST_WIN" ]; then
        IDLE_COUNT=$((IDLE_COUNT + 2))
        REMAIN=$((THRESHOLD - IDLE_COUNT))
        [ $REMAIN -lt 0 ] && REMAIN=0
        echo "$REMAIN" > "$COUNTDOWN_FILE"

        if [ $IDLE_COUNT -ge $THRESHOLD ]; then
            IDLE_COUNT=0
            echo "900" > "$COUNTDOWN_FILE"
            systemctl suspend
        fi
    else
        IDLE_COUNT=0
        LAST_POS="$CUR_POS"
        LAST_WIN="$CUR_WIN"
        echo "900" > "$COUNTDOWN_FILE"
    fi
done
