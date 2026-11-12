#!/bin/bash
LOCK="/tmp/caffeine_active"
IDLE_COUNT=0
THRESHOLD=900  # 15 分鐘 = 900 秒 (每 5 秒檢測一次)

LAST_POS=""
LAST_WIN=""

while true; do
    sleep 5

    # 若咖啡因開啟 (常醒無眠)，計時歸零，絕不睡眠
    if [ -f "$LOCK" ]; then
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
