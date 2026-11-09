#!/bin/bash
ACTION=$1

if [ "$ACTION" == "strike" ]; then
    TARGET_X=$2
    TARGET_Y=$3
    DRAG_MODE=$4
    SNAP_BACK=$5

    CUR_POS=$(hyprctl cursorpos 2>/dev/null)
    CUR_X=$(echo $CUR_POS | cut -d, -f1)
    CUR_Y=$(echo $CUR_POS | cut -d, -f2 | tr -d " ")

    if [ "$DRAG_MODE" == "true" ]; then
        ydotool click 0x40
        ydotool mousemove -a $TARGET_X $TARGET_Y
        sleep 0.02
        ydotool click 0x80
    else
        ydotool mousemove -a $TARGET_X $TARGET_Y
        ydotool click 0xC0
    fi

    if [ "$SNAP_BACK" == "true" ]; then
        sleep 0.01
        ydotool mousemove -a $CUR_X $CUR_Y
    fi
    exit 0
fi

if [ "$ACTION" == "auto_q" ]; then
    Q_LOCK="/tmp/q_spam.lock"
    while true; do
        if [ -f "$Q_LOCK" ]; then
            ydotool key 16:1 16:0
            sleep 0.05
        else
            sleep 0.05
        fi
    done
fi
